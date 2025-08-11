# Establishes list of domain controllers that will be tested.
$domainName = Read-Host "Enter your domain name"
$DCs = Get-ADDomainController -discover -domain $domainName | Select-Object -ExpandProperty HostName

# Establishes user that will be used for PCNS valication testing.
$username = Read-Host "Enter the username for which you want to reset the password"
Write-Host ""

#Establishes required information for setting PCNS agents to verbose logging mode.
$registryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\PCNSSVC\Parameters"
$registryValueName = "EventLogLevel"
$registryValueData = "3"

# Contains the script that will be executed on each domain controller in the Invoke-Command.
$scriptBlock = {

param($registryPath, $registryValueName, $registryValueData, $username)
    
    # Contains IPv4 address for the domain controller that is currently being tested.
    $IP = Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
        $_.IPAddress -ne "127.0.0.1" -and $_.IPAddress -notlike "169.254*"
    } | Select-Object -ExpandProperty IPAddress
    
    # In-line output indicating which domain controller is currently conducting PCNS validation testting.
    Write-Host "Conducting PCNS Validation Testing on DC: $env:COMPUTERNAME IP: $IP" -ForegroundColor DarkYellow
    Write-Output "$env:COMPUTERNAME,$IP"

    # Creates required registry path for PCNS verbose logging if it does not exist.
    try {
        if (-not (Test-Path $registryPath)) {
            New-Item -Path $registryPath -Force
            Write-Host "New registry path to enable PCNS logging created"
        }

        # Sets the registry value to enable PCNS verbose logging.
        try {
            $currentValueData = Get-ItemPropertyValue -Path $registryPath -Name $registryValueName
            if($currentValueData -ne $registryValueData){
                Set-ItemProperty -Path $registryPath -Name $registryValueName -Value $registryValueData
                Write-Host "Registry value updated to enable PCNS verbose logging"

                # Resets the PCNS service to apply registry value change.
                $ServiceName = "PCNSSVC"
                try {
                    Write-Host "Stopping the service: $ServiceName"
                    Stop-Service -Name $ServiceName -Force
                    Write-Host "Starting the service: $ServiceName"
                    Start-Service -Name $ServiceName
                    Write-Host "$ServiceName service has been reset"
                } catch {
                    Write-Host "An error occurred while restarting $ServiceName service" -ForegroundColor Red
                }
            } else {
                Write-Host "Registry value to enable PCNS verbose logging already exists"
            }
        } catch {
            Write-Host "An error occurred updating the registry value to enable PCNS verbose logging" -ForegroundColor Red
        }
    } catch {
        Write-Host "An error occurred creating the registry path to enable PCNS logging" -ForegroundColor Red
    }
    
    # Pauses the script to give time for the PCNS service to start before conducting a password reset.
    Start-Sleep -Seconds 5

    # Establishes a random secure password to be used for resetting the user's password.
    Add-Type -AssemblyName System.Web
    $newPassword = [System.Web.Security.Membership]::GeneratePassword(16, 4)
    $securePassword = ConvertTo-SecureString $newPassword -AsPlainText -Force

    try {
        # Records time to use when filtering event codes.
        $resetTime = Get-Date
        $resetTime = $resetTime.AddMinutes(-1)

        # Resets user's password.
        Set-ADAccountPassword -Identity $username -NewPassword $securePassword
        Set-ADUser -Identity $username -PasswordNeverExpires $false
        Write-Host "Password for user $username has been reset"

        # Pauses script to allow event codes to populate.
        Start-Sleep -Seconds 5

        # Checks event log for identified PCNS events and outputs test results.
        try {
            $Events = Get-EventLog -LogName Application | Where-Object { 
                $_.Source -eq "PCNSSVC" -and $_.TimeGenerated -gt $resetTime
            }
            if ($Events) {
                    Write-Output "Time,Event ID,Description"
                    $Events | ForEach-Object { 
                        $message = $_.Message -split "`n" | Select-Object -First 1
                        if ($_.EntryType -eq "Information") {
                            Write-Output "$($_.TimeGenerated),$($_.EventId),$($message.Trim())"
                            if ($_.EventID -eq "2100") {
                                Write-Host "Time: $($_.TimeGenerated), Event ID: $($_.EventId), $($message.Trim())" -ForegroundColor Green
                            }
                        } elseif ($_.EntryType -eq "Warning") {
                            Write-Output "$($_.TimeGenerated),$($_.EventId),$($message.Trim())"
                        } elseif ($_.EntryType -eq "Error") {
                            Write-Output "$($_.TimeGenerated),$($_.EventId),$($message.Trim())"
                        }
                    }
            } else {
                Write-Output "No relevant event codes were found."
            }
        } catch {
            Write-Output "An error occurred while checking the Event Viewer:,$_"
        }
    } catch {
        Write-Output "An error occurred while resetting the password:,$_"
    }

    # Resets registry value to disable PCNS verbose logging.
    $loggingValueData = Get-ItemPropertyValue -Path $registryPath -Name $registryValueName
    if ($loggingValueData -eq "3"){
        try{
            Set-ItemProperty -Path $registryPath -Name $registryValueName -Value "1"
            Write-Host "Registry value updated successfully to disable PCNS verbose logging"
        } catch {
            Write-Host "An error occurred updating the registry value to disable PCNS verbose logging"
        }
                
    }

    Write-Output ""
    Write-Host ""
    Start-Sleep -Seconds 5
} 

# Runs script block on each domain controller in Active Directory and outputs test results to a local text file.
$results = Invoke-Command -ComputerName $DCs -ScriptBlock $scriptBlock -ArgumentList $registryPath, $registryValueName, $registryValueData, $username | Out-File "C:\Temp\PCNS_Test.csv"
