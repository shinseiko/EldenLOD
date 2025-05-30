---
title: "PowerShell Coding Standards for EldenLOD"
author: "shinseiko"
date: "2025-05-30"
version: "1.0"
status: "Active"
tags: 
  - standards
  - powershell
  - best-practices
  - documentation
---

# PowerShell Coding Standards for EldenLOD

This document defines the coding standards, best practices, and documentation requirements for PowerShell scripts in the EldenLOD project.

## 1. Code Style

### 1.1 Naming Conventions

- **Functions**: Use approved PowerShell Verb-Noun format (e.g., `Get-TPFContent`, `Update-LODFile`)
- **Parameters**: Use PascalCase (e.g., `$GamePath`, `$ExtractMode`)
- **Variables**: Use camelCase (e.g., `$fileCount`, `$currentModel`)
- **Constants**: Use UPPER_SNAKE_CASE (e.g., `$SCRIPT_VERSION`, `$MAX_RETRIES`)
- **Private Functions**: Prefix with underscore (e.g., `_ValidateGamePath`, `_ProcessLODFile`)

### 1.2 Formatting

- Use 4 spaces for indentation, not tabs
- Keep line length under 100 characters where possible
- Place opening braces on the same line for control structures
- Use single quotes for static strings, double quotes for expandable strings
- Add a single space after commas and around operators

### 1.3 Script Structure

1. File header with metadata comment block
2. Parameter declarations
3. Function definitions
4. Main script logic
5. Cleanup operations

## 2. Documentation

### 2.1 Script Header

Every script must have a header comment block containing:

```powershell
<#
.SYNOPSIS
    Brief summary of what the script does
.DESCRIPTION
    Detailed description of the script functionality and purpose
.NOTES
    Author: [Author Name]
    Version: [x.y.z]
    Date: [YYYY-MM-DD]
    Requirements: PowerShell 5.1+
    License: [License Name]
.LINK
    Project repository: https://github.com/shinseiko/EldenLOD
#>
```

### 2.2 Function Documentation

All public functions must include comment-based help:

```powershell
<#
.SYNOPSIS
    Brief description of function purpose
.DESCRIPTION
    Detailed description of what the function does
.PARAMETER ParameterName
    Description of the parameter and its purpose
.EXAMPLE
    Example-Function -Parameter "Value"
    Description of what this example does
.INPUTS
    Type of input object (if accepting pipeline input)
.OUTPUTS
    Type of output object
.NOTES
    Additional information about the function
#>
```

### 2.3 Code Comments

- Use single-line comments (`#`) for explanatory notes
- Add AI-friendly annotations for complex sections:
  ```powershell
  # @context: Business logic for handling empty TPF files
  # @complexity: Medium
  # @dependencies: EldenLOD.psm1:Get-TPFContent, System.IO
  ```
- Comment complex algorithms and non-obvious logic

## 3. Error Handling

### 3.1 Error Types

- Use `Write-Error` for non-terminating errors
- Use `throw` for terminating errors
- Use `try/catch/finally` blocks for operations that may fail
- Include meaningful error messages with context information

### 3.2 Error Reporting

```powershell
try {
    # Operation that might fail
} catch [System.IO.FileNotFoundException] {
    Write-Error "The required file '$filePath' was not found. Please check if the game is installed correctly."
} catch {
    Write-Error "An unexpected error occurred: $($_.Exception.Message)"
} finally {
    # Cleanup operations
}
```

## 4. Logging

### 4.1 Log Levels

- `Write-Verbose` - For detailed progress information
- `Write-Warning` - For non-critical issues
- `Write-Error` - For errors that should be addressed
- `Write-Debug` - For debugging information

### 4.2 Log Formatting

```powershell
Write-Verbose "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] [INFO] Processing file: $fileName"
```

## 5. Security Practices

- Never store credentials in scripts
- Validate all user input before processing
- Use SecureString for sensitive data
- Apply the principle of least privilege

## 6. Performance

- Avoid nested loops where possible
- Use pipeline for processing large datasets
- Minimize disk I/O operations
- Consider using parallel processing for independent operations

## 7. Testing

### 7.1 Test Strategy

- Every script should have associated test cases
- Tests should cover both normal and error paths
- Use Pester framework for unit tests
- Include integration tests for workflow validation

### 7.2 Test Documentation

```powershell
<#
.SYNOPSIS
    Tests for Function-Name
.DESCRIPTION
    This test case validates that Function-Name correctly handles:
    - Scenario 1
    - Scenario 2
    - Error condition
#>
```

## 8. Code Analysis

### 8.1 PSScriptAnalyzer

All code should pass PSScriptAnalyzer with the following rules enabled:

```powershell
$analyzerRules = @(
    'PSAvoidUsingCmdletAliases',
    'PSAvoidUsingPositionalParameters',
    'PSUseApprovedVerbs',
    'PSAvoidUsingInvokeExpression',
    'PSUseDeclaredVarsMoreThanAssignments',
    'PSUsePSCredentialType',
    'PSAvoidHardcodedPaths'
)
```

### 8.2 Static Analysis

Run PSScriptAnalyzer regularly:

```powershell
Invoke-ScriptAnalyzer -Path "scripts" -RecurseCustomRulePath "tests/rules" -IncludeRule $analyzerRules
```

## 9. Version Control

- Use meaningful commit messages
- Reference issue numbers in commits where applicable
- Keep commits focused on single logical changes
- Document breaking changes in CHANGELOG.md

## 10. Module Development

### 10.1 Module Structure

```
ModuleName/
├── ModuleName.psd1         # Module manifest
├── ModuleName.psm1         # Module script
├── Public/                 # Public functions
│   ├── Function1.ps1
│   └── Function2.ps1
├── Private/                # Private functions
│   ├── Helper1.ps1
│   └── Helper2.ps1
└── en-US/                  # Localized strings
    └── about_ModuleName.help.txt
```

### 10.2 Module Manifest

Include comprehensive metadata:

```powershell
@{
    ModuleVersion     = '0.1.0'
    GUID              = 'unique-guid-here'
    Author            = 'Author Name'
    Description       = 'Description of module functionality'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('Public-Function1', 'Public-Function2')
    PrivateData       = @{
        PSData = @{
            Tags       = @('tag1', 'tag2')
            ProjectUri = 'https://github.com/username/project'
            LicenseUri = 'https://github.com/username/project/blob/main/LICENSE'
        }
    }
}
```

## 11. AI Compatibility

### 11.1 AI-Friendly Documentation

Include machine-readable metadata:

```powershell
# @metadata: {
#   "version": "0.1.0",
#   "author": "Author Name",
#   "dependencies": ["System.IO", "Newtonsoft.Json"],
#   "complexity": "medium"
# }
```

### 11.2 Structured Comments

Use consistent annotations for AI tools:

```powershell
# @context: Description of business context
# @algorithm: Name/description of algorithm used
# @inputs: Description of expected input
# @outputs: Description of expected output
# @dependencies: List of dependencies
# @complexity: [low|medium|high]
```

## References

1. [PowerShell Best Practices and Style Guide](https://poshcode.gitbooks.io/powershell-practice-and-style/)
2. [Microsoft PowerShell Documentation](https://docs.microsoft.com/en-us/powershell/)
3. [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer)
4. [Approved PowerShell Verbs](https://docs.microsoft.com/en-us/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands)
