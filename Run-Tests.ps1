# EldenLOD Local Test Runner
# Comprehensive test runner for local development and CI/CD validation

param(
    [string]$TestLevel = "Full",  # Options: "Minimal", "Simple", "Full"
    [switch]$KeepFiles,
    [switch]$Verbose,
    [switch]$SkipExecution = $false,
    [string]$TestCase = "TestCaseMaliketh"
)

$ErrorActionPreference = "Stop"
$scriptsDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-TestHeader {
    param([string]$Message)
    Write-Host "`n=== $Message ===" -ForegroundColor Cyan
}

function Write-TestResult {
    param([string]$Message, [string]$Status)
    $color = switch ($Status) {
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
        default { "White" }
    }
    Write-Host "$Message" -ForegroundColor $color
}

Write-TestHeader "EldenLOD Local Test Runner"
Write-Host "Test Level: $TestLevel" -ForegroundColor Yellow
Write-Host "Test Case: $TestCase" -ForegroundColor Yellow
Write-Host "Skip Execution: $SkipExecution" -ForegroundColor Yellow

$allTestsPassed = $true
$testResults = @()

try {
    # Always run minimal test first
    Write-TestHeader "Running Minimal Test"
    try {
        $minimalScript = Join-Path $scriptsDir "tests\minimal-test.ps1"
        if (Test-Path $minimalScript) {
            $result = & $minimalScript 2>&1
            Write-Host $result
            Write-TestResult "✓ Minimal test passed" "SUCCESS"
            $testResults += @{ Name = "Minimal"; Status = "PASSED" }
        } else {
            Write-TestResult "✗ Minimal test script not found" "ERROR"
            $testResults += @{ Name = "Minimal"; Status = "FAILED" }
            $allTestsPassed = $false
        }
    }
    catch {
        Write-TestResult "✗ Minimal test failed: $($_.Exception.Message)" "ERROR"
        $testResults += @{ Name = "Minimal"; Status = "FAILED" }
        $allTestsPassed = $false
    }

    # Run comprehensive tests based on level
    if ($TestLevel -eq "Simple" -or $TestLevel -eq "Full") {
        Write-TestHeader "Running Simple Comprehensive Test"
        try {
            $simpleScript = Join-Path $scriptsDir "tests\Test-EldenLOD-Simple.ps1"
            if (Test-Path $simpleScript) {
                $params = @{
                    TestCaseName = $TestCase
                }
                if ($KeepFiles) { $params.KeepTempFiles = $true }
                if ($Verbose) { $params.Verbose = $true }
                if ($SkipExecution) { $params.SkipExecution = $true }
                
                & $simpleScript @params
                
                if ($LASTEXITCODE -eq 0) {
                    Write-TestResult "✓ Simple comprehensive test passed" "SUCCESS"
                    $testResults += @{ Name = "Simple"; Status = "PASSED" }
                } else {
                    Write-TestResult "✗ Simple comprehensive test failed (exit code: $LASTEXITCODE)" "ERROR"
                    $testResults += @{ Name = "Simple"; Status = "FAILED" }
                    $allTestsPassed = $false
                }
            } else {
                Write-TestResult "⚠ Simple test script not found, skipping" "WARNING"
                $testResults += @{ Name = "Simple"; Status = "SKIPPED" }
            }
        }
        catch {
            Write-TestResult "✗ Simple comprehensive test failed: $($_.Exception.Message)" "ERROR"
            $testResults += @{ Name = "Simple"; Status = "FAILED" }
            $allTestsPassed = $false
        }
    }

    if ($TestLevel -eq "Full") {
        Write-TestHeader "Running Full Comprehensive Test"
        try {
            $fullScript = Join-Path $scriptsDir "tests\Test-EldenLOD-Fixed.ps1"
            if (Test-Path $fullScript) {
                $params = @{
                    TestCaseName = $TestCase
                }
                if ($KeepFiles) { $params.KeepTempFiles = $true }
                if ($Verbose) { $params.Verbose = $true }
                
                & $fullScript @params
                
                if ($LASTEXITCODE -eq 0) {
                    Write-TestResult "✓ Full comprehensive test passed" "SUCCESS"
                    $testResults += @{ Name = "Full"; Status = "PASSED" }
                } else {
                    Write-TestResult "✗ Full comprehensive test failed (exit code: $LASTEXITCODE)" "ERROR"
                    $testResults += @{ Name = "Full"; Status = "FAILED" }
                    $allTestsPassed = $false
                }
            } else {
                Write-TestResult "⚠ Full test script not found, using alternative" "WARNING"
                
                # Try the robust version as fallback
                $robustScript = Join-Path $scriptsDir "tests\Test-EldenLOD-Robust.ps1"
                if (Test-Path $robustScript) {
                    $params = @{
                        TestCaseName = $TestCase
                    }
                    if ($KeepFiles) { $params.KeepTempFiles = $true }
                    if ($Verbose) { $params.Verbose = $true }
                    
                    & $robustScript @params
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-TestResult "✓ Robust comprehensive test passed" "SUCCESS"
                        $testResults += @{ Name = "Robust"; Status = "PASSED" }
                    } else {
                        Write-TestResult "✗ Robust comprehensive test failed" "ERROR"
                        $testResults += @{ Name = "Robust"; Status = "FAILED" }
                        $allTestsPassed = $false
                    }
                } else {
                    Write-TestResult "✗ No comprehensive test scripts found" "ERROR"
                    $testResults += @{ Name = "Full"; Status = "FAILED" }
                    $allTestsPassed = $false
                }
            }
        }
        catch {
            Write-TestResult "✗ Full comprehensive test failed: $($_.Exception.Message)" "ERROR"
            $testResults += @{ Name = "Full"; Status = "FAILED" }
            $allTestsPassed = $false
        }
    }

    # Validate script syntax
    Write-TestHeader "Validating Script Syntax"
    $scripts = @(
        "EldenLOD-Extract.ps1",
        "EldenLOD-Repack.ps1", 
        "EldenLOD.psm1",
        "Invoke-EldenLOD.ps1"
    )
    
    $syntaxErrors = 0
    foreach ($script in $scripts) {
        $scriptPath = Join-Path $scriptsDir $script
        if (Test-Path $scriptPath) {
            try {
                $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $scriptPath -Raw), [ref]$null)
                Write-TestResult "✓ $script syntax valid" "SUCCESS"
            } catch {
                Write-TestResult "✗ $script syntax error: $($_.Exception.Message)" "ERROR"
                $syntaxErrors++
            }
        } else {
            Write-TestResult "⚠ $script not found" "WARNING"
        }
    }
    
    if ($syntaxErrors -gt 0) {
        $allTestsPassed = $false
        $testResults += @{ Name = "Syntax"; Status = "FAILED" }
    } else {
        $testResults += @{ Name = "Syntax"; Status = "PASSED" }
    }

    # Generate final report
    Write-TestHeader "Test Results Summary"
    foreach ($result in $testResults) {
        $status = $result.Status
        $color = switch ($status) {
            "PASSED" { "Green" }
            "SKIPPED" { "Yellow" }
            "FAILED" { "Red" }
            default { "White" }
        }
        Write-Host "  $($result.Name): $status" -ForegroundColor $color
    }
    
    if ($allTestsPassed) {
        Write-TestHeader "ALL TESTS PASSED"
        Write-TestResult "The EldenLOD script is working correctly!" "SUCCESS"
        $exitCode = 0
    } else {
        Write-TestHeader "SOME TESTS FAILED"
        Write-TestResult "Check the test logs for details." "ERROR"
        $exitCode = 1
    }
}
catch {
    Write-TestHeader "TEST EXECUTION FAILED"
    Write-TestResult "Critical error: $($_.Exception.Message)" "ERROR"
    $exitCode = 1
}

# Show log locations
Write-Host "`nTest logs available at:" -ForegroundColor Blue
$logPaths = @(
    "$scriptsDir\tests\test-results.log",
    "$scriptsDir\tests\test-results-simple.log",
    "$scriptsDir\tests\test-results-final.log"
)

foreach ($logPath in $logPaths) {
    if (Test-Path $logPath) {
        Write-Host "  $logPath" -ForegroundColor Cyan
    }
}

Write-Host "`nUsage examples:" -ForegroundColor Blue
Write-Host "  .\Run-Tests.ps1                          # Run all tests" -ForegroundColor Gray
Write-Host "  .\Run-Tests.ps1 -TestLevel Minimal       # Run only minimal test" -ForegroundColor Gray
Write-Host "  .\Run-Tests.ps1 -TestLevel Simple        # Run minimal + simple tests" -ForegroundColor Gray
Write-Host "  .\Run-Tests.ps1 -SkipExecution -Verbose  # Dry-run with detailed output" -ForegroundColor Gray
Write-Host "  .\Run-Tests.ps1 -KeepFiles               # Keep test files for inspection" -ForegroundColor Gray

exit $exitCode
