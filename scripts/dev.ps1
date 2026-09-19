[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    throw "uv was not found. Install it from https://docs.astral.sh/uv/getting-started/installation/"
}
if (-not (Get-Command npm.cmd -ErrorAction SilentlyContinue)) {
    throw "npm was not found. Install Node.js 22.22 or newer."
}

uv sync --project ".\thirdparty\hermes-agent" --extra dev
if ($LASTEXITCODE -ne 0) { throw "Hermes Python dependency sync failed: $LASTEXITCODE" }
$hermesNodeModules = Join-Path $repoRoot "thirdparty\hermes-agent\node_modules"
if (-not (Test-Path -LiteralPath $hermesNodeModules)) {
    npm.cmd --prefix "thirdparty/hermes-agent" install
    if ($LASTEXITCODE -ne 0) { throw "Hermes Desktop dependency install failed: $LASTEXITCODE" }
} else {
    Write-Host "Using the existing Hermes Desktop node_modules installation."
}

$hermesRoot = Join-Path $repoRoot "thirdparty\hermes-agent"
$env:HERMES_DESKTOP_PYTHON = Join-Path $hermesRoot ".venv\Scripts\python.exe"
$env:HERMES_DESKTOP_HERMES_ROOT = $hermesRoot
$env:HERMES_DESKTOP_CDP_PORT = "off"
$env:PYTHONPATH = $hermesRoot
$env:API_SERVER_ENABLED = "true"
$env:API_SERVER_HOST = "127.0.0.1"
if (-not $env:API_SERVER_KEY) {
    $apiKeyBytes = New-Object byte[] 32
    $apiKeyGenerator = [Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $apiKeyGenerator.GetBytes($apiKeyBytes)
    } finally {
        $apiKeyGenerator.Dispose()
    }
    $env:API_SERVER_KEY = (($apiKeyBytes | ForEach-Object { $_.ToString("x2") }) -join "")
}

Write-Host "Starting Hermes Desktop with the Hermes-managed Video Knowledge Worker. Press Ctrl+C to stop." -ForegroundColor Cyan
npm.cmd run dev
if ($LASTEXITCODE -ne 0) { throw "Hermes Desktop exited unexpectedly: $LASTEXITCODE" }
