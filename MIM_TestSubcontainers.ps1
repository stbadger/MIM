Import-Module ActiveDirectory

#Establishes the different required subcontainers for testing.
$testContainers = @("Enabled", "In-Scope", "Out-of-Scope")

#Establishes the different test user accounts that will need to be moved.
$testUsers = @("MIM Test1", "MIM Test2", "PCNS Test1", "PCNS Test2")

$agency = Read-Host "Please enter your agency's acronym"
$parentOU = (Get-ADOrganizationalUnit -Filter 'Name -eq "MIM-Test"').DistinguishedName
$destination = "Enabled"

# Creates required subcontainers for testing in the MIM-Test OU.
foreach ($t in $testContainers){
    try{
        New-ADOrganizationalUnit `
        -Name "$t" `
        -Path $parentOU `
        -ProtectedFromAccidentalDeletion $false 
        Write-Host "The $t subcontainer in the MIM-Test OU has been successfully created." -ForegroundColor Green
    } catch {
        Write-Host "There was an issue creating the subcontainer $t in the MIM-Test OU." -ForegroundColor Red
    }
}

# Moves test user accounts from the MIM-Test OU to the Enabled subcontainer.
foreach ($t in $testUsers){
    $identity = ($agency + "." + ($t -replace ' ','')).ToLower()
    try{
        Get-ADUser $identity | Move-ADObject -TargetPath (Get-ADOrganizationalUnit -Filter 'Name -eq $destination' -SearchBase $parentOU).DistinguishedName
        Write-Host "$identity has been successfully moved to the $destination OU." -ForegroundColor Green
    } catch {
        Write-Host "There was an issue movoing $identity to the $destination OU." -ForegroundColor Red
    }
}
