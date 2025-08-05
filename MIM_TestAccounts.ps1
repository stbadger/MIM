Import-Module ActiveDirectory

#Establishes the different test user accounts that will need to be created.
$testUsers = @("MIM Test1", "MIM Test2", "PCNS Test1", "PCNS Test2")

#Establishes the different required subcontainers for testing.
$testContainers = @("Enabled", "In-Scope", "Out-of-Scope")

#Creates the test OU that will be used to scope testing to only include test user accounts.
try{
    New-ADOrganizationalUnit -Name "MIM-Test" -Path (Get-ADDomain).DistinguishedName -Description "This OU contains test user accounts for the 2025 State's MIM deployment." -ProtectedFromAccidentalDeletion $false
    $parentOU = (Get-ADOrganizationalUnit -Filter 'Name -eq "MIM-Test"').DistinguishedName
    Write-Host "The MIM-Test OU has been successfully created."

    foreach ($t in $testContainers){
        New-ADOrganizationalUnit `
        -Name "$t" `
        -Path $parentOU `
        -ProtectedFromAccidentalDeletion $false 
        Write-Host "The $t subcontainer in the MIM-Test OU has been successfully created."
    }
} catch {
    if (Get-ADOrganizationalUnit -Filter 'Name -eq "MIM-Test"'){
        Write-Host "The MIM-Test OU already exists."
    } else{
        Write-Host "There was an issue creating the MIM-Test OU."
        exit
    }
}

$agency = Read-Host "Please enter your agency's acronym"

#Creates required MIM test accounts.
foreach ($t in $testUsers){
    switch ($t) {
        "MIM Test1" {$description = "This test user represents an existing user in the MDgov AD."}
        "MIM Test2" {$description = "This test user represents an identity that does not yet exist in the MDgov AD."}
        "PCNS Test1" {$description = "This test user represents an existing user in the MDgov AD."}
        "PCNS Test2" {$description = "This test user represents an identity that does not yet exist in the MDgov AD."}
    }

    $identity = ($agency + "." + ($t -replace ' ','')).ToLower()

    try{
        New-ADUser `
            -Name "$agency $t" `
            -GivenName $agency `
            -Surname "$t" `
            -SamAccountName $identity `
            -AccountPassword (Read-Host "Enter password for $agency $t" -AsSecureString) `
            -Path (Get-ADOrganizationalUnit -Filter 'Name -eq "Enabled"' -SearchBase $parentOU).DistinguishedName `
            -Enabled $true `
            -Description $description `
            -ChangePasswordAtLogon $false

        if ($t -like "*1*"){
            Set-ADUser -Identity $identity -Replace @{otherHomePhone="$identity@maryland.gov"}
        }
        
        Write-Host "The $agency $t user account has been successfully created."
    }catch {
        Write-Host "There was an issue creating the $agency $t user account, please review Active Directory and and error logging to troubleshoot the root cause of this failure."
    }
}

#Starts PCNS service and sets startup type to automatic for all DCs in AD.
try {
    $DCs = Get-ADDomainController -Filter * | Select-Object -ExpandProperty HostName
    Invoke-Command -ComputerName $DCs -ScriptBlock {
        Set-Service -Name "PCNSSVC" -StartupType Automatic
        Start-Service -Name "PCNSSVC"
    }

    $results = Invoke-Command -ComputerName $DCs -ScriptBlock {
        Get-CimInstance -ClassName Win32_Service -Filter "Name='PCNSSVC'" | 
        Select-Object PSComputerName, Name, StartMode, State
    } 
    
    Write-Host "PCNS services on all domain controllers have been succesfully started, and set to the Automatic startup type."
    $results | Select-Object PSComputerName, Name, StartMode, State
} catch{
    Write-host "There was an issue starting and setting startup type for the PCNS service."
}
