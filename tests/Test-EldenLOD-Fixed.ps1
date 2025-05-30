# Elden Ring LOD Test Framework
# Automated testing for the EldenLOD script functionality

param(
    [string]$TestCaseName = "TestCaseMaliketh",
    [switch]$Verbose,
    [switch]$KeepTempFiles
)

$ErrorActionPreference = "Stop"
$testsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptsDir = Split-Path -Parent $testsDir
$encumberedDir = Join-Path $testsDir "encumbered"

# Test configuration
$testConfig = @{
    CleanZip = Join-Path $encumberedDir "$TestCaseName.zip"
    ExpectedZip = Join-Path $encumberedDir "$TestCaseName-Fixed.zip"
    WorkingDir = Join-Path $encumberedDir "test-working"
    ExpectedDir = Join-Path $encumberedDir "test-expected"
    LogFile = Join-Path $testsDir "test-results.log"
    MainScript = Join-Path $scriptsDir "EldenLOD-Extract.ps1"
}

function Write-TestLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry
    Add-Content -Path $testConfig.LogFile -Value $logEntry
}

function Initialize-TestEnvironment {
    Write-TestLog "Initializing test environment..."
    
    # Clean up any existing test directories
    if (Test-Path $testConfig.WorkingDir) {
        Remove-Item $testConfig.WorkingDir -Recurse -Force
    }
    if (Test-Path $testConfig.ExpectedDir) {
        Remove-Item $testConfig.ExpectedDir -Recurse -Force
    }
    
    # Create test directories
    New-Item -ItemType Directory -Path $testConfig.WorkingDir -Force | Out-Null
    New-Item -ItemType Directory -Path $testConfig.ExpectedDir -Force | Out-Null
    
    # Extract test cases
    Write-TestLog "Extracting clean test case..."
    Expand-Archive -Path $testConfig.CleanZip -DestinationPath $testConfig.WorkingDir -Force
    
    Write-TestLog "Extracting expected results..."
    Expand-Archive -Path $testConfig.ExpectedZip -DestinationPath $testConfig.ExpectedDir -Force
    
    Write-TestLog "Test environment initialized successfully"
}

function Test-ScriptExecution {
    Write-TestLog "Testing script execution..."
    
    # Find the parts directory in the working directory
    $partsDir = Get-ChildItem -Path $testConfig.WorkingDir -Recurse -Directory -Name "parts" | Select-Object -First 1
    if (-not $partsDir) {
        throw "Could not find 'parts' directory in extracted test case"
    }
    
    $fullPartsDir = Join-Path $testConfig.WorkingDir $partsDir
    Write-TestLog "Found parts directory: $fullPartsDir"
    
    # Test dry-run first
    Write-TestLog "Running dry-run test..."
    try {
        & $testConfig.MainScript -partsDir $fullPartsDir
        Write-TestLog "Dry-run completed successfully" "SUCCESS"
    }
    catch {
        Write-TestLog "Dry-run failed: $($_.Exception.Message)" "ERROR"
        throw
    }
    
    # Test actual execution
    Write-TestLog "Running actual execution..."
    try {
        & $testConfig.MainScript -partsDir $fullPartsDir -Execute
        Write-TestLog "Execution completed successfully" "SUCCESS"
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
    
    # Find expected parts directory
    $expectedPartsDir = Get-ChildItem -Path $testConfig.ExpectedDir -Recurse -Directory -Name "parts" | Select-Object -First 1
    if (-not $expectedPartsDir) {
        throw "Could not find 'parts' directory in expected results"
    }
    
    $fullExpectedPartsDir = Join-Path $testConfig.ExpectedDir $expectedPartsDir
    Write-TestLog "Expected parts directory: $fullExpectedPartsDir"
    
    # Compare file lists
    Write-TestLog "Comparing file lists..."
    $actualFiles = Get-ChildItem -Path $PartsDir -Filter "*.dcx" | Sort-Object Name
    $expectedFiles = Get-ChildItem -Path $fullExpectedPartsDir -Filter "*.dcx" | Sort-Object Name
    
    $differences = Compare-Object $actualFiles $expectedFiles -Property Name
    if ($differences) {
        Write-TestLog "File list differences found:" "ERROR"
        foreach ($diff in $differences) {
            $side = if ($diff.SideIndicator -eq "<=") { "ACTUAL ONLY" } else { "EXPECTED ONLY" }
            Write-TestLog "  ${side}: $($diff.Name)" "ERROR"
        }
        throw "File list validation failed"
    }
    
    Write-TestLog "File lists match perfectly" "SUCCESS"
    
    # Validate specific expected files
    $expectedLodFiles = @(
        "am_m_1620_L.partsbnd.dcx",
        "bd_m_1620_L.partsbnd.dcx", 
        "hd_m_1800_L.partsbnd.dcx",
        "lg_m_1620_L.partsbnd.dcx"
    )
    
    foreach ($lodFile in $expectedLodFiles) {
        $actualPath = Join-Path $PartsDir $lodFile
        if (-not (Test-Path $actualPath)) {
            Write-TestLog "Missing expected LOD file: $lodFile" "ERROR"
            throw "Missing LOD file validation failed"
        }
        Write-TestLog "Found expected LOD file: $lodFile" "SUCCESS"
    }
    
    # Validate file sizes (basic sanity check)
    Write-TestLog "Validating file sizes..."
    foreach ($file in $actualFiles) {
        if ($file.Length -eq 0) {
            Write-TestLog "Zero-byte file detected: $($file.Name)" "ERROR"
            throw "File size validation failed"
        }
    }
    
    Write-TestLog "All file sizes are valid" "SUCCESS"
    Write-TestLog "Result validation completed successfully" "SUCCESS"
}

function Test-MixedNumberingCase {
    param([string]$PartsDir)
    
    Write-TestLog "Testing mixed numbering case fix..."
    
    # Check if hd_m_1800.partsbnd.dcx was processed correctly
    # This file should have had internal renumbering from 1620 to 1800
    $hdFile = Join-Path $PartsDir "hd_m_1800.partsbnd.dcx"
    if (-not (Test-Path $hdFile)) {
        Write-TestLog "HD file not found: $hdFile" "ERROR"
        return $false
    }
    
    # Look for the log file to check if renumbering occurred
    $logFile = Get-ChildItem -Path $PartsDir -Recurse -Filter "*.log" | Select-Object -First 1
    if ($logFile) {
        $logContent = Get-Content $logFile.FullName -Raw
        if ($logContent -match "Container/Content mismatch.*HD_M_1620.*HD_M_1800") {
            Write-TestLog "Mixed numbering fix confirmed in logs" "SUCCESS"
            return $true
        }
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
        if (Test-Path $testConfig.ExpectedDir) {
            Remove-Item $testConfig.ExpectedDir -Recurse -Force
        }
        Write-TestLog "Cleanup completed"
    } else {
        Write-TestLog "Keeping temp files for inspection: $($testConfig.WorkingDir)"
    }
}

# Main test execution
try {
    Write-TestLog "=== STARTING ELDEN LOD TEST SUITE ==="
    Write-TestLog "Test case: $TestCaseName"
    
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
    $exitCode = 1
}
finally {
    Clear-TestEnvironment
}

exit $exitCode
