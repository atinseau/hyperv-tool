

$vmName = Read-Host "Enter vm name"
$vmUsername = Read-Host "Enter vm username"


$vm = Get-VM -Name $vmName
if ($vm.State -ne "Running") {
  Write-Host "VM is not running, starting it !"
  exit
}