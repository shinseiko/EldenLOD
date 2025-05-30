# Debug path resolution
$testsDir = Split-Path -Parent $MyInvocation.MyCommand.Path  
$mainScriptsDir = Split-Path -Parent $testsDir
$encumberedDir = Join-Path $testsDir "encumbered"

Write-Host "testsDir: $testsDir"
Write-Host "mainScriptsDir: $mainScriptsDir"
Write-Host "encumberedDir: $encumberedDir"
Write-Host "MainScript would be: $(Join-Path $mainScriptsDir 'EldenLOD-Extract.ps1')"
Write-Host "LogFile would be: $(Join-Path $testsDir 'test-results.log')"

# Test if paths exist
Write-Host "MainScript exists: $(Test-Path (Join-Path $mainScriptsDir 'EldenLOD-Extract.ps1'))"
Write-Host "Encumbered dir exists: $(Test-Path $encumberedDir)"
