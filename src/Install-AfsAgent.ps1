function Install-AfsAgent {
    # Extract the MSI from the pre-downloaded install package
    $tempFolder = New-Item -Path "afstemp" -ItemType Directory
    Start-Process -FilePath "C:\Agents\StorageSyncAgent_V4_WS2016.exe" -ArgumentList "/C /T:$tempFolder" -Wait

    # Install the MSI. Start-Process is used to PowerShell blocks until the operation is complete.
    Start-Process -FilePath "$($tempFolder.FullName)\StorageSyncAgent.msi" -ArgumentList "/quiet" -Wait
}

Install-AfsAgent