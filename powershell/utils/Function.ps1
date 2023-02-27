# Global variables
$addressesFile = "$env:USERPROFILE\.addresses.json"
$bashDirectory = $PSScriptRoot.Replace("\powershell\utils", "\bash")
$confDirectory = $PSScriptRoot.Replace("\powershell\utils", "\conf")

# Global functions
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


function VmPrompt {
    param (
        [Boolean] $AskForVmName = $true,
        [Boolean] $AskForVmUsername = $true,
        [Boolean] $AskForVmIp = $true,
        [string] $vmName = "",
        [string] $vmUsername = "",
        [string] $vmIp = ""
    )
    $vm = $null

    if ($AskForVmName) {
        $vmName = Read-Host "Enter vm name"
        if ([string]::IsNullOrEmpty($vmName)) {
            Write-Error "No vm name provided"
            exit
        }
    }

    if ($AskForVmUsername) {
        $vmUsername = Read-Host "Enter vm username"
        if ([string]::IsNullOrEmpty($vmUsername)) {
            Write-Error "No vm name provided"
            exit
        }
    }

    if ($AskForVmIp) {
        $vmIp = Read-Host "Enter Vm IP"
        if ([string]::IsNullOrEmpty($vmIp)) {
            Write-Error "No ip provided"
            exit
        }
    }

    if ([string]::IsNullOrEmpty($vmName) -eq $false) {
        $vm = Get-VM -Name $vmName
        if ($vm.State -ne "Running") {
            Write-Host "VM is not running, starting it !"
            exit
        }
    }

    return $vmName, $vmUsername, $vmIp, $vm
}


function FixAuthorizedKeys {

    param (
        [Parameter(Mandatory = $true)]
        [string] $vmUsername,
        [Parameter(Mandatory = $true)]
        [string] $vmIp,
        [Boolean] $Throwable = $true
    )

    # FIX SSH AUTHORIZED KEYS IN VM
    $authorizedKeys = (ssh $vmUsername@$vmIp "cat .ssh/authorized_keys 2> /dev/null")

    if ($Throwable -eq $true -and $LASTEXITCODE -ne 0) {
        Throw "Error while getting authorized_keys file, please check if ssh is working !"
    }
    
    if ([string]::IsNullOrEmpty($authorizedKeys) -or (Get-Content $env:USERPROFILE\.ssh\id_rsa.pub | Select-String -Pattern "$authorizedKeys" -SimpleMatch -Quiet) -ne $true) {
        Write-Host "Recreating authorized_keys file with windows ssh key !"
        Get-Content $env:USERPROFILE\.ssh\id_rsa.pub | ssh $vmUsername@$vmIp "cat >> .ssh/authorized_keys"
    }
}

# Function to create addresses file
# if it does not exist, create it with vmName, vmIp and windowsIp object
# if it exist but is empty, create it with vmName, vmIp and windowsIp object
# if it exist, add vmName, vmIp and windowsIp object
function PromptForAddressesFile {
    param (
        [Parameter(Mandatory = $true)]
        [string] $vmName,
        [Parameter(Mandatory = $true)]
        [string] $errorMessage
    )
    Write-Host "#########################################################"
    Write-Host $errorMessage
    Write-Host "It very important for replacing all old ip usage of windows and vm"
    Write-Host "Please create it at $addressesFile for automatic replacement"
    Write-Host "#########################################################"
    $createFile = Read-Host "Do you want to create it now ? (y/n)"
    if ($createFile -eq "y") {
        $vmIp = Read-Host "Enter old vm ip"
        if ([string]::IsNullOrEmpty($vmIp)) {
            Write-Error "Vm ip cannot be empty !"
            exit
        }

        $windowsIp = Read-Host "Enter old windows ip"
        if ([string]::IsNullOrEmpty($windowsIp)) {
            Write-Error "Windows ip cannot be empty !"
            exit
        }

        CreateAddressesFile `
            -vmName $vmName `
            -vmIp $vmIp `
            -windowsIp $windowsIp `
            -addressesFile $addressesFile
        Write-Host "Restarting script !"
    }
    else {
        Write-Host "Exiting script !"
    }
    exit
}

function GetCurrentVmIpConfig {
    param (
        [Parameter(Mandatory = $true)]
        [string] $vmName
    )

    
    # Check if addresses file exist (file with old vm and windows ip)
    if ($true -ne (Test-Path $addressesFile -PathType leaf)) {
        PromptForAddressesFile `
            -vmName $vmName `
            -errorMessage "Addresses file does not exist !"
    }

    $addresses = (Get-Content $addressesFile) | ConvertFrom-Json

    # Check if addresses file is empty or invalid
    if ([string]::IsNullOrEmpty($addresses)) {
        PromptForAddressesFile `
            -vmName $vmName `
            -errorMessage "Addresses file is empty or invalid !"
        exit
    }

    $currentVmAddresses = $addresses | Select-Object -ExpandProperty $vmName -ErrorAction SilentlyContinue

    # Check if vm is not in addresses file
    if ([string]::IsNullOrEmpty($currentVmAddresses)) {
        PromptForAddressesFile `
            -vmName $vmName `
            -errorMessage "Vm is not in addresses file !"
        exit
    }

    $vmIp = $currentVmAddresses.vm
    $hostIp = $currentVmAddresses.host

    return $vmIp, $hostIp, $addresses
}