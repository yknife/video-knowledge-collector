[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ArtifactsDirectory,
    [string]$UnpackedDirectory = ""
)

$ErrorActionPreference = "Stop"
$artifactRoot = [IO.Path]::GetFullPath($ArtifactsDirectory)
$manifestPath = Join-Path $artifactRoot "release-manifest.json"
$stampPath = Join-Path $artifactRoot "install-stamp.json"

if (-not (Test-Path -LiteralPath $manifestPath) -or -not (Test-Path -LiteralPath $stampPath)) {
    throw "RC manifest or install stamp is missing from $artifactRoot"
}
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$stamp = Get-Content -LiteralPath $stampPath -Raw | ConvertFrom-Json

if ($manifest.schema_version -ne 1 -or -not $manifest.artifacts) {
    throw "RC manifest is invalid or contains no installer artifacts."
}
if ($stamp.schemaVersion -lt 2 -or $stamp.repository -ne $manifest.source.hermes_repository) {
    throw "Install stamp repository metadata is missing or inconsistent."
}
if ($stamp.commit -ne $manifest.source.hermes_commit) {
    throw "Install stamp commit does not match the release manifest."
}

foreach ($record in $manifest.artifacts) {
    $path = Join-Path $artifactRoot $record.name
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing installer artifact: $($record.name)"
    }
    $file = Get-Item -LiteralPath $path
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($file.Length -ne $record.bytes -or $hash -ne $record.sha256) {
        throw "Artifact integrity check failed: $($record.name)"
    }
}

if ($UnpackedDirectory) {
    $unpacked = [IO.Path]::GetFullPath($UnpackedDirectory)
    foreach ($relative in @("Hermes.exe", "resources\app.asar", "resources\install-stamp.json")) {
        if (-not (Test-Path -LiteralPath (Join-Path $unpacked $relative))) {
            throw "Unpacked RC is missing $relative"
        }
    }
}

Write-Host "RC verification passed for $($manifest.artifacts.Count) artifact(s)." -ForegroundColor Green
