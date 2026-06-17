$EntraUsers = Get-EntraUser -All
$EntraUsersLocation = foreach ($User in $EntraUsers) {
    if ($null -eq $User.usageLocation) {
        [pscustomobject]@{
            Id                  = $user.Id
            DisplayName         = $user.DisplayName
            UserPrincipalName   = $user.UserPrincipalName
            usageLocation       = $user.usageLocation
        }
    }
}
$EntraUsersLocation | Format-Table Id, DisplayName, UserPrincipalName, usageLocation -AutoSize