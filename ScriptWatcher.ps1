#Requires -Version 5.1

<#
.SYNOPSIS
    Watches a folder for new scripts and executes them automatically with full logging.

.DESCRIPTION
    This script monitors a queue folder for new .bat and .ps1 files.
    When a new script is detected and fully written, it executes the script
    and captures all output to a timestamped log file.

.PARAMETER QueuePath
    Path to monitor for new scripts. Defaults to .\queue

.PARAMETER LogPath
    Path to store log files. Defaults to .\logs

.PARAMETER CompletedPath
    Path to move completed scripts. Defaults to .\completed

.PARAMETER ArchivePath
    Path to move scripts that fail to execute. Defaults to .\archive

.EXAMPLE
    .\ScriptWatcher.ps1 -QueuePath "C:\ScriptQueue" -LogPath "C:\ScriptLogs"
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$QueuePath = "$PSScriptRoot\queue",

    [Parameter()]
    [string]$LogPath = "$PSScriptRoot\logs",

    [Parameter()]
    [string]$CompletedPath = "$PSScriptRoot\completed",

    [Parameter()]
    [string]$ArchivePath = "$PSScriptRoot\archive",

    [Parameter()]
    [int]$FileStabilityDelayMs = 1000
)

# Ensure paths exist
@($QueuePath, $LogPath, $CompletedPath, $ArchivePath) | ForEach-Object {
    if (-not (Test-Path $_)) {
        New-Item -ItemType Directory -Path $_ -Force | Out-Null
        Write-Host "Created directory: $_"
    }
}

# Function to wait for file to be fully written
function Wait-FileReady {
    param([string]$FilePath)

    Write-Host "Waiting for file to be fully written: $FilePath"

    # Wait initial delay
    Start-Sleep -Milliseconds $FileStabilityDelayMs

    # Try to open file exclusively to ensure it's not being written
    $maxAttempts = 10
    $attempt = 0

    while ($attempt -lt $maxAttempts) {
        try {
            $stream = [System.IO.File]::Open($FilePath, 'Open', 'Read', 'None')
            $stream.Close()
            $stream.Dispose()
            Write-Host "File is ready for processing"
            return $true
        }
        catch {
            $attempt++
            Write-Host "File still being written, waiting... (attempt $attempt/$maxAttempts)"
            Start-Sleep -Milliseconds 500
        }
    }

    Write-Warning "File may still be locked after $maxAttempts attempts"
    return $false
}

# Function to execute a script and capture output
function Invoke-ScriptWithLogging {
    param(
        [string]$ScriptPath,
        [string]$LogPath
    )

    $scriptName = [System.IO.Path]::GetFileNameWithoutExtension($ScriptPath)
    $scriptExt = [System.IO.Path]::GetExtension($ScriptPath)
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $logFile = Join-Path $LogPath "${scriptName}_${timestamp}.log"

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Processing: $scriptName$scriptExt" -ForegroundColor Cyan
    Write-Host "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
    Write-Host "Log file: $logFile" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    # Prepare log header
    $logHeader = @"
========================================
Script Execution Log
========================================
Script: $ScriptPath
Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Host: $env:COMPUTERNAME
User: $env:USERNAME
Working Directory: $(Get-Location)
========================================

"@

    $logHeader | Out-File -FilePath $logFile -Encoding UTF8

    try {
        $startTime = Get-Date

        if ($scriptExt -eq '.ps1') {
            # Execute PowerShell script
            Write-Host "Executing PowerShell script..." -ForegroundColor Yellow

            # Run in a new PowerShell process to capture all output
            $process = Start-Process -FilePath "powershell.exe" `
                -ArgumentList "-ExecutionPolicy", "Bypass", "-File", "`"$ScriptPath`"" `
                -NoNewWindow `
                -Wait `
                -PassThru `
                -RedirectStandardOutput "$logFile.stdout" `
                -RedirectStandardError "$logFile.stderr"

            # Combine stdout and stderr into main log
            "`n--- Standard Output ---`n" | Out-File -FilePath $logFile -Append -Encoding UTF8
            if (Test-Path "$logFile.stdout") {
                Get-Content "$logFile.stdout" | Out-File -FilePath $logFile -Append -Encoding UTF8
                Remove-Item "$logFile.stdout"
            }

            "`n--- Standard Error ---`n" | Out-File -FilePath $logFile -Append -Encoding UTF8
            if (Test-Path "$logFile.stderr") {
                Get-Content "$logFile.stderr" | Out-File -FilePath $logFile -Append -Encoding UTF8
                Remove-Item "$logFile.stderr"
            }

            $exitCode = $process.ExitCode
        }
        elseif ($scriptExt -eq '.bat' -or $scriptExt -eq '.cmd') {
            # Execute batch file
            Write-Host "Executing batch script..." -ForegroundColor Yellow

            $process = Start-Process -FilePath "cmd.exe" `
                -ArgumentList "/c", "`"$ScriptPath`"" `
                -NoNewWindow `
                -Wait `
                -PassThru `
                -RedirectStandardOutput "$logFile.stdout" `
                -RedirectStandardError "$logFile.stderr"

            # Combine stdout and stderr into main log
            "`n--- Standard Output ---`n" | Out-File -FilePath $logFile -Append -Encoding UTF8
            if (Test-Path "$logFile.stdout") {
                Get-Content "$logFile.stdout" | Out-File -FilePath $logFile -Append -Encoding UTF8
                Remove-Item "$logFile.stdout"
            }

            "`n--- Standard Error ---`n" | Out-File -FilePath $logFile -Append -Encoding UTF8
            if (Test-Path "$logFile.stderr") {
                Get-Content "$logFile.stderr" | Out-File -FilePath $logFile -Append -Encoding UTF8
                Remove-Item "$logFile.stderr"
            }

            $exitCode = $process.ExitCode
        }
        else {
            throw "Unsupported script type: $scriptExt"
        }

        $endTime = Get-Date
        $duration = $endTime - $startTime

        # Append execution summary
        $summary = @"

========================================
Execution Summary
========================================
Exit Code: $exitCode
Completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Duration: $($duration.ToString())
Status: $(if ($exitCode -eq 0) { 'SUCCESS' } else { 'FAILED' })
========================================
"@

        $summary | Out-File -FilePath $logFile -Append -Encoding UTF8

        if ($exitCode -eq 0) {
            Write-Host "Script completed successfully (Exit Code: $exitCode)" -ForegroundColor Green
            Write-Host "Duration: $($duration.ToString())" -ForegroundColor Green
            return @{ Success = $true; ExitCode = $exitCode; LogFile = $logFile }
        }
        else {
            Write-Host "Script failed with exit code: $exitCode" -ForegroundColor Red
            Write-Host "Duration: $($duration.ToString())" -ForegroundColor Yellow
            return @{ Success = $false; ExitCode = $exitCode; LogFile = $logFile }
        }
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Host "ERROR: $errorMsg" -ForegroundColor Red

        "`n========================================`nERROR: $errorMsg`n========================================" |
            Out-File -FilePath $logFile -Append -Encoding UTF8

        return @{ Success = $false; ExitCode = -1; LogFile = $logFile; Error = $errorMsg }
    }
}

