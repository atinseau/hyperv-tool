# Global variables
. "$PSScriptRoot\Variables.ps1"
. "$PSScriptRoot\Functions.ps1"

# Auto reload script if it has been updated
function CheckUpdate () {
    $currentPath = (Get-Location).Path
    Set-Location $gitDirectory
    git fetch 
    $diff = git diff master...origin/master
    if ($diff) {
        git pull 
        Write-Host "[Script reloaded]" -ForegroundColor Green
        $currentScript = $MyInvocation.ScriptName
        Set-Location $currentPath
        . "$currentScript"
        exit
    }
    Set-Location $currentPath
}


CheckUpdate
