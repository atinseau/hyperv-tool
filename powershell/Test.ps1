


$array = @()

$a = @{}
$a.Add('id', 1)

$b = @{}
$b.Add('id', 2)

$c = @{}
$c.Add('id', 3)

$array += $a
$array += $b
$array += $c

$array | ForEach-Object {
  if ($_.id -eq 2) {
    return
  }
  Write-Host $_.id
}