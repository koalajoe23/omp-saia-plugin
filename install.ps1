# pi SAIA Plugin Installer for Windows PowerShell

if (-not (Test-Path env:SAIA_API_KEY)) {
    Write-Error "SAIA_API_KEY environment variable not set"
    Write-Host "Get your key from https://chat-ai.academiccloud.de/ then run:"
    Write-Host "  [Environment]::SetEnvironmentVariable('SAIA_API_KEY', 'your_key_here', 'User')"
    exit 1
}

# PI config directory
$piConfigDir = Join-Path $HOME ".config\pi"
$pluginDir = Join-Path $piConfigDir "plugins\saia"

# Create directories
if (-not (Test-Path $pluginDir)) {
    New-Item -ItemType Directory -Path $pluginDir -Force | Out-Null
}

# Copy plugin files
Copy-Item -Path "src\*" -Destination $pluginDir -Recurse -Force

# Make shell scripts executable (Unix-like systems via WSL)
Get-ChildItem -Path "$pluginDir\*.sh" | ForEach-Object {
    try {
        # This works in WSL/bash environments
        Invoke-Expression "chmod +x '$($_.FullName)'"
    } catch {
        # Ignore on native Windows
    }
}

# Create pi.json if it doesn't exist
$piConfig = Join-Path $piConfigDir "pi.json"
if (-not (Test-Path $piConfig)) {
    @{
        `$schema = "https://pi.code/config.json"
        plugin = @("saia")
    } | ConvertTo-Json | Out-File -FilePath $piConfig -Encoding UTF8
    Write-Host "✓ Created $piConfig with plugin registration"
} else {
    Write-Host "⚠ Config exists at $piConfig"
    Write-Host "  Add plugin registration if not already present:"
    Write-Host '  "plugin": ["saia"]'
}

Write-Host "`n✓ Plugin installed to $pluginDir"
Write-Host "  pi will automatically load SAIA models on startup"
Write-Host "`nTo test: run pi and use /model saia/<model-name>"
Write-Host "Example: /model saia/glm-4.7"
