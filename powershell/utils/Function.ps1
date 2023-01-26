function GetSwitchHostIp {
    param (
        $Name
    )
    $allAddresses = Get-NetIPAddress -AddressFamily IPV4 | Select-Object -Property IPAddress, InterfaceAlias
    $newHostIp = ($allAddresses | Where-Object { $_.InterfaceAlias -eq "vEthernet (${Name})" }).IPAddress
    return $newHostIp
}

function CreateAddressesFile {

    param (
        [Parameter(Mandatory = $true)]
        [string] $vmName,
        [Parameter(Mandatory = $true)]
        [string] $vmIp,
        [Parameter(Mandatory = $true)]
        [string] $windowsIp,
        [Parameter(Mandatory = $true)]
        [string] $addressesFile
    )

    if ($true -ne (Test-Path $addressesFile -PathType leaf)) {
        $json = @{}
        $json.Add($vmName, @{"vm" = $vmIp; "host" = $windowsIp})
        $json | ConvertTo-Json | Set-Content $addressesFile
        Write-Host "Addresses file created !"
    } else {
        $addresses = (Get-Content $addressesFile) | ConvertFrom-Json 
        if ([string]::IsNullOrEmpty($addresses)) {
            $addresses = @{}
        } else {
            $tmpAddresses = @{}
            $addresses.PSObject.Properties  | ForEach-Object {
                $tmpAddresses.Add($_.Name, $_.Value)
            }
            $addresses = $tmpAddresses
        }
       
        try {
            $addresses.Add($vmName, @{"vm" = $vmIp; "host" = $windowsIp})
            $addresses | ConvertTo-Json | Set-Content $addressesFile
            Write-Host "Addresses file updated !"
        } catch {
            Write-Host "Addresses file already contains this vm name !"
        }
    }
}