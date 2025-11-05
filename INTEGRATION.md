# Claude Integration Guide

This document compares the two ways to integrate WSL-Windows Script Runner with Claude Code.

## Quick Comparison

| Feature | MCP Server ⭐ | Bash Helper |
|---------|-------------|-------------|
| **Setup Complexity** | Medium (one-time) | Low |
| **Claude Integration** | Native tools | Manual bash calls |
| **Tool Calls per Task** | 1 | 3-5 |
| **Structured Results** | Yes (JSON) | No (raw text) |
| **Discoverability** | High | Low |
| **Async Support** | Built-in | Manual |
| **Error Handling** | Structured | Manual parsing |
| **Best For** | Regular use | Quick testing |

## Option 1: MCP Server (Recommended) ⭐

### Setup (One-Time)

```bash
# 1. Install MCP server
cd /mnt/d/Dev2/wsl-windows-script-runner/mcp-server
./setup.sh

# 2. Configure Claude Code
./configure-claude.sh

# 3. Restart Claude Code
```

### Usage

Claude can now use native tools:

**Execute PowerShell:**
```
Use windows_execute to get the current Windows time
```

**Execute with custom timeout:**
```
Use windows_execute to run a long task with a 5 minute timeout:
Get-Process | Export-Csv processes.csv
```

**Check status:**
```
Check the Windows script runner status
```

**View logs:**
```
Show me the 5 most recent Windows execution logs
```

**Read specific log:**
```
Read the log file ps_20250115_143022_a1b2c3d4_20250115_143023.log
```

### How It Works

```
User: "Check Windows disk space"
  ↓
Claude: [Uses windows_execute tool]
  ↓
MCP Server: Creates temp .ps1, submits to queue, waits
  ↓
Windows: Executes script, creates log
  ↓
MCP Server: Reads log, parses results
  ↓
Claude: Presents results to user
```

**Tool calls:** 1
**Complexity:** Low
**Response time:** Fast

### Pros

✅ Native Claude integration
✅ Single tool call per task
✅ Structured JSON responses
✅ Built-in timeout handling
✅ Automatic log retrieval
✅ Clean error messages
✅ Discoverable by Claude

### Cons

❌ Requires MCP setup
❌ One more service to manage
❌ Python dependency

### Tools Available

1. **windows_execute** - Execute PowerShell
   ```json
   {
     "command": "Get-Process chrome",
     "script_name": "check-chrome",  // optional
     "wait": true,                    // default: true
     "timeout": 60                    // default: 60
   }
   ```

2. **windows_execute_batch** - Execute batch/cmd
   ```json
   {
     "command": "dir C:\\"
   }
   ```

3. **windows_get_status** - Get runner status
   ```json
   {}
   ```

4. **windows_list_logs** - List recent logs
   ```json
   {
     "limit": 10,         // default: 10
     "pattern": "backup"  // optional filter
   }
   ```

5. **windows_read_log** - Read specific log
   ```json
   {
     "log_name": "ps_20250115_143022.log"
   }
   ```

## Option 2: Bash Helper Script

### Setup

```bash
# Optional: Add alias to ~/.bashrc
echo 'alias wsl-run="/mnt/d/Dev2/wsl-windows-script-runner/wsl-submit.sh"' >> ~/.bashrc
source ~/.bashrc
```

### Usage

Claude uses the Bash tool:

**Execute PowerShell:**
```bash
# Create script
cat > /tmp/check-time.ps1 << 'EOF'
Get-Date
EOF

# Submit
/mnt/d/Dev2/wsl-windows-script-runner/wsl-submit.sh /tmp/check-time.ps1

# Wait
sleep 2

# Read log
latest=$(ls -t /mnt/d/Dev2/wsl-windows-script-runner/logs/*.log | head -1)
cat "$latest"
```

**Check status:**
```bash
/mnt/d/Dev2/wsl-windows-script-runner/wsl-submit.sh --status
```

**View logs:**
```bash
/mnt/d/Dev2/wsl-windows-script-runner/wsl-submit.sh --logs
```

### How It Works

```
User: "Check Windows disk space"
  ↓
Claude: [Uses Write tool to create script]
  ↓
Claude: [Uses Bash tool to submit script]
  ↓
Claude: [Uses Bash tool to wait/check]
  ↓
Claude: [Uses Read tool to read log]
  ↓
Claude: [Parses log manually]
  ↓
Claude: Presents results to user
```

**Tool calls:** 4-5
**Complexity:** High
**Response time:** Slower

### Pros

✅ Simple setup
✅ No additional services
✅ Direct file system access
✅ Full control over process

### Cons

❌ Multiple tool calls
❌ Manual log parsing
❌ No structured responses
❌ Harder for Claude to discover
❌ More error-prone
❌ Verbose workflow

## Real-World Example

### Task: Get Windows System Info

#### With MCP Server (1 call):

**User:** "Get Windows system information"

**Claude:**
```
I'll use windows_execute to get system information.
```

**Result:** Structured JSON with system info in ~2 seconds

---

#### With Bash Helper (5 calls):

**User:** "Get Windows system information"

**Claude:**
```
I'll create a PowerShell script, submit it, wait for execution, and read the results.

[Uses Write tool to create script]
[Uses Bash tool to submit: wsl-submit.sh script.ps1]
[Uses Bash tool to wait: sleep 3]
[Uses Bash tool to find log: ls -t logs/*.log | head -1]
[Uses Read tool to read log]
```

**Result:** Raw log text, manually parsed, in ~5-10 seconds

## Recommendation

### Use MCP Server If:
- ✅ You use Claude Code regularly
- ✅ You want clean, native integration
- ✅ You value structured responses
- ✅ You're okay with one-time setup

### Use Bash Helper If:
- ✅ You need quick testing
- ✅ You want minimal dependencies
- ✅ You rarely execute Windows commands
- ✅ You prefer direct control

## Migration Path

You can start with the Bash helper and migrate to MCP later:

```bash
# Start with Bash helper (works immediately)
/mnt/d/Dev2/wsl-windows-script-runner/wsl-submit.sh test.ps1

# Later, add MCP server (both work simultaneously)
cd /mnt/d/Dev2/wsl-windows-script-runner/mcp-server
./setup.sh
./configure-claude.sh

# Now Claude will prefer MCP tools but Bash still works
```

Both approaches use the same underlying infrastructure, so there's no conflict.

## Summary

**For most Claude Code users:** Use the **MCP Server** (Option 1)
**For quick tests or automation:** Use the **Bash Helper** (Option 2)

The MCP server provides a significantly better experience with minimal setup cost.

---

## Next Steps

### If you chose MCP Server:
1. [Install MCP Server](mcp-server/README.md)
2. Configure Claude Code
3. Test with simple commands
4. Enjoy native integration

### If you chose Bash Helper:
1. [Read Quick Start](QUICKSTART.md)
2. Optionally add alias
3. Use wsl-submit.sh
4. Consider MCP later

Both options use the same Windows Script Watcher service, so you only need to install that once.
