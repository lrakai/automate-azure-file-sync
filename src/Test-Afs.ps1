function Test-Afs {
    # Write text to a file in the server endpoint path (D:\dev)
    "Sync me" | Out-File D:\dev\test.txt
}

Test-Afs