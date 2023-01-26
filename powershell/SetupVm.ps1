# Import utils
. "$PSScriptRoot\utils\Function.ps1" 

# global variables
$addressesFile = "$env:USERPROFILE\.addresses.json"
$sshKeyFile = "$env:USERPROFILE\.ssh\id_rsa.pub"
$hostsFile = "C:\Windows\System32\drivers\etc\hosts"

# Setup variables
$vmName = Read-Host "Enter Vm name"
if ($null -eq $vmName) {
    Write-Error "No vm name provided"
    exit
}

$username = Read-Host "Enter Vm username"
if ($null -eq $username) {
    Write-Error "No username provided"
    exit
}


$ip = Read-Host "Enter Vm IP"
if ($null -eq $ip) {
    Write-Error "No ip provided"
    exit
}

# Setup addresses file
$vm = Get-VM -Name $vmName
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
$ip $alias
"@
    Write-Output $aliasFile | Add-Content $hostsFile
    Write-Host "Alias created in hosts file"
}

# Setup ssh
if ($true -ne (Test-Path $sshKeyFile -PathType leaf)) {
    ssh-keygen
}
Get-Content $sshKeyFile | ssh $username@$ip "cat >> .ssh/authorized_keys"

$postInstallScript = "W:\Projets\Digital-Etudes\1.Environnements et outils\Environnements\HyperV VM\bash\post-install.sh"
$netplanConfig = "W:\Projets\Digital-Etudes\1.Environnements et outils\Environnements\HyperV VM\conf\00-installer-config.yaml"
$ogfProxyFile = "W:\Projets\Digital-Etudes\1.Environnements et outils\Environnements\HyperV VM\conf\ogf-proxy.sh"

$windowsUsername = Read-Host "Enter windows username"
$windowsPassword = Read-Host "Enter windows password"

# DEPRECATED
# $setupProxy = Read-Host "Setup proxy (only if you have the vpn enabled)? (y/n)"
# if ($setupProxy -eq "y") {
#     $proxyFile = @"
# Acquire::http::Proxy "http://${windowsUsername}:${windowsPassword}@prdproxyserv.groupe.lan:3128/";
# Acquire::https::Proxy "http://${windowsUsername}:${windowsPassword}@prdproxyserv.groupe.lan:3128/";
# "@
#     Write-Output $proxyFile | ssh $username@$ip "cat > proxy.conf"
#     ssh $username@$ip "sudo -S mv proxy.conf /etc/apt/apt.conf.d/proxy.conf"
# }

ssh $username@$ip "sudo -S apt update -y; sudo -S apt upgrade -y; sudo -S apt install -y dos2unix"

Get-Content $postInstallScript | ssh $username@$ip 'cat > /tmp/post-install.sh && dos2unix /tmp/post-install.sh'
Get-Content $netplanConfig | ssh $username@$ip 'cat > /tmp/00-installer-config.yaml && dos2unix /tmp/00-installer-config.yaml'
Get-Content $ogfProxyFile | ssh $username@$ip 'cat > /tmp/ogf-proxy.sh && dos2unix /tmp/ogf-proxy.sh'

ssh $username@$ip "export VM_IP=$ip;export WINDOWS_IP=$windowsIp; export WINDOWS_USERNAME=$windowsUsername; export WINDOWS_PASSWORD=$windowsPassword;chmod +x /tmp/post-install.sh && /tmp/post-install.sh"

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
    if ($defaultSwitchIp -ne $null) {
        $running = $false
        $hostContent = Get-Content $hostsFile
        $hostContent = $hostContent -replace $ip, $defaultSwitchIp
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