# WSL-Windows Script Runner

A bridge service that allows WSL environments to execute Windows scripts (.bat, .ps1) on the Windows host automatically with full logging and monitoring.

## Overview

This tool solves the problem of running Windows-native scripts from WSL (Windows Subsystem for Linux). It monitors a queue folder for new scripts, automatically executes them on Windows, captures full output logs, and organizes completed scripts.

**Perfect for**: AI assistants (like Claude) running in WSL that need to execute Windows commands, automated workflows, testing, or any scenario where WSL needs to trigger Windows-side operations.

## Features

- **Automatic Execution**: Scripts placed in the queue folder are executed immediately
- **Full Logging**: Complete stdout/stderr capture with timestamps
- **File Stability Detection**: Waits for files to be fully written before execution
- **Organized Output**: Automatic sorting into completed/archive folders
- **Exit Code Tracking**: Success/failure detection with proper logging
- **Multiple Script Types**: Supports .ps1, .bat, and .cmd files
- **WSL Integration**: Easy-to-use bash helper script for submissions
- **Service Mode**: Runs as a Windows Scheduled Task (starts at boot)
- **Error Recovery**: Automatic restart on failure
- **MCP Integration**: Optional MCP server for native Claude Code integration

## Integration Options

### Option 1: MCP Server (Recommended for Claude Code) ⭐

The MCP (Model Context Protocol) server provides native Claude integration with dedicated tools:

- `windows_execute` - Execute PowerShell commands with one tool call
- `windows_get_status` - Check runner status
- `windows_list_logs` - View recent logs
- `windows_read_log` - Read specific log files

**Setup:**
```bash
cd /mnt/d/Dev2/wsl-windows-script-runner/mcp-server
./setup.sh
./configure-claude.sh
```

See [mcp-server/README.md](mcp-server/README.md) for full documentation.

**Usage in Claude:**
```
Use windows_execute to get the Windows computer name
Use windows_execute to list all running Chrome processes
Check the Windows script runner status
```

### Option 2: Bash Helper Script

Use the `wsl-submit.sh` helper script directly:

```bash
/mnt/d/Dev2/wsl-windows-script-runner/wsl-submit.sh script.ps1
```

This option requires more manual steps but works without MCP setup.

## Architecture

```
WSL Environment                    Windows Host
┌─────────────────┐               ┌──────────────────────┐
│                 │               │                      │
│  Claude/User    │               │  Script Watcher      │
│      ↓          │               │  (Scheduled Task)    │
│  wsl-submit.sh  │───────┐       │         ↓            │
│      ↓          │       │       │  FileSystemWatcher   │
│  Copy to queue  │       │       │         ↓            │
│                 │       │       │  Execute Script      │
└─────────────────┘       │       │         ↓            │
                          │       │  Capture Logs        │
   Shared Folder          │       │         ↓            │
┌─────────────────────────┼───────┼──────────────────────┐
│ /mnt/d/Dev2/wsl-...     │       │  D:\Dev2\wsl-...     │
│                         │       │                      │
│  queue/ ←───────────────┘       │  ← Monitor           │
│  logs/                          │  → Write             │
│  completed/                     │  → Move (success)    │
│  archive/                       │  → Move (failure)    │
└─────────────────────────────────┴──────────────────────┘
```

## Directory Structure

```
wsl-windows-script-runner/
├── queue/                      # Drop scripts here (monitored)
├── logs/                       # Execution logs with timestamps
├── completed/                  # Successfully executed scripts
├── archive/                    # Failed scripts
├── ScriptWatcher.ps1           # Main file watcher service
├── Install-ScriptWatcher.ps1   # Installation script
├── Uninstall-ScriptWatcher.ps1 # Removal script
├── Get-WatcherStatus.ps1       # Status checker
├── wsl-submit.sh               # WSL helper script
└── README.md                   # This file
```

## Installation

### Step 1: Install the Scheduled Task (Windows, as Administrator)

```powershell
# Open PowerShell as Administrator
cd D:\Dev2\wsl-windows-script-runner

# Install the service
.\Install-ScriptWatcher.ps1
```

This will:
- Create a scheduled task named "WSL-Windows-ScriptRunner"
- Configure it to run at system startup
- Run with SYSTEM privileges for maximum compatibility
- Set up automatic restart on failure

### Step 2: Verify Installation

```powershell
# Check status (Windows)
.\Get-WatcherStatus.ps1

# Or from WSL
/mnt/d/Dev2/wsl-windows-script-runner/wsl-submit.sh --status
```

### Step 3: Optional - Add WSL Helper to PATH

