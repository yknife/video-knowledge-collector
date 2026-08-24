[CmdletBinding()]
param([string]$BaseUrl = "http://127.0.0.1:8000")

$ErrorActionPreference = "Stop"
$response = Invoke-RestMethod -Uri "$BaseUrl/api/v1/system/health" -Headers @{ "X-Request-ID" = "req_smoke_test" }
if ($response.status -ne "ok" -or $response.components.database.status -ne "ok") {
    throw "健康检查未通过：$($response | ConvertTo-Json -Depth 5)"
}
$response | ConvertTo-Json -Depth 5

