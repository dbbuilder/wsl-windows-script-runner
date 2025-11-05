#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Installs the Script Watcher as a Windows Scheduled Task.

.DESCRIPTION
    Creates a scheduled task that runs the ScriptWatcher.ps1 at system startup.
    The task runs with highest privileges and restarts on failure.

.PARAMETER TaskName
    Name of the scheduled task. Defaults to "WSL-Windows-ScriptRunner"

.PARAMETER ScriptPath
    Path to the ScriptWatcher.ps1 script. Defaults to the script in the same directory.

.EXAMPLE
    .\Install-ScriptWatcher.ps1

.EXAMPLE
    .\Install-ScriptWatcher.ps1 -TaskName "MyScriptRunner"
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$TaskName = "WSL-Windows-ScriptRunner",

    [Parameter()]
    [string]$ScriptPath = "$PSScriptRoot\ScriptWatcher.ps1"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "WSL-Windows Script Runner - Installation" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Verify script exists
if (-not (Test-Path $ScriptPath)) {
    Write-Host "ERROR: ScriptWatcher.ps1 not found at: $ScriptPath" -ForegroundColor Red
    exit 1
}

Write-Host "Script Path: $ScriptPath" -ForegroundColor White
Write-Host "Task Name: $TaskName" -ForegroundColor White
Write-Host ""

# Check if task already exists
$existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

if ($existingTask) {
    Write-Host "WARNING: Scheduled task '$TaskName' already exists." -ForegroundColor Yellow
    $response = Read-Host "Do you want to remove and recreate it? (y/N)"

    if ($response -eq 'y' -or $response -eq 'Y') {
        Write-Host "Removing existing task..." -ForegroundColor Yellow
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "Existing task removed.`n" -ForegroundColor Green
    }
    else {
        Write-Host "Installation cancelled." -ForegroundColor Gray
        exit 0
    }
}

# Create the scheduled task
Write-Host "Creating scheduled task..." -ForegroundColor Yellow

# Define the action
$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$ScriptPath`""

# Define the trigger (at startup)
$trigger = New-ScheduledTaskTrigger -AtStartup

# Define settings
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -ExecutionTimeLimit (New-TimeSpan -Days 0)

# Define principal (run with highest privileges)
$principal = New-ScheduledTaskPrincipal `
    -UserId "SYSTEM" `
    -LogonType ServiceAccount `
    -RunLevel Highest

# Register the task
try {
    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Principal $principal `
        -Description "Monitors queue folder for new scripts and executes them automatically with logging. Used to bridge WSL and Windows script execution." |
        Out-Null

    Write-Host "Scheduled task created successfully!`n" -ForegroundColor Green

    # Display task information
    Write-Host "Task Details:" -ForegroundColor Cyan
    Write-Host "  Name: $TaskName" -ForegroundColor White
    Write-Host "  Trigger: At system startup" -ForegroundColor White
    Write-Host "  User: SYSTEM" -ForegroundColor White
    Write-Host "  Status: Ready" -ForegroundColor White
    Write-Host ""

    # Ask if user wants to start the task now
    $startNow = Read-Host "Do you want to start the task now? (Y/n)"

    if ($startNow -ne 'n' -and $startNow -ne 'N') {
        Write-Host "Starting task..." -ForegroundColor Yellow
        Start-ScheduledTask -TaskName $TaskName
        Start-Sleep -Seconds 2

        # Check if task is running
        $task = Get-ScheduledTask -TaskName $TaskName
        if ($task.State -eq 'Running') {
            Write-Host "Task is now running!`n" -ForegroundColor Green
        }
        else {
            Write-Host "Task started but may have stopped. Check Task Scheduler for details.`n" -ForegroundColor Yellow
        }
    }

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Installation Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Queue folder: $PSScriptRoot\queue" -ForegroundColor White
    Write-Host "Logs folder: $PSScriptRoot\logs" -ForegroundColor White
    Write-Host ""
    Write-Host "To manage the task:" -ForegroundColor Yellow
    Write-Host "  - View status: Get-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Gray
    Write-Host "  - Start: Start-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Gray
    Write-Host "  - Stop: Stop-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Gray
    Write-Host "  - Remove: Unregister-ScheduledTask -TaskName '$TaskName' -Confirm:`$false" -ForegroundColor Gray
    Write-Host ""
    Write-Host "From WSL, place scripts in: /mnt/d/Dev2/wsl-windows-script-runner/queue" -ForegroundColor Cyan
    Write-Host ""
}
catch {
    Write-Host "ERROR: Failed to create scheduled task" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