```bash
# Add to your ~/.bashrc or ~/.zshrc
echo 'alias wsl-run="/mnt/d/Dev2/wsl-windows-script-runner/wsl-submit.sh"' >> ~/.bashrc
source ~/.bashrc

# Now you can use:
wsl-run script.ps1
wsl-run --status
wsl-run --logs
```

## Usage

### From WSL

#### Submit a Script for Execution

```bash
# Using the helper script
/mnt/d/Dev2/wsl-windows-script-runner/wsl-submit.sh myscript.ps1

# Or if you added the alias
wsl-run myscript.ps1

# Or copy directly
cp myscript.bat /mnt/d/Dev2/wsl-windows-script-runner/queue/
```

#### Check Status

```bash
wsl-run --status
```

#### View Logs

```bash
# List recent logs
wsl-run --logs

# Filter logs
wsl-run --logs backup

# Tail a specific log
wsl-run --tail backup_20250115_143022.log
```

#### Watch Queue in Real-Time

```bash
wsl-run --watch
```

### From Windows

#### Manual Execution (Testing)

```powershell
# Run the watcher manually (for testing)
.\ScriptWatcher.ps1

# Press Ctrl+C to stop
```

#### Check Status

```powershell
.\Get-WatcherStatus.ps1

# Or check the scheduled task
Get-ScheduledTask -TaskName "WSL-Windows-ScriptRunner"
```

#### Start/Stop the Service

```powershell
# Start
Start-ScheduledTask -TaskName "WSL-Windows-ScriptRunner"

# Stop
Stop-ScheduledTask -TaskName "WSL-Windows-ScriptRunner"

# Restart
Stop-ScheduledTask -TaskName "WSL-Windows-ScriptRunner"
Start-ScheduledTask -TaskName "WSL-Windows-ScriptRunner"
```

## Examples

### Example 1: Simple PowerShell Script

**From WSL:**

```bash
# Create a test script
cat > /tmp/test.ps1 << 'EOF'
Write-Host "Hello from Windows!"
Write-Host "Current User: $env:USERNAME"
Write-Host "Computer: $env:COMPUTERNAME"
Get-Date
EOF

# Submit it
wsl-run /tmp/test.ps1

# View the log
wsl-run --logs test
```

**Log Output:** `logs/test_20250115_143022.log`

### Example 2: Batch Script with Error Handling

**From WSL:**

```bash
cat > /tmp/backup.bat << 'EOF'
@echo off
echo Starting backup...
echo Timestamp: %DATE% %TIME%

REM This will fail - demonstrates error logging
copy "C:\NonExistent\file.txt" "C:\Backup\" 2>&1

echo Backup process completed
EOF

wsl-run /tmp/backup.bat

# Check the archive (failed scripts)
ls /mnt/d/Dev2/wsl-windows-script-runner/archive/
```

### Example 3: Claude Code Integration

When Claude needs to run a Windows command from WSL:

```bash
# Claude creates a script
cat > /tmp/windows-task.ps1 << 'EOF'
# Install a Windows application
winget install --id Microsoft.PowerToys --silent

# Check if installation succeeded
if ($LASTEXITCODE -eq 0) {
    Write-Host "Installation successful"
} else {
    Write-Error "Installation failed with code: $LASTEXITCODE"
    exit $LASTEXITCODE
}
EOF

# Submit for execution
/mnt/d/Dev2/wsl-windows-script-runner/wsl-submit.sh /tmp/windows-task.ps1

# Wait and check the log
sleep 5
latest_log=$(ls -t /mnt/d/Dev2/wsl-windows-script-runner/logs/*.log | head -1)
cat "$latest_log"
```

## Log Format

Each execution creates a timestamped log file with:

```
========================================
Script Execution Log
========================================
Script: D:\Dev2\wsl-windows-script-runner\queue\test.ps1
Started: 2025-01-15 14:30:22
Host: DESKTOP-ABC123
User: SYSTEM
Working Directory: D:\Dev2\wsl-windows-script-runner
========================================

--- Standard Output ---
Hello from Windows!
Current User: SYSTEM
Computer: DESKTOP-ABC123
Wednesday, January 15, 2025 2:30:22 PM

--- Standard Error ---

========================================
Execution Summary
========================================
Exit Code: 0
Completed: 2025-01-15 14:30:23
Duration: 00:00:01.1234567
Status: SUCCESS
========================================
```

## Troubleshooting

### Task Not Running

