# Stop-Ollama.ps1
# Safely stop all Ollama background processes.

Write-Host "🔴 Stopping Ollama server(s)..."

# Stop every running ollama.exe process silently
Get-Process -Name ollama -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        Write-Host "✅ Stopped process ID $($_.Id)"
    } catch {
        Write-Host "⚠️ Could not stop process ID $($_.Id): $($_.Exception.Message)"
    }
}

if (-not (Get-Process -Name ollama -ErrorAction SilentlyContinue)) {
    Write-Host "🟢 All Ollama processes are stopped."
} else {
    Write-Host "⚠️ Some Ollama processes might still be running. Check Task Manager."
}

Start-Sleep -Seconds 2
