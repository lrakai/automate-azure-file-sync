# Must run on a Windows Server with Azure File Sync Agent and Azure PowerShell module installed

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
    return $credential, $acctInfo
}

function Remove-StorageSyncResources {
    param($sss)

    Get-AzureRmStorageSyncServer -StorageSyncServiceName $sss.Name |
        Unregister-AzureRmStorageSyncServer -Force
    Get-AzureRmStorageSyncGroup -StorageSyncServiceName $sss.Name | 
        % {
            Get-AzureRmStorageSyncCloudEndpoint -StorageSyncServiceName $sss.Name -SyncGroupName $_.Name |
                Remove-AzureRmStorageSyncCloudEndpoint
        }
    Get-AzureRmStorageSyncGroup -StorageSyncServiceName $sss.Name |
        Remove-AzureRmStorageSyncGroup
    Remove-AzureRmStorageSyncService -StorageSyncServiceName $sss.Name
}

# Login to Azure
$username = Read-Host -Prompt 'Input your Azure user email'
$password = Read-Host -Prompt 'Input your Azure user password'
$credential, $acctInfo = Login-Azure $username $password

cd "C:\Program Files\Azure\StorageSyncAgent"
ipmo .\StorageSync.Management.PowerShell.Cmdlets.dll -verbose


$tenantId = (Get-AzureRmContext).Tenant.Id
Get-AzureRmSubscription | % {
    Select-AzureRmSubscription -Subscription $_
    $subscriptionId = $_.Id
    Get-AzureRmResource -ResourceType Microsoft.StorageSync/storageSyncServices |
    % { 
        'Removing {0} in {1}' -f $_.Name, $_.ResourceGroupName
        Login-AzureRmStorageSync -SubscriptionId $subscriptionId `
            -TenantId $tenantId `
            -ResourceGroupName $_.ResourceGroupName `
            -Location $_.Location `
            -Credential $credential
        $sss = Get-AzureRmStorageSyncService -Id $_.Id
        $lastEvent = Get-AzureRmLog -ResourceId $sss.Id |
            sort SubmissionTimestamp -Descending |
            select -First 1
        # If not active (conservatively), clean up
        try {
            if (((Get-Date).AddDays(-1) - $lastEvent.SubmissionTimestamp) -gt [TimeSpan]::FromHours(2)) {
                Remove-StorageSyncResources -sss $sss
            }
        }
        catch {
            "No activity log. Proceeding to remove..."
            Remove-StorageSyncResources -sss $sss
        }
    }
}