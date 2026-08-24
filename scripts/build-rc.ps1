[CmdletBinding()]
param(
    [ValidateSet("nsis", "msi", "all")]
    [string]$Target = "nsis",
    [string]$ArtifactsDirectory = "",
    [ValidatePattern('^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$')]
    [string]$BootstrapRepository = "yknife/hermes-agent",
    [switch]$SkipChecks,
    [switch]$AllowDirty
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$hermesRoot = Join-Path $repoRoot "thirdparty\hermes-agent"
$desktopRoot = Join-Path $hermesRoot "apps\desktop"
$releaseRoot = Join-Path $desktopRoot "release"

if (-not $ArtifactsDirectory) {
    $ArtifactsDirectory = Join-Path $repoRoot "artifacts\windows-rc"
}
$artifactRoot = [IO.Path]::GetFullPath($ArtifactsDirectory)

function Assert-LastExitCode([string]$CommandName) {
    if ($LASTEXITCODE -ne 0) {
        throw "$CommandName failed with exit code $LASTEXITCODE"
    }
}

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw "Windows RC packages must be built on Windows."
}
if (-not (Test-Path -LiteralPath (Join-Path $hermesRoot ".git"))) {
    throw "Hermes submodule is not initialized. Run: git submodule update --init --recursive"
}

$dirty = git -C $hermesRoot status --porcelain --untracked-files=no
Assert-LastExitCode "git status"
if ($dirty -and -not $AllowDirty) {
    throw "Hermes has tracked changes. Commit them before producing an RC, or pass -AllowDirty for a non-release build."
}

$hermesCommit = (git -C $hermesRoot rev-parse HEAD).Trim()
Assert-LastExitCode "git rev-parse HEAD"
$hermesBranch = (git -C $hermesRoot branch --show-current).Trim()
Assert-LastExitCode "git branch --show-current"
if (-not $hermesBranch) {
    $hermesBranch = "vkc-integration"
}

if (-not $SkipChecks) {
    & (Join-Path $PSScriptRoot "check.ps1")
}

$previousCommit = $env:HERMES_DESKTOP_BOOTSTRAP_COMMIT
$previousBranch = $env:HERMES_DESKTOP_BOOTSTRAP_BRANCH
$previousRepository = $env:HERMES_DESKTOP_BOOTSTRAP_REPOSITORY
$previousSigning = $env:CSC_IDENTITY_AUTO_DISCOVERY
try {
    $env:HERMES_DESKTOP_BOOTSTRAP_COMMIT = $hermesCommit
    $env:HERMES_DESKTOP_BOOTSTRAP_BRANCH = $hermesBranch
    $env:HERMES_DESKTOP_BOOTSTRAP_REPOSITORY = $BootstrapRepository
    $env:CSC_IDENTITY_AUTO_DISCOVERY = "false"

    Push-Location -LiteralPath $desktopRoot
    try {
        $scriptName = if ($Target -eq "all") { "dist:win" } else { "dist:win:$Target" }
        npm.cmd run $scriptName
        Assert-LastExitCode "npm run $scriptName"
    } finally {
        Pop-Location
    }
} finally {
    $env:HERMES_DESKTOP_BOOTSTRAP_COMMIT = $previousCommit
    $env:HERMES_DESKTOP_BOOTSTRAP_BRANCH = $previousBranch
    $env:HERMES_DESKTOP_BOOTSTRAP_REPOSITORY = $previousRepository
    $env:CSC_IDENTITY_AUTO_DISCOVERY = $previousSigning
}

$package = Get-Content -LiteralPath (Join-Path $desktopRoot "package.json") -Raw | ConvertFrom-Json
$extensions = if ($Target -eq "nsis") { @(".exe") } elseif ($Target -eq "msi") { @(".msi") } else { @(".exe", ".msi") }
$artifacts = @(
    Get-ChildItem -LiteralPath $releaseRoot -File |
        Where-Object { $_.Name -like "Hermes-$($package.version)-win-*" -and $extensions -contains $_.Extension.ToLowerInvariant() } |
        Sort-Object Name
)
if (-not $artifacts) {
    throw "No Windows installer artifacts were produced under $releaseRoot"
}

$unpackedRoot = Join-Path $releaseRoot "win-unpacked"
$installStampPath = Join-Path $unpackedRoot "resources\install-stamp.json"
$asarPath = Join-Path $unpackedRoot "resources\app.asar"
if (-not (Test-Path -LiteralPath $installStampPath) -or -not (Test-Path -LiteralPath $asarPath)) {
    throw "Packaged runtime is incomplete: expected app.asar and install-stamp.json in win-unpacked/resources."
}
$installStamp = Get-Content -LiteralPath $installStampPath -Raw | ConvertFrom-Json
if ($installStamp.commit -ne $hermesCommit -or $installStamp.repository -ne $BootstrapRepository) {
    throw "Install stamp does not point to the requested Hermes fork commit."
}

New-Item -ItemType Directory -Path $artifactRoot -Force | Out-Null
$records = foreach ($artifact in $artifacts) {
    $destination = Join-Path $artifactRoot $artifact.Name
    Copy-Item -LiteralPath $artifact.FullName -Destination $destination -Force
    $copied = Get-Item -LiteralPath $destination
    [ordered]@{
        name = $copied.Name
        bytes = $copied.Length
        sha256 = (Get-FileHash -LiteralPath $copied.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}
Copy-Item -LiteralPath $installStampPath -Destination (Join-Path $artifactRoot "install-stamp.json") -Force

$outerCommit = (git -C $repoRoot rev-parse HEAD).Trim()
Assert-LastExitCode "outer git rev-parse HEAD"
$manifest = [ordered]@{
    schema_version = 1
    product = "Hermes with Video Knowledge Collector"
    version = $package.version
    built_at = [DateTime]::UtcNow.ToString("o")
    target = $Target
    source = [ordered]@{
        workspace_commit = $outerCommit
        hermes_repository = $BootstrapRepository
        hermes_branch = $hermesBranch
        hermes_commit = $hermesCommit
    }
    data_root = "%LOCALAPPDATA%\hermes"
    uninstall_default = "preserve-user-data"
    artifacts = @($records)
}
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $artifactRoot "release-manifest.json") -Encoding utf8

& (Join-Path $PSScriptRoot "verify-rc.ps1") -ArtifactsDirectory $artifactRoot -UnpackedDirectory $unpackedRoot
Write-Host "Windows RC artifacts are ready at $artifactRoot" -ForegroundColor Green