```powershell
# Check task status
Get-ScheduledTask -TaskName "WSL-Windows-ScriptRunner" | Format-List *

# Check last run result
Get-ScheduledTaskInfo -TaskName "WSL-Windows-ScriptRunner"

# View task history in Event Viewer
# Event Viewer → Task Scheduler → Task Scheduler Library
```

### Scripts Not Executing

1. **Check if task is running:**
   ```powershell
   Get-ScheduledTask -TaskName "WSL-Windows-ScriptRunner" | Select State
   ```

2. **Run watcher manually to see errors:**
   ```powershell
   .\ScriptWatcher.ps1
   ```

3. **Check file permissions:**
   ```bash
   ls -l /mnt/d/Dev2/wsl-windows-script-runner/queue/
   ```

### Scripts Stuck in Queue

- File may still be locked (writing in progress)
- Check watcher is running: `Get-WatcherStatus.ps1`
- Check file extension is .ps1, .bat, or .cmd
- Try restarting the scheduled task

### Logs Not Created

- Check logs directory exists and is writable
- Run `Get-WatcherStatus.ps1` to verify paths
- Check Task Scheduler for execution errors
- Verify SYSTEM account has write permissions

## Advanced Configuration

### Custom Paths

```powershell
# Install with custom paths
.\Install-ScriptWatcher.ps1 -TaskName "MyScriptRunner"

# Run watcher with custom paths
.\ScriptWatcher.ps1 `
    -QueuePath "C:\CustomQueue" `
    -LogPath "C:\CustomLogs" `
    -CompletedPath "C:\CustomCompleted" `
    -ArchivePath "C:\CustomArchive"
```

### File Stability Delay

If scripts are large and take time to write:

```powershell
.\ScriptWatcher.ps1 -FileStabilityDelayMs 5000  # Wait 5 seconds
```

### Execution Policy

If you encounter execution policy errors:

```powershell
# Check current policy
Get-ExecutionPolicy

# Set to allow local scripts (as Administrator)
Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy RemoteSigned -Force
```

## Security Considerations

- **Runs as SYSTEM**: The scheduled task runs with SYSTEM privileges for maximum compatibility
- **No Authentication**: Any file placed in the queue folder will be executed
- **Code Execution**: Scripts have full system access - only use in trusted environments
- **Network Access**: Scripts can access network resources
- **File Permissions**: Ensure queue folder has appropriate ACLs for your security requirements

**Recommendation**: Use this tool only in development/testing environments or on systems where you trust all users with access to the queue folder.

## Uninstallation

```powershell
# Open PowerShell as Administrator
cd D:\Dev2\wsl-windows-script-runner

# Remove the scheduled task
.\Uninstall-ScriptWatcher.ps1

# Optionally, delete the entire directory
# cd ..
# Remove-Item -Recurse -Force wsl-windows-script-runner
```

## Integration with Claude Code

### Best Option: MCP Server (Recommended) ⭐

Install the MCP server for seamless integration:

```bash
cd /mnt/d/Dev2/wsl-windows-script-runner/mcp-server
./setup.sh
./configure-claude.sh
```

Then simply ask Claude:
- "Use windows_execute to check Windows disk space"
- "Get the Windows version using windows_execute"
- "Check the Windows script runner status"

See [mcp-server/README.md](mcp-server/README.md) for details.

### Alternative: Manual Commands

Add to your `~/.claude/CLAUDE.md`:

```markdown
## WSL-Windows Script Runner

When you need to execute Windows-native commands from WSL:

1. Create a PowerShell or batch script with the required commands
2. Submit using: `/mnt/d/Dev2/wsl-windows-script-runner/wsl-submit.sh script.ps1`
3. Check logs in: `/mnt/d/Dev2/wsl-windows-script-runner/logs/`

Helper alias: `wsl-run <script>`
```

## Technical Details

- **File Watcher**: Uses .NET FileSystemWatcher for efficient monitoring
- **Process Execution**: Spawns separate processes to capture output
- **Exit Codes**: Properly captures and logs process exit codes
- **File Locking**: Implements retry logic to ensure files are fully written
- **Encoding**: UTF-8 encoding for log files
- **Restart Policy**: Automatic restart on failure (3 retries, 1-minute interval)

## License

This is free and unencumbered software released into the public domain.

## Contributing

Feel free to submit issues, fork the repository, and create pull requests for any improvements.

## Support

For issues and questions:
1. Check the troubleshooting section above
2. Run `Get-WatcherStatus.ps1` to diagnose
3. Review recent logs in the `logs/` directory
4. Check Windows Event Viewer for Task Scheduler errors

---

**Created for**: Bridging WSL and Windows environments for seamless script execution
**Version**: 1.0.0
**Last Updated**: January 2025
