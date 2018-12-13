# automate-azure-file-sync

Demonstrate how to automate Azure File Sync deployments using PowerShell. This Lab automates the tasks performed manually in Azure Portal and over RDP on the Windows Server in [this Lab](https://github.com/lrakai/azure-file-sync).

![Final Environment](https://user-images.githubusercontent.com/3911650/49923274-30018b80-fe70-11e8-9430-83d281531e20.png)

## Getting Started

An Azure RM template is included in `infrastructure/` to create the environment:

<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Flrakai%2Fautomate-azure-file-sync%2Fmaster%2Finfrastructure%2Farm-template.json">
    <img src="https://camo.githubusercontent.com/536ab4f9bc823c2e0ce72fb610aafda57d8c6c12/687474703a2f2f61726d76697a2e696f2f76697375616c697a65627574746f6e2e706e67" data-canonical-src="http://armviz.io/visualizebutton.png" style="max-width:100%;">
</a> 

Using Azure PowerShell, do the following to provision the resources:

```ps1
.\New-Lab.ps1
```

Alternatively, you can perform a one-click deploy with the following button:

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Flrakai%2Fautomate-azure-file-sync%2Fmaster%2Finfrastructure%2Farm-template.json">
    <img src="https://camo.githubusercontent.com/9285dd3998997a0835869065bb15e5d500475034/687474703a2f2f617a7572656465706c6f792e6e65742f6465706c6f79627574746f6e2e706e67" data-canonical-src="http://azuredeploy.net/deploybutton.png" style="max-width:100%;">
</a>

## Following Along

1. Start an Azure Cloud Shell PowerShell.

1. Create a file share:

    ```ps1
    $fileShareName = "sync"
    $resourceGroupName = Get-AzResourceGroup | select -ExpandProperty ResourceGroupName
    $storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName | `
                  where StorageAccountName -like calabsync*
    New-AzureStorageShare -Context $storageAccount.Context -Name $fileShareName
    ```

1. Open the Cloud Shell editor:

    ```ps1
    code .
    ```

1. Paste in the `src/Install-AfsAgent.ps1` script for installing the Azure File Sync Agent on the VM.

1. Save the script as Install-AfsAgent.ps1.

1. Use the VM Custom Script Extension to install the agent on the VM:

    ```ps1
    # Create a blog storage container that permits anonymous access to invidividual blobs
    $containerName = "deploy-afs"
    New-AzureStorageContainer -Name $containerName -Context $storageAccount.Context -Permission blob

    # Upload the Install-Afs.ps1 script to the blob container
    Set-AzureStorageBlobContent -File "Install-AfsAgent.ps1" `
        -Container $containerName `
        -Context $storageAccount.Context 

    $fileUri = "$($storageAccount.Context.BlobEndPoint)$containerName/Install-AfsAgent.ps1"
    $Settings = @{
        "fileUris" = @($fileUri)
    }
    $ProtectedSettings = @{
        "commandToExecute" = "powershell -ExecutionPolicy Unrestricted -File Install-AfsAgent.ps1"
    }
    Set-AzVMExtension -ResourceGroupName $resourceGroupName `
        -VMName $vm.Name `
        -Location $vm.Location `
        -Publisher "Microsoft.Compute" `
        -ExtensionType "CustomScriptExtension" `
        -TypeHandlerVersion "1.9" `
        -Settings $Settings `
        -ProtectedSettings $ProtectedSettings `
        -Name provision
    ```

1. Create a sync group by running the `src/Deploy-Afs.ps1` script in the same fashion.

## Tearing Down

When finished, first delete the server endpoint, cloud endpoint, sync group, and registered server in Storage Sync Service (These resources cannot be deleted by deleting the resource group) and finally remove the remaining Azure resources with:

```ps1
.\Remove-Lab.ps1
```