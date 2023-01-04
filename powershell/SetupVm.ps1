# Import utils
. "$PSScriptRoot\utils\Function.ps1" 

# global variables
$addressesFile = "$env:USERPROFILE\.addresses.json"

# Setup variables
$username = Read-Host "Enter Vm username"
$ip = Read-Host "Enter Vm IP"

# Setup addresses file
$vm = Get-VM | Get-VMNetworkAdapter
if ($null -eq $vm) {
    Write-Error "Cannot find vm with ip $ip"
    exit
}

$windowsIp = GetSwtichHostIp $vm.SwitchName
Write-Output "{`"host`": `"$windowsIp`", `"vm`": `"$ip`"}" | Set-Content $addressesFile

# Setup ssh
Get-Content $env:USERPROFILE\.ssh\id_rsa.pub | ssh $username@$ip "cat >> .ssh/authorized_keys"

$postInstallScript = "W:\Projets\Digital-Etudes\1.Environnements et outils\Environnements\HyperV VM\bash\post-install.sh"

$windowsUsername = Read-Host "Enter windows username"
$windowsPassword = Read-Host "Enter windows password"


$setupProxy = Read-Host "Setup proxy (only if you have the vpn enabled)? (y/n)"

if ($setupProxy -eq "y") {
    $proxyFile = @"
Acquire::http::Proxy "http://${windowsUsername}:${windowsPassword}@prdproxyserv.groupe.lan:3128/";
Acquire::https::Proxy "http://${windowsUsername}:${windowsPassword}@prdproxyserv.groupe.lan:3128/";
"@
    Write-Output $proxyFile | ssh $username@$ip "cat > proxy.conf"
    ssh $username@$ip "sudo -S mv proxy.conf /etc/apt/apt.conf.d/proxy.conf"
}

ssh $username@$ip "sudo -S apt update -y; sudo -S apt upgrade -y; sudo -S apt install -y dos2unix"
Get-Content $postInstallScript | ssh $username@$ip 'cat > /tmp/post-install.sh && dos2unix /tmp/post-install.sh'


ssh $username@$ip "export WINDOWS_IP=$windowsIp; export WINDOWS_USERNAME=$windowsUsername; export WINDOWS_PASSWORD=$windowsPassword;chmod +x /tmp/post-install.sh && /tmp/post-install.sh"