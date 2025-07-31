<#
.SYNOPSIS
    Repack all extracted LOD directories into .partsbnd.dcx files for Elden Ring mods, repacking TPFs individually.
.DESCRIPTION
    - For each *-partsbnd-dcx directory in $partsDir:
        - Cleans up .bak files and extraneous content.
        - Finds *_L.tpf and its extracted *_L-tpf subdirectory.
        - Repacks the TPF from *_L-tpf using WitchyBND (-r, NOT recursive).
        - Deletes the *_L-tpf directory after repacking the TPF.
        - Repacks the LOD BND itself using WitchyBND (-r, NOT recursive).
.PARAMETER partsDir
    Folder containing all your extracted LOD folders (*-partsbnd-dcx).
.PARAMETER Execute
    Actually performs operations. If not set, shows a dry-run only.
#>

param(
    [string] $partsDir = (Get-Location).Path,
    [switch] $Execute,
    [switch] $NoRenumber
)

# Import shared module
$modulePath = Join-Path $PSScriptRoot 'EldenLOD.psm1'
Import-Module $modulePath -Force -ErrorAction Stop

# 1. Verify $partsDir exists
try {
    $partsDir = Convert-Path -Path $partsDir -ErrorAction Stop
} catch {
    Write-Error "Invalid partsDir: '$partsDir'. Please specify an existing folder."
    exit 1
}

# 2. Setup log
$logDir = Join-Path $partsDir '_logs'
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}
$logFile = Join-Path $logDir 'Repack-LOD.log'
"[{0}] Starting Repack-LOD.ps1 Execute={1}`n" -f (Timestamp), $Execute |
    Out-File -FilePath $logFile -Encoding UTF8 -Append

if (-not $Execute) {
    Write-Warning 'DRY-RUN MODE: no changes will be made. Add -Execute to apply.'
}

# 3. Main process loop
$lodDirs = Get-ChildItem -Path $partsDir -Directory | Where-Object { $_.Name -like '*_L-partsbnd-dcx' }

