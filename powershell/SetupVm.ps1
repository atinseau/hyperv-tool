# Import utils
. "$PSScriptRoot\utils\Function.ps1" 


function PreSetup {
    param (
        [Parameter(Mandatory = $true)]
        [string] $vmName
    )
    $snapshot = Get-VMSnapshot -Name 'BeforeSetupVm' -VMName $vmName -ErrorAction SilentlyContinue
    if ($null -eq $snapshot) {
        Checkpoint-VM -Name $vmName -SnapshotName BeforeSetupVm
    }
    else {
        Write-Host "Snapshot already exists"
    }
}

function GetWindowsIp {
    param (
        [Parameter(Mandatory = $true)]
        $vm
    )
    $vmBridge = $vm | Get-VMNetworkAdapter | Where-Object { $_.SwitchName -eq "Bridge" }
    if ($null -eq $vmBridge) {
        Write-Error "No VM with bridge network adapter found"
        exit
    }
    $windowsIp = GetSwitchHostIp $vmBridge.SwitchName
    return $windowsIp
}

function CreateAlias {
    param (
        [Parameter(Mandatory = $true)]
        [string] $vmName,
        [Parameter(Mandatory = $true)]
        [string] $vmIp
    )

    $createAlias = Read-Host "Create alias in hosts file? (y/n)"
    if ($createAlias -ne "y") {
        Write-Host "Alias not created"
        return
    }

    $alias = WhilePrompt "Enter alias for $vmName"
    if ($null -eq $alias) {
        Write-Error "No alias provided"
        exit
    }
    if (Get-Content $hostsFile | Select-String -Pattern $alias) {
        Write-Error "Alias already exists in hosts file"
        exit
    }
    $aliasFile = @"
$vmIp $alias
"@
    Write-Output $aliasFile | Add-Content $hostsFile
    Write-Host "Alias created in hosts file"
}

function SetupVm {
    param (
        [Parameter(Mandatory = $true)]
        [string] $vmUsername,
        [Parameter(Mandatory = $true)]
        [string] $vmIp,
        [Parameter(Mandatory = $true)]
        [string] $windowsIp
    )

    $postInstallScript = $bashDirectory + "\post-install.sh"
    $windowsUsername = WhilePrompt -Prompt "Enter windows username"
    $windowsPassword = WhilePrompt `
        -Secure $true `
        -Prompt "Enter windows password"

    # Prepare vm to execute post-install.sh
    ssh -t $vmUsername@$vmIp `
        "su -c 'apt-get update -y && apt-get -y install sudo dos2unix && echo \`"$vmUsername  ALL=(ALL) NOPASSWD:ALL\`" >> /etc/sudoers' root;"
    Get-Content $postInstallScript | ssh $vmUsername@$vmIp 'cat > /tmp/post-install.sh && dos2unix /tmp/post-install.sh'
    ssh -t $vmUsername@$vmIp "chmod +x /tmp/post-install.sh && sudo -S /tmp/post-install.sh `$HOME `$USER $vmIp $windowsIp $windowsUsername $windowsPassword"
}

function PostSetup {
    param (
        [Parameter(Mandatory = $true)]
        [string] $vmName
    )
    # Create snapshot after setup
    $snapshot = Get-VMSnapshot -Name 'AfterSetupVm' -VMName $vmName -ErrorAction SilentlyContinue
    if ($null -ne $snapshot) {
        Remove-VMSnapshot -Name 'AfterSetupVm' -VMName $vmName -Confirm:$false
    }
    Checkpoint-VM -Name $vmName -SnapshotName AfterSetupVm
    Restart-VM -Name $vmName -Force
}


# Get vm info and credentials
$vmName, $vmUsername, $vmIp, $vm = VmPrompt


# Create snapshot before setup if it doesn't exist
PreSetup `
    -vmName $vmName


# Get windows ip with bridge network adapter 
$windowsIp = GetWindowsIp -vm $vm

# Create alias in hosts file 
CreateAlias `
    -vmName $vmName `
    -vmIp $vmIp

# Fix authorized_keys and create ssh key in windows for vm
FixAuthorizedKeys `
    -vmUsername $vmUsername `
    -vmIp $vmIp

# Transfer post-install.sh to vm and execute it
SetupVm `
    -vmUsername $vmUsername `
    -vmIp $vmIp `
    -windowsIp $windowsIp

# Create snapshot after setup and restart vm
PostSetup `
    -vmName $vmName


Write-Host "Setup completed"
