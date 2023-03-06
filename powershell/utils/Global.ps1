# Global variables
. "$PSScriptRoot\Variables.ps1"
. "$PSScriptRoot\Functions.ps1"

git fetch
$diff = git diff master...origin/master

if ($diff) {
    Write-Output "There are changes in the remote repository"
    Write-Output "Updating local repository"
    git pull
    Write-Output "Local repository updated"
}

Write-Output "Global variables and functions loaded"