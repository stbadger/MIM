# Each password reset needs to be set to a different password for PCNS to receive and deliver a notification to the MIM Sync server. 
# This function ensures that when the script is pushed out to DCs, each password reset will utilize a new, complex password.
function Generate-ComplexPassword {
    param(
        [int]$length = 16
    )
    $upper   = [char[]]'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    $lower   = [char[]]'abcdefghijklmnopqrstuvwxyz'
    $digits  = [char[]]'0123456789'
    $special = [char[]]'!@#$%^&*()-_=+[]{}|;:,.<>/?'

    $all = $upper + $lower + $digits + $special
    $password = -join (
        ($upper | Get-Random -Count 2) +
        ($lower | Get-Random -Count 2) +
        ($digits | Get-Random -Count 2) +
        ($special | Get-Random -Count 2) +
        ($all | Get-Random -Count ($length - 8))
    )
    $password = ($password.ToCharArray() | Get-Random -Count $length) -join ''
    return $password
}

# Hard coded sAMAccountName, PCNS validation testing will involve resetting this user's password on each DC.
$username = "default"

# Hard coded file path to a txt file where the testing results will be outputted to, needs to be accessible by all DCs.
$filePath = "default"

$NewPassword = Generate-ComplexPassword
$output = ""
$service = "PCNSSVC"

# Creates txt file to output test results to if it does not already exist.
if (-not (Test-Path $filePath)) {
    New-Item -Path $filePath -ItemType File
}

$IP = Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
        $_.IPAddress -ne "127.0.0.1" -and $_.IPAddress -notlike "169.254*"
    } | Select-Object -ExpandProperty IPAddress

$output += "`n" + $env:COMPUTERNAME + " " + $IP

# Conducts PCNS validation testing and formats outputted test results.
try {
    if ($service.Status -ne "Running"){
        Start-Service -Name $service
        Start-Sleep -Seconds 5
    }
    try { 
        $resetTime = (Get-Date).AddMinutes(-1)

        Set-ADAccountPassword -Identity $username -NewPassword (ConvertTo-SecureString $NewPassword -AsPlainText -Force)
        Set-ADUser -Identity $username -PasswordNeverExpires $false
        $output += "`n" + "Password reset successful for $username"

        Start-Sleep -Seconds 5
        try {
            $Events = Get-EventLog -LogName Application | Where-Object {
                $_.Source -eq "PCNSSVC" -and $_.TimeGenerated -gt $resetTime
            }
            if ($Events) {
                $output += "`n" + "PCNS Event Codes:"
                $Events | ForEach-Object {
                    $message = $_.Message -split "`n" | Select-Object -First 1
                    if ($_.EntryType -eq "Information") {
                        if ($_.EventID -eq "2100"){
                            $output += "`n" + "[Success] $($_.TimeGenerated), Event ID: $($_.EventId), $message"
                        } else {
                            $output += "`n" + "[$($_.EntryType)] $($_.TimeGenerated), Event ID: $($_.EventId), $message"
                        }
                    } elseif ($_.EntryType -eq "Warning") {
                        $output += "`n" + "[$($_.EntryType)] $($_.TimeGenerated), Event ID: $($_.EventId), $message"
                    } elseif ($_.EntryType -eq "Error") {
                        $output += "`n" + "[$($_.EntryType)] $($_.TimeGenerated), Event ID: $($_.EventId), $message"
                    }
                }
            } else {
                $output += "`n" + "No relevant event codes were found."
            }
        } catch {
            $output += "`n" + "An error occurred while checking the Event Viewer for PCNS event codes"
        }
    } catch {
        $output += "`n" + "An error occurred while resetting the password for $username"
    }
} catch {
    $output += "`n" + "An error occurred while starting the PCNS service"
}

$output | Out-File -FilePath $filePath -Encoding UTF8 -Append
