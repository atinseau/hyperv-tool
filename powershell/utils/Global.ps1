# Global variables
. "$PSScriptRoot\Variables.ps1"
. "$PSScriptRoot\Functions.ps1"

$gitDirectory

# Auto reload script if it has been updated
git fetch
$diff = git diff master...origin/master
if ($diff) {
    git pull 
    Write-Host "[Script reloaded]" -ForegroundColor Green
    $currentScript = $MyInvocation.ScriptName
    . "$currentScript"
    exit
}
