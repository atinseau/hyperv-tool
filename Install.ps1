function AddPath($Path) {
  $oldPath = [Environment]::GetEnvironmentVariable("PATH", "User")
  if ($oldPath -like "*$Path*") {
    Write-Host "Path already exists: $Path"
    return
  }
  $Path = $oldPath + [IO.Path]::PathSeparator + $Path
  [Environment]::SetEnvironmentVariable("PATH", $Path, "User")
  $Env:Path = $Path
  Write-Host "Adding to path: $Path"
}

function AutoInstall() {
  git clone "https://github.com/atinseau/hyperv-tool.git" "hyperv-tool"
  $currentPath = (Get-Location).Path
  AddPath -Path "$currentPath\hyperv-tool\powershell"
}

AutoInstall

Write-Host "Restart your terminal to use HyperV tools"
Write-Host ""
Write-Host "  CreateVm  # Create a new VM"
Write-Host "  SetupVm  # Auto setup a VM with docker,node, git, yarn, pnpm, etc..."
Write-Host "  UpdateAddress # update all host ip and vm ip usage"
Write-Host "  DeployUpdate -?Only <update_id> -?Ignore <update_ids[],>  # Deploy new update, script, package in your vm"
Write-Host
Write-Host "Done! You can now run hyper v commands from any directory."