foreach ($lodDirItem in $lodDirs) {
    $lodDir = $lodDirItem.FullName
    $bndBase = $lodDirItem.Name -replace '_L-partsbnd-dcx$', ''
    $bndLName = "${bndBase}_L.partsbnd.dcx"

    Write-Host "`n===== Processing $($lodDirItem.Name) ====="

    # Enhanced logging for better traceability
    Write-Verbose "Processing LOD directory: $lodDir" | Out-File -FilePath $logFile -Encoding UTF8 -Append

    # --- Remove vanilla FLVER and TPF files if they exist ---
    if ($Execute -and (Test-Path $lodDir)) {
        $vanillaFlver = Get-ChildItem -Path $lodDir -Filter "*.flver" | Where-Object { $_.Name -like "*_L.flver" } | Select-Object -First 1
        if ($vanillaFlver) {
            Write-Host "Removing vanilla mesh: '$($vanillaFlver.Name)'"
            Remove-Item $vanillaFlver.FullName -Force
        }
        
        $vanillaTpf = Get-ChildItem -Path $lodDir -Filter "*.tpf" | Where-Object { $_.Name -like "*_L.tpf" } | Select-Object -First 1
        if ($vanillaTpf) {
            Write-Host "Removing vanilla TPF: '$($vanillaTpf.Name)'"
            Remove-Item $vanillaTpf.FullName -Force
        }
    }

    # Log vanilla file removal
    if ($vanillaFlver) {
        Write-Host "[LOG] Removed vanilla FLVER: $($vanillaFlver.Name)" | Out-File -FilePath $logFile -Encoding UTF8 -Append
    }
    if ($vanillaTpf) {
        Write-Host "[LOG] Removed vanilla TPF: $($vanillaTpf.Name)" | Out-File -FilePath $logFile -Encoding UTF8 -Append
    }

    # --- Copy modded mesh from regular modded extract dir into LOD dir, renaming to *_L.flver ---
    $modExtractDir = Join-Path $partsDir ("${bndBase}-partsbnd-dcx")
    $modFlver = Get-ChildItem -Path $modExtractDir -Filter "${bndBase}.flver" -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($modFlver) {
        $lodFlverName = "${bndBase}_L.flver"
        $lodFlverPath = Join-Path $lodDir $lodFlverName
        Write-Host "Copying modded mesh to LOD: '$($modFlver.Name)' -> '$lodFlverName'"
        Copy-Item -Path $modFlver.FullName -Destination $lodFlverPath -Force
    } else {
        Write-Host "No modded mesh found to port to LOD for $bndBase."
    }

    # Log modded file copying
    if ($modFlver) {
        Write-Host "[LOG] Copied modded FLVER to LOD: $($modFlver.Name) -> $lodFlverName" | Out-File -FilePath $logFile -Encoding UTF8 -Append
    } else {
        Write-Host "[LOG] No modded FLVER found for $bndBase" | Out-File -FilePath $logFile -Encoding UTF8 -Append
    }

    Write-Host "`n===== Processing $($lodDirItem.Name) ====="

    # --- Clean .bak and junk files in LOD dir before packing ---
    $cruft = Get-ChildItem -Path $lodDir -Recurse -Include '*.bak', '*.tmp', '*~', '*.old'
    foreach ($file in $cruft) {
        if ($Execute) {
            Write-Host "Deleting cruft: $($file.FullName)"
            Remove-Item $file.FullName -Force
            $ts = Timestamp
            "[$ts] Deleted cruft: $($file.FullName)" | Out-File -FilePath $logFile -Encoding UTF8 -Append
        } else {
            Write-Host "Would delete cruft: $($file.FullName)"
        }
    }

    # --- Find and process TPF files, ensuring ALL content is preserved with proper LOD naming ---
    $tpfName = "${bndBase}_L.tpf"
    $tpfFile = Get-ChildItem -Path $lodDir -Filter $tpfName -File | Select-Object -First 1
    
    # Find original TPF for content preservation - handle case-insensitively
    $originalTpfName = $bndBase -replace '_L$', '' -replace '_l$', ''
    
    # Look for the original TPF directory with proper casing
    $originalTpfDir = Get-ChildItem -Path $partsDir -Directory | 
        Where-Object { $_.Name -like "$($originalTpfName)-partsbnd-dcx" } |
        Select-Object -First 1 |
        ForEach-Object { $_.FullName }
        
    if (-not $originalTpfDir) {
        Write-Warning "Could not find original TPF directory for content preservation"
        return
    }
    
    $originalTpfExtractDir = Get-ChildItem -Path $originalTpfDir -Directory | 
        Where-Object { $_.Name -like "*-tpf" } |
        Select-Object -First 1 |
        ForEach-Object { $_.FullName }
        
    if ($tpfFile) {
        $tpfExtractDir = Join-Path $lodDir ($tpfFile.BaseName + '-tpf')
        
        # If we have the original TPF extracted, copy its contents first
        if ($originalTpfExtractDir) {
            Write-Host "Found original TPF extracted at: $originalTpfExtractDir"
            
            if (-not (Test-Path $tpfExtractDir)) {
                New-Item -Path $tpfExtractDir -ItemType Directory -Force | Out-Null
            }
            
            # First, copy the XML metadata
            $xmlFiles = Get-ChildItem -Path $originalTpfExtractDir -Filter "*witchy-tpf.xml"
            foreach ($xml in $xmlFiles) {
                Copy-Item -Path $xml.FullName -Destination (Join-Path $tpfExtractDir "_witchy-tpf.xml") -Force
            }
            
            # Now copy and rename DDS files based on NoRenumber setting
            Get-ChildItem -Path $originalTpfExtractDir -Filter "*.dds" | ForEach-Object {
                $targetName = if ($NoRenumber) {
                    # Keep original name for non-renumbering
                    $_.Name
                } else {
                    # Add _L suffix before .dds
                    $_.Name -replace '\.dds$', '_L.dds'
                }
                
                Write-Host "Copying $($_.Name) -> $targetName"
                Copy-Item -Path $_.FullName -Destination (Join-Path $tpfExtractDir $targetName) -Force
            }
        } else {
            Write-Warning "Could not find original TPF extracted directory in: $originalTpfDir"
        }
        
        if (Test-Path $tpfExtractDir) {            # Validate and repack TPF
            if ($Execute) {
                # Always use NoRenumber for TPF repacking to preserve content
                if (Invoke-TpfRepack -tpfPath $tpfFile.FullName -tpfDir $tpfExtractDir -logFile $logFile -NoRenumber:$true) {
                    Write-Host "Successfully repacked TPF: '$($tpfFile.Name)'"

                    # Remove the extracted *-tpf dir after repacking!
                    Write-Host "Deleting extracted TPF dir: '$($tpfExtractDir)'"
                    Remove-Item $tpfExtractDir -Recurse -Force
                    $ts = Timestamp
                    "[$ts] Deleted extracted TPF dir: $($tpfExtractDir)" | Out-File -FilePath $logFile -Encoding UTF8 -Append
                } else {
                    Write-Host "Would repack TPF: '$($tpfFile.Name)' and delete '$($tpfExtractDir)'"
                }
            }
        } else {
            Write-Host "No extracted *-tpf dir to repack for '$($tpfFile.Name)'."
        }
    } else {
        Write-Warning "No $tpfName found in '$lodDir'!"
        $ts = Timestamp
        "[$ts] No $tpfName in $lodDir" | Out-File -FilePath $logFile -Encoding UTF8 -Append
    }

    # --- Clean again for cruft (in case *-tpf or .bak files still exist) ---
    $cruft2 = Get-ChildItem -Path $lodDir -Recurse -Include '*.bak', '*.tmp', '*~', '*.old'
    foreach ($file in $cruft2) {
        if ($Execute) {
            Write-Host "Deleting cruft: $($file.FullName)"
            Remove-Item $file.FullName -Force
            $ts = Timestamp
            "[$ts] Deleted cruft: $($file.FullName)" | Out-File -FilePath $logFile -Encoding UTF8 -Append
        } else {
            Write-Host "Would delete cruft: $($file.FullName)"
        }
    }


    # --- Optionally skip renumbering if -NoRenumber is set ---
    if ($NoRenumber) {
        Write-Host "Skipping internal renumbering due to -NoRenumber switch."
    } else {
        # Place any renumbering logic here if it exists in this script
        # If renumbering is handled in called functions, this block may be empty
    }

    # --- Repack the BND directory into *_L.partsbnd.dcx, preserving all content ---
    if ($Execute) {
        Push-Location $lodDir
        Write-Host "Repacking: '$($bndLName)' from '$($lodDir)'"
        
        # Create links/copies for WitchyBND to handle both LOD and non-LOD naming
        $tempFiles = @()
        if ($tpfFile) {
            # Create non-LOD version for compatibility
            $nonLodName = $tpfFile.Name -replace '_L\.tpf$', '.tpf'
            $tempTpf = Join-Path $lodDir $nonLodName
            Write-Host "Creating temporary TPF copy: '$nonLodName'"
            Copy-Item -Path $tpfFile.FullName -Destination $tempTpf -Force
            $tempFiles += $tempTpf
        }
        
        # Perform the repack
        Write-Host "Repacking BND..."
        & witchybnd -r $lodDir
        $repackResult = $LASTEXITCODE
        
        # Clean up temporary TPF
        if ($tempTpf -and (Test-Path $tempTpf)) {
            Write-Host "Cleaning up temporary TPF: '$tempTpf'"
            Remove-Item $tempTpf -Force
        }
        
        if ($repackResult -ne 0) {
            Write-Warning "ERROR: witchybnd failed for '$bndLName'"
            $ts = Timestamp
            "[$ts] ERROR repacking $bndLName" | Out-File -FilePath $logFile -Encoding UTF8 -Append
        } else {
            $ts = Timestamp
            "[$ts] Repacked: $bndLName" | Out-File -FilePath $logFile -Encoding UTF8 -Append
            
            # Clean up the extracted BND directory after successful repack
            Pop-Location  # Need to move out of the directory before deleting it
            if (Test-Path $lodDir) {
                Write-Host "Cleaning up extracted BND directory: '$lodDir'"
                Remove-Item $lodDir -Recurse -Force
                $ts = Timestamp
                "[$ts] Cleaned up: $lodDir" | Out-File -FilePath $logFile -Encoding UTF8 -Append
            }
        }
        if (-not $repackResult -eq 0) {
            Pop-Location  # Only pop if we failed, otherwise already done above
        }
    } else {
        Write-Host "Would repack BND dir: '$($lodDir)' into '$($bndLName)'"
    }
}

# --- Update extracted TPF files and XML metadata for LOD naming ---
if ($tpfFile) {
    $tpfExtractDir = Join-Path $lodDir ($tpfFile.BaseName + '-tpf')

    if (Test-Path $tpfExtractDir) {
        # Rename DDS files with _L suffix
        Get-ChildItem -Path $tpfExtractDir -Filter "*.dds" | ForEach-Object {
            $newName = $_.Name -replace '\.dds$', '_L.dds'
            $newPath = Join-Path $tpfExtractDir $newName
            Rename-Item -Path $_.FullName -NewName $newPath -Force
            Write-Host "Renamed: $($_.Name) -> $newName"
        }

        # Update XML metadata to reflect _L naming
        $xmlFiles = Get-ChildItem -Path $tpfExtractDir -Filter "*_witchy-tpf.xml"
        foreach ($xml in $xmlFiles) {
            (Get-Content -Path $xml.FullName) -replace '(?<=<File>)(.*?)(?=\.dds<\/File>)', { $_ + '_L' } |
                Set-Content -Path $xml.FullName -Force
            Write-Host "Updated XML metadata: $($xml.Name)"
        }
    } else {
        Write-Warning "No extracted TPF directory found for: $($tpfFile.Name)"
    }
}

# After all LOD repacks, clean up modded extract directories
if ($Execute) {
    $modExtractDirs = Get-ChildItem -Path $partsDir -Directory | Where-Object { $_.Name -like '*-partsbnd-dcx' -and $_.Name -notlike '*_L-partsbnd-dcx' }
    foreach ($dir in $modExtractDirs) {
        if (Test-Path $dir.FullName) {
            Write-Host "Cleaning up modded extract directory: '$($dir.FullName)'"
            Remove-Item $dir.FullName -Recurse -Force
            $ts = Timestamp
            "[$ts] Cleaned up modded extract directory: $($dir.FullName)" | Out-File -FilePath $logFile -Encoding UTF8 -Append
        }
    }
    Write-Host "`nExecute complete."
    $ts = Timestamp
    "[$ts] Execute complete.`n" | Out-File -FilePath $logFile -Encoding UTF8 -Append
} else {
    Write-Host "`nDry-run complete."
    $ts = Timestamp
    "[$ts] Dry-run complete.`n" | Out-File -FilePath $logFile -Encoding UTF8 -Append
}
Write-Host "Log written to: $logFile"
Write-Host "You can now check the log file for details: $logFile"
Write-Host "Thank you for using Elden LOD!"
# End of script
# -----------------------------------------------------------------------------