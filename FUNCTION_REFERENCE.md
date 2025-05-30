# Function Reference Guide

## Shared Module Functions (`EldenLOD.psm1`)

### `Invoke-FileRenumbering`
**Purpose**: Renames non-TPF files (FLVER, ANIBND, CLM2, HKX, etc.) with new numbering

**Parameters**:
- `$extractDir` - Directory containing extracted files
- `$expectedNumber` - Target number (e.g., 1800)
- `$currentNumber` - Source number ("auto" for detection)
- `$logFile` - Path to log file
- `$Execute` - Whether to actually rename files
- `$DryRun` - Whether to show preview only

**Returns**: Object with `Success`, `RenamedFiles`, `Message` properties

**Example Usage**:
```powershell
$result = Invoke-FileRenumbering -extractDir $dir -expectedNumber 1800 -currentNumber "auto" -logFile $log -Execute:$Execute -DryRun:(-not $Execute)
```

### `Invoke-DdsRenumbering`
**Purpose**: Renames DDS files inside TPF containers and updates TPF XML references

**Parameters**:
- `$tpfExtractDir` - TPF extract directory path
- `$expectedNumber` - Target number (e.g., 1800)
- `$logFile` - Path to log file  
- `$Execute` - Whether to actually rename files
- `$DryRun` - Whether to show preview only

**Returns**: Object with `Success`, `RenamedFiles`, `Message` properties

**Critical Notes**:
- Looks for `_witchy-tpf.xml` in the TPF directory
- Handles mixed file patterns (some correct, some needing renaming)
- Updates XML references after renaming DDS files

### `Update-TpfXmlReferences`
**Purpose**: Updates TPF XML file with new DDS file names after renaming

**Parameters**:
- `$tpfExtractDir` - TPF extract directory path
- `$renamedFiles` - Hashtable of old → new file names
- `$expectedNumber` - Target number for validation
- `$logFile` - Path to log file
- `$Execute` - Whether to actually update XML
- `$DryRun` - Whether to show preview only

**Returns**: Boolean success status

### `Update-BndXmlReferences`
**Purpose**: Updates BND XML file with new file references after renaming

**Parameters**:
- `$extractDir` - BND extract directory path
- `$renamedFiles` - Hashtable of old → new file names
- `$logFile` - Path to log file
- `$Execute` - Whether to actually update XML
- `$DryRun` - Whether to show preview only

**Returns**: Boolean success status

## Main Script Flow (`EldenLOD-Extract.ps1`)

### Parameter Validation
```powershell
# CORRECT parameter name
[Parameter(Mandatory=$true)]
[string]$partsDir
```

### Processing Flow
1. **Discovery**: Find all `-partsbnd-dcx` directories
2. **For each BND directory**:
   - Extract if not already extracted
   - Call `Invoke-FileRenumbering` for non-TPF files
   - Call `Update-BndXmlReferences` if files were renamed
3. **For each TPF in BND**:
   - Extract TPF if not already extracted  
   - Call `Invoke-DdsRenumbering` for DDS files
   - Repack TPF if changes were made
4. **Create LOD directories**: Copy processed files to `*_L-partsbnd-dcx` directories
5. **Cleanup**: Remove temporary extract directories

### Critical Execution Points
- DDS renumbering must happen AFTER TPF extraction
- XML updates must happen AFTER file renaming
- TPF repacking must happen AFTER DDS renaming and XML updates
- LOD directory creation must use renamed files

## Debugging Checkpoints

### Verify Function Calls
Add logging before each function call:
```powershell
Write-Host "About to call Invoke-DdsRenumbering for $tpfExtractDir"
$ddsResult = Invoke-DdsRenumbering -tpfExtractDir $tpfExtractDir ...
Write-Host "DDS result: Success=$($ddsResult.Success), Message=$($ddsResult.Message)"
```

### Verify File States
Check file existence before and after operations:
```powershell
Write-Host "Before: $(Get-ChildItem $tpfExtractDir -Filter '*.dds' | Select-Object -ExpandProperty Name)"
# ... operation ...
Write-Host "After: $(Get-ChildItem $tpfExtractDir -Filter '*.dds' | Select-Object -ExpandProperty Name)"
```

### Verify XML Content
Check XML before and after updates:
```powershell
$xmlContent = Get-Content "$tpfExtractDir\_witchy-tpf.xml" -Raw
Write-Host "XML contains HD_M_1620: $($xmlContent -match 'HD_M_1620')"
Write-Host "XML contains HD_M_1800: $($xmlContent -match 'HD_M_1800')"
```
