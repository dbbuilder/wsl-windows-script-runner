# Example: Export data from Windows that can be read by WSL
# This demonstrates how to pass information back to WSL

param(
    [string]$OutputPath = "D:\Dev2\wsl-windows-script-runner\queue\output.json"
)

Write-Host "Collecting Windows system information..." -ForegroundColor Cyan

# Collect system information
$systemInfo = @{
    Timestamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    ComputerName = $env:COMPUTERNAME
    UserName = $env:USERNAME
    OSVersion = (Get-CimInstance Win32_OperatingSystem).Caption
    OSArchitecture = (Get-CimInstance Win32_OperatingSystem).OSArchitecture
    TotalMemoryGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
    ProcessorCount = (Get-CimInstance Win32_ComputerSystem).NumberOfProcessors
    LogicalProcessors = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
    PowerShellVersion = "$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)"

    # Network information
    NetworkAdapters = @(
        Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object Name, InterfaceDescription, MacAddress, LinkSpeed
    )

    # Disk information
    Disks = @(
        Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -ne $null } | Select-Object Name,
            @{Name='UsedGB';Expression={[math]::Round(($_.Used / 1GB), 2)}},
            @{Name='FreeGB';Expression={[math]::Round(($_.Free / 1GB), 2)}},
            @{Name='TotalGB';Expression={[math]::Round((($_.Used + $_.Free) / 1GB), 2)}}
    )

    # Running processes (top 10 by memory)
    TopProcesses = @(
        Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 10 |
            Select-Object ProcessName,
                @{Name='MemoryMB';Expression={[math]::Round($_.WorkingSet / 1MB, 2)}},
                Id, CPU
    )
}

# Convert to JSON
$json = $systemInfo | ConvertTo-Json -Depth 5

# Output to console
Write-Host "`nCollected System Information:" -ForegroundColor Green
Write-Host $json -ForegroundColor Gray

# Save to file
$json | Out-File -FilePath $OutputPath -Encoding UTF8
Write-Host "`nData exported to: $OutputPath" -ForegroundColor Green

# Also create a simple text summary
$summaryPath = $OutputPath -replace '\.json$', '.txt'
$summary = @"
Windows System Summary
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
==========================================

Computer: $env:COMPUTERNAME
User: $env:USERNAME
OS: $($systemInfo.OSVersion) ($($systemInfo.OSArchitecture))
Memory: $($systemInfo.TotalMemoryGB) GB
Processors: $($systemInfo.ProcessorCount) physical, $($systemInfo.LogicalProcessors) logical
PowerShell: v$($systemInfo.PowerShellVersion)

Disk Space:
$(
    $systemInfo.Disks | ForEach-Object {
        "  $($_.Name):\ - $($_.FreeGB) GB free of $($_.TotalGB) GB total"
    } | Out-String
)

Top Processes by Memory:
$(
    $systemInfo.TopProcesses | ForEach-Object {
        "  $($_.ProcessName) - $($_.MemoryMB) MB"
    } | Out-String
)
==========================================
"@

$summary | Out-File -FilePath $summaryPath -Encoding UTF8
Write-Host "Summary exported to: $summaryPath" -ForegroundColor Green

Write-Host "`nTo read this data from WSL:" -ForegroundColor Yellow
Write-Host "  cat /mnt/d/Dev2/wsl-windows-script-runner/queue/output.json | jq" -ForegroundColor Gray
Write-Host "  cat /mnt/d/Dev2/wsl-windows-script-runner/queue/output.txt" -ForegroundColor Gray

exit 0
