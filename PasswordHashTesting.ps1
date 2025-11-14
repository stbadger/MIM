# Starts PCNS service if it is not running.
if((Get-Service -Name "PCNSSVC").status -ne "Running"){
    Write-Host "Starting PCNS service"
    Start-Service -Name "PCNSSVC"
    Write-Host "PCNS service has been started" -ForegroundColor Yellow
    Start-Sleep -Seconds 5
}

$testUsers = @(".mimtest1", ".pcnstest1")
$resetTime = Get-Date
$resetTime = $resetTime.AddMinutes(-1)

foreach($t in $testUsers){

    # Establishes credentials to be used for password hash test.
    $user = Get-ADUser -Filter "sAMAccountName -like '*$t'" -Properties sAMAccountName
    if($user.DistinguishedName -like "*OU=MIM-Test*"){
        $username = $user.SamAccountName
        $newPassword = Read-Host "Enter the new password for $username" -AsSecureString

        # Resets user's password.
        Set-ADAccountPassword -Identity $username -NewPassword $newPassword
        Set-ADUser -Identity $username -PasswordNeverExpires $false
        Write-Host "Password for user $username has been reset successfully" -ForegroundColor Yellow
    }
}

Start-Sleep -Seconds 5

# Checks event log for identified PCNS events and outputs test results.
$Events = Get-EventLog -LogName Application | Where-Object { 
    $_.Source -eq "PCNSSVC" -and $_.TimeGenerated -gt $resetTime
    }
if ($Events) {
    Write-Host "`nPCNS Event Codes:"
    $Events | ForEach-Object {
        $user = [regex]::Match($_.Message, 'User: (.+)').Groups[1].Value
        $message = $_.Message -split "`n" | Select-Object -First 1

        # Outputs the event information that indicates the PCNS agent successfully delivered the password reset notification.
        if ($_.EventId -eq "2100" -and $_.TimeGenerated) {
            Write-Host "User: $user, Time: $($_.TimeGenerated), Event ID: $($_.EventId), $message" -ForegroundColor Green
        
        # Outputs the event information for non-error PCNS events other than the successful event.
        } elseif ($_.EntryType -ne "Warning" -and $_.EventId -ne "2100") {
            Write-Host "Time: $($_.TimeGenerated), Event ID: $($_.EventId), $message" -ForegroundColor Yellow
        
        # Outputs the event information for error PCNS events.
        } elseif ($_.EntryType -eq "Error") {
            Write-Host "Time: $($_.TimeGenerated), Event ID: $($_.EventId), $message" -ForegroundColor Red
        }
    }
} else {
    Write-Host "`nNo relevant event codes were found." -ForegroundColor Red
}
