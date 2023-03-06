# Global variables
. "$PSScriptRoot\Variables.ps1"
. "$PSScriptRoot\Functions.ps1"

git fetch
$diff = git diff master...origin/master
if ($diff) {
    git pull 
    Write-Host "[Script reloaded]" -ForegroundColor Green
    $currentScript = $MyInvocation.ScriptName
    . "$currentScript"
    exit
}