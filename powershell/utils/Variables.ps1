$addressesFile = "$env:USERPROFILE\.addresses.json"
$sshKeyFile = "$env:USERPROFILE\.ssh\id_rsa.pub"
$hostsFile = "C:\Windows\System32\drivers\etc\hosts"
$bashDirectory = $PSScriptRoot.Replace("\powershell\utils", "\bash")
$toolDirectory = $PSScriptRoot.Replace("\powershell\utils", "\tools")
$gitDirectory = $PSScriptRoot.Replace("\powershell\utils", "")