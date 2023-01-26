# Import utils
. "$PSScriptRoot\utils\Function.ps1" 

$vmName = Read-Host "Enter vm name"

$hostFile = "C:\Windows\System32\drivers\etc\hosts"
$sshConfigFile = "$env:USERPROFILE\.ssh\config"
$addressesFile = "$env:USERPROFILE\.addresses.json"
$replaceIpScript = "W:\Projets\Digital-Etudes\1.Environnements et outils\Environnements\HyperV VM\bash\replace-ip.sh"


# Function to create addresses file
# if it does not exist, create it with vmName, vmIp and windowsIp object
# if it exist but is empty, create it with vmName, vmIp and windowsIp object
# if it exist, add vmName, vmIp and windowsIp object
Function PromptForAddressesFile {
    param (
        [Parameter(Mandatory = $true)]
        [string] $vmName,
        [Parameter(Mandatory = $true)]
        [string] $errorMessage
    )
    Write-Error "#########################################################"
    Write-Error $errorMessage
    Write-Error "It very important for replacing all old ip usage of windows and vm"
    Write-Error "Please create it at $addressesFile for automatic replacement"
    Write-Error "#########################################################"
    $createFile = Read-Host "Do you want to create it now ? (y/n)"
    if ($createFile -eq "y") {
        $vmIp = Read-Host "Enter old vm ip"
        if ([string]::IsNullOrEmpty($vmIp)) {
            Write-Error "Vm ip cannot be empty !"
            exit
        }

        $windowsIp = Read-Host "Enter old windows ip"
        if ([string]::IsNullOrEmpty($windowsIp)) {
            Write-Error "Windows ip cannot be empty !"
            exit
        }

        CreateAddressesFile `
            -vmName $vmName `
            -vmIp $vmIp `
            -windowsIp $windowsIp `
            -addressesFile $addressesFile
        Write-Host "Restarting script !"
    }
    else {
        Write-Host "Exiting script !"
    }
    exit
}


# Start script

# Get name and check if vm is running
$vm = Get-VM -Name $vmName
if ($vm.State -ne "Running") {
    Write-Error "VM is not running, starting it !"
    exit
}

# Check if addresses file exist (file with old vm and windows ip)
if ($true -ne (Test-Path $addressesFile -PathType leaf)) {
    PromptForAddressesFile `
        -vmName $vmName `
        -errorMessage "Addresses file does not exist !"
}

$addresses = (Get-Content $addressesFile) | ConvertFrom-Json

# Check if addresses file is empty or invalid
if ([string]::IsNullOrEmpty($addresses)) {
    PromptForAddressesFile `
        -vmName $vmName `
        -errorMessage "Addresses file is empty or invalid !"
    exit
}

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

# Get old addresses for asked vm name
$currentVmAddresses = $addresses | Select-Object -ExpandProperty $vmName -ErrorAction SilentlyContinue

# Check if vm is not in addresses file
if ([string]::IsNullOrEmpty($currentVmAddresses)) {
    PromptForAddressesFile `
        -vmName $vmName `
        -errorMessage "Vm is not in addresses file !"
    exit
}

#old ip
$oldVmIp = $currentVmAddresses.vm
$oldHostIp = $currentVmAddresses.host

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
$authorizedKeys = (ssh $username@$newVmIp "cat .ssh/authorized_keys 2> /dev/null")
if ([string]::IsNullOrEmpty($authorizedKeys) -or (Get-Content $env:USERPROFILE\.ssh\id_rsa.pub | Select-String -Pattern "$authorizedKeys" -SimpleMatch -Quiet) -ne $true) {
    Write-Host "  -  [vm:authorized_keys] at .ssh/authorized_keys"
    Get-Content $env:USERPROFILE\.ssh\id_rsa.pub | ssh $username@$newVmIp "cat >> .ssh/authorized_keys"
}

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
