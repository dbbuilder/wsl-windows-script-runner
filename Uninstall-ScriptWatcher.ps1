#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Uninstalls the Script Watcher scheduled task.

.PARAMETER TaskName
    Name of the scheduled task. Defaults to "WSL-Windows-ScriptRunner"

.EXAMPLE
    .\Uninstall-ScriptWatcher.ps1
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$TaskName = "WSL-Windows-ScriptRunner"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "WSL-Windows Script Runner - Uninstallation" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Check if task exists
$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

if (-not $task) {
    Write-Host "Scheduled task '$TaskName' not found." -ForegroundColor Yellow
    Write-Host "Nothing to uninstall.`n" -ForegroundColor Gray
    exit 0
}

Write-Host "Found task: $TaskName" -ForegroundColor White
Write-Host "Status: $($task.State)`n" -ForegroundColor White

# Confirm removal
$response = Read-Host "Are you sure you want to remove this task? (y/N)"

if ($response -eq 'y' -or $response -eq 'Y') {
    try {
        # Stop the task if running
        if ($task.State -eq 'Running') {
            Write-Host "Stopping task..." -ForegroundColor Yellow
            Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1
        }

        # Remove the task
        Write-Host "Removing task..." -ForegroundColor Yellow
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false

        Write-Host "Task removed successfully!`n" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "Uninstallation Complete!" -ForegroundColor Green
        Write-Host "========================================`n" -ForegroundColor Cyan
    }
    catch {
        Write-Host "ERROR: Failed to remove task" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        exit 1
    }
}
else {
    Write-Host "Uninstallation cancelled.`n" -ForegroundColor Gray
}
