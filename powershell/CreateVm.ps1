# Import utils
. "$PSScriptRoot\utils\Function.ps1"

$isoUrl = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-11.6.0-amd64-netinst.iso";
$isoName = "debian-11.6.0-amd64-netinst.iso";

function Get-Folder {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [string]$Message = "Please select a directory.",

        [Parameter(Mandatory = $false, Position = 1)]
        [string]$InitialDirectory,

        [Parameter(Mandatory = $false)]
        [System.Environment+SpecialFolder]$RootFolder = [System.Environment+SpecialFolder]::Desktop,

        [switch]$ShowNewFolderButton
    )
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = $Message
    $dialog.SelectedPath = $InitialDirectory
    $dialog.RootFolder = $RootFolder
    $dialog.ShowNewFolderButton = if ($ShowNewFolderButton) { $true } else { $false }
    $selected = $null

    $result = $dialog.ShowDialog((New-Object System.Windows.Forms.Form -Property @{TopMost = $true }))
    if ($result -eq [Windows.Forms.DialogResult]::OK) {
        $selected = $dialog.SelectedPath
    }
   
    $dialog.Dispose()
    $selected
} 


function CreateVm {
    param (
        [Parameter(Mandatory = $true)]
        [string]$name,
        [Parameter(Mandatory = $true)]
        [long]$memSize,
        [Parameter(Mandatory = $true)]
        [long]$diskSize,
        [Parameter(Mandatory = $true)]
        [string]$path,
        [Parameter(Mandatory = $true)]
        [string]$switchName
    )
    Write-Host "[SETUP] Creating VM $name"
    New-VM `
        -Name $name `
        -MemoryStartupBytes $memSize `
        -Path "$path\$name" `
        -NewVHDPath "$path\$name\disk.vhdx" `
        -NewVHDSizeBytes $diskSize `
        -Generation 2 `
        -SwitchName $switchName | Out-Null
}

function CreateVmSwitch {
    param (
        [Parameter(Mandatory = $true)]
        [string]$name
    )

    Write-Host "[SETUP] Creating VM Switch $name"

    $switch = Get-VMSwitch -Name $name -ErrorAction SilentlyContinue
    if ($switch -ne $null) {
        Write-Host "Switch already exists"
        return
    }

    $uppedAdapter = Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
    if ($null -eq $uppedAdapter) {
        Throw "[ERROR] No upped adapter found"
    }
    New-VMSwitch `
        -Name $name `
        -NetAdapterName $uppedAdapter.Name `
        -AllowManagementOS $true | Out-Null
    Write-Host "[SETUP] Switch created successfully"
}

function SetVwFirmware {
    param (
        [Parameter(Mandatory = $true)]
        [string]$name
    )
    Set-VMFirmware `
        -VMName $name `
        -EnableSecureBoot Off `
        -BootOrder $(Get-VMDvdDrive -VMName $name), $(Get-VMHardDiskDrive -VMName $name), $(Get-VMNetworkAdapter -VMName $name) | Out-Null
}

function SetVmCpu {
    param (
        [Parameter(Mandatory = $true)]
        [string]$name,
        [Parameter(Mandatory = $true)]
        [int]$count
    )
    Write-Host "[SETUP] Setting VM $name CPU count to $count"
    Set-VMProcessor `
        -VMName $name `
        -ExposeVirtualizationExtensions $true `
        -Count $count | Out-Null
}

function SetVmDvdDrive {
    param (
        [Parameter(Mandatory = $true)]
        [string]$name,
        [Parameter(Mandatory = $true)]
        [string]$path
    )
    Write-Host "[SETUP] Setting VM $name DVD drive"
    Add-VMDvdDrive `
        -VMName $name `
        -Path $path | Out-Null
}

function FetchIsoDrive {
    $downloadedIso = "$env:USERPROFILE\Downloads\$isoName"

    if ((Test-Path -Path $downloadedIso -PathType Leaf) -ne $true) {
        try {
            Write-Host "[SETUP] Downloading ISO file..."
            (New-Object System.Net.WebClient).DownloadFile($isoUrl, $downloadedIso)
            Write-Host "[SETUP] ISO file downloaded to $downloadedIso"
        }
        catch {
            Write-Error $_
            Throw "[ERROR] Failed to download ISO file"
        }
    }
    else {
        Write-Host "[SETUP] ISO file already downloaded to $downloadedIso"
    }

    return $downloadedIso
}

function SecureCreateVm {

    $name = '';
    $path = $null;

    Write-Host "[SETUP] Welcome to the VM creation wizard"

    $iso = FetchIsoDrive

    while ($true) {
        if ($name -eq '') {
            $name = Read-Host "Enter VM name"
            if ($name -eq '') {
                Write-Error '[ERROR] VM name cannot be empty'
                continue
            }
            $vm = Get-VM -Name $name -ErrorAction SilentlyContinue
            if ($null -ne $vm) {
                Write-Error "[ERROR] VM with name $name already exists"
                $name = ''
                continue
            }
        }
        if ($null -eq $path) {
            Write-Host "[SETUP] Select VM path.."
            $path = Get-Folder -Message "Please select a directory."
            if ($null -eq $path) {
                Throw '[ERROR] Path cannot be empty'
            }
            Write-Host "[SETUP] VM path is $path"
        }

        CreateVmSwitch -name "Bridge"
        CreateVm `
            -name $name `
            -memSize 4GB `
            -diskSize 124GB `
            -path $path `
            -switchName "Bridge"
        SetVmCpu -name $name -count 4
        SetVmDvdDrive -name $name -path $iso
        SetVwFirmware -name $name

        Start-VM -Name $name
        Write-Host "[FINISH] VM $name created successfully and started"
        break;
    }
}

SecureCreateVm
