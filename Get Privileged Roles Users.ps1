Connect-MgGraph -Scopes "RoleManagement.Read.Directory","Directory.Read.All","User.Read.All" -NoWelcome

$roles = Get-MgBetaDirectoryRole

$results = foreach ($role in $roles) {
    $members = Get-MgBetaDirectoryRoleMember -DirectoryRoleId $role.Id

    foreach ($member in $members) {
        $user = Get-MgBetaUser -UserId $member.Id -ErrorAction SilentlyContinue
        if ($user) {
            [PSCustomObject]@{
                Role        = $role.DisplayName
                DisplayName = $user.DisplayName
                UPN         = $user.UserPrincipalName
                UserId      = $user.Id
            }
        }
    }
}

$results | Export-Csv -Path "$env:USERPROFILE\Downloads\DirectoryRoles.csv" -NoTypeInformation