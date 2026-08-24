[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

function Assert-LastExitCode([string]$CommandName) {
    if ($LASTEXITCODE -ne 0) {
        throw "$CommandName failed with exit code $LASTEXITCODE"
    }
}

uv run --project thirdparty/hermes-agent --extra dev ruff check --isolated --line-length 100 --select E,F,I,UP,B,ASYNC thirdparty/hermes-agent/plugins/video_knowledge/backend thirdparty/hermes-agent/tests/video_knowledge thirdparty/hermes-agent/plugins/video_knowledge/dashboard/plugin_api.py
Assert-LastExitCode "ruff check"
uv run --project thirdparty/hermes-agent --extra dev ruff format --check thirdparty/hermes-agent/plugins/video_knowledge/backend thirdparty/hermes-agent/tests/video_knowledge thirdparty/hermes-agent/plugins/video_knowledge/dashboard/plugin_api.py
Assert-LastExitCode "ruff format"
uv run --project thirdparty/hermes-agent --extra dev pytest thirdparty/hermes-agent/tests/video_knowledge
Assert-LastExitCode "Video Knowledge pytest"
uv run --project thirdparty/hermes-agent --extra dev pytest thirdparty/hermes-agent/tests/gateway/test_api_server.py thirdparty/hermes-agent/tests/gateway/test_api_server_multiplex_secret_scope.py
Assert-LastExitCode "Hermes Gateway pytest"
npm.cmd --prefix thirdparty/hermes-agent/apps/desktop run typecheck
Assert-LastExitCode "Hermes Desktop typecheck"
npm.cmd --prefix thirdparty/hermes-agent/apps/desktop exec -- eslint thirdparty/hermes-agent/apps/desktop/src/plugins/video-knowledge
Assert-LastExitCode "Video Knowledge plugin lint"
Push-Location -LiteralPath "thirdparty/hermes-agent/apps/desktop"
try {
    npm.cmd exec -- vitest run src/plugins/video-knowledge/api.test.ts
    Assert-LastExitCode "Video Knowledge plugin tests"
} finally {
    Pop-Location
}

Write-Host "All Sprint 6 checks passed." -ForegroundColor Green
