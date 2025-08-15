# Test network connectivity to an angecy's domain controller by entering the known SwGi IP address as defined in the $remoteIP parameter:
#
# Define the IP address of the remote domain/forest
$remoteIP = "10.84.9.11" # Change this to the IP address you want to test

# Define the list of ports to test
$ports = @(53, 88, 135, 389, 445, 464, 636, 3268, 3269)

# Function to test connectivity to a specific port
function Test-Port {
    param (
        [string]$IPAddress,
        [int]$Port
    )
    
    try {
        $connection = New-Object System.Net.Sockets.TcpClient
        $connection.Connect($IPAddress, $Port)
        Write-Host "Port ${Port}: Open" -ForegroundColor Green
        $connection.Close()
    } catch {
        Write-Host "Port ${Port}: Closed" -ForegroundColor Red
    }
}

# Test each port
foreach ($port in $ports) {
    Test-Port -IPAddress $remoteIP -Port $port
}
