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

$parseErrors = @()
foreach ($script in @("scripts/build-rc.ps1", "scripts/verify-rc.ps1", "thirdparty/hermes-agent/scripts/install.ps1")) {
    $tokens = $null
    $errors = $null
    [Management.Automation.Language.Parser]::ParseFile(
        (Resolve-Path -LiteralPath $script),
        [ref]$tokens,
        [ref]$errors
    ) | Out-Null
    $parseErrors += @($errors)
}
if ($parseErrors) {
    throw "PowerShell release scripts contain parser errors: $($parseErrors -join '; ')"
}

uv run --project thirdparty/hermes-agent --extra dev ruff check --isolated --line-length 100 --select E,F,I,UP,B,ASYNC thirdparty/hermes-agent/plugins/video_knowledge/backend thirdparty/hermes-agent/tests/video_knowledge thirdparty/hermes-agent/plugins/video_knowledge/dashboard/plugin_api.py thirdparty/hermes-agent/plugins/video_knowledge/gateway_delivery.py thirdparty/hermes-agent/plugins/video_knowledge/messaging_tools.py thirdparty/hermes-agent/tests/gateway/test_feishu_notification_idempotency.py
Assert-LastExitCode "ruff check"
uv run --project thirdparty/hermes-agent --extra dev ruff format --check thirdparty/hermes-agent/plugins/video_knowledge/backend thirdparty/hermes-agent/tests/video_knowledge thirdparty/hermes-agent/plugins/video_knowledge/dashboard/plugin_api.py thirdparty/hermes-agent/plugins/video_knowledge/gateway_delivery.py thirdparty/hermes-agent/plugins/video_knowledge/messaging_tools.py thirdparty/hermes-agent/tests/gateway/test_feishu_notification_idempotency.py
Assert-LastExitCode "ruff format"
uv run --project thirdparty/hermes-agent --extra dev pytest thirdparty/hermes-agent/tests/video_knowledge
Assert-LastExitCode "Video Knowledge pytest"
uv run --project thirdparty/hermes-agent --extra dev pytest thirdparty/hermes-agent/tests/gateway/test_api_server.py thirdparty/hermes-agent/tests/gateway/test_api_server_multiplex_secret_scope.py thirdparty/hermes-agent/tests/gateway/test_feishu_notification_idempotency.py
Assert-LastExitCode "Hermes Gateway pytest"
uv run --project thirdparty/hermes-agent --extra dev pytest thirdparty/hermes-agent/tests/test_install_ps1_ascii_only.py
Assert-LastExitCode "Windows installer source tests"
npm.cmd --prefix thirdparty/hermes-agent/apps/desktop run typecheck
Assert-LastExitCode "Hermes Desktop typecheck"
npm.cmd --prefix thirdparty/hermes-agent/apps/desktop exec -- eslint thirdparty/hermes-agent/apps/desktop/src/plugins/video-knowledge
Assert-LastExitCode "Video Knowledge plugin lint"
Push-Location -LiteralPath "thirdparty/hermes-agent/apps/desktop"
try {
    npm.cmd exec -- vitest run src/plugins/video-knowledge/api.test.ts electron/bootstrap-runner.test.ts scripts/write-build-stamp.test.mjs
    Assert-LastExitCode "Video Knowledge and RC bootstrap tests"
} finally {
    Pop-Location
}

Write-Host "All Video Knowledge Collector checks passed." -ForegroundColor Green
