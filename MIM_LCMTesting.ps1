$agency = Read-Host "Please enter your agency's acronym"

$parentOU = (Get-ADOrganizationalUnit -Filter 'Name -eq "MIM-Test"').DistinguishedName

# Disable user account test.
try{
    $testUser1 = "MIM Test1"
    $identity = ($agency + "." + ($testUser -replace ' ','')).ToLower()
    Disable-LocalUser -Name $identity
    Write-Host "$identity has been successfully disabled."
} catch {
    Write-Host "There was an issue disabling $identity."
}

# Move user account from in-scope OU to in-scope OU test.
try{
    $testUser2 = "MIM Test2"
    $identity2 = ($agency + "." + ($testUser2 -replace ' ','')).ToLower()
    Get-ADUser $identity2 | Move-ADObject -TargetPath (Get-ADOrganizationalUnit -Filter 'Name -eq "In-Scope"' -SearchBase $parentOU).DistinguishedName
    Write-Host "$identity2 has been successfully moved from the Enabled OU to the In-Scope OU."
} catch {
    Write-Host "There was an issue moving $identity2 from the Enabled OU to the In-Scope OU."
}

# Move user account from in-scope OU to out-of-scope OU test.
try{
    $testUser3 = "PCNS Test1"
    $identity3 = ($agency + "." + ($testUser3 -replace ' ','')).ToLower()
    Get-ADUser $identity3 | Move-ADObject -TargetPath (Get-ADOrganizationalUnit -Filter 'Name -eq "Out-of-Scope"' -SearchBase $parentOU).DistinguishedName
    Write-Host "$identity3 has been successfully moved from the Enabled OU to the Out-of-Scope OU."
} catch {
    Write-Host "There was an issue moving $identity3 from the Enabled OU to the Out-of-Scope OU."
}

# Reset user account password test
try{
    $testUser4 = "PCNS Test2"
    $identity4 = ($agency + "." + ($testUser4 -replace ' ','')).ToLower()
    $newPassword = Read-Host "Enter password for $identity" -AsSecureString
    Set-ADAccountPassword -Identity $identity4 -NewPassword $newPassword
    Write-Host "The password for $identity4 has been successfully reset."
}catch{
    Write-Host "There was an issue resetting the password for $identity4."
}
