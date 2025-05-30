<#
.SYNOPSIS
EldenLOD - Elden Ring Level of Detail (LOD) Asset Processing Toolkit

.DESCRIPTION
Automates the complete workflow for processing Elden Ring LOD assets:
- Extracts and renumbers modded archives
- Patches LOD files with modded content  
- Repacks everything for seamless co-op compatibility

.PARAMETER PartsDir
Directory containing your mod's .partsbnd.dcx files

.PARAMETER WorkflowType
Specify processing type: 'Full', 'ExtractOnly', 'RepackOnly'

.PARAMETER Execute
Actually perform operations (default is dry-run)

.EXAMPLE
Invoke-EldenLOD -PartsDir "C:\Mods\MyMod\parts" -Execute

.EXAMPLE
Invoke-EldenLOD -PartsDir "C:\Mods\MyMod\parts" -WorkflowType ExtractOnly -Execute

.NOTES
Enhanced version combining the best features from multiple script approaches.
Handles empty TPF files, proper file renumbering, and comprehensive error handling.
#>
[CmdletBinding()]
param(
    [string]$PartsDir = (Get-Location).Path,
    [ValidateSet('Full', 'ExtractOnly', 'RepackOnly')]
    [string]$WorkflowType = 'Full',
    [switch]$Execute
)

# Import shared module
$modulePath = Join-Path $PSScriptRoot 'EldenLOD.psm1'
Import-Module $modulePath -Force -ErrorAction Stop

# Validate paths and setup
try {
    $PartsDir = Convert-Path -Path $PartsDir -ErrorAction Stop
} catch {
    Write-Error "Invalid PartsDir: '$PartsDir'. Please specify an existing folder."
    exit 1
}

Write-Host "EldenLOD v2.0 - Elden Ring LOD Asset Processing Toolkit"
Write-Host "Working directory: $PartsDir"
Write-Host "Workflow type: $WorkflowType"
if (-not $Execute) {
    Write-Warning "DRY-RUN MODE: Add -Execute to perform actual operations"
}

# Compose argument hashtables for downstream scripts
$commonArgs = @{
    partsDir = $PartsDir
}
if ($Execute) { 
    $commonArgs.Execute = $true 
}

# Define script paths using the restructured approach
$extractScript = Join-Path $PSScriptRoot 'EldenLOD-Extract.ps1'
$repackScript = Join-Path $PSScriptRoot 'EldenLOD-Repack.ps1'

# Validate scripts exist
if (-not (Test-Path $extractScript)) {
    Write-Error "Extract script not found: $extractScript"
    exit 1
}
if (-not (Test-Path $repackScript)) {
    Write-Error "Repack script not found: $repackScript"
    exit 1
}

# Execute workflow stages
switch ($WorkflowType) {
    'Full' {
        Write-Host "`n=== [EldenLOD] Starting Extraction and Patching ==="
        & $extractScript @commonArgs
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Extraction/Patching failed or was interrupted."
            exit $LASTEXITCODE
        }

        Write-Host "`n=== [EldenLOD] Starting Repacking ==="
        & $repackScript @commonArgs
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Repacking failed or was interrupted."
            exit $LASTEXITCODE
        }
    }
    'ExtractOnly' {
        Write-Host "`n=== [EldenLOD] Starting Extraction and Patching Only ==="
        & $extractScript @commonArgs
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Extraction/Patching failed or was interrupted."
            exit $LASTEXITCODE
        }
    }
    'RepackOnly' {
        Write-Host "`n=== [EldenLOD] Starting Repacking Only ==="
        & $repackScript @commonArgs
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Repacking failed or was interrupted."
            exit $LASTEXITCODE
        }
    }
}

Write-Host "`n[EldenLOD] $WorkflowType workflow complete!"
Write-Host "Check _logs directory for detailed processing information."
