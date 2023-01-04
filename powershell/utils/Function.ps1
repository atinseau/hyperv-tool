function GetSwtichHostIp {
    param (
        $Name
    )
    $allAddresses = Get-NetIPAddress -AddressFamily IPV4 | Select-Object -Property IPAddress, InterfaceAlias
    $newHostIp = ($allAddresses | Where-Object { $_.InterfaceAlias -eq "vEthernet (${Name})" }).IPAddress
    return $newHostIp
}