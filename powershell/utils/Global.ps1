# Global variables
. "$PSScriptRoot\Variables.ps1"
. "$PSScriptRoot\Functions.ps1"

function CheckUpdate () {
    $currentPath = (Get-Location ).Path
    Set-Location $gitDirectory | Out-Null
    git fetch 
    $diff = git diff master...origin/master
    if ($diff) {
        git pull
    }
    Set-Location $currentPath | Out-Null
    if ($diff) {
        Write-Host "[Script reloaded]" -ForegroundColor Green
        $currentScript = $MyInvocation.ScriptName
        . "$currentScript"
        exit
    }
}

# Auto reload script if it has been updated
CheckUpdate
