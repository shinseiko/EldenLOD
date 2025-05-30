# Elden Ring LOD Script - Critical Corrections & Documentation

## CRITICAL STRUCTURE FACTS - DO NOT FORGET

### 1. LOD Directory Structure
- **WRONG**: There is NO generic `$partsDir/LOD` directory
- **CORRECT**: LOD directories are named with specific patterns like:
  - `HD_M_1800_L-partsbnd-dcx` (for head piece 1800)
  - `BD_M_1620_L-partsbnd-dcx` (for body piece 1620)
  - `LG_M_1620_L-partsbnd-dcx` (for leg piece 1620)
  - `AM_M_1620_L-partsbnd-dcx` (for arm piece 1620)
- Each LOD directory corresponds to its base armor piece with `_L` suffix

### 2. Script Parameters
- **WRONG**: `-InputDir` and `-OutputDir`
- **CORRECT**: EldenLOD-Extract.ps1 uses `-partsDir` parameter only
- The script determines output locations automatically based on input structure

### 3. TPF XML File Structure
- **WRONG**: Assuming XML is named after the directory or some generic pattern
- **CORRECT**: TPF XML files are ALWAYS named `_witchy-tpf.xml`
- Located inside the TPF extraction directory (e.g., `HD_M_1800-tpf/_witchy-tpf.xml`)

### 4. Mixed Numbering in Mods
- Some mods contain multiple armor pieces with DIFFERENT base numbers
- Example: Maliketh mod has:
  - `am_m_1620` (arm piece)
  - `bd_m_1620` (body piece) 
  - `lg_m_1620` (leg piece)
  - `hd_m_1800` (head piece)
- Each piece retains its own numbering for LOD generation
- **BUT**: Internal files within each piece should match that piece's number

### 5. Current Issue Pattern
- TPF container: `HD_M_1800-tpf` (correct)
- Internal DDS files: `HD_M_1620_*.dds` (WRONG - should be `HD_M_1800_*.dds`)
- XML references: Still point to `HD_M_1620_*.dds` (WRONG)

## DEBUGGING MISTAKES TO AVOID

### 1. Directory Navigation Errors
- Don't assume standard directory structures
- Always verify actual paths before making assumptions
- Use `list_dir` to confirm structure before proceeding

### 2. Parameter Confusion
- Check script parameter definitions before calling
- Don't assume parameter names without verification

### 3. File Naming Assumptions
- Don't guess file naming patterns
- Verify actual file names in directories
- TPF XML is always `_witchy-tpf.xml`, never variations

### 4. Log File Analysis
- Script may not create verbose logs by default
- Need to check if verbose/debug modes are available
- Simple "Processing complete!" doesn't mean everything worked

## CURRENT STATUS - CRITICAL BUG FOUND
- ✅ Script executes without errors
- ✅ DDS renumbering function IS being called (confirmed in verbose log)
- ❌ **BUG**: DDS files are NOT actually renamed despite log showing they were
- ❌ **BUG**: XML shows "already has correct references" but files are still wrong
- ✅ LOD directories are created with correct names
- ❌ **CRITICAL**: The `Invoke-DdsRenumbering` function reports success but doesn't actually rename files

## BUG EVIDENCE
**Log shows successful renaming:**
```
Container/Content mismatch - Renumbering DDS: 'HD_M_1620_a.dds' -> 'HD_M_1800_a.dds'
Container/Content mismatch - Renumbering DDS: 'HD_M_1620_m.dds' -> 'HD_M_1800_m.dds'
Container/Content mismatch - Renumbering DDS: 'HD_M_1620_n.dds' -> 'HD_M_1800_n.dds'
XML file '_witchy-tpf.xml' already has correct references
```

**But final result shows files NOT renamed:**
- Files still exist as: `HD_M_1620_a.dds`, `HD_M_1620_m.dds`, `HD_M_1620_n.dds`
- Should be: `HD_M_1800_a.dds`, `HD_M_1800_m.dds`, `HD_M_1800_n.dds`

## NEXT STEPS
1. Fix the DDS renumbering function call or logic
2. Ensure XML references get updated after DDS renaming
3. Verify complete workflow from TPF extraction through LOD generation
