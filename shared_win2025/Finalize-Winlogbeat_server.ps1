<#
.SYNOPSIS
    This script automates the full setup of Sysmon and Winlogbeat.
    It is designed to be run twice. The first run installs Sysmon and reboots.
    The second run installs and starts Winlogbeat.
#>

# --- Step 1: Verify Administrator Privileges ---
Write-Host "Step 1: Checking for Administrator privileges..." -ForegroundColor Yellow
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "This script must be run as an Administrator. Please re-run from an elevated PowerShell."
    Start-Sleep -Seconds 10
    Exit
}
Write-Host "Success: Running as Administrator." -ForegroundColor Green
Write-Host ""


# --- Step 2: Configuration - VERIFY YOUR PATHS HERE ---
$sysmonPath = "C:\Program Files\temp"
$sysmonConfig = "sysmonconfig-export.xml"
$winlogbeatPath = "C:\Program Files\winlogbeat-9.1.4-windows-x86_64"


# --- Step 3: Install or Update Sysmon Configuration ---
Write-Host "Step 3: Checking Sysmon installation..." -ForegroundColor Yellow
$sysmonService = Get-Service -Name "Sysmon" -ErrorAction SilentlyContinue
if ($sysmonService) {
    Write-Host "Sysmon is already installed. Proceeding to next step." -ForegroundColor Green
}
else {
    Write-Host "Sysmon not found. Installing now..." -ForegroundColor Yellow
    Set-Location -Path $sysmonPath
    try {
        Start-Process -FilePath ".\sysmon.exe" -ArgumentList "-accepteula -i $sysmonConfig" -Wait -ErrorAction Stop
        Write-Host "Success: Sysmon installed. The system will now reboot to finalize the installation." -ForegroundColor Green
        # Write-Host "After rebooting, please run this script again to complete the setup." -ForegroundColor Cyan
        Start-Sleep -Seconds 20
        # Restart-Computer -Force
        # Exit # The script will exit here and the computer will restart.
    }
    catch {
        Write-Error "Failed to install/configure Sysmon. Error: $_"
        Start-Sleep -Seconds 10
        Exit
    }
}
Write-Host ""


# --- Step 4: Install the Winlogbeat Service ---
Write-Host "Step 4: Installing the Winlogbeat service..." -ForegroundColor Yellow
Set-Location -Path $winlogbeatPath
$winlogbeatService = Get-Service -Name "winlogbeat" -ErrorAction SilentlyContinue
if ($winlogbeatService) {
    Write-Host "Service 'winlogbeat' is already installed." -ForegroundColor Green
}
else {
    PowerShell.exe -ExecutionPolicy Bypass -File .\install-service-winlogbeat.ps1
    Write-Host "Service 'winlogbeat' installed successfully." -ForegroundColor Green
}
Write-Host ""


# --- Step 5: Start and Verify the Service ---
Write-Host "Step 5: Starting and verifying the Winlogbeat service..." -ForegroundColor Yellow
try {
    Start-Service -Name "winlogbeat" -ErrorAction Stop
    Write-Host "Waiting 10 seconds for the service to fully initialize..."
    Start-Sleep -Seconds 10

    $serviceStatus = (Get-Service -Name "winlogbeat").Status
    if ($serviceStatus -eq "Running") {
        Write-Host "SUCCESS: Winlogbeat service is now running." -ForegroundColor Green
    }
    else {
        Write-Warning "The Winlogbeat service was started but its status is now '$($serviceStatus)'."
    }
}
catch {
    Write-Error "Failed to start the Winlogbeat service. Error: $_"
}

Write-Host ""
Write-Host "Automation script finished."