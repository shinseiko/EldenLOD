# Elden Ring LOD Test Framework - Simple Working Version
# Basic automated testing for the EldenLOD script functionality

param(
    [string]$TestCaseName = "TestCaseMaliketh",
    [switch]$Verbose,
    [switch]$KeepTempFiles,
    [switch]$SkipExecution = $false
)

$ErrorActionPreference = "Stop"
$testsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptsDir = Split-Path -Parent $testsDir
$encumberedDir = Join-Path $testsDir "encumbered"

# Test configuration
$testConfig = @{
    CleanZip = Join-Path $encumberedDir "$TestCaseName.zip"
    WorkingDir = Join-Path $encumberedDir "test-working-simple"
    LogFile = Join-Path $testsDir "test-results-simple.log"
    MainScript = Join-Path $scriptsDir "EldenLOD-Extract.ps1"
}

function Write-TestLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry
    
    try {
        $logDir = Split-Path $testConfig.LogFile
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        Add-Content -Path $testConfig.LogFile -Value $logEntry -ErrorAction SilentlyContinue
    }
    catch {
        # Continue if logging fails
    }
}

function Test-Prerequisites {
    Write-TestLog "Checking prerequisites..."
    
    if (-not (Test-Path $testConfig.MainScript)) {
        throw "Main script not found: $($testConfig.MainScript)"
    }
    Write-TestLog "Main script found"
    
    if (-not (Test-Path $testConfig.CleanZip)) {
        throw "Test case ZIP not found: $($testConfig.CleanZip)"
    }
    Write-TestLog "Test case ZIP found"
    
    Write-TestLog "Prerequisites check completed"
}

function Initialize-TestEnvironment {
    Write-TestLog "Initializing test environment..."
    
    # Clean up existing directory
    if (Test-Path $testConfig.WorkingDir) {
        try {
            Remove-Item $testConfig.WorkingDir -Recurse -Force
        }
        catch {
            Write-TestLog "Could not clean up existing directory, continuing..." "WARNING"
        }
    }
    
    # Create test directory
    New-Item -ItemType Directory -Path $testConfig.WorkingDir -Force | Out-Null
    Write-TestLog "Created working directory"
    
    # Extract test case
    Write-TestLog "Extracting clean test case..."
    Expand-Archive -Path $testConfig.CleanZip -DestinationPath $testConfig.WorkingDir -Force
    Write-TestLog "Test case extracted successfully"
    
    Write-TestLog "Test environment initialized"
}

