Import-Module ActiveDirectory

#Establishes the different test user accounts that will need to be created.
$testUsers = @("MIM Test1", "MIM Test2", "PCNS Test1", "PCNS Test2")

#Creates the test OU that will be used to scope testing to only include test user accounts.
try{
    New-ADOrganizationalUnit -Name "MIM-Test" -Path (Get-ADDomain).DistinguishedName -Description "This is OU contains MIM test user accounts"
} catch {
    if (Get-ADOrganizationalUnit -Filter 'Name -eq "MIM-Test"'){
        Write-Host "The MIM-Test OU already exists"
    } else{
        Write-Host "There was an issue creating the MIM-Test OU"
        exit
    }
}

$agency = Read-Host "Please enter your agency's acronym"

#Creates required MIM test accounts.
foreach ($t in $testUsers){
    switch ($t) {
        "MIM Test1" {$description = "Legacy MDgov"}
        "MIM Test2" {$description = "Net new"}
        "PCNS Test1" {$description = "Legacy MDgov"}
        "PCNS Test2" {$description = "Net new"}
    }

    $identity = ($agency + "." + ($t -replace ' ','')).ToLower()

    try{
        New-ADUser `
            -Name "$agency $t" `
            -GivenName $agency `
            -Surname "$t" `
            -SamAccountName $identity `
            -AccountPassword (Read-Host "Enter password" -AsSecureString) `
            -Path (Get-ADOrganizationalUnit -Filter 'Name -eq "MIM-Test"').DistinguishedName `
            -Enabled $false `
            -Description $description `
            -ChangePasswordAtLogon $false

        if ($t -like "*1*"){
            Set-ADUser -Identity $identity -Replace @{otherHomePhone="$identity@maryland.gov"}
        }
        
        Write-Host "$agency $t user account has been successfully created"
    }catch {
        Write-Host "There was an issue creating the $agency $t user account"
    }
}

#Starts PCNS service and sets startup type to auto for all DCs in AD.
try {
    $DCs = Get-ADDomainController -Filter * | Select-Object -ExpandProperty HostName
    Invoke-Command -ComputerName $DCs -ScriptBlock {
        Set-Service -Name "PCNSSVC" -StartupType Automatic
        Start-Service -Name "PCNSSVC"

        Get-CimInstance -ClassName Win32_Service -Filter "Name='PCNSSVC'" | 
        Select-Object PSComputerName, Name, StartMode, State
    }

    Write-Host "PCNS services on all domain controllers have been succesfully started and set to automatic startup type"
} catch{
    Write-host "There was an issue starting and setting startup type for the PCNS service"
}
