# This script is designed to be idempotent and robust.

# --- Script Parameters ---
# CRITICAL: Make sure these values are correct!
$DomainName = "ttpl.local"
$DC_IP = "192.168.10.220"  # IMPORTANT: Use the NEW IP address of your DC
$AdminUser = "administrator"
$AdminPassword = "admin" # CRITICAL: This MUST match the password used to create the domain

# --- Idempotency Check ---
Write-Host "Checking if this PC is already joined to the domain..."
if ((Get-ComputerInfo).Domain -eq $DomainName) {
    Write-Host "This PC is already a member of the '$DomainName' domain. Exiting script."
    exit
}
Write-Host "PC is not domain-joined. Proceeding..."

# --- 1. Wait for Domain Controller ---
Write-Host "Waiting for the Domain Controller at $DC_IP to come online..."
while (-not (Test-NetConnection -ComputerName $DC_IP -Port 389 -InformationLevel "Quiet")) {
    Write-Host "DC is not reachable yet. Retrying in 10 seconds..."
    Start-Sleep -Seconds 10
}
Write-Host "Domain Controller is online!"

# --- 2. Robust Network Configuration ---
Write-Host "Configuring static IP and DNS..."
$ipAddress = "192.168.10.219" # A free IP for this client
$gateway = "192.168.10.1"
$dnsServer = $DC_IP # DNS MUST point to the Domain Controller

# Find the primary active network adapter
$adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1

if ($adapter) {
    Write-Host "Found active network adapter: $($adapter.Name)"
    
    # --- THE FINAL FIX ---
    # This logic now uses separate, direct commands to configure the network.
    # This avoids the complex object type mismatch and is the most reliable method.
    
    # First, remove any old IP addresses to prevent conflicts.
    Remove-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4 -Confirm:$false
    
    # Second, create the new IP address and gateway.
    New-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -IPAddress $ipAddress -PrefixLength 24 -DefaultGateway $gateway
    
    # Finally, set the DNS server.
    Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses $dnsServer
    
    Write-Host "Static IP and DNS configured."
    Start-Sleep -Seconds 15 # Give network settings a moment to apply
}
else {
    Write-Error "Could not find an active network adapter."
    exit
}

# --- 3. Join the Domain ---
Write-Host "Joining the domain '$DomainName'..."
$username = "$DomainName\$AdminUser"
$credential = New-Object System.Management.Automation.PSCredential($username, (ConvertTo-SecureString $AdminPassword -AsPlainText -Force))

Add-Computer -DomainName $DomainName -Credential $credential -Restart -Force
Write-Host "Domain join complete. The computer will restart automatically."

