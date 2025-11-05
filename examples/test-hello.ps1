# Simple test script to verify the WSL-Windows Script Runner is working

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "WSL-Windows Script Runner Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "System Information:" -ForegroundColor Yellow
Write-Host "  Computer: $env:COMPUTERNAME" -ForegroundColor White
Write-Host "  User: $env:USERNAME" -ForegroundColor White
Write-Host "  OS: $((Get-CimInstance Win32_OperatingSystem).Caption)" -ForegroundColor White
Write-Host "  PowerShell: $($PSVersionTable.PSVersion)" -ForegroundColor White
Write-Host ""

Write-Host "Current Time:" -ForegroundColor Yellow
Write-Host "  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
Write-Host ""

Write-Host "Working Directory:" -ForegroundColor Yellow
Write-Host "  $(Get-Location)" -ForegroundColor White
Write-Host ""

Write-Host "Environment Variables (sample):" -ForegroundColor Yellow
Write-Host "  TEMP: $env:TEMP" -ForegroundColor White
Write-Host "  USERPROFILE: $env:USERPROFILE" -ForegroundColor White
Write-Host "  PATH (first entry): $($env:PATH.Split(';')[0])" -ForegroundColor White
Write-Host ""

Write-Host "Test Operations:" -ForegroundColor Yellow
Write-Host "  Creating temporary file..." -ForegroundColor Gray
$tempFile = Join-Path $env:TEMP "wsl-runner-test-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
"Test content from WSL-Windows Script Runner" | Out-File -FilePath $tempFile
if (Test-Path $tempFile) {
    Write-Host "  SUCCESS: Created $tempFile" -ForegroundColor Green
    Write-Host "  Cleaning up..." -ForegroundColor Gray
    Remove-Item $tempFile
    Write-Host "  Cleanup complete" -ForegroundColor Green
} else {
    Write-Host "  FAILED: Could not create temp file" -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test Completed Successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

# Return success
exit 0
