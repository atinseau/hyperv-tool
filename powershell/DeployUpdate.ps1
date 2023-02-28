param (
  [string] $Action = "deploy",
  [string] $UpdateName,
  [string] $UpdateId,
  [string] $Ignore = $null,
  [string] $Only = $null
)

# Import utils
. "$PSScriptRoot\utils\Function.ps1"

# Global variables
$updatesDirectory = $bashDirectory + "\updates"
$id = Get-Date -Format "ddMMyyHHmmss"

if ($Action -eq "create") {
  if ([string]::IsNullOrEmpty($UpdateName)) {
    Write-Error "You must provide a name for the update !"
    exit
  }
  $fixedUpdateName = $UpdateName.Replace(" ", "_")
  $fileName = "$id-$fixedUpdateName.sh"
  $updatesPath = $updatesDirectory + "\$fileName"
  New-Item -ItemType File -Path $updatesPath -Force | Out-Null
  "#!/bin/bash" | Out-File -FilePath $updatesPath -Append
  Write-Host "Update created at $updatesPath"
  exit
}

$vmName, $vmUsername, $vm =  VmPrompt `
    -AskForVmIp $false

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


# Get updates
$updates = Get-ChildItem -Path $updatesDirectory  -Filter "*.sh" -Recurse

$updateToPush = @()

$updates | ForEach-Object {
  $id = $_.Name -split "-" | Select-Object -First 1
  
  if ([string]::IsNullOrEmpty($Ignore) -eq $false) {
    $ignoredIds = $Ignore -split ","
    if ($ignoredIds -contains $id) {
      Write-Host "Ignoring update $id"
      return
    }
  }

  if ([string]::IsNullOrEmpty($Only) -eq $false -and $Only -ne $id) {
    Write-Host "Skipping update $id"
    return
  }

  # find id in registry
  $alreadyInstalled = $updateRegistry | Select-Object -ExpandProperty $id -ErrorAction SilentlyContinue
  if ($null -eq $alreadyInstalled -or $alreadyInstalled -eq $false) {
    
    [hashtable]$objectProperty = @{}
    $objectProperty.Add('Hash', $id)
    $objectProperty.Add('Path', $_)

    $object = New-Object -TypeName psobject -Property $objectProperty
    $updateToPush += $object
  }
}

Write-Host "You will install this updates:"
Write-Host "" # line break
Write-Host ($updateToPush | Format-Table | Out-String).Trim()
Write-Host "" # line break
Write-Host "You can ignore some packages by using the -Ignore <hash(,)>"
Write-Host "You can only install some packages by using the -Only <hash>"
$confirm = Read-Host "Do you want to continue ? (y/n)"

if ($confirm -ne "y") {
  Write-Host "Aborting..."
  exit
}

if ($updateToPush.Count -ge 1) {
  Write-Host "Updates to push: $($updateToPush.Count)"
  ssh $vmUsername@$vmIp "rm -rf /tmp/updates; mkdir -p /tmp/updates"
  Get-Content ($bashDirectory + "\" + "update-pusher.sh") | ssh $vmUsername@$vmIp "cat > /tmp/update-pusher.sh; dos2unix -q /tmp/update-pusher.sh; chmod +x /tmp/update-pusher.sh;"
  # Transfer updates to vm

  $updateToPush | Sort-Object -Property Hash | ForEach-Object {
    $updatePath = $updatesDirectory + "\" + $_.Path
    Write-Host "Transferring update $($_.Hash) from $($_.Path) to vm..."
    Get-Content $updatePath | ssh $vmUsername@$vmIp "cat > /tmp/updates/$($_.Path); dos2unix -q /tmp/updates/$($_.Path); chmod +x /tmp/updates/$($_.Path);"
  }

  # Create snapshot before update vm
  Checkpoint-VM -Name $vmName -SnapshotName "BeforeUpdate-$id"

  # Execute update pusher
  Write-Host "Executing updates..."
  ssh -t $vmUsername@$vmIp "sudo /tmp/update-pusher.sh `$HOME `$USER $vmIp $hostIp"

  if ($LASTEXITCODE -ne 0) {
    Remove-VMSnapshot -VMName $vmName -Name "BeforeUpdate-$id"
    Write-Error "Update failed !"
  }


} else {
  Write-Host "No updates to push !"
  exit
}
