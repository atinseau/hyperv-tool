# Import utils
. "$PSScriptRoot\utils\Global.ps1" 

$sshConfigFile = "$env:USERPROFILE\.ssh\config"
$replaceIpScript = $bashDirectory + "\replace-ip.sh"

$vmName, $vm = VmPrompt `
    -AskForVmUsername $false `
    -AskForVmIp $false

# Get old ip config (vm and host) in .addresses.json
$oldVmIp, $oldHostIp, $addresses = GetCurrentVmIpConfig -vmName $vmName

$vmNetAdapters = Get-VMNetworkAdapter -VMName $vm.Name

# Get external bridge switch
$bridgeAdapter = $vmNetAdapters | Where-Object -FilterScript {$_.SwitchName -eq "Bridge"}
if ($null -eq $bridgeAdapter) {
    Throw "This vm does not have 'Bridge' in his adapter"
}

# new ip, use for the replacement
$newVmIp = $bridgeAdapter.IPAddresses[0]
$newHostIp = GetSwitchHostIp -Name $bridgeAdapter.SwitchName

if ($oldVmIp -eq $newVmIp -and $oldHostIp -eq $newHostIp) {
    Write-Host "No ip change detected !"
    exit
}

Write-Host "VM ip:" $oldVmIp " => " $newVmIp
Write-Host "Windows ip:" $oldHostIp " => " $newHostIp

Write-Host "Starting replacing..."

# Update hosts in windows
Write-Host "  -  [windows:hosts] at $hostsFile"
$hostContent = Get-Content $hostsFile

# Create backup
$hostContent | Set-Content $env:USERPROFILE\hosts.bak

$hostContent = $hostContent -replace $oldVmIp, $newVmIp
$hostContent | Set-Content $hostsFile

# Update ssh config in windows
if (Test-Path $sshConfigFile -PathType leaf) {
    Write-Host "  -  [windows:config] at $sshConfigFile"
    $sshConfigContent = Get-Content $sshConfigFile
    $sshConfigContent = $sshConfigContent -replace $oldVmIp, $newVmIp
    $sshConfigContent | Set-Content $sshConfigFile
}

$username = WhilePrompt -Prompt "Enter vm username" -errorMessage "No vm username provided"

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
