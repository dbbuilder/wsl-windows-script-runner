# Quick Start Guide

Get up and running with WSL-Windows Script Runner in 5 minutes.

## 1. Install (Windows - Run as Administrator)

```powershell
# Open PowerShell as Administrator
cd D:\Dev2\wsl-windows-script-runner
.\Install-ScriptWatcher.ps1
```

When prompted, choose **Yes** to start the task immediately.

## 2. Verify Installation

### From Windows:

```powershell
.\Get-WatcherStatus.ps1
```

You should see:
- Scheduled Task: **Running** (green)
- All directories: **Exists** (green)

### From WSL:

```bash
/mnt/d/Dev2/wsl-windows-script-runner/wsl-submit.sh --status
```

## 3. Test with Sample Script

### From WSL:

```bash
# Submit the test script
/mnt/d/Dev2/wsl-windows-script-runner/wsl-submit.sh \
  /mnt/d/Dev2/wsl-windows-script-runner/examples/test-hello.ps1

# Wait 2 seconds
sleep 2

# View the log
latest_log=$(ls -t /mnt/d/Dev2/wsl-windows-script-runner/logs/*.log | head -1)
cat "$latest_log"
```

You should see system information and a success message.

## 4. Create Your Own Script

```bash
# Create a simple PowerShell script
cat > /tmp/my-test.ps1 << 'EOF'
Write-Host "Hello from WSL via Windows!" -ForegroundColor Green
Write-Host "Current directory: $(Get-Location)"
Get-ChildItem C:\ | Select-Object -First 5
EOF

# Submit it
/mnt/d/Dev2/wsl-windows-script-runner/wsl-submit.sh /tmp/my-test.ps1

# Check the logs
/mnt/d/Dev2/wsl-windows-script-runner/wsl-submit.sh --logs my-test
```

## 5. Add Convenience Alias (Optional)

Add to your `~/.bashrc` or `~/.zshrc`:

```bash
echo 'alias wsl-run="/mnt/d/Dev2/wsl-windows-script-runner/wsl-submit.sh"' >> ~/.bashrc
source ~/.bashrc
```

Now you can use:

```bash
wsl-run script.ps1        # Submit a script
wsl-run --status          # Check status
wsl-run --logs            # View logs
wsl-run --logs pattern    # Filter logs
wsl-run --tail logfile    # Tail a log
```

## Common Tasks

### Submit a PowerShell Script

```bash
wsl-run myscript.ps1
```

### Submit a Batch File

```bash
wsl-run backup.bat
```

### View Recent Logs

```bash
wsl-run --logs
```

### Filter Logs by Name

```bash
wsl-run --logs backup
```

### Read a Specific Log

```bash
wsl-run --tail backup_20250115_143022.log
```

### Check Service Status

```bash
wsl-run --status
```

## Troubleshooting

### Task Not Running

**Windows (PowerShell as Admin):**

```powershell
# Check task state
Get-ScheduledTask -TaskName "WSL-Windows-ScriptRunner"

# Start it manually
Start-ScheduledTask -TaskName "WSL-Windows-ScriptRunner"

# Check if it's running
Get-ScheduledTask -TaskName "WSL-Windows-ScriptRunner" | Select State
```

### Script Not Executing

1. **Verify the watcher is running:**
   ```bash
   wsl-run --status
   ```

2. **Check queue folder:**
   ```bash
   ls -la /mnt/d/Dev2/wsl-windows-script-runner/queue/
   ```

3. **Run watcher manually (Windows):**
   ```powershell
   # Stop the scheduled task first
   Stop-ScheduledTask -TaskName "WSL-Windows-ScriptRunner"

   # Run manually to see errors
   .\ScriptWatcher.ps1

   # In another window, submit a test script from WSL
   ```

### No Logs Created

1. **Check permissions:**
   ```bash
   ls -ld /mnt/d/Dev2/wsl-windows-script-runner/logs/
   ```

2. **Verify watcher is running:**
   ```powershell
   Get-ScheduledTask -TaskName "WSL-Windows-ScriptRunner" | Format-List *
   ```

3. **Check Event Viewer (Windows):**
   - Event Viewer → Windows Logs → Application
   - Look for PowerShell errors

## Next Steps

- Read the full [README.md](README.md) for advanced usage
- Check [examples/](examples/) for sample scripts
- Customize paths in `Install-ScriptWatcher.ps1` if needed

## Uninstall

```powershell
# Windows PowerShell as Administrator
cd D:\Dev2\wsl-windows-script-runner
.\Uninstall-ScriptWatcher.ps1
```

---

**Need Help?** See the [Troubleshooting](README.md#troubleshooting) section in the main README.
