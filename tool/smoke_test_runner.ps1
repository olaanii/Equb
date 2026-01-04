param(
    [switch]$SkipClean,
    [switch]$SkipAnalyze,
    [switch]$SkipUnit,
    [switch]$SkipTargeted
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot

function Invoke-Step {
    param(
        [string]$Name,
        [scriptblock]$Action
    )

    Write-Host "==> $Name" -ForegroundColor Cyan
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        & $Action
        $stopwatch.Stop()
        Write-Host "<== $Name completed in $($stopwatch.Elapsed.ToString('mm\:ss\.fff'))" -ForegroundColor Green
    } catch {
        $stopwatch.Stop()
        Write-Host "<== $Name failed after $($stopwatch.Elapsed.ToString('mm\:ss\.fff'))" -ForegroundColor Red
        throw
    }
}

try {
    if (-not $SkipClean) {
        Invoke-Step 'flutter clean' { flutter clean }
    }

    Invoke-Step 'flutter pub get' { flutter pub get }

    if (-not $SkipAnalyze) {
        Invoke-Step 'flutter analyze' { flutter analyze }
    }

    if (-not $SkipUnit) {
        Invoke-Step 'flutter test (full suite)' { flutter test }
    }

    if (-not $SkipTargeted) {
        $targeted = @(
            'test/ui/wallet_screen_test.dart',
            'test/ui/tx_history_screen_test.dart',
            'test/ui/group_detail_gateway_test.dart',
            'test/services/bank_settlement_worker_test.dart',
            'test/services/reminder_scheduler_service_test.dart',
            'test/services/analytics_persistence_test.dart',
            'test/providers/wallet_cohort_summary_test.dart'
        )
        Invoke-Step 'flutter test (targeted suites)' {
            flutter test @targeted
        }
    }

    Write-Host 'Smoke test run complete ✅' -ForegroundColor Green
} finally {
    Pop-Location
}
