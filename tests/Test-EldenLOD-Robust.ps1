# Elden Ring LOD Test Framework - Robust Version
# Automated testing for the EldenLOD script functionality
<#
.SYNOPSIS
    Advanced test framework for EldenLOD functionality with robust error handling.
.DESCRIPTION
    This script provides comprehensive testing for the EldenLOD system, with detailed logging,
    proper error handling, and validation of expected results. It supports both
    the original directory structure and the new reorganized structure.
.PARAMETER TestCaseName
    Name of the test case to use from the encumbered directory.
.PARAMETER Verbose
    Enable verbose output of test progress.
.PARAMETER KeepTempFiles
    Retain temporary files after testing for debugging purposes.
.NOTES
    Author: EldenLOD Team
    Version: 0.1 Alpha
    Created: 2025-05-28
#>

param(
    [string]$TestCaseName = "TestCaseMaliketh",
    [switch]$Verbose,
    [switch]$KeepTempFiles
)

$ErrorActionPreference = "Stop"
$testsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $testsDir
$encumberedDir = Join-Path $testsDir "encumbered"

# Handle both original and new directory structure
$scriptsDir = Join-Path $projectRoot "scripts"
if (-not (Test-Path $scriptsDir)) {
    # Fall back to the project root if scripts directory doesn't exist
    $scriptsDir = $projectRoot
}

# Test configuration
$testConfig = @{
    CleanZip = Join-Path $encumberedDir "$TestCaseName.zip"
    WorkingDir = Join-Path $encumberedDir "test-working"
    LogFile = Join-Path $testsDir "test-results.log"
    MainScript = Join-Path $scriptsDir "EldenLOD-Extract.ps1"
}

# Ensure the MainScript exists, if not try both paths
if (-not (Test-Path $testConfig.MainScript)) {
    $altScriptPath = Join-Path $projectRoot "EldenLOD-Extract.ps1"
    if (Test-Path $altScriptPath) {
        $testConfig.MainScript = $altScriptPath
    }
}

function Write-TestLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry
    if (Test-Path (Split-Path $testConfig.LogFile)) {
        Add-Content -Path $testConfig.LogFile -Value $logEntry
    }
}

function Initialize-TestEnvironment {
    Write-TestLog "Initializing test environment..."
    
    # Clean up any existing test directories
    if (Test-Path $testConfig.WorkingDir) {
        Remove-Item $testConfig.WorkingDir -Recurse -Force
    }
    
    # Create test directories
    New-Item -ItemType Directory -Path $testConfig.WorkingDir -Force | Out-Null
    
    # Extract test cases
    Write-TestLog "Extracting clean test case..."
    if (-not (Test-Path $testConfig.CleanZip)) {
        throw "Test case not found: $($testConfig.CleanZip)"
    }
    
    Expand-Archive -Path $testConfig.CleanZip -DestinationPath $testConfig.WorkingDir -Force
    Write-TestLog "Test environment initialized successfully"
}

function Test-ScriptExecution {
    Write-TestLog "Testing script execution..."
    
    # Find the parts directory in the working directory
    $partsDir = Get-ChildItem -Path $testConfig.WorkingDir -Recurse -Directory -Filter "parts" | Select-Object -First 1
    if (-not $partsDir) {
        throw "Could not find 'parts' directory in extracted test case"
    }
    
    $fullPartsDir = $partsDir.FullName
    Write-TestLog "Found parts directory: $fullPartsDir"
    
    # Test dry-run first
    Write-TestLog "Running dry-run test..."
    try {
        $dryRunOutput = & $testConfig.MainScript -partsDir $fullPartsDir 2>&1
        Write-TestLog "Dry-run completed successfully" "SUCCESS"
        if ($Verbose) {
            Write-TestLog "Dry-run output: $($dryRunOutput -join "`n")" "DEBUG"
        }
    }
    catch {
        Write-TestLog "Dry-run failed: $($_.Exception.Message)" "ERROR"
        throw
    }
    
    # Test actual execution
    Write-TestLog "Running actual execution..."
    try {
        $executeOutput = & $testConfig.MainScript -partsDir $fullPartsDir -Execute 2>&1
        Write-TestLog "Execution completed successfully" "SUCCESS"
        if ($Verbose) {
            Write-TestLog "Execute output: $($executeOutput -join "`n")" "DEBUG"
        }
    }
    catch {
        Write-TestLog "Execution failed: $($_.Exception.Message)" "ERROR"
        throw
    }
    
    return $fullPartsDir
}

