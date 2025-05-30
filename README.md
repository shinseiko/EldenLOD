# EldenLOD v0.1 Alpha

EldenLOD is a PowerShell-based toolkit designed to automate the process of extracting, renumbering, and repacking Level of Detail (LOD) assets for Elden Ring mods. This suite ensures that mods display correctly at various distances, enhancing the seamless co-op experience.

**Latest Enhancement**: Complete refactoring with shared module functions, enhanced dry-run mode, comprehensive testing framework, and CI/CD integration.

---

## Features

- **Smart Renumbering:** Only renumbers files when there's a mismatch between container and content numbers
- **Enhanced Dry-Run Mode:** Detailed preview showing exactly what changes would be made and why
- **Shared Module Architecture:** Modular functions for better maintainability and reusability
- **Empty TPF Handling:** Properly handles intentionally empty texture files
- **Flexible Workflow:** Choose from Full, ExtractOnly, or RepackOnly processing
- **Comprehensive Testing:** Automated testing framework with multiple test levels
- **CI/CD Integration:** GitHub Actions workflow for continuous testing
- **Comprehensive Logging:** Detailed logs for debugging and verification
- **Integration with WitchyBND:** Utilizes external tools for archive management
- **Error Recovery:** Robust error handling and validation

---

## Prerequisites

- PowerShell 5.1 or higher (PowerShell 7+ recommended)
- WitchyBND (must be installed and added to your system PATH)
- Extracted Elden Ring game files (UnpackedGame directory)

---

## Installation

1. **Clone the repository:**

        git clone https://github.com/shinseiko/EldenLOD.git

2. **Navigate to the project directory:**

        cd EldenLOD

3. **Ensure dependencies are met:**
   - Verify PowerShell and WitchyBND are correctly installed
   - Set up UnpackedGame directory or UnpackedGameDir environment variable

---

## Quick Start

### Main Entry Point (Recommended)

The unified entry point supports different workflow types:

**Full Processing (Extract + Repack):**
```powershell
.\Invoke-EldenLOD.ps1 -PartsDir "C:\YourMod\parts" -Execute
```

**Extract Only:**
```powershell
.\Invoke-EldenLOD.ps1 -PartsDir "C:\YourMod\parts" -WorkflowType ExtractOnly -Execute
```

**Repack Only:**
```powershell
.\Invoke-EldenLOD.ps1 -PartsDir "C:\YourMod\parts" -WorkflowType RepackOnly -Execute
```

**Dry Run (Preview Changes):**
```powershell
.\Invoke-EldenLOD.ps1 -PartsDir "C:\YourMod\parts"
```

### Individual Steps

**Extract and Process:**
```powershell
.\EldenLOD-Extract.ps1 -partsDir "C:\YourMod\parts" -Execute
```

**Repack Processed Files:**
```powershell
.\EldenLOD-Repack.ps1 -partsDir "C:\YourMod\parts" -Execute
```

### Batch Files (Windows)

For convenience, you can also use the provided batch files:
- `Invoke-EldenLOD.bat` - Main entry point
- `EldenLOD-Extract.bat` - Extract only
- `EldenLOD-Repack.bat` - Repack only

---

## Key Changes in v0.1 Alpha

### Enhanced Shared Module Architecture
- **Modular Functions:** Moved renumbering logic to `EldenLOD.psm1` for better maintainability
- Functions: `Invoke-FileRenumbering`, `Invoke-DdsRenumbering`, `Update-BndXmlReferences`, `Update-TpfXmlReferences`
- **Improved Reusability:** Consistent parameter handling across all operations

### Enhanced Dry-Run Mode  
- **Detailed Previews:** Shows exactly what files would be renamed and why
- **Action Descriptions:** Displays which XML references would be updated
- **Process Insights:** Explains container/content mismatches before changes

### Fixed Internal TPF File Renumbering
- **CRITICAL FIX:** Properly renumbers DDS files inside TPF containers
- **Container Sync:** Ensures TPF contents match container numbering
- **LOD Processing:** Correctly handles _L suffix addition for LOD variants

### Comprehensive Testing Framework
- **Multiple Test Levels:** Minimal, Simple, and Full test suites
- **Automated Validation:** Tests both dry-run and execute modes
- **CI/CD Integration:** GitHub Actions workflow for continuous testing
- **Test Runner:** `Run-Tests.ps1` with detailed reporting and flexible parameters

### Enhanced Error Handling
- **Consistent Logic:** Execute/DryRun branching throughout all scripts
- **Better Validation:** Improved TPF empty detection and XML parsing
- **Robust Recovery:** Graceful handling of missing files and failed operations

---

## Important Notes

> **EXECUTION REQUIRED:**  
> All scripts require the `-Execute` switch to actually perform operations.  
> Without `-Execute`, scripts run in dry-run mode and only show what they *would* do.

> **BACKUP RECOMMENDED:**  
> Always backup your mod files before processing. The scripts modify files in-place.

> **CORRECT ORDER:**  
> When using individual scripts, always run Extract before Repack.

---

## Directory Structure

```
EldenLOD/
├── Invoke-EldenLOD.ps1           # Main entry point (unified workflow)
├── EldenLOD-Extract.ps1          # Extract and process files
├── EldenLOD-Repack.ps1           # Repack processed files
├── EldenLOD.psm1                 # Shared module (functions)
├── Run-Tests.ps1                 # Test runner with multiple test levels
├── *.bat                         # Windows batch file shortcuts
├── tests/                        # Testing framework
│   ├── minimal-test.ps1          # Simple functionality test
│   ├── Test-EldenLOD-Simple.ps1  # Comprehensive test framework
│   ├── Test-EldenLOD-*.ps1       # Additional test variants
│   └── encumbered/               # Test data and cases
├── .github/workflows/            # CI/CD pipeline
│   └── test-eldenlod.yml         # GitHub Actions workflow
├── docs/                         # Comprehensive documentation
│   ├── PROJECT_OVERVIEW.md       # Architecture and common mistakes
│   ├── FUNCTION_REFERENCE.md     # Function documentation
│   ├── DEBUGGING_TRAIL.md        # Investigation history
│   └── TESTING_FRAMEWORK_COMPLETE.md # Testing implementation guide
├── EMPTY_TPF_HANDLING.md         # Empty TPF documentation
├── _logs/                        # Processing logs
└── config/                       # Configuration files
```

---

## Troubleshooting

### Common Issues

**"No UnpackedGame directory found"**
- Set environment variable: `$env:UnpackedGameDir = "C:\Path\To\UnpackedGame"`
- Or place UnpackedGame folder in your mod's parts directory
- Or use `-UnpackedGameDir` parameter

**"witchybnd command not found"**
- Ensure WitchyBND is installed and in your system PATH
- Try running `witchybnd --help` to verify installation

**"TPF extraction failed"**
- Check if TPF files are corrupted
- Verify sufficient disk space
- Check log files in `_logs` directory

### Log Files

All operations are logged to `_logs\*.log` files:
- `Extract-And-Patch-LOD.log` - Extraction and processing details
- `Repack-LOD.log` - Repacking operation details

Enable verbose output for more details:
```powershell
$VerbosePreference = 'Continue'
.\Invoke-EldenLOD.ps1 -Execute -Verbose
```

---

## Examples

### Example 1: Full Processing
```powershell
# Process all files in current directory
.\Invoke-EldenLOD.ps1 -Execute

# Process specific mod directory
.\Invoke-EldenLOD.ps1 -PartsDir "C:\Mods\MyArmorMod\parts" -Execute
```

### Example 2: Extract Only (for debugging)
```powershell
# Extract and process, but don't repack
.\Invoke-EldenLOD.ps1 -WorkflowType ExtractOnly -Execute

# Then inspect the extracted files before repacking
# .\Invoke-EldenLOD.ps1 -WorkflowType RepackOnly -Execute
```

### Example 3: Dry Run Preview (Enhanced)
```powershell
# See detailed preview of what would be processed without making changes
.\Invoke-EldenLOD.ps1 -PartsDir "C:\Mods\TestMod\parts"

# Output shows:
# - Which files would be renamed and why (container/content mismatches)
# - Which XML references would be updated  
# - Which archives would be repacked
# - Which directories would be cleaned up
```

### Example 4: Testing Framework
```powershell
# Run all test levels with detailed reporting
.\Run-Tests.ps1 -Execute

# Run specific test level
.\Run-Tests.ps1 -TestLevel Minimal -Execute

# Run with timeout protection
.\Run-Tests.ps1 -TestLevel Simple -TimeoutSeconds 300 -Execute
```

---

## Technical Details

### Shared Module Functions
The project now uses a modular architecture with shared functions in `EldenLOD.psm1`:

- **`Invoke-FileRenumbering`** - Handles all non-TPF file types (FLVER, ANIBND, CLM2, HKX, etc.)
- **`Invoke-DdsRenumbering`** - Handles DDS files within TPF containers  
- **`Update-BndXmlReferences`** - Updates BND4 XML file references after renaming
- **`Update-TpfXmlReferences`** - Updates TPF XML file references after DDS renaming

### Renumbering Logic
The script compares container BND numbers with internal file numbers:
- **Container:** `HD_M_1800.partsbnd.dcx` expects number `1800`
- **Contents:** TPF contains `HD_M_1620` files (number `1620`)
- **Action:** Rename `1620` → `1800` (mismatch correction)

### Enhanced Dry-Run Mode
- **Process Preview:** Shows exactly which files would be renamed with before/after names
- **Mismatch Detection:** Explains why renumbering is needed (container vs content number differences)  
- **XML Updates:** Details which XML references would be updated and why
- **Action Sequence:** Displays the complete processing workflow before execution

### Testing Framework
- **Test Levels:** Minimal (basic functionality), Simple (comprehensive), Full (all features)
- **Validation:** Tests both dry-run preview and actual execution modes
- **Automated Reports:** Detailed test results with pass/fail status and execution times
- **CI/CD Ready:** GitHub Actions integration for automated testing on commits

---

## Workflow Types

| Type | Description | Use Case |
|------|-------------|----------|
| `Full` | Extract + Process + Repack | Normal mod processing |
| `ExtractOnly` | Extract and process only | Debugging, inspection |
| `RepackOnly` | Repack previously processed files | After manual edits |

---

## Roadmap

### Completed ✅
- [x] Fixed critical renumbering logic bug
- [x] Enhanced shared module architecture with reusable functions
- [x] Implemented comprehensive testing framework with CI/CD integration
- [x] Enhanced dry-run mode with detailed action previews
- [x] Fixed internal TPF file renumbering issues
- [x] Improved error handling and logging
- [x] Created extensive documentation and debugging guides

### Future Enhancements 🚀
- [ ] Graphical user interface (GUI) for ease of use
- [ ] Batch processing optimization for large mod collections
- [ ] Integration with popular mod managers
- [ ] Support for additional Elden Ring asset types
- [ ] Automated backup and restore functionality
- [ ] Performance monitoring and optimization
- [ ] Advanced configuration options

---

## Testing

### Running Tests Locally

The project includes a comprehensive testing framework with multiple test levels:

```powershell
# Run all tests with detailed reporting
.\Run-Tests.ps1 -Execute

# Run specific test level
.\Run-Tests.ps1 -TestLevel Minimal -Execute    # Quick functionality check
.\Run-Tests.ps1 -TestLevel Simple -Execute     # Comprehensive testing
.\Run-Tests.ps1 -TestLevel Full -Execute       # All features and edge cases

# Run with custom timeout
.\Run-Tests.ps1 -TestLevel Simple -TimeoutSeconds 300 -Execute
```

### Test Levels

| Level | Description | Duration | Use Case |
|-------|-------------|----------|----------|
| **Minimal** | Basic functionality test | ~30 seconds | Quick validation |
| **Simple** | Comprehensive test with error handling | ~2-5 minutes | Development testing |
| **Full** | All features with multiple test cases | ~5-10 minutes | Release validation |

### CI/CD Integration

The project includes GitHub Actions workflow (`.github/workflows/test-eldenlod.yml`) that:
- Runs tests on every commit and pull request
- Tests multiple PowerShell versions
- Validates both Windows and cross-platform compatibility
- Provides detailed test reports and artifacts

---

## Contributing

Contributions are welcome!

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes with clear commit messages
4. Test thoroughly with different mod types
5. Submit a pull request describing your changes

Please ensure your code follows PowerShell best practices and includes appropriate error handling.

---

## License

This project is licensed under the MIT License. See `LICENSE` file for details.

---

## Acknowledgments

- **FromSoftware** for creating Elden Ring
- **WitchyBND** developers for essential archive management tools
- **Elden Ring modding community** for feedback and testing
- **Contributors** who helped identify and fix critical bugs

---

## Support

If you encounter issues:

1. **Check the troubleshooting section above**
2. **Review log files** in `_logs` directory for detailed error information
3. **Run tests** to validate your environment: `.\Run-Tests.ps1 -TestLevel Minimal -Execute`
4. **Check documentation** in the `docs/` folder:
   - `PROJECT_OVERVIEW.md` - Architecture and common mistakes
   - `FUNCTION_REFERENCE.md` - Function documentation and debugging
   - `DEBUGGING_TRAIL.md` - Investigation history and solutions
5. **Create an issue on GitHub** with:
   - Full error message and log contents
   - Steps to reproduce the issue
   - Your environment details (PowerShell version, WitchyBND version)
   - Test results from `.\Run-Tests.ps1`

### Quick Diagnostics
```powershell
# Check your PowerShell version
$PSVersionTable.PSVersion

# Test WitchyBND installation
witchybnd --help

# Validate project functionality
.\Run-Tests.ps1 -TestLevel Minimal -Execute

# Check for common issues
Get-ChildItem -Path $partsDir -Filter "*.partsbnd.dcx" | Measure-Object
```

---

*EldenLOD v0.1 Alpha - Enhanced Elden Ring LOD Asset Processing with Comprehensive Testing*
