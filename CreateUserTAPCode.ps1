# Very slight mod to MS's script

.NOTES
# You need the Graph.Beta module installed to use this. 

# Connect to Graph
$context = Get-MgContext 
if ($null -ne $context -and $context.Scopes -contains "UserAuthenticationMethod.ReadWrite.All") {
} else {
    Connect-MgGraph -Scopes "UserAuthenticationMethod.ReadWrite.All" -NoWelcome
}

# Define the time you want TAp to take affect
$time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$user = Read-Host "Enter the email for the user"

# Create a Temporary Access Pass for a user that can be used more than once
$properties = @{}
$properties.isUsableOnce = $false
$properties.startDateTime = $time
$propertiesJSON = $properties | ConvertTo-Json

try {
    $tap = New-MgBetaUserAuthenticationTemporaryAccessPassMethod -UserID $user -BodyParameter $propertiesJSON -ErrorAction Stop | Out-Host
    Write-Host "MFA Setup Link:`nhttps://aka.ms/mfasetup" -ForegroundColor Magenta
}
catch {
    Write-Host "Failed to create TAP." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    
    return
}

try {
    $question = Read-Host "Do you want to remove the current TAP?"
    if ($question -like "y") {
        $existingtap = (Get-MgBetaUserAuthenticationTemporaryAccessPassMethod -UserId $user).Id
        Remove-MgBetaUserAuthenticationTemporaryAccessPassMethod -UserId $user -TemporaryAccessPassAuthenticationMethodId $existingtap
        Write-Host "TAP with ID $existingtap removed" -ForegroundColor Green
    } else {
        Write-Host "You declined. TAP will remain active for 60 minutes from the time it was created."
    }
}
catch {
    Write-Host "Failed to remove TAP. Manually remove from the Entra Admin Center" -ForegroundColor Red
    "Error: $($_.Exception.Message)"
}