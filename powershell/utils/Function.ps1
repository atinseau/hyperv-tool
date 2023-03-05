# Global variables
$addressesFile = "$env:USERPROFILE\.addresses.json"
$sshKeyFile = "$env:USERPROFILE\.ssh\id_rsa.pub"
$hostsFile = "C:\Windows\System32\drivers\etc\hosts"
$bashDirectory = $PSScriptRoot.Replace("\powershell\utils", "\bash")
$confDirectory = $PSScriptRoot.Replace("\powershell\utils", "\conf")

# Global functions
function SecureReadHost {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    # stop with ctrl+c
    $securedValue = Read-Host -AsSecureString $Message
    if ($null -eq $securedValue) {
        exit
    }
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securedValue)
    $value = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    return $value
}


function WhilePrompt {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Prompt,
        [Parameter(Mandatory = $false)]
        [string]$errorMessage = "No input provided",
        [Parameter(Mandatory = $false)]
        [bool]$Secure = $false
    )
    while ($true) {
        $output = $null
        if ($Secure) {
            $output = SecureReadHost -Message $Prompt
        } else {
            $output = Read-Host $Prompt
        }
        if ([string]::IsNullOrEmpty($output)) {
            Write-Error $errorMessage
            continue
        }
        return $output
    }
}

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
        $vmName = WhilePrompt -Prompt "Enter vm name" -errorMessage "No vm name provided"
    }
    if ($AskForVmUsername) {
        $vmUsername = WhilePrompt -Prompt "Enter vm username" -errorMessage "No vm username provided"
    }
    if ($AskForVmIp) {
        $vmIp = WhilePrompt -Prompt "Enter Vm IP" -errorMessage "No vm ip provided"
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
        [string] $vmIp
    )

    if ($true -ne (Test-Path $sshKeyFile -PathType leaf)) {
        ssh-keygen
    }

    # FIX SSH AUTHORIZED KEYS IN VM
    $authorizedKeys = (ssh $vmUsername@$vmIp "cat .ssh/authorized_keys 2> /dev/null")
    
    if ([string]::IsNullOrEmpty($authorizedKeys) -or (Get-Content $sshKeyFile | Select-String -Pattern "$authorizedKeys" -SimpleMatch -Quiet) -ne $true) {
        Write-Host "Recreating authorized_keys file with windows ssh key !"
        Get-Content $sshKeyFile | ssh $vmUsername@$vmIp "cat > authorized_keys && mkdir -p ~/.ssh && mv authorized_keys ~/.ssh/"
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
        $vmIp = WhilePrompt -Prompt "Enter old vm ip" -errorMessage "Vm ip cannot be empty !"
        $windowsIp = WhilePrompt -Prompt "Enter old windows ip" -errorMessage "Windows ip cannot be empty !"

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
