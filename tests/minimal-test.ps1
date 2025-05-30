# Minimal test to verify the EldenLOD script works
param(
    [switch]$Execute
)

Write-Host "=== Minimal EldenLOD Test ===" -ForegroundColor Cyan

# Set up paths correctly
$testsDir = $PSScriptRoot  # This gives us the tests directory directly
$mainDir = Split-Path -Parent $testsDir  # This gives us the main EldenLOD directory
$mainScript = Join-Path $mainDir "EldenLOD-Extract.ps1"
$encumberedDir = Join-Path $testsDir "encumbered"
$cleanDataDir = Join-Path $encumberedDir "TestCaseMaliketh-Clean\TestCaseMaliketh\parts"

Write-Host "Tests directory: $testsDir"
Write-Host "Main directory: $mainDir" 
Write-Host "Main script: $mainScript"
Write-Host "Test data: $cleanDataDir"

# Verify paths exist
if (-not (Test-Path $mainScript)) {
    Write-Error "Main script not found: $mainScript"
    exit 1
}

if (-not (Test-Path $cleanDataDir)) {
    Write-Error "Test data not found: $cleanDataDir"
    exit 1
}

Write-Host "All paths verified!" -ForegroundColor Green

# Run the test
try {
    if ($Execute) {
        Write-Host "Running EldenLOD script with -Execute..." -ForegroundColor Yellow
        & $mainScript -partsDir $cleanDataDir -Execute
    } else {
        Write-Host "Running EldenLOD script in dry-run mode..." -ForegroundColor Yellow
        & $mainScript -partsDir $cleanDataDir
    }
    
    Write-Host "=== TEST COMPLETED SUCCESSFULLY ===" -ForegroundColor Green
} catch {
    Write-Host "=== TEST FAILED ===" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}