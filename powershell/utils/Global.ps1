# Global variables
. "$PSScriptRoot\Variables.ps1"
. "$PSScriptRoot\Functions.ps1"

git fetch
$diff = git diff master...origin/master
if ($diff) {
    git pull
    exit
}