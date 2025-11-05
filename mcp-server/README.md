# MCP Server for WSL-Windows Script Runner

This MCP (Model Context Protocol) server provides native Claude Code integration for executing Windows scripts from WSL.

## Overview

Instead of using bash commands to submit scripts, Claude can now use dedicated tools:

- `windows_execute` - Execute PowerShell commands/scripts
- `windows_execute_batch` - Execute batch commands
- `windows_get_status` - Get runner status
- `windows_list_logs` - List recent logs
- `windows_read_log` - Read specific log files

## Installation

### Step 1: Install the MCP Server (WSL)

```bash
cd /mnt/d/Dev2/wsl-windows-script-runner/mcp-server
./setup.sh
```

This will:
- Create a Python virtual environment
- Install the `mcp` package
- Make the server executable

### Step 2: Configure Claude Code

Add the MCP server to your Claude Code configuration.

**File:** `~/.config/claude/claude_desktop_config.json` (Linux/WSL)
**File:** `%APPDATA%\Claude\claude_desktop_config.json` (Windows)

```json
{
  "mcpServers": {
    "windows-runner": {
      "command": "/mnt/d/Dev2/wsl-windows-script-runner/mcp-server/venv/bin/python",
      "args": ["/mnt/d/Dev2/wsl-windows-script-runner/mcp-server/server.py"]
    }
  }
}
```

**Note:** Use the absolute paths shown by the setup script.

### Step 3: Install Windows Script Watcher (Windows)

Make sure the Windows side is running:

```powershell
# PowerShell as Administrator
cd D:\Dev2\wsl-windows-script-runner
.\Install-ScriptWatcher.ps1
```

### Step 4: Restart Claude Code

Restart Claude Code to load the MCP server.

## Usage Examples

### Execute PowerShell Commands

**Simple command:**

```
Use windows_execute to get the current Windows user
```

Claude will call:
```json
{
  "command": "$env:USERNAME",
  "wait": true
}
```

**Complex script:**

```
Use windows_execute to list all running Chrome processes with their memory usage
```

Claude will call:
```json
{
  "command": "Get-Process | Where-Object Name -like '*chrome*' | Select-Object Name, @{Name='MemoryMB';Expression={[math]::Round($_.WorkingSet / 1MB, 2)}}, Id | Format-Table",
  "wait": true
}
```

### Execute Batch Commands

```
Use windows_execute_batch to check the Windows version
```

Claude will call:
```json
{
  "command": "ver",
  "wait": true
}
```

### Check Status

```
Check the status of the Windows script runner
```

Claude will call `windows_get_status` and get:

```json
{
  "queue": {
    "path": "/mnt/d/Dev2/wsl-windows-script-runner/queue",
    "pending_scripts": 0,
    "files": []
  },
  "logs": {
    "path": "/mnt/d/Dev2/wsl-windows-script-runner/logs",
    "total_logs": 15,
    "latest": "test_20250115_143022.log",
    "latest_time": "2025-01-15T14:30:23"
  },
  "completed": {
    "path": "/mnt/d/Dev2/wsl-windows-script-runner/completed",
    "count": 10
  },
  "archive": {
    "path": "/mnt/d/Dev2/wsl-windows-script-runner/archive",
    "count": 2
  }
}
```

### List and Read Logs

```
Show me the 5 most recent Windows execution logs
```

Claude will call:
```json
{
  "limit": 5
}
```

```
Read the log file test_20250115_143022.log
```

Claude will call:
```json
{
  "log_name": "test_20250115_143022.log"
}
```

## Tool Reference

### windows_execute

Execute PowerShell commands or scripts on Windows.

**Parameters:**
- `command` (required, string) - PowerShell command or multi-line script
- `script_name` (optional, string) - Custom name for the script (without .ps1)
- `wait` (optional, boolean) - Wait for execution to complete (default: true)
- `timeout` (optional, integer) - Max seconds to wait (default: 60)

**Returns:**
```json
{
  "script_name": "ps_20250115_143022_a1b2c3d4.ps1",
  "submitted": true,
  "success": true,
  "log_file": "ps_20250115_143022_a1b2c3d4_20250115_143023.log",
  "log_content": "... full log output ...",
  "exit_code": 0,
  "status": "SUCCESS",
  "duration": "00:00:01.1234567"
}
```

**Example:**
```python
# Claude uses this tool like:
windows_execute(
    command="Get-Process chrome | Select-Object -First 5",
    wait=True
)
```

### windows_execute_batch

Execute batch/cmd commands on Windows.

**Parameters:**
- `command` (required, string) - Batch command or script
- `script_name` (optional, string) - Custom name for the script (without .bat)
- `wait` (optional, boolean) - Wait for execution to complete (default: true)
- `timeout` (optional, integer) - Max seconds to wait (default: 60)

**Returns:** Same format as `windows_execute`

### windows_get_status

Get current status of the Windows script runner.

**Parameters:** None

**Returns:**
```json
{
  "queue": {
    "path": "...",
    "pending_scripts": 0,
    "files": []
  },
  "logs": {
    "path": "...",
    "total_logs": 15,
    "latest": "...",
    "latest_time": "..."
  },
  "completed": { "count": 10 },
  "archive": { "count": 2 }
}
```

