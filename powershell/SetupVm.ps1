# Import utils
. "$PSScriptRoot\utils\Function.ps1" 

# global variables
$sshKeyFile = "$env:USERPROFILE\.ssh\id_rsa.pub"
$hostsFile = "C:\Windows\System32\drivers\etc\hosts"

# Get vm info and credentials
$vmName, $vmUsername, $vmIp, $vm = VmPrompt


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

$postInstallScript = "W:\Projets\Digital-Etudes\1.Environnements et outils\Environnements\HyperV VM\bash\post-install.sh"
$netplanConfig = "W:\Projets\Digital-Etudes\1.Environnements et outils\Environnements\HyperV VM\conf\00-installer-config.yaml"
$ogfProxyFile = "W:\Projets\Digital-Etudes\1.Environnements et outils\Environnements\HyperV VM\conf\ogf-proxy.sh"

$windowsUsername = Read-Host "Enter windows username"
$windowsPassword = Read-Host "Enter windows password"

ssh $vmUsername@$vmIp "sudo -S apt update -y; sudo -S apt upgrade -y; sudo -S apt install -y dos2unix"

Get-Content $postInstallScript | ssh $vmUsername@$vmIp 'cat > /tmp/post-install.sh && dos2unix /tmp/post-install.sh'
Get-Content $netplanConfig | ssh $vmUsername@$vmIp 'cat > /tmp/00-installer-config.yaml && dos2unix /tmp/00-installer-config.yaml'
Get-Content $ogfProxyFile | ssh $vmUsername@$vmIp 'cat > /tmp/ogf-proxy.sh && dos2unix /tmp/ogf-proxy.sh'

ssh $vmUsername@$vmIp "export VM_IP=$vmIp;export WINDOWS_IP=$windowsIp; export WINDOWS_USERNAME=$windowsUsername; export WINDOWS_PASSWORD=$windowsPassword;chmod +x /tmp/post-install.sh && /tmp/post-install.sh"

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

Write-Host "Done !"