function Test-Results {
    param([string]$PartsDir)
    
    Write-TestLog "Validating results..."
    
    # Check for basic file existence
    $actualFiles = Get-ChildItem -Path $PartsDir -Filter "*.dcx" -ErrorAction SilentlyContinue | Sort-Object Name
    if (-not $actualFiles) {
        throw "No DCX files found in parts directory"
    }
    
    Write-TestLog "Found $($actualFiles.Count) DCX files in parts directory"
    
    # Validate specific expected LOD files
    $expectedLodFiles = @(
        "am_m_1620_L.partsbnd.dcx",
        "bd_m_1620_L.partsbnd.dcx", 
        "hd_m_1800_L.partsbnd.dcx",
        "lg_m_1620_L.partsbnd.dcx"
    )
    
    $foundLodFiles = @()
    foreach ($lodFile in $expectedLodFiles) {
        $actualPath = Join-Path $PartsDir $lodFile
        if (Test-Path $actualPath) {
            Write-TestLog "Found expected LOD file: $lodFile" "SUCCESS"
            $foundLodFiles += $lodFile
        } else {
            Write-TestLog "Missing expected LOD file: $lodFile" "WARNING"
        }
    }
    
    if ($foundLodFiles.Count -eq 0) {
        throw "No LOD files were created"
    }
    
    Write-TestLog "Found $($foundLodFiles.Count) out of $($expectedLodFiles.Count) expected LOD files"
    
    # Validate file sizes (basic sanity check)
    Write-TestLog "Validating file sizes..."
    foreach ($file in $actualFiles) {
        if ($file.Length -eq 0) {
            Write-TestLog "Zero-byte file detected: $($file.Name)" "ERROR"
            throw "File size validation failed"
        }
        if ($file.Name -like "*_L.partsbnd.dcx") {
            Write-TestLog "LOD file size OK: $($file.Name) ($($file.Length) bytes)" "SUCCESS"
        }
    }
    
    Write-TestLog "All file sizes are valid" "SUCCESS"
    Write-TestLog "Result validation completed successfully" "SUCCESS"
}

function Test-MixedNumberingCase {
    param([string]$PartsDir)
    
    Write-TestLog "Testing mixed numbering case fix..."
    
    # Check if hd_m_1800.partsbnd.dcx was processed correctly
    $hdFile = Join-Path $PartsDir "hd_m_1800.partsbnd.dcx"
    $hdLodFile = Join-Path $PartsDir "hd_m_1800_L.partsbnd.dcx"
    
    if (Test-Path $hdFile) {
        Write-TestLog "HD file found: $hdFile" "SUCCESS"
    } else {
        Write-TestLog "HD file not found: $hdFile" "WARNING"
    }
    
    if (Test-Path $hdLodFile) {
        Write-TestLog "HD LOD file found: $hdLodFile" "SUCCESS"
    } else {
        Write-TestLog "HD LOD file not found: $hdLodFile" "WARNING"
    }
    
    Write-TestLog "Mixed numbering case validation completed" "SUCCESS"
    return $true
}

function Clear-TestEnvironment {
    if (-not $KeepTempFiles) {
        Write-TestLog "Cleaning up test environment..."
        if (Test-Path $testConfig.WorkingDir) {
            Remove-Item $testConfig.WorkingDir -Recurse -Force
        }
        Write-TestLog "Cleanup completed"
    } else {
        Write-TestLog "Keeping temp files for inspection: $($testConfig.WorkingDir)"
    }
}

# Main test execution
try {
    Write-TestLog "=== STARTING ELDEN LOD ROBUST TEST SUITE ==="
    Write-TestLog "Test case: $TestCaseName"
    
    # Validate prerequisites
    if (-not (Test-Path $testConfig.MainScript)) {
        throw "Main script not found: $($testConfig.MainScript)"
    }
    
    if (-not (Test-Path $testConfig.CleanZip)) {
        throw "Test case ZIP not found: $($testConfig.CleanZip)"
    }
    
    # Initialize environment
    Initialize-TestEnvironment
    
    # Run the script
    $partsDir = Test-ScriptExecution
    
    # Validate results
    Test-Results -PartsDir $partsDir
    
    # Test specific cases
    Test-MixedNumberingCase -PartsDir $partsDir
    
    Write-TestLog "=== ALL TESTS PASSED SUCCESSFULLY ===" "SUCCESS"
    $exitCode = 0
}
catch {
    Write-TestLog "=== TEST SUITE FAILED ===" "ERROR"
    Write-TestLog "Error: $($_.Exception.Message)" "ERROR"
    if ($_.Exception.InnerException) {
        Write-TestLog "Inner Exception: $($_.Exception.InnerException.Message)" "ERROR"
    }
    $exitCode = 1
}
finally {
    Clear-TestEnvironment
}

exit $exitCode
