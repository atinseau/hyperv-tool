# Import utils
. "$PSScriptRoot\utils\Function.ps1" 

# global variables
$sshKeyFile = "$env:USERPROFILE\.ssh\id_rsa.pub"
$hostsFile = "C:\Windows\System32\drivers\etc\hosts"

# Get vm info and credentials
$vmName, $vmUsername, $vmIp, $vm = VmPrompt

$snapshot = Get-VMSnapshot -Name 'BeforeSetupVm' -VMName $vmName -ErrorAction SilentlyContinue
if ($null -eq $snapshot) {
    Checkpoint-VM -Name $vmName -SnapshotName BeforeSetupVm
} else {
    Write-Host "Snapshot already exists"
}

$vmBridge = $vm | Get-VMNetworkAdapter | Where-Object { $_.SwitchName -eq "Bridge" }
if ($null -eq $vmBridge) {
    Write-Error "No VM with bridge network adapter found"
    exit
}

$windowsIp = GetSwitchHostIp $vmBridge.SwitchName

# Attach default switch to vm
$vmDefault = $vm | Get-VMNetworkAdapter | Where-Object { $_.SwitchName -eq "Default Switch" }
if ($null -eq $vmDefault) {
    $vm | Add-VMNetworkAdapter -SwitchName "Default Switch"
} else {
    Write-Host "Default switch already attached to vm"
}

# Create alias in hosts file
$createAlias = Read-Host "Create alias in hosts file? (y/n)"
if ($createAlias -eq "y") {
    $alias = Read-Host "Enter alias for $vmName"
    if ($null -eq $alias) {
        Write-Error "No alias provided"
        exit
    }
    if (Get-Content $hostsFile | Select-String -Pattern $alias) {
        Write-Error "Alias already exists in hosts file"
        exit
    }
    $aliasFile = @"
$vmIp $alias
"@
    Write-Output $aliasFile | Add-Content $hostsFile
    Write-Host "Alias created in hosts file"
}

# Setup ssh
if ($true -ne (Test-Path $sshKeyFile -PathType leaf)) {
    ssh-keygen
}
Get-Content $sshKeyFile | ssh $vmUsername@$vmIp "cat >> .ssh/authorized_keys"

$postInstallScript = $bashDirectory + "\post-install.sh"
$workspaceConfig = $confDirectory + "\workspace_config.yaml"
$noWifiConfig = $confDirectory + "\no_wifi_config.yaml"
$ogfProxyFile = $confDirectory + "\ogf-proxy.sh"


$windowsUsername = Read-Host "Enter windows username"
$windowsPassword = Read-Host "Enter windows password"

ssh -t $vmUsername@$vmIp "sudo -S apt update -y; sudo -S apt install -y dos2unix"

# DEPRECATED
$proxyFile = @"
Acquire::http::Proxy "http://${windowsUsername}:${windowsPassword}@prdproxyserv.groupe.lan:3128/";
Acquire::https::Proxy "http://${windowsUsername}:${windowsPassword}@prdproxyserv.groupe.lan:3128/";
"@
Write-Output $proxyFile | ssh $vmUsername@$vmIp "cat > /tmp/proxy.conf && dos2unix /tmp/proxy.conf"

Get-Content $postInstallScript | ssh $vmUsername@$vmIp 'cat > /tmp/post-install.sh && dos2unix /tmp/post-install.sh'
Get-Content $workspaceConfig | ssh $vmUsername@$vmIp 'cat > /tmp/workspace_config.yaml && dos2unix /tmp/workspace_config.yaml'
Get-Content $noWifiConfig | ssh $vmUsername@$vmIp 'cat > /tmp/no_wifi_config.yaml && dos2unix /tmp/no_wifi_config.yaml'
Get-Content $ogfProxyFile | ssh $vmUsername@$vmIp 'cat > /tmp/ogf-proxy.sh && dos2unix /tmp/ogf-proxy.sh'

ssh -t $vmUsername@$vmIp "chmod +x /tmp/post-install.sh && sudo -S /tmp/post-install.sh `$HOME `$USER $vmIp $windowsIp $windowsUsername $windowsPassword"

Restart-VM -Name $vmName -Force

# Waiting for vm to start and replacing Bridge ip by Default Switch ip in hosts file
# and creating addresses file for UpdateAddresses.ps1
$running = $true
while ($running) {
    $vm = Get-VM -Name $vmName
    if ($vm.State -eq "Running") {
        $running = $false
        break
    }
    Write-Host "Waiting for vm to start..."
    Start-Sleep -Seconds 1
}

$running = $true
while ($running) {
    $vm = Get-VM -Name $vmName
    $defaultSwitch = $vm | Get-VMNetworkAdapter | Where-Object { $_.SwitchName -eq "Default Switch" }
    $defaultSwitchIp = $defaultSwitch.IPAddresses[0]
    if ($null -ne $defaultSwitchIp) {
        $running = $false
        $hostContent = Get-Content $hostsFile

        # Backup hosts file
        $hostContent | Set-Content $env:USERPROFILE\hosts.bak

        $hostContent = $hostContent -replace $vmIp, $defaultSwitchIp
        $hostContent | Set-Content $hostsFile

        CreateAddressesFile `
            -vmName $vmBridge.VMName `
            -vmIp $defaultSwitchIp `
            -windowsIp $windowsIp `
            -addressesFile $addressesFile
        break
    }
    Write-Host "Waiting for ip..."
    Start-Sleep -Seconds 1
}


$snapshot = Get-VMSnapshot -Name 'AfterSetupVm' -VMName $vmName -ErrorAction SilentlyContinue
if ($null -ne $snapshot) {
    Remove-VMSnapshot -Name 'AfterSetupVm' -VMName $vmName -Confirm:$false
}
Checkpoint-VM -Name $vmName -SnapshotName AfterSetupVm

Write-Host "Done !"
