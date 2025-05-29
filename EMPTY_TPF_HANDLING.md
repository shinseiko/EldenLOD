# Empty TPF Handling in EldenLOD Scripts

## Overview
The EldenLOD scripts now properly handle intentionally empty TPF files (Texture Pack Files) that contain no DDS texture files. This is common in Elden Ring modding where some armor pieces deliberately have no textures.

## Problem
Previously, the scripts would fail when encountering TPF files like `am_m_1620.tpf` that are intentionally empty, causing the entire processing pipeline to halt with errors.

## Solution
Added comprehensive empty TPF detection and handling:

### 1. New Function: `Test-TpfEmpty`
Located in `EldenLOD.psm1`, this function:
- Checks for both `_witchy-tpf.xml` and `witchy-tpf.xml` files
- Parses XML to determine if TPF is intentionally empty
- Handles various XML structures that indicate empty TPFs
- Returns `$true` if TPF is deliberately empty, `$false` otherwise

### 2. Enhanced `Test-TpfValid` Function
- Now properly handles both naming conventions for witchy XML files
- Validates empty TPFs before checking for DDS files
- Improved error handling and XML parsing
- Better logging for debugging empty TPF cases

### 3. Updated Processing Scripts
Both `Extract-And-Patch-LOD.ps1` and `Extract-And-Patch-LOD-Fixed.ps1` now:
- Check if TPF is empty before attempting to process DDS files
- Skip renumbering operations for empty TPFs
- Continue processing other files when empty TPF is encountered
- Log appropriate messages for empty TPF cases

## Key Changes

### EldenLOD.psm1
- Added `Test-TpfEmpty` function for dedicated empty TPF detection
- Enhanced `Test-TpfValid` with better XML handling and empty TPF support
- Fixed XML file naming convention handling (both `_witchy-tpf.xml` and `witchy-tpf.xml`)
- Improved error handling and logging

### Extract-And-Patch-LOD.ps1
- Added empty TPF checks before DDS file processing
- Skip renumbering for intentionally empty TPFs
- Continue processing when empty TPFs are encountered
- Enhanced logging for empty TPF cases

### Extract-And-Patch-LOD-Fixed.ps1
- Same empty TPF handling as main script
- Integrated with simplified, linear workflow

## Usage
The scripts now automatically detect and handle empty TPFs without user intervention. When an empty TPF is encountered:

1. Script detects the empty TPF via XML analysis
2. Logs that the TPF is intentionally empty
3. Skips DDS file processing for that TPF
4. Continues processing other files in the archive

## Examples of Empty TPF Handling
```
TPF is intentionally empty, skipping file processing: 'am_m_1620.tpf'
TPF is intentionally empty, skipping renumbering: 'hd_m_1620.tpf'
LOD TPF is intentionally empty, skipping _L suffix processing: 'AM_M_1620_L.tpf'
```

## Technical Details

### XML Structure Recognition
The script recognizes empty TPFs through these XML patterns:
- `<textures Count="0">` with no child elements
- `<textures>` with no child nodes
- Missing or empty texture definitions

### File Processing Flow
1. Extract TPF archive
2. Check if TPF is intentionally empty
3. If empty: log and continue to next file
4. If not empty: proceed with normal DDS processing

## Future Considerations
- The current implementation preserves empty TPFs as-is
- Future versions might handle empty TPF compression/optimization
- Error reporting distinguishes between "intentionally empty" and "extraction failed"

## Debugging
Enable verbose logging to see detailed empty TPF detection:
```powershell
$VerbosePreference = 'Continue'
.\Extract-And-Patch-LOD.ps1 -Execute -Verbose
```

Check log files in `_logs` directory for detailed processing information.
