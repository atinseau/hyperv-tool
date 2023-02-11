# Import utils
. "$PSScriptRoot\utils\Function.ps1" 

$vmName = Read-Host "Enter vm name"

$hostFile = "C:\Windows\System32\drivers\etc\hosts"
$sshConfigFile = "$env:USERPROFILE\.ssh\config"
$replaceIpScript = "W:\Projets\Digital-Etudes\1.Environnements et outils\Environnements\HyperV VM\bash\replace-ip.sh"





# Start script

# Get name and check if vm is running
$vm = Get-VM -Name $vmName
if ($vm.State -ne "Running") {
    Write-Host "VM is not running, starting it !"
    exit
}

# Get old ip config (vm and host) in .addresses.json
$oldVmIp, $oldHostIp = GetCurrentVmIpConfig


$vmNetAdapters = Get-VMNetworkAdapter -VMName $vm.Name
if ($vmNetAdapters.Length -ne 2) {
    Throw "This vm does not have the mandatory switch, Bridge and Default Switch !"
}

#Get internal default switch (use for connectivity inside vm)
$defaultAdapter = $vmNetAdapters | Where-Object -FilterScript {$_.SwitchName -eq "Default Switch"}
if ($null -eq $defaultAdapter) {
    Throw "This vm does not have 'Default Switch' in his adapter"
}

# Get external bridge switch (use for windows share)
$bridgeAdapter = $vmNetAdapters | Where-Object -FilterScript {$_.SwitchName -eq "Bridge"}
if ($null -eq $bridgeAdapter) {
    Throw "This vm does not have 'Bridge' in his adapter"
}

# new ip, use for the replacement
$newVmIp = $defaultAdapter.IPAddresses[0]
$newHostIp = GetSwitchHostIp -Name $bridgeAdapter.SwitchName


if ($oldVmIp -eq $newVmIp -and $oldHostIp -eq $newHostIp) {
    Write-Host "No ip change detected !"
    exit
}

Write-Host "VM ip:" $oldVmIp " => " $newVmIp
Write-Host "Windows ip:" $oldHostIp " => " $newHostIp


Write-Host "Starting replacing..."

# Update hosts in windows
Write-Host "  -  [windows:hosts] at $hostFile"
$hostContent = Get-Content $hostFile
$hostContent = $hostContent -replace $oldVmIp, $newVmIp
$hostContent | Set-Content $hostFile

# Update ssh config in windows
if (Test-Path $sshConfigFile -PathType leaf) {
    Write-Host "  -  [windows:config] at $sshConfigFile"
    $sshConfigContent = Get-Content $sshConfigFile
    $sshConfigContent = $sshConfigContent -replace $oldVmIp, $newVmIp
    $sshConfigContent | Set-Content $sshConfigFile
}

$username = Read-Host "Enter vm username"

# FIX SSH AUTHORIZED KEYS IN VM
FixAuthorizedKeys `
    -vmUsername $username `
    -vmIp $newVmIp

# Start update ip script in vm
Get-Content $replaceIpScript | ssh $username@$newVmIp "cat > /tmp/replace-ip.sh; dos2unix /tmp/replace-ip.sh; chmod +x /tmp/replace-ip.sh;"
ssh $username@$newVmIp "/tmp/replace-ip.sh ${oldHostIp} ${newHostIp} ${oldVmIp} ${newVmIp}"

Write-Host "Updating addresses file..."

$addresses.PSObject.Properties | ForEach-Object {
    if ($_.Name -eq $vmName) {
        $_.Value.host = $newHostIp
        $_.Value.vm = $newVmIp
    }
}

$addresses | ConvertTo-Json | Set-Content $addressesFile
Write-Host "Done!"