### windows_list_logs

List recent execution log files.

**Parameters:**
- `limit` (optional, integer) - Max logs to return (default: 10)
- `pattern` (optional, string) - Filter pattern for log names

**Returns:**
```json
[
  {
    "name": "test_20250115_143022.log",
    "size_kb": 1.23,
    "modified": "2025-01-15T14:30:23"
  }
]
```

### windows_read_log

Read the complete contents of a log file.

**Parameters:**
- `log_name` (required, string) - Name of the log file

**Returns:** Full log file contents as text

## How It Works

```
┌─────────────────────────────────────────────────┐
│ Claude Code (WSL)                               │
│                                                 │
│  User: "Check Windows disk space"              │
│    ↓                                            │
│  Claude decides to use windows_execute          │
│    ↓                                            │
│  MCP Server (Python)                            │
│    ├─ Creates temp PowerShell script           │
│    ├─ Writes to queue/ folder                  │
│    └─ Waits for execution                      │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│ Windows Host                                    │
│                                                 │
│  ScriptWatcher (Scheduled Task)                 │
│    ├─ Detects new file in queue/               │
│    ├─ Executes PowerShell script                │
│    ├─ Captures output to logs/                 │
│    └─ Moves script to completed/               │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│ MCP Server (Python)                             │
│    ├─ Detects script removed from queue        │
│    ├─ Finds matching log file                  │
│    ├─ Reads and parses results                 │
│    └─ Returns to Claude                        │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│ Claude Code                                     │
│    └─ Presents results to user                 │
└─────────────────────────────────────────────────┘
```

## Advantages Over Bash Tool

### Before (Bash Tool):
```
Claude: I'll create a PowerShell script and submit it.
  [Uses Write tool to create script]
  [Uses Bash tool to call wsl-submit.sh]
  [Uses Bash tool to wait]
  [Uses Read tool to read log]
  [Parses log manually]
```

4-5 tool calls, manual log parsing

### After (MCP Server):
```
Claude: I'll execute this Windows command.
  [Uses windows_execute]
  [Gets structured result immediately]
```

1 tool call, structured response

## Troubleshooting

### MCP Server Not Showing in Claude

1. Check configuration path:
   ```bash
   cat ~/.config/claude/claude_desktop_config.json
   ```

2. Verify paths are absolute (not relative)

3. Restart Claude Code completely

4. Check Claude Code logs for MCP server errors

### Commands Timing Out

1. Increase timeout:
   ```json
   {
     "command": "long-running-task",
     "timeout": 300
   }
   ```

2. For very long tasks, use `wait: false`:
   ```json
   {
     "command": "very-long-task",
     "wait": false
   }
   ```
   Then check logs manually later

### Windows Script Watcher Not Running

Check from WSL:
```bash
/mnt/d/Dev2/wsl-windows-script-runner/wsl-submit.sh --status
```

Or from Windows:
```powershell
Get-ScheduledTask -TaskName "WSL-Windows-ScriptRunner"
```

### Script Executed But No Results

1. Check if log was created:
   ```
   Use windows_list_logs to see recent executions
   ```

2. Read the log manually:
   ```
   Use windows_read_log with the log file name
   ```

3. Check the archive folder (failed scripts):
   ```bash
   ls /mnt/d/Dev2/wsl-windows-script-runner/archive/
   ```

## Configuration Options

### Custom Base Directory

Edit `server.py` line 18:

```python
BASE_DIR = Path("/your/custom/path")
```

### Adjust Default Timeout

Edit `server.py` tool definitions to change default from 60 seconds:

```python
"timeout": {
    "type": "integer",
    "description": "Maximum seconds to wait for execution (default: 120)",
    "default": 120
}
```

## Security Considerations

- **MCP server runs as your WSL user** - has access to your files
- **Windows scripts run as SYSTEM** - have full Windows privileges
- **No authentication** - any code submitted will execute
- **Use only in trusted environments**

## Testing

### Test 1: Simple Command

From Claude:
```
Use windows_execute to get the computer name
```

Expected: Quick response with computer name

### Test 2: Complex Script

From Claude:
```
Use windows_execute to get the top 5 processes by memory usage
```

Expected: Formatted table of processes

### Test 3: Status Check

From Claude:
```
Check the Windows script runner status
```

Expected: JSON with queue/logs/completed counts

## Development

### Running Manually

```bash
cd /mnt/d/Dev2/wsl-windows-script-runner/mcp-server
source venv/bin/activate
python server.py
```

The server expects MCP protocol on stdin/stdout.

### Debugging

Add logging to `server.py`:

```python
import sys

def debug_log(msg):
    with open("/tmp/mcp-debug.log", "a") as f:
        f.write(f"{datetime.now()}: {msg}\n")

# Use throughout code
debug_log(f"Executing command: {command}")
```

## Version

- **Version:** 1.0.0
- **MCP Protocol:** 1.0
- **Python:** 3.7+
- **Dependencies:** `mcp>=1.0.0`

## License

Free and unencumbered software released into the public domain.

## See Also

- [Main README](../README.md) - WSL-Windows Script Runner documentation
- [Quick Start](../QUICKSTART.md) - 5-minute setup guide
- [MCP Documentation](https://modelcontextprotocol.io/) - Model Context Protocol