function Test-DryRun {
    param([string]$PartsDir)
    
    Write-TestLog "=== TESTING DRY-RUN MODE ==="
    
    try {
        $result = & $testConfig.MainScript -partsDir $PartsDir 2>&1
        Write-TestLog "Dry-run completed successfully" "SUCCESS"
        
        $outputText = $result -join "`n"
        if ($outputText -match "DRY-RUN MODE") {
            Write-TestLog "Dry-run mode confirmed in output" "SUCCESS"
        }
        
        if ($outputText -match "Processing:.*\.partsbnd\.dcx") {
            Write-TestLog "File processing detected in dry-run" "SUCCESS"
        }
        
        if ($Verbose) {
            Write-TestLog "Dry-run output sample:"
            $result | Select-Object -First 5 | ForEach-Object { Write-TestLog "  $_" }
        }
        
        return $true
    }
    catch {
        Write-TestLog "Dry-run failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Test-Execution {
    param([string]$PartsDir)
    
    if ($SkipExecution) {
        Write-TestLog "=== SKIPPING EXECUTION TEST ==="
        return $true
    }
    
    Write-TestLog "=== TESTING ACTUAL EXECUTION ==="
    
    try {
        $result = & $testConfig.MainScript -partsDir $PartsDir -Execute 2>&1
        Write-TestLog "Execution completed successfully" "SUCCESS"
        
        $outputText = $result -join "`n"
        if ($outputText -match "Processing complete") {
            Write-TestLog "Processing completion confirmed" "SUCCESS"
        }
        
        if ($outputText -match "Container/Content mismatch.*Renumbering") {
            Write-TestLog "DDS renumbering functionality confirmed" "SUCCESS"
        }
        
        if ($Verbose) {
            Write-TestLog "Execution output sample:"
            $result | Where-Object { $_ -match "(Processing:|Container/Content)" } | Select-Object -First 5 | ForEach-Object { Write-TestLog "  $_" }
        }
        
        return $true
    }
    catch {
        Write-TestLog "Execution failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Test-Results {
    param([string]$PartsDir)
    
    Write-TestLog "=== VALIDATING RESULTS ==="
    
    try {
        $actualFiles = @()
        if (Test-Path $PartsDir) {
            $actualFiles = Get-ChildItem -Path $PartsDir -Filter "*.dcx" -ErrorAction SilentlyContinue
        }
        
        if ($SkipExecution) {
            Write-TestLog "Skipping file validation (execution was skipped)" "INFO"
            return $true
        }
        
        if (-not $actualFiles -or $actualFiles.Count -eq 0) {
            throw "No DCX files found in parts directory"
        }
        
        Write-TestLog "Found $($actualFiles.Count) DCX files"
        
        # Check for expected LOD files
        $expectedLodFiles = @(
            "am_m_1620_L.partsbnd.dcx",
            "bd_m_1620_L.partsbnd.dcx", 
            "hd_m_1800_L.partsbnd.dcx",
            "lg_m_1620_L.partsbnd.dcx"
        )
        
        $foundCount = 0
        foreach ($lodFile in $expectedLodFiles) {
            $actualPath = Join-Path $PartsDir $lodFile
            if (Test-Path $actualPath) {
                $foundCount++
                $fileInfo = Get-Item $actualPath
                Write-TestLog "Found LOD file: $lodFile ($($fileInfo.Length) bytes)" "SUCCESS"
            }
        }
        
        if ($foundCount -eq 0) {
            throw "No expected LOD files were found"
        }
        
        Write-TestLog "Found $foundCount of $($expectedLodFiles.Count) expected LOD files" "SUCCESS"
        
        # Check file sizes
        $zeroByteFiles = $actualFiles | Where-Object { $_.Length -eq 0 }
        if ($zeroByteFiles) {
            throw "Zero-byte files detected: $($zeroByteFiles.Name -join ', ')"
        }
        
        Write-TestLog "All files have valid sizes" "SUCCESS"
        Write-TestLog "Result validation completed" "SUCCESS"
        return $true
    }
    catch {
        Write-TestLog "Result validation failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Write-TestReport {
    param(
        [bool]$DryRunSuccess,
        [bool]$ExecutionSuccess, 
        [bool]$ValidationSuccess
    )
    
    Write-TestLog "=== TEST REPORT ==="
    
    $overallSuccess = $DryRunSuccess -and $ExecutionSuccess -and $ValidationSuccess
    
    Write-TestLog "Test Case: $TestCaseName"
    Write-TestLog "Dry-Run: $(if ($DryRunSuccess) { 'PASSED' } else { 'FAILED' })"
    Write-TestLog "Execution: $(if ($SkipExecution) { 'SKIPPED' } elseif ($ExecutionSuccess) { 'PASSED' } else { 'FAILED' })"
    Write-TestLog "Validation: $(if ($ValidationSuccess) { 'PASSED' } else { 'FAILED' })"
    Write-TestLog "Overall: $(if ($overallSuccess) { 'SUCCESS' } else { 'FAILED' })"
}

function Clear-TestEnvironment {
    if (-not $KeepTempFiles) {
        Write-TestLog "Cleaning up test environment..."
        try {
            if (Test-Path $testConfig.WorkingDir) {
                Remove-Item $testConfig.WorkingDir -Recurse -Force
            }
            Write-TestLog "Cleanup completed"
        }
        catch {
            Write-TestLog "Cleanup failed, files may remain" "WARNING"
        }
    } else {
        Write-TestLog "Keeping temp files: $($testConfig.WorkingDir)"
    }
}

# Main execution
$dryRunSuccess = $false
$executionSuccess = $false
$validationSuccess = $false

try {
    Write-TestLog "=== STARTING ELDEN LOD SIMPLE TEST SUITE ==="
    Write-TestLog "Test case: $TestCaseName"
    Write-TestLog "Skip execution: $SkipExecution"
    
    # Run tests
    Test-Prerequisites
    Initialize-TestEnvironment
    
    # Find parts directory
    $partsItem = Get-ChildItem -Path $testConfig.WorkingDir -Recurse -Directory -Filter "parts" | Select-Object -First 1
    if (-not $partsItem) {
        throw "Could not find 'parts' directory in test case"
    }
    $partsDir = $partsItem.FullName
    Write-TestLog "Found parts directory: $partsDir"
    
    # Execute tests
    $dryRunSuccess = Test-DryRun -PartsDir $partsDir
    $executionSuccess = Test-Execution -PartsDir $partsDir
    $validationSuccess = Test-Results -PartsDir $partsDir
    
    # Generate report
    Write-TestReport -DryRunSuccess $dryRunSuccess -ExecutionSuccess $executionSuccess -ValidationSuccess $validationSuccess
    
    if ($dryRunSuccess -and $executionSuccess -and $validationSuccess) {
        Write-TestLog "=== ALL TESTS PASSED ===" "SUCCESS"
        $exitCode = 0
    } else {
        Write-TestLog "=== SOME TESTS FAILED ===" "ERROR"
        $exitCode = 1
    }
}
catch {
    Write-TestLog "=== CRITICAL ERROR ===" "ERROR"
    Write-TestLog "Error: $($_.Exception.Message)" "ERROR"
    Write-TestReport -DryRunSuccess $dryRunSuccess -ExecutionSuccess $executionSuccess -ValidationSuccess $validationSuccess
    $exitCode = 1
}
finally {
    Clear-TestEnvironment
}

exit $exitCode