# Function to process a script file
function Process-ScriptFile {
    param([string]$FilePath)

    $fileName = [System.IO.Path]::GetFileName($FilePath)

    # Wait for file to be fully written
    if (-not (Wait-FileReady -FilePath $FilePath)) {
        Write-Warning "Skipping file that appears to still be locked: $fileName"
        return
    }

    # Execute the script
    $result = Invoke-ScriptWithLogging -ScriptPath $FilePath -LogPath $LogPath

    # Move script to completed or archive folder
    try {
        if ($result.Success) {
            $destination = Join-Path $CompletedPath $fileName
            Move-Item -Path $FilePath -Destination $destination -Force
            Write-Host "Moved to completed: $destination`n" -ForegroundColor Green
        }
        else {
            $destination = Join-Path $ArchivePath $fileName
            Move-Item -Path $FilePath -Destination $destination -Force
            Write-Host "Moved to archive (failed): $destination`n" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Warning "Could not move script file: $_"
    }
}

# Main execution
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "WSL-Windows Script Runner - File Watcher" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Queue Path: $QueuePath" -ForegroundColor White
Write-Host "Log Path: $LogPath" -ForegroundColor White
Write-Host "Completed Path: $CompletedPath" -ForegroundColor White
Write-Host "Archive Path: $ArchivePath" -ForegroundColor White
Write-Host "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
Write-Host "========================================`n" -ForegroundColor Cyan

# Process any existing files in the queue
Write-Host "Checking for existing files in queue..." -ForegroundColor Yellow
$existingFiles = Get-ChildItem -Path $QueuePath -Filter "*.ps1", "*.bat", "*.cmd" -File
if ($existingFiles) {
    Write-Host "Found $($existingFiles.Count) existing file(s) to process`n" -ForegroundColor Yellow
    foreach ($file in $existingFiles) {
        Process-ScriptFile -FilePath $file.FullName
    }
}
else {
    Write-Host "No existing files found`n" -ForegroundColor Gray
}

# Set up file system watcher
Write-Host "Starting file system watcher..." -ForegroundColor Yellow
Write-Host "Monitoring for new .ps1, .bat, and .cmd files`n" -ForegroundColor Yellow

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $QueuePath
$watcher.Filter = "*.*"
$watcher.IncludeSubdirectories = $false
$watcher.EnableRaisingEvents = $true

# Define the event handler
$action = {
    $path = $Event.SourceEventArgs.FullPath
    $name = $Event.SourceEventArgs.Name
    $changeType = $Event.SourceEventArgs.ChangeType

    # Only process .ps1, .bat, and .cmd files
    if ($path -match '\.(ps1|bat|cmd)$') {
        Write-Host "Detected: $changeType - $name" -ForegroundColor Cyan

        # Process the file
        Process-ScriptFile -FilePath $path
    }
}

# Register event handlers
$handlers = @()
$handlers += Register-ObjectEvent -InputObject $watcher -EventName "Created" -Action $action
$handlers += Register-ObjectEvent -InputObject $watcher -EventName "Changed" -Action $action

Write-Host "File watcher is active. Press Ctrl+C to stop..." -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan

# Keep the script running
try {
    while ($true) {
        Start-Sleep -Seconds 1
    }
}
finally {
    # Cleanup
    Write-Host "`n`nShutting down..." -ForegroundColor Yellow
    $handlers | ForEach-Object { Unregister-Event -SourceIdentifier $_.Name }
    $watcher.EnableRaisingEvents = $false
    $watcher.Dispose()
    Write-Host "File watcher stopped." -ForegroundColor Gray
}
