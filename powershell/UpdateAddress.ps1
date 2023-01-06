# Import utils
. "$PSScriptRoot\utils\Function.ps1" 

$vmName = Read-Host "Enter vm name"

$hostFile = "C:\Windows\System32\drivers\etc\hosts"
$sshConfigFile = "$env:USERPROFILE\.ssh\config"
$addressesFile = "$env:USERPROFILE\.addresses.json"
$replaceIpScript = "W:\Projets\Digital-Etudes\1.Environnements et outils\Environnements\HyperV VM\bash\replace-ip.sh"

$vm = Get-VM -Name $vmName
if ($vm.State -ne "Running") {
    Write-Host "VM is not running, starting it !"
    exit
}

if ($true -ne (Test-Path $addressesFile -PathType leaf)) {
    Write-Host "#########################################################"
    Write-Host "Cannot find addresses file !"
    Write-Host "It very important for replacing all old ip usage of windows and vm"
    Write-Host "Please create it at $addressesFile for automatic replacement"
    Write-Host 'Format: {"host": "<old_windows_ip>", "vm": "<old_vm_ip>"}'
    Write-Host "#########################################################"

    $createFile = Read-Host "Do you want to create it now ? (y/n)"

    if ($createFile -eq "y") {
        $vmIp = Read-Host "Enter old vm ip"
        $windowsIp = Read-Host "Enter old windows ip"
        Write-Output "{`"host`": `"$windowsIp`", `"vm`": `"$vmIp`"}" > $addressesFile
        Write-Host "File created !"
        Write-Host "Restarting script !"
    }
    else {
        Write-Host "Exiting script !"
    }
    exit
}

$addresses = (Get-Content $addressesFile) | ConvertFrom-Json

if ([string]::IsNullOrEmpty($addresses)) {
    Write-Host "Addresses file is empty or invalid !"
    exit
}

$vmNetAdapters = Get-VMNetworkAdapter -VMName $vm.Name

# if ($vmNetAdapters.Length -ne 2) {
#     Throw "This vm does not have the mandatory switch, Bridge and Default Switch !"
# }

# Get internal default switch (use for connectivity inside vm)
# $defaultAdapter = $vmNetAdapters | Where-Object -FilterScript {$_.SwitchName -eq "Default Switch"}
# if ($null -eq $defaultAdapter) {
    # Throw "This vm does not have 'Default Switch' in his adapter"
# }

# Get external bridge switch (use for windows share)
$bridgeAdapter = $vmNetAdapters | Where-Object -FilterScript {$_.SwitchName -eq "Bridge"}
if ($null -eq $bridgeAdapter) {
    Throw "This vm does not have 'Bridge' in his adapter"
}

#old ip
$oldVmIp = $addresses.vm
$oldHostIp = $addresses.host

# new ip, use for the replacement
$newVmIp = $bridgeAdapter.IPAddresses[0]
$newHostIp = GetSwtichHostIp -Name $bridgeAdapter.SwitchName


if ($addresses.vm -eq $newVmIp -and $addresses.host -eq $newHostIp) {
    Write-Host "No ip change detected !"
    exit
}

Write-Host "VM ip:" $addresses.vm " => " $newVmIp
Write-Host "Windows ip:" $addresses.host " => " $newHostIp


Write-Host "Starting replacing..."

# Update hosts in windows
Write-Host "  -  [windows:hosts] at $hostFile"
$hostContent = Get-Content $hostFile
$hostContent = $hostContent -replace $addresses.vm, $newVmIp
$hostContent | Set-Content $hostFile

# Update ssh config in windows
if (Test-Path $sshConfigFile -PathType leaf) {
    Write-Host "  -  [windows:config] at $sshConfigFile"
    $sshConfigContent = Get-Content $sshConfigFile
    $sshConfigContent = $sshConfigContent -replace $addresses.vm, $newVmIp
    $sshConfigContent | Set-Content $sshConfigFile
}

$username = Read-Host "Enter vm username"

# FIX SSH AUTHORIZED KEYS IN VM
$authorizedKeys = (ssh $username@$newVmIp "cat .ssh/authorized_keys 2> /dev/null")
if ([string]::IsNullOrEmpty($authorizedKeys) -or (Get-Content $env:USERPROFILE\.ssh\id_rsa.pub | Select-String -Pattern "$authorizedKeys" -SimpleMatch -Quiet) -ne $true) {
    Write-Host "  -  [vm:authorized_keys] at .ssh/authorized_keys"
    Get-Content $env:USERPROFILE\.ssh\id_rsa.pub | ssh $username@$newVmIp "cat >> .ssh/authorized_keys"
}

# Start update ip script in vm
Get-Content $replaceIpScript | ssh $username@$newVmIp "cat > /tmp/replace-ip.sh; dos2unix /tmp/replace-ip.sh; chmod +x /tmp/replace-ip.sh;"
ssh $username@$newVmIp "/tmp/replace-ip.sh ${oldHostIp} ${newHostIp} ${oldVmIp} ${newVmIp}"

Write-Host "Updating addresses file..."

$addresses.host = $newHostIp
$addresses.vm = $newVmIp
$addresses | ConvertTo-Json | Set-Content $addressesFile

Write-Host "Done !"