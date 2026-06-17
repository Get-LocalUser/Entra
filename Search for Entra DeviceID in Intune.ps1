Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All" -NoWelcome

$DeviceIDs = Get-Content "" # enter pathway to txt file of deviceID's

foreach ($ID in $DeviceIDs) {
    $Device = Get-MgBetaDeviceManagementManagedDevice -Filter "azureADDeviceId eq '$ID'" 
    if ($Device) {
        Write-Host "FOUND - $($Device.DeviceName) | $ID" -ForegroundColor Green
    } else {
        Write-Host "NOT FOUND - $ID" -ForegroundColor Red
    }
}