<#
.SYNOPSIS
  Safely extracts, renumbers, and prepares Elden Ring LOD asset archives for modding.
  Ensures all LOD BNDs get injected with your modded TPF/FLVER, even if vanilla data 
  has different numbering, and extracts in the correct order so no step is skipped.

.PARAMETER partsDir
  Folder containing your working mod .partsbnd.dcx files.

.PARAMETER Execute
  Actually perform operations; otherwise dry-run/preview only.

.PARAMETER UnpackedGameDir
  Path to extracted vanilla files (e.g., from UXM). If not provided, script tries to guess based on partsDir or pulls from ENV.
#>
param(
    [string] $partsDir = (Get-Location).Path,
    [switch] $Execute,
    [string] $UnpackedGameDir = ""
)

# Import shared module 
$modulePath = Join-Path $PSScriptRoot 'EldenLOD.psm1'
Import-Module $modulePath -Force -ErrorAction Stop

# --- Setup and Log ---
try { $partsDir = Convert-Path -Path $partsDir -ErrorAction Stop }
catch { Write-Error "Invalid partsDir: '$partsDir'"; exit 1 }

if (-not $UnpackedGameDir -or -not (Test-Path $UnpackedGameDir)) {
    if ($env:UnpackedGameDir -and (Test-Path $env:UnpackedGameDir)) {
        $UnpackedGameDir = $env:UnpackedGameDir
    } else {
        # Only check current directory
        $parentDir = Split-Path $partsDir -Parent
        $guessDir = Join-Path $parentDir 'parts'
        if (Test-Path $guessDir) {
            $UnpackedGameDir = Split-Path $guessDir -Parent
        } else {
            Write-Warning "UnpackedGameDir not found. Please set `$env:UnpackedGameDir or provide -UnpackedGameDir parameter."
            exit 1
        }
    }
}

$vanillaPartsDir = Join-Path $UnpackedGameDir 'parts'
Write-Host "INFO: Using vanilla parts dir: $vanillaPartsDir"

$logDir = Join-Path $partsDir '_logs'
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logDir 'EldenLOD-Extract.log'
"[{0}] Starting EldenLOD-Extract.ps1 Execute={1}`n" -f (Timestamp), $Execute |
    Out-File -FilePath $logFile -Encoding UTF8 -Append

if (-not $Execute) { 
    Write-Warning 'DRY-RUN MODE: no changes will be made. Add -Execute to apply.'
    Write-Host "DRY-RUN will show you:"
    Write-Host "  - Which files would be renamed and why"
    Write-Host "  - Which XML references would be updated"
    Write-Host "  - Which archives would be repacked"
    Write-Host "  - Which directories would be cleaned up"
    Write-Host ""
}

# --- Main Processing ---
$modPrimaryBnds = Get-ChildItem -Path $partsDir -Filter '*.partsbnd.dcx' -File | Where-Object { $_.BaseName -notmatch '_L$' }

foreach ($bndFile in $modPrimaryBnds) {
    $base = $bndFile.Name -replace '\.partsbnd\.dcx$', ''
    $baseUpper = $base.ToUpper()
    $lodFile = "${base}_L.partsbnd.dcx"
    $modLodPath = Join-Path $partsDir $lodFile
    
    Write-Host "`n===== Processing: $($bndFile.Name) ====="
    Write-VerboseLog -message "Processing BND: $($bndFile.Name) -> Expected LOD: $lodFile" -logFile $logFile
    
    $renumbered = $false
    $tpfExtractDirs = @()

    # --- 1. Ensure LOD BND exists (copy vanilla if missing) ---
    if (!(Test-Path $modLodPath)) {
        $vanillaLodPath = Join-Path $vanillaPartsDir $lodFile
        if (Test-Path $vanillaLodPath) {
            Write-Host "Copying vanilla LOD BND: '$lodFile'"
            if ($Execute) {
                Copy-Item -Path $vanillaLodPath -Destination $modLodPath -Force
                Write-VerboseLog -message "Copied vanilla LOD: $vanillaLodPath -> $modLodPath" -logFile $logFile
            }
        } else {
            Write-Warning "Cannot find vanilla LOD BND: '$vanillaLodPath' - skipping."
            Write-LogMessage -message "Missing vanilla LOD BND: $vanillaLodPath" -logFile $logFile -isError
            continue
        }
    }

    # --- 2. Extract modded BND (skip if already extracted) ---
    $modExtractDir = Join-Path $partsDir ($base + '-partsbnd-dcx')
    if (!(Test-Path $modExtractDir)) {
        Write-Host "Extracting modded BND: '$($bndFile.Name)'"
        Write-VerboseLog -message "Starting BND extraction: $($bndFile.Name)" -logFile $logFile
        if ($Execute) {
            Push-Location $partsDir
            & witchybnd -u $bndFile.Name
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "ERROR: Failed to extract modded BND: $($bndFile.Name)"
                Write-LogMessage -message "BND extraction failed: $($bndFile.Name)" -logFile $logFile -isError
                Pop-Location
                continue
            }
            Pop-Location
        }
    } else {
        Write-Host "Modded BND already extracted: '$modExtractDir'"
        Write-VerboseLog -message "BND already extracted: $modExtractDir" -logFile $logFile
    }    # --- 3. Process TPFs: renumber, extract, and handle contents ---
    if (Test-Path $modExtractDir) {
        $tpfFiles = Get-ChildItem -Path $modExtractDir -Filter '*.tpf' -File
        foreach ($tpf in $tpfFiles) {
            # First ensure we're in the directory containing the TPF
            Push-Location $modExtractDir
            
            # Check if TPF needs renumbering based on BND container vs TPF contents
            if ($tpf.Name -match '^([A-Z]+_[A-Z]+)_([0-9]+)(.*)\.tpf$') {
                $tpfPrefix = $matches[1]
                $tpfCurrentNumber = $matches[2]
                $tpfSuffix = $matches[3]
                
                # Get expected number from the BND container name (e.g., "1800" from "HD_M_1800")
                $expectedNumber = $baseUpper -replace '^[A-Z]+_[A-Z]+_', ''
                  # Only rename if there's a mismatch between container and contents
                if ($tpfCurrentNumber -ne $expectedNumber) {
                    $newTpfName = "${tpfPrefix}_${expectedNumber}${tpfSuffix}.tpf"
                    if (-not $Execute) {
                        Write-Host "[DRY-RUN] Would rename TPF: '$($tpf.Name)' -> '$newTpfName'"
                        Write-Host "[DRY-RUN]   Container expects: $expectedNumber, TPF contains: $tpfCurrentNumber"
                        Write-Host "[DRY-RUN]   Would update BND4 XML references"
                    } else {
                        Write-Host "Container/Content mismatch - Renumbering TPF: '$($tpf.Name)' -> '$newTpfName'"
                        Write-Host "  Container expects: $expectedNumber, TPF contains: $tpfCurrentNumber"
                        
                        $oldPath = $tpf.FullName
                        $newPath = Join-Path $modExtractDir $newTpfName
                        if (Test-Path $newPath) { Remove-Item $newPath -Force }
                        Rename-Item -Path $oldPath -NewName $newTpfName -Force
                        $tpf = Get-Item $newPath # Update TPF reference to renamed file
                        $renumbered = $true
                        
                        # Update BND4 XML to reference the new TPF filename
                        $bndXmlFile = Join-Path $modExtractDir "_witchy-bnd4.xml"
                        if (Test-Path $bndXmlFile) {
                            $bndXmlContent = Get-Content $bndXmlFile -Raw
                            $oldTpfName = "${tpfPrefix}_${tpfCurrentNumber}${tpfSuffix}.tpf"
                            $newBndXml = $bndXmlContent -replace [regex]::Escape($oldTpfName), $newTpfName
                            if ($newBndXml -ne $bndXmlContent) {
                                Write-Host "Updating BND4 XML references: '$oldTpfName' -> '$newTpfName'"
                                $newBndXml | Set-Content -Path $bndXmlFile -Encoding UTF8 -NoNewline
                            }
                        }
                    }
                } else {
                    if (-not $Execute) {
                        Write-Host "[DRY-RUN] TPF numbering matches container - no renaming needed: '$($tpf.Name)'"
                    } else {
                        Write-Host "TPF numbering matches container - no renaming needed: '$($tpf.Name)'"
                    }
                }
            }
              # Now extract the TPF (witchybnd will create the -tpf directory and XML)
            if (-not $Execute) {
                Write-Host "[DRY-RUN] Would extract TPF: '$($tpf.Name)'"
            } else {
                Write-Host "Extracting TPF: '$($tpf.Name)'"
                Write-VerboseLog -message "Starting TPF extraction: $($tpf.Name)" -logFile $logFile
                
                & witchybnd -u $tpf.Name
            }
            
            $tpfExtractDir = Join-Path $modExtractDir ("$($tpf.BaseName)-tpf")
            
            if (($Execute -and $LASTEXITCODE -eq 0 -and (Test-Path $tpfExtractDir)) -or (-not $Execute)) {
                if ($Execute) {
                    Write-VerboseLog -message "TPF extracted: $($tpf.Name) -> $tpfExtractDir" -logFile $logFile
                }
                
                # Track for cleanup
                $tpfExtractDirs += $tpfExtractDir
                
                # Check if TPF is intentionally empty first
                if ($Execute -and (Test-TpfEmpty -tpfExtractDir $tpfExtractDir -logFile $logFile)) {
                    Write-Host "TPF is intentionally empty, skipping renumbering: '$($tpf.Name)'"
                    Write-VerboseLog -message "Skipped processing empty TPF: $($tpf.Name)" -logFile $logFile
                    continue
                } elseif (-not $Execute) {
                    Write-Host "[DRY-RUN] Would check if TPF is empty and skip if needed"
                }
                
                # Process DDS files using shared module function
                $expectedNumber = $baseUpper -replace '^[A-Z]+_[A-Z]+_', ''
                $ddsResult = Invoke-DdsRenumbering -tpfExtractDir $tpfExtractDir -expectedNumber $expectedNumber -logFile $logFile -Execute:$Execute -DryRun:(-not $Execute)
                
                if ($ddsResult.Renumbered) {
                    $renumbered = $true
                    
                    # Update TPF XML references using shared module function
                    if (Update-TpfXmlReferences -tpfExtractDir $tpfExtractDir -renamedFiles $ddsResult.RenamedFiles -expectedNumber $expectedNumber -logFile $logFile -Execute:$Execute -DryRun:(-not $Execute)) {
                        if (-not $Execute) {
                            Write-Host "[DRY-RUN] Would update TPF XML references"
                        }
                    }
                }
            } else {
                Write-Warning "Failed to extract TPF: $($tpf.Name)"
                Write-LogMessage -message "TPF extraction failed: $($tpf.Name)" -logFile $logFile -isError
            }
              Pop-Location
        }        # --- 4. Process other file types using shared module function ---
        if (Test-Path $modExtractDir) {
            # Get expected number from the BND container name (e.g., "1800" from "HD_M_1800")
            $expectedNumber = $baseUpper -replace '^[A-Z]+_[A-Z]+_', ''
            
            # Use shared module function for file renumbering (currentNumber will be auto-detected from files)
            $fileResult = Invoke-FileRenumbering -extractDir $modExtractDir -expectedNumber $expectedNumber -currentNumber "auto" -logFile $logFile -Execute:$Execute -DryRun:(-not $Execute)
            
            if ($fileResult.Renumbered) {
                $renumbered = $true
                
                # Update BND4 XML references using shared module function
                $bndXmlFile = Join-Path $modExtractDir "_witchy-bnd4.xml"
                if (Update-BndXmlReferences -bndXmlFile $bndXmlFile -renamedFiles $fileResult.RenamedFiles -logFile $logFile -Execute:$Execute -DryRun:(-not $Execute)) {
                    if (-not $Execute) {
                        Write-Host "[DRY-RUN] Would update BND4 XML references"
                    }
                }
            }
        }
    }    # If renumbered, repack the modded BND
    if ($renumbered -and $Execute) {
        # First repack all modified TPFs
        $tpfFiles = Get-ChildItem -Path $modExtractDir -Filter '*.tpf' -File
        foreach ($tpf in $tpfFiles) {
            $tpfExtractDir = Join-Path $modExtractDir ("$($tpf.BaseName)-tpf")
            if (Test-Path $tpfExtractDir) {
                Push-Location $modExtractDir
                Write-Host "Repacking modded TPF: '$($tpf.Name)'"
                & witchybnd -r $tpf.Name
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "ERROR: Failed to repack TPF: $($tpf.Name)"
                    $ts = Timestamp
                    "[$ts] ERROR repacking TPF: $($tpf.Name)" | Out-File -FilePath $logFile -Encoding UTF8 -Append
                }
                Pop-Location
                
                # Clean up the extract directory after successful repack
                if ($LASTEXITCODE -eq 0 -and (Test-Path $tpfExtractDir)) {
                    Remove-Item $tpfExtractDir -Recurse -Force
                }
            }
        }

        # Then repack the main BND
        Push-Location $partsDir
        Write-Host "Repacking modded BND: '$($bndFile.Name)'"
        & witchybnd -r ($base + '-partsbnd-dcx')
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "ERROR: Failed to repack modded BND: $($bndFile.Name)"
            $ts = Timestamp
            "[$ts] ERROR repacking modded BND: $($bndFile.Name)" | Out-File -FilePath $logFile -Encoding UTF8 -Append
            Pop-Location
            continue
        }
        Pop-Location
        
        # Clean up the modded extract directory after successful repack
        if (Test-Path $modExtractDir) {
            Remove-Item $modExtractDir -Recurse -Force
        }
    } elseif ($renumbered -and -not $Execute) {
        Write-Host "[DRY-RUN] Would repack modified TPFs and main BND due to renumbering"
        Write-Host "[DRY-RUN] Would clean up extracted directories after repacking"
    }    # --- 4. Extract LOD BND (skip if already extracted) ---
    $lodDir = Join-Path $partsDir ($lodFile -replace '\.partsbnd\.dcx$', '-partsbnd-dcx')
    if (!(Test-Path $lodDir)) {
        if (-not $Execute) {
            Write-Host "[DRY-RUN] Would extract LOD BND: '$lodFile'"
        } else {
            Write-Host "Extracting LOD BND: '$lodFile'"
            Write-VerboseLog -message "Starting LOD BND extraction: $lodFile" -logFile $logFile
            
            Push-Location $partsDir
            & witchybnd -u $lodFile
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "ERROR: Failed to extract LOD BND: $lodFile"
                Write-LogMessage -message "LOD BND extraction failed: $lodFile" -logFile $logFile -isError
                Pop-Location
                continue
            }
            Pop-Location
        }
    } else {
        if (-not $Execute) {
            Write-Host "[DRY-RUN] LOD BND already extracted: '$lodDir'"
        } else {
            Write-Host "LOD BND already extracted: '$lodDir'"
            Write-VerboseLog -message "LOD BND already extracted: $lodDir" -logFile $logFile
        }
    }    # --- 5. Copy modded files to LOD directory ---
    if (($Execute -and (Test-Path $lodDir)) -or (-not $Execute)) {
        if ((Test-Path $modExtractDir) -or (-not $Execute)) {
            if (-not $Execute) {
                Write-Host "[DRY-RUN] Would copy modded files to LOD directory"
                if (Test-Path $modExtractDir) {
                    $modFiles = Get-ChildItem -Path $modExtractDir -File
                    foreach ($modFile in $modFiles) {
                        Write-Host "[DRY-RUN]   Would copy: '$($modFile.Name)'"
                    }
                }
            } else {
                $modFiles = Get-ChildItem -Path $modExtractDir -File
                foreach ($modFile in $modFiles) {
                    $destPath = Join-Path $lodDir $modFile.Name
                    Write-Host "Copying modded file to LOD: '$($modFile.Name)'"
                    Copy-Item -Path $modFile.FullName -Destination $destPath -Force
                    Write-VerboseLog -message "Copied to LOD: $($modFile.Name)" -logFile $logFile
                }
            }
        }
    }    # --- 6. Add _L suffix to LOD TPF files ---
    if ((Test-Path $lodDir) -or (-not $Execute)) {
        if (-not $Execute) {
            Write-Host "[DRY-RUN] Would process LOD TPF files to add _L suffix"
            if (Test-Path $lodDir) {
                $lodTpfFiles = Get-ChildItem -Path $lodDir -Filter '*.tpf' -File | Where-Object { $_.Name -notmatch '_L\.tpf$' }
                foreach ($lodTpf in $lodTpfFiles) {
                    $newLodName = $lodTpf.Name -replace '\.tpf$', '_L.tpf'
                    Write-Host "[DRY-RUN]   Would rename: '$($lodTpf.Name)' -> '$newLodName'"
                    Write-Host "[DRY-RUN]   Would extract and add _L suffix to DDS files"
                    Write-Host "[DRY-RUN]   Would update LOD XML references"
                    Write-Host "[DRY-RUN]   Would repack LOD TPF"
                }
            }
        } else {
            $lodTpfFiles = Get-ChildItem -Path $lodDir -Filter '*.tpf' -File | Where-Object { $_.Name -notmatch '_L\.tpf$' }
            foreach ($lodTpf in $lodTpfFiles) {
                $newLodName = $lodTpf.Name -replace '\.tpf$', '_L.tpf'
                Write-Host "Adding _L suffix to LOD TPF: '$($lodTpf.Name)' -> '$newLodName'"
                
                $newLodPath = Join-Path $lodDir $newLodName
                if (Test-Path $newLodPath) { Remove-Item $newLodPath -Force }
                Rename-Item -Path $lodTpf.FullName -NewName $newLodName -Force
                Write-VerboseLog -message "Renamed LOD TPF: $($lodTpf.Name) -> $newLodName" -logFile $logFile
                
                # Extract the renamed LOD TPF to add _L suffix to DDS files
                Push-Location $lodDir
                & witchybnd -u $newLodName
                $lodTpfExtractDir = Join-Path $lodDir ("$([IO.Path]::GetFileNameWithoutExtension($newLodName))-tpf")
                
                if ($LASTEXITCODE -eq 0 -and (Test-Path $lodTpfExtractDir)) {
                    # Check if TPF is intentionally empty
                    if (Test-TpfEmpty -tpfExtractDir $lodTpfExtractDir -logFile $logFile) {
                        Write-Host "LOD TPF is intentionally empty, skipping _L suffix processing: '$newLodName'"
                        Write-VerboseLog -message "Skipped _L processing for empty LOD TPF: $newLodName" -logFile $logFile
                    } else {
                        # Add _L suffix to DDS files inside LOD TPF
                        $lodDdsFiles = Get-ChildItem -Path $lodTpfExtractDir -Filter '*.dds' -File | Where-Object { $_.Name -notmatch '_L\.dds$' }
                        foreach ($lodDds in $lodDdsFiles) {
                            $newLodDdsName = $lodDds.Name -replace '\.dds$', '_L.dds'
                            Write-Host "Adding _L suffix to LOD DDS: '$($lodDds.Name)' -> '$newLodDdsName'"
                            Rename-Item -Path $lodDds.FullName -NewName $newLodDdsName -Force
                        }
                        
                        # Update XML to reference _L.dds files
                        $lodXmlFiles = Get-ChildItem -Path $lodTpfExtractDir -Filter '*-tpf.xml' -File
                        if ($lodXmlFiles.Count -eq 0) {
                            $lodXmlFiles = Get-ChildItem -Path $lodTpfExtractDir -Filter 'witchy-tpf.xml' -File
                        }
                        
                        foreach ($lodXml in $lodXmlFiles) {
                            $lodXmlContent = Get-Content $lodXml.FullName -Raw
                            $newLodXml = $lodXmlContent -replace '<n>([^<>]+?)\.dds</n>', '<n>$1_L.dds</n>'
                            
                            if ($newLodXml -ne $lodXmlContent) {
                                Write-Host "Updating LOD XML references to _L.dds: '$($lodXml.Name)'"
                                $newLodXml | Set-Content -Path $lodXml.FullName -Encoding UTF8 -NoNewline
                                Write-VerboseLog -message "Updated LOD XML: $($lodXml.Name)" -logFile $logFile
                            }
                        }
                    }
                    
                    # Repack the LOD TPF
                    & witchybnd -r $newLodName
                    if ($LASTEXITCODE -eq 0 -and (Test-Path $lodTpfExtractDir)) {
                        Remove-Item $lodTpfExtractDir -Recurse -Force
                    }
                }
                Pop-Location
            }
        }
    }    # Clean up extracted modded directory if not needed for repacking
    if (!$renumbered -and $Execute -and (Test-Path $modExtractDir)) {
        Write-Host "Cleaning up modded extract directory: '$modExtractDir'"
        Remove-Item $modExtractDir -Recurse -Force
        Write-VerboseLog -message "Cleaned up extract dir: $modExtractDir" -logFile $logFile
    } elseif (!$renumbered -and -not $Execute) {
        Write-Host "[DRY-RUN] Would clean up modded extract directory if no renumbering occurred"
    }
}

if (-not $Execute) {
    Write-Host "`n[DRY-RUN] Processing complete! Re-run with -Execute to apply changes."
} else {
    Write-Host "`nProcessing complete!"
}
Write-VerboseLog -message "EldenLOD-Extract.ps1 processing complete" -logFile $logFile