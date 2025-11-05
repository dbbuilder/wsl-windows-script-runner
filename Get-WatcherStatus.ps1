#Requires -Version 5.1

<#
.SYNOPSIS
    Displays the status of the Script Watcher.

.PARAMETER TaskName
    Name of the scheduled task. Defaults to "WSL-Windows-ScriptRunner"

.EXAMPLE
    .\Get-WatcherStatus.ps1
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$TaskName = "WSL-Windows-ScriptRunner",

    [Parameter()]
    [switch]$ShowRecentLogs
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "WSL-Windows Script Runner - Status" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Check scheduled task
$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

if ($task) {
    Write-Host "Scheduled Task:" -ForegroundColor Yellow
    Write-Host "  Name: $($task.TaskName)" -ForegroundColor White
    Write-Host "  State: $($task.State)" -ForegroundColor $(if ($task.State -eq 'Running') { 'Green' } else { 'Yellow' })
    Write-Host "  Description: $($task.Description)" -ForegroundColor Gray
    Write-Host ""

    # Get task info
    $taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($taskInfo) {
        Write-Host "  Last Run: $($taskInfo.LastRunTime)" -ForegroundColor White
        Write-Host "  Last Result: $($taskInfo.LastTaskResult)" -ForegroundColor $(if ($taskInfo.LastTaskResult -eq 0) { 'Green' } else { 'Red' })
        Write-Host "  Next Run: $($taskInfo.NextRunTime)" -ForegroundColor White
        Write-Host ""
    }
}
else {
    Write-Host "Scheduled Task: NOT INSTALLED" -ForegroundColor Red
    Write-Host "Run Install-ScriptWatcher.ps1 to install.`n" -ForegroundColor Yellow
}

# Check directories
$baseDir = Split-Path -Parent $PSCommandPath
$queueDir = Join-Path $baseDir "queue"
$logsDir = Join-Path $baseDir "logs"
$completedDir = Join-Path $baseDir "completed"
$archiveDir = Join-Path $baseDir "archive"

Write-Host "Directories:" -ForegroundColor Yellow
Write-Host "  Queue: $queueDir" -ForegroundColor White
if (Test-Path $queueDir) {
    $queueFiles = Get-ChildItem -Path $queueDir -Filter "*.ps1", "*.bat", "*.cmd" -File
    Write-Host "    Status: Exists" -ForegroundColor Green
    Write-Host "    Pending scripts: $($queueFiles.Count)" -ForegroundColor $(if ($queueFiles.Count -gt 0) { 'Cyan' } else { 'Gray' })
}
else {
    Write-Host "    Status: NOT FOUND" -ForegroundColor Red
}

Write-Host ""
Write-Host "  Logs: $logsDir" -ForegroundColor White
if (Test-Path $logsDir) {
    $logFiles = Get-ChildItem -Path $logsDir -Filter "*.log" -File | Sort-Object LastWriteTime -Descending
    Write-Host "    Status: Exists" -ForegroundColor Green
    Write-Host "    Total logs: $($logFiles.Count)" -ForegroundColor Gray
    if ($logFiles.Count -gt 0) {
        Write-Host "    Latest: $($logFiles[0].Name) ($($logFiles[0].LastWriteTime))" -ForegroundColor Gray
    }
}
else {
    Write-Host "    Status: NOT FOUND" -ForegroundColor Red
}

Write-Host ""
Write-Host "  Completed: $completedDir" -ForegroundColor White
if (Test-Path $completedDir) {
    $completedFiles = Get-ChildItem -Path $completedDir -File
    Write-Host "    Status: Exists" -ForegroundColor Green
    Write-Host "    Completed scripts: $($completedFiles.Count)" -ForegroundColor Gray
}
else {
    Write-Host "    Status: NOT FOUND" -ForegroundColor Red
}

Write-Host ""
Write-Host "  Archive: $archiveDir" -ForegroundColor White
if (Test-Path $archiveDir) {
    $archiveFiles = Get-ChildItem -Path $archiveDir -File
    Write-Host "    Status: Exists" -ForegroundColor Green
    Write-Host "    Failed scripts: $($archiveFiles.Count)" -ForegroundColor $(if ($archiveFiles.Count -gt 0) { 'Yellow' } else { 'Gray' })
}
else {
    Write-Host "    Status: NOT FOUND" -ForegroundColor Red
}

Write-Host ""

# Show recent logs if requested
if ($ShowRecentLogs -and (Test-Path $logsDir)) {
    $recentLogs = Get-ChildItem -Path $logsDir -Filter "*.log" -File | Sort-Object LastWriteTime -Descending | Select-Object -First 5

    if ($recentLogs) {
        Write-Host "Recent Log Files (last 5):" -ForegroundColor Yellow
        foreach ($log in $recentLogs) {
            Write-Host "  $($log.Name)" -ForegroundColor White
            Write-Host "    Modified: $($log.LastWriteTime)" -ForegroundColor Gray
            Write-Host "    Size: $([math]::Round($log.Length / 1KB, 2)) KB" -ForegroundColor Gray
            Write-Host ""
        }
    }
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Management Commands:" -ForegroundColor Yellow
Write-Host "  Start: Start-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Gray
Write-Host "  Stop: Stop-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Gray
Write-Host "  Install: .\Install-ScriptWatcher.ps1" -ForegroundColor Gray
Write-Host "  Uninstall: .\Uninstall-ScriptWatcher.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "From WSL:" -ForegroundColor Yellow
Write-Host "  Place scripts in: /mnt/d/Dev2/wsl-windows-script-runner/queue" -ForegroundColor Gray
Write-Host "  View logs: /mnt/d/Dev2/wsl-windows-script-runner/logs" -ForegroundColor Gray
Write-Host "========================================`n" -ForegroundColor Cyan
