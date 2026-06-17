$EntraUsers = Get-EntraUser -All
$EntraUsersWithLicenses = foreach ($user in $EntraUsers) {
    if ($user.AssignedLicenses.Count -lt 1) {
        [pscustomobject]@{
            Id                  = $user.Id
            DisplayName         = $user.DisplayName
            UserPrincipalName   = $user.UserPrincipalName
            AssignedLicenses    = ($user.AssignedLicenses | ForEach-Object { $_.SkuId }) -join ", "
        }
    }
}
$EntraUsersWithLicenses | Format-Table Id, DisplayName, UserPrincipalName, AssignedLicenses -AutoSize