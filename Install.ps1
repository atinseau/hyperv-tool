function AddPath($Path) {
  $oldPath = [Environment]::GetEnvironmentVariable("PATH")
  if ($oldPath -like "*$Path*") {
    Write-Host "Path already exists: $Path"
    return
  }
  $Path = $oldPath + [IO.Path]::PathSeparator + $Path
  setx PATH $Path
}

AddPath -Path "$PSScriptRoot\powershell"

Write-Host "Done! You can now run hyper v commands from any directory."


# (Invoke-WebRequest -Uri https://raw.githubusercontent.com/atinseau/hyperv-tool/master/Install.ps1) | Invoke-Expression