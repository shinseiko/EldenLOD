# Elden Ring LOD Modding Scripts - Project Overview

## PURPOSE
These scripts automate the creation of Level of Detail (LOD) versions of Elden Ring armor mods by:
1. Extracting mod files from BND containers
2. Renumbering files to create LOD variants (e.g., 1800 → 1801, 1802, 1803)
3. Creating proper directory structures for each LOD level
4. Handling TPF texture containers and their internal DDS files
5. Repacking everything back into proper BND containers

## CRITICAL ARCHITECTURAL FACTS
### Directory Structure Reality
- **WRONG**: There is NO generic "LOD" directory
- **CORRECT**: LOD directories are named like the original but with L suffix: `HD_M_1800-partsbnd-dcx` → `HD_M_1800_L-partsbnd-dcx`
- **CORRECT**: Each armor piece gets its own LOD directory with its specific number (1620, 1800, etc.)

### TPF File Structure Reality
- **TPF XML files**: Always named `_witchy-tpf.xml` inside the TPF extract directory
- **DDS files**: Live inside TPF containers and need renumbering too
- **Mixed numbering**: Mods can have multiple pieces with different base numbers (e.g., am_m_1620, hd_m_1800)

### Script Parameters Reality
- **Main script**: `EldenLOD-Extract.ps1`
- **Parameter**: `-partsDir` (NOT -InputDir or -OutputDir)
- **Vanilla parts**: Script expects vanilla parts at `S:\ELDEN RING\Game\parts`

## FILE HIERARCHY
```
Mod Directory Structure:
├── hd_m_1800-partsbnd-dcx/           # Main armor piece container
│   ├── _witchy-bnd.xml               # BND container XML
│   ├── HD_M_1800.flver              # 3D model file
│   ├── HD_M_1800-tpf/               # Texture container
│   │   ├── _witchy-tpf.xml          # TPF XML (lists DDS files)
│   │   ├── c2110_*.dds              # Texture files
│   │   └── HD_M_1620_*.dds          # ← PROBLEM: Wrong numbering
│   └── other files...
├── bd_m_1620-partsbnd-dcx/          # Body piece (different number)
├── lg_m_1620-partsbnd-dcx/          # Leg piece (different number)
└── Generated LOD directories:
    ├── hd_m_1800_L-partsbnd-dcx/    # LOD for head piece
    ├── bd_m_1620_L-partsbnd-dcx/    # LOD for body piece
    └── lg_m_1620_L-partsbnd-dcx/    # LOD for leg piece
```

## KNOWN ISSUES BEING SOLVED
1. **Internal TPF DDS renumbering**: DDS files inside TPF containers maintain old numbering patterns
2. **XML reference updates**: TPF XML files don't get updated with new DDS file names
3. **Code maintainability**: Renumbering logic was duplicated across scripts

## SOLUTION ARCHITECTURE
### Shared Module: `EldenLOD.psm1`
Contains reusable functions:
- `Invoke-FileRenumbering`: Handles non-TPF files (FLVER, ANIBND, etc.)
- `Invoke-DdsRenumbering`: Handles DDS files within TPF containers
- `Update-BndXmlReferences`: Updates BND XML after file renaming
- `Update-TpfXmlReferences`: Updates TPF XML after DDS renaming

### Main Script: `EldenLOD-Extract.ps1`
- Uses shared module functions instead of inline logic
- Enhanced dry-run mode shows exactly what will be changed
- Proper error handling and logging
- Handles mixed numbering scenarios

## TESTING APPROACH
### Test Data Location
`C:\EldenMods\RoKaMyuu\MalikethCostume\parts - Copy\`

### Known Test Case Issues
- TPF: `hd_m_1800-partsbnd-dcx\HD_M_1800-tpf\`
- Problem files: `HD_M_1620_*.dds` (should be `HD_M_1800_*.dds`)
- XML references: `_witchy-tpf.xml` still references old `HD_M_1620_*.dds` names

### Verification Steps
1. Run dry-run to preview changes
2. Execute script to apply fixes
3. Verify DDS files are renamed correctly
4. Verify TPF XML is updated with new references
5. Verify LOD directories are created with proper names
6. Verify repacking works correctly

## COMMON MISTAKES TO AVOID
1. Looking for a generic "LOD" output directory (doesn't exist)
2. Using wrong script parameters (-InputDir instead of -partsDir)
3. Expecting uniform numbering (mods can have mixed numbers)
4. Ignoring TPF internal structure (DDS files and XML need updating)
5. Case sensitivity issues with file pattern matching

## EXECUTION EXAMPLES
```powershell
# Dry run to preview changes
.\EldenLOD-Extract.ps1 -partsDir "C:\EldenMods\SomeMod\parts"

# Execute changes
.\EldenLOD-Extract.ps1 -partsDir "C:\EldenMods\SomeMod\parts" -Execute

# Full workflow
.\Invoke-EldenLOD.ps1 -partsDir "C:\EldenMods\SomeMod\parts"
```
