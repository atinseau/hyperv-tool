param (
  [string] $Action = "deploy",
  [string] $UpdateName,
  [string] $UpdateId
)

# Import utils
. "$PSScriptRoot\utils\Function.ps1"

# Global variables
$updatesDirectory = $bashDirectory + "\updates"

if ($Action -eq "create") {
  if ([string]::IsNullOrEmpty($UpdateName)) {
    Write-Error "You must provide a name for the update !"
    exit
  }
  $id = Get-Date -Format "ddMMyyHHmmss"
  $fixedUpdateName = $UpdateName.Replace(" ", "_")
  $fileName = "$id-$fixedUpdateName.sh"
  $updatesPath = $updatesDirectory + "\$fileName"
  New-Item -ItemType File -Path $updatesPath -Force | Out-Null
  "#!/bin/bash" | Out-File -FilePath $updatesPath -Append
  Write-Host "Update created at $updatesPath"
  exit
}

$vmName, $vmUsername, $vm =  VmPrompt `
    -AskForVmIp $false `
    -AskForVmName $false `
    -AskForVmUsername $false `
    -vmName "Ogf-ubuntu" `
    -vmUsername "arthur"

if ($vmUsername -eq "root") {
  Write-Error "You can't use root user !"
  exit
}

$vmIp, $hostIp = GetCurrentVmIpConfig -vmName $vmName

FixAuthorizedKeys `
    -vmUsername $vmUsername `
    -vmIp $vmIp


# Get update registry
$updateRegistryRaw = (ssh $vmUsername@$vmIp "cat .installed 2> /dev/null")

if ([string]::IsNullOrEmpty($updateRegistryRaw) -or $updateRegistryRaw -eq "installed") {
  Write-Host "Registry is empty, setting up registry..."
  $updateRegistryRaw = "{}"
  ssh $vmUsername@$vmIp "echo '$updateRegistryRaw' > .installed"
}

# Convert registry to json
$updateRegistry =  $updateRegistryRaw | ConvertFrom-Json

$updateToPush = @()

# Get updates
$updates = Get-ChildItem -Path $updatesDirectory  -Filter "*.sh" -Recurse

$updates | ForEach-Object {
  $id = $_.Name -split "-" | Select-Object -First 1

  # find id in registry
  $alreadyInstalled = $updateRegistry | Select-Object -ExpandProperty $id -ErrorAction SilentlyContinue

  if ($null -eq $alreadyInstalled -or $alreadyInstalled -eq $false) {
    $updateToPush += $_
  }
}

if ($updateToPush.Count -ge 1) {
  Write-Host "Updates to push: $($updateToPush.Count)"
  ssh $vmUsername@$vmIp "rm -rf /tmp/updates; mkdir -p /tmp/updates"
  Get-Content ($bashDirectory + "\" + "update-pusher.sh") | ssh $vmUsername@$vmIp "cat > /tmp/update-pusher.sh; dos2unix -q /tmp/update-pusher.sh; chmod +x /tmp/update-pusher.sh;"
  # Transfer updates to vm
  $updateToPush | ForEach-Object {
    $updatePath = $updatesDirectory + "\" + $_.Name
    Write-Host "Transferring update $($_.Name) to vm..."
    Get-Content $updatePath | ssh $vmUsername@$vmIp "cat > /tmp/updates/$($_.Name); dos2unix -q /tmp/updates/$($_.Name); chmod +x /tmp/updates/$($_.Name);"
  }

  # Execute update pusher
  Write-Host "Executing updates..."
  ssh -t $vmUsername@$vmIp "/tmp/update-pusher.sh"

} else {
  Write-Host "No updates to push !"
  exit
}
