function Login-Azure {
    param (
        [string]$username,
        [string]$password # Use [secureString] outside of secure environments
    )
    # Convert password to secure string (required for creating login credential)
    $securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force

    # Create login cretential with username and password
    $credential = New-Object -typename System.Management.Automation.PSCredential `
        -argumentlist $username, $securePassword
    
    # Login non-interactively using the credential
    $acctInfo = Login-AzureRmAccount -Credential $credential
    return $acctInfo
}

function New-StorageSyncService {
    param (
        $acctInfo,
        [string]$storageSyncName,
        [string]$resourceGroupName
    )
    # The location of the Azure File Sync Agent
    $agentPath = "C:\Program Files\Azure\StorageSyncAgent"

    # Import the Azure File Sync management cmdlets 
    # (cmdlets not yet included in the Azure PowerShell Module)
    Import-Module "$agentPath\StorageSync.Management.PowerShell.Cmdlets.dll"

    # Store your subscription and Azure Active Directory tenant ID 
    $subID = $acctInfo.Context.Subscription.Id
    $tenantID = $acctInfo.Context.Tenant.Id

    # Get the resource group to determine the location of the sync service
    $resourceGroup = Get-AzureRmResourceGroup -Name $resourceGroupName
    $location = $resourceGroup.Location

    # The following command creates an AFS context 
    # it enables subsequent AFS cmdlets to be executed with minimal 
    # repetition of parameters or separate authentication 
    Login-AzureRmStorageSync `
        –SubscriptionId $subID `
        -ResourceGroupName $resourceGroupName `
        -TenantId $tenantID `
        -Location $location

    # Create a new Storage Sync Service in the
    # Login-AzureRmStorageSync context
    New-AzureRmStorageSyncService -StorageSyncServiceName $storageSyncName
}

function Register-StorageSyncServer {
    param (
        [string]$storageSyncName
    )
    # Register the server executing the script as a server endpoint
    $registeredServer = New-AzureRmStorageSyncService -StorageSyncServiceName $storageSyncName
    return $registeredServer
}

function New-SyncGroup {
    param (
        [string]$storageSyncName,
        [string]$syncGroupName,
        [string]$storageAccountName,
        [string]$fileShareName
    )
    # Get the storage account with desired name
    $storageAccount = Get-AzureRmStorageAccount -ResourceGroupName $resourceGroup -Name $storageAccountName
    
    # Create the sync group with a cloud endpoint (file share)
    New-AzureRmStorageSyncCloudEndpoint `
        -StorageSyncServiceName $storageSyncName `
        -SyncGroupName $syncGroupName `
        -StorageAccountResourceId $storageAccount.Id `
        -StorageAccountShareName $fileShareName
}

function New-ServerEndpoint {
    param (
        [string]$storageSyncName,
        [string]$syncGroupName,
        $registeredServer,
        [string]$serverEndpointPath,
        [bool]$cloudTieringDesired,
        [int]$volumeFreeSpacePercentage
    )
    # Prepare a settings hashtable for splatting
    $settings = @{
        StorageSyncServiceName = $storageSyncName
        SyncGroupName = $syncGroupName 
        ServerId = $registeredServer.Id
        ServerLocalPath = $serverEndpointPath 
    }

    # Add additional settings if cloud tiering is desired
    if ($cloudTieringDesired) {
        # Ensure endpoint path is not the system volume
        $directoryRoot = [System.IO.Directory]::GetDirectoryRoot($serverEndpointPath)
        $osVolume = "$($env:SystemDrive)\"
        if ($directoryRoot -eq $osVolume) {
            throw [System.Exception]::new("Cloud tiering cannot be enabled on the system volume")
        }

        # Add cloud tiering settings
        $settings += @{
            CloudTiering = $true
            VolumeFreeSpacePercent = $volumeFreeSpacePercentage
        }
    }
    # Use splatting to set parameters
    New-AzureRmStorageSyncServerEndpoint @settings
}


$resourceGroupName = Get-AzResourceGroup | Select-Object -ExpandProperty ResourceGroupName
$storageAccountName = Get-AzStorageAccount -ResourceGroupName $resourceGroupName | `
    Where-Object StorageAccountName -like calabsync* | `
    Select-Object -ExpandProperty Name
$fileShareName = "sync"
$storageSyncName = "sync"
$syncGroupName = "dev"
$serverEndpointPath = "D:\dev"
$cloudTieringDesired = $true
$volumeFreeSpacePercentage = 50

$acctInfo = Login-Azure
New-StorageSyncService $acctInfo $storageSyncName $resourceGroupName
$registeredServer = Register-StorageSyncServer $storageSyncName
New-SyncGroup $storageSyncName $syncGroupName $storageAccountName $fileShareName
New-ServerEndpoint $storageSyncName `
                   $syncGroupName `
                   $registeredServer `
                   $serverEndpointPath `
                   $cloudTieringDesired `
                   $volumeFreeSpacePercentage