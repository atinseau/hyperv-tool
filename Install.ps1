function AddPath($Path) {
  $oldPath = [Environment]::GetEnvironmentVariable("PATH", "User")
  if ($oldPath -like "*$Path*") {
    Write-Host "Path already exists: $Path"
    return
  }
  $Path = $oldPath + [IO.Path]::PathSeparator + $Path
  [Environment]::SetEnvironmentVariable("PATH", $Path, "User")
  $Env:Path = $Path
}

$currentPath = (Get-Location).Path

AddPath -Path "$currentPath\powershell"

Write-Host "Done! You can now run hyper v commands from any directory."