---
title: "EldenLOD Usage Guide"
author: "shinseiko"
date: "2025-05-30"
version: "0.1-alpha"
description: "Comprehensive guide for using EldenLOD tool"
keywords:
  - EldenLOD
  - Elden Ring
  - Modding
  - LOD
  - Level of Detail
schema:
  "@context": "https://schema.org"
  "@type": "TechArticle"
  "name": "EldenLOD Usage Guide"
  "articleSection": "Documentation"
  "applicationCategory": "Game Modding"
---

# EldenLOD Usage Guide

## Overview

EldenLOD is a tool for extracting, modifying, and repacking Level of Detail (LOD) files for Elden Ring. This guide covers all commands and operations available through the unified EldenLOD command interface.

## Commands

### Basic Usage

```
EldenLOD <command> [options]
```

Where `<command>` is one of:
- `extract` - Extract LOD files from the game
- `repack` - Repack modified LOD files
- `full` - Perform both extract and repack operations
- `invoke` - Invoke a specific EldenLOD operation
- `test` - Run tests to validate the functionality
- `help` - Show this help information

### Command: extract

Extract LOD files from Elden Ring game directory.

```
EldenLOD extract [path] [options]
```

**Parameters:**
- `path` - Optional path to the Elden Ring game directory. If not specified, the tool will attempt to locate it automatically.

**Options:**
- `-Clean` - Extract clean files without applying any modifications
- `-NoBak` - Do not create backup files
- `-Verbose` - Display detailed progress information
- `-Silent` - Suppress all output except errors

**Examples:**
```
EldenLOD extract
EldenLOD extract "S:\ELDEN RING\Game" -NoBak
EldenLOD extract -Verbose
```

### Command: repack

Repack modified LOD files.

```
EldenLOD repack [path] [options]
```

**Parameters:**
- `path` - Optional path to the directory containing modified LOD files. If not specified, the tool will use the default extraction directory.

**Options:**
- `-Clean` - Repack files without applying any additional modifications
- `-NoBak` - Do not create backup files
- `-Verbose` - Display detailed progress information
- `-Silent` - Suppress all output except errors

**Examples:**
```
EldenLOD repack
EldenLOD repack "C:\ModdingProjects\EldenRing\LOD" -NoBak
EldenLOD repack -Verbose
```

### Command: full

Perform both extract and repack operations in sequence.

```
EldenLOD full [gamePath] [modPath] [options]
```

**Parameters:**
- `gamePath` - Optional path to the Elden Ring game directory
- `modPath` - Optional path to the directory for modified LOD files

**Options:**
- `-Clean` - Process files without applying any modifications
- `-NoBak` - Do not create backup files
- `-Verbose` - Display detailed progress information
- `-Silent` - Suppress all output except errors

**Examples:**
```
EldenLOD full
EldenLOD full "S:\ELDEN RING\Game" "C:\ModdingProjects\EldenRing\LOD"
EldenLOD full -Verbose
```

### Command: invoke

Invoke a specific EldenLOD operation.

```
EldenLOD invoke <operation> [parameters]
```

**Parameters:**
- `operation` - The specific operation to invoke (see Operations section)
- `parameters` - Parameters specific to the operation

**Examples:**
```
EldenLOD invoke ExtractSpecificModel "am_m_1620"
EldenLOD invoke RepairTPF "path\to\broken.tpf"
```

### Command: test

Run tests to validate EldenLOD functionality.

```
EldenLOD test [testName] [options]
```

**Parameters:**
- `testName` - Optional specific test to run. If not specified, all tests will run.

**Options:**
- `-Simple` - Run only simple tests
- `-Verbose` - Display detailed test output
- `-SkipExecution` - Validate test logic without executing file operations

**Examples:**
```
EldenLOD test
EldenLOD test SimpleExtraction -Verbose
EldenLOD test -SkipExecution
```

### Command: help

Show help information.

```
EldenLOD help [command]
```

**Parameters:**
- `command` - Optional command to show detailed help for

**Examples:**
```
EldenLOD help
EldenLOD help extract
EldenLOD help full
```

## Operations

EldenLOD supports the following operations that can be invoked directly:

- `ExtractAll` - Extract all LOD files
- `ExtractSpecificModel` - Extract a specific model's LOD files
- `RepackAll` - Repack all modified LOD files
- `RepackSpecificModel` - Repack a specific model's LOD files
- `RepairTPF` - Repair a corrupted TPF file
- `ValidateExtraction` - Validate extracted files
- `ValidateRepack` - Validate repacked files

## Configuration

EldenLOD uses the following configuration file:

```
config/EldenLOD-schema.yaml
```

This file contains settings for paths, model definitions, and processing options.

## Log Files

Log files are stored in the `_logs` directory with the following naming convention:

```
_logs/EldenLOD-<operation>-<timestamp>.log
```

## Examples

### Basic LOD Extraction

```
EldenLOD extract
```

### Extract and Repack in One Command

```
EldenLOD full -Verbose
```

### Advanced Usage with Custom Paths

```
EldenLOD extract "S:\ELDEN RING\Game" -NoBak -Verbose
EldenLOD repack "C:\ModdingProjects\EldenRing\LOD" -Clean
```

## Troubleshooting

If you encounter issues, check the log files in the `_logs` directory for detailed error information.

Common issues:
- Game directory not found
- Missing file permissions
- Corrupted LOD files
- Insufficient disk space

## Version History

- v0.1-alpha (2025-05-30) - Initial release with basic functionality

## Credits

EldenLOD is developed and maintained by shinseiko.

## License

See the LICENSE file for details.
