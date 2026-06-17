$renameMap = @{
    "Entra-Delete-Device.ps1"                  = "RemoveEntraDevice.ps1"
    "Entra-Get-User-WithoutLicense.ps1"        = "GetUsersWithoutLicense.ps1"
    "Entra-Get-User-WithoutUsageLocation.ps1"  = "GetUsersWithoutUsageLocation.ps1"
    "Entra-New-User-TAPCode.ps1"               = "CreateUserTAPCode.ps1"
    "Entra-Search-Device.ps1"                  = "FindEntraDevice.ps1"
}

foreach ($entry in $renameMap.GetEnumerator()) {
    if (Test-Path $entry.Key) {
        Rename-Item -Path $entry.Key -NewName $entry.Value
        Write-Host "Renamed: $($entry.Key) -> $($entry.Value)"
    } else {
        Write-Host "Not found: $($entry.Key)"
    }
}