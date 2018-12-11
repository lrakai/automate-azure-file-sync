function Login-Azure {
    param (
        [string]$username,
        [string]$password # Use [secureString] outside of secure environments
    )


    # Login non-interactively
    $acctInfo = Login-AzureRmAccount
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
    New-AzureRmStorageSyncService -StorageSyncServiceName $storageSyncName
}


$resourceGroupName = Get-AzResourceGroup | Select-Object -ExpandProperty ResourceGroupName
$storageAccountName = Get-AzStorageAccount -ResourceGroupName $resourceGroupName | `
                          Where-Object StorageAccountName -like calabsync*
$storageSyncName = "sync"

$acctInfo = Login-Azure
New-StorageSyncService $acctInfo $storageSyncName $resourceGroupName
Register-StorageSyncServer $storageSyncName