param(
    [switch]$Logging
)

# Updates registry path to enable PCNS verbose logging if -Logging switch is used.
if ($Logging) {
    $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\PCNSSVC\Parameters"
    $registryValueName = "EventLogLevel"
    $registryValueData = "3"

    # Creates required registry path if it does not exist.
    try {
        if (-not (Test-Path $registryPath)) {
            New-Item -Path $registryPath -Force
            Write-Host "New registry path to enable PCNS logging created" -ForegroundColor Green
        }

        # Sets the registry value to enable PCNS verbose logging.
        try {
            $currentValueData = Get-ItemPropertyValue -Path $registryPath -Name $registryValueName
            if($currentValueData -ne $registryValueData){
                Set-ItemProperty -Path $registryPath -Name $registryValueName -Value $registryValueData
                Write-Host "Registry value updated successfully to enable PCNS verbose logging" -ForegroundColor Green

                # Resets the PCNS service to apply registry value change.
                $ServiceName = "PCNSSVC"
                try {
                    Write-Host "Stopping the service: $ServiceName"
                    Stop-Service -Name $ServiceName -Force
                    Write-Host "Starting the service: $ServiceName"
                    Start-Service -Name $ServiceName
                    Write-Host "Service $ServiceName has been reset successfully" -ForegroundColor Green
                } catch {
                    Write-Host "An error occurred while restarting the PCNS service" -ForegroundColor Red
                }
            } else {
                Write-Host "Registry value to enable PCNS verbose logging already exists" -ForegroundColor Yellow
            }
        } catch {
        Write-Host "An error occurred updating the registry value to enable PCNS verbose logging" -ForegroundColor Red
        }
    } catch {
        Write-Host "An error occurred creating the registry path to enable PCNS logging" -ForegroundColor Red
    }
}

# Prompts user to enter username and password. 
$username = Read-Host "Enter the username for which you want to reset the password"
Write-Host "Enter the new password:"
$newPassword = Read-Host -AsSecureString

try {
    # Records time to use when filtering event codes.
    $resetTime = Get-Date
    $resetTime = $resetTime.AddMinutes(-1)

    # Resets user's password.
    Set-ADAccountPassword -Identity $username -NewPassword $newPassword
    Set-ADUser -Identity $username -PasswordNeverExpires $false
    Write-Host "Password for user $username has been reset successfully" -ForegroundColor Green

    # Pauses script to allow event codes to populate.
    Start-Sleep -Seconds 5

    # Checks event log for identified PCNS events and outputs test results.
    try {
        $Events = Get-EventLog -LogName Application | Where-Object { 
            $_.Source -eq "PCNSSVC" -and $_.TimeGenerated -gt $resetTime
        }
        if ($Events) {
                Write-Host ""
                Write-Host "PCNS Event Codes:"
                $Events | ForEach-Object { 
                    $message = $_.Message -split "`n" | Select-Object -First 1
                    if ($_.EntryType -eq "Information") {
                        Write-Host "Time: $($_.TimeGenerated), Event ID: $($_.EventId), $message" -ForegroundColor Green
                    } elseif ($_.EntryType -eq "Warning") {
                        Write-Host "Time: $($_.TimeGenerated), Event ID: $($_.EventId), $message" -ForegroundColor Yellow
                    } elseif ($_.EntryType -eq "Error") {
                        Write-Host "Time: $($_.TimeGenerated), Event ID: $($_.EventId), $message" -ForegroundColor Red
                    }
                }
        } else {
            Write-Host ""
            Write-Host "No relevant event codes were found." -ForegroundColor Red
        }
    } catch {
        Write-Host ""
        Write-Host "An error occurred while checking the Event Viewer: $_" -ForegroundColor Red
    }
} catch {
    Write-Host "An error occurred while resetting the password: $_" -ForegroundColor Red
}

# If PCNS logging registry value is set to verbose, asks user if they want to return to default logging capabilities.
$loggingValueData = Get-ItemPropertyValue -Path $registryPath -Name $registryValueName
if ($loggingValueData -eq "3"){

    do {
        Write-Host ""
        $loggingReset = Read-Host "Currently PCNS logging is set to verbose mode in the registry, return to default logging (Y/N)?"
        try {
            if ($loggingReset -eq "Y" -or $loggingReset -eq "y"){
                Set-ItemProperty -Path $registryPath -Name $registryValueName -Value "1"
                Write-Host "Registry value updated successfully to disable PCNS verbose logging" -ForegroundColor Green
                $validInput = $true
            } elseif ($loggingReset -eq "N" -or $loggingReset -eq "n"){
                Write-Host "Registry value has not been updated, PCNS verbose logging remains enabled" -ForegroundColor Green
                $validInput = $true
            } else {
                Write-Host "Invalid input, please enter Y or N" -ForegroundColor Red
                $validInput = $false
            }
        } catch {
            Write-Host "An error occurred updating the registry value to enable default PCNS logging" -ForegroundColor Red
        }
    } until ($validInput)
}
