<#
.SYNOPSIS
  Safely extracts, renumbers, and prepares Elden Ring LOD asset archives for modding.
  Ensures all LOD BNDs get injected with your modded TPF/FLVER, even if vanilla d                # Update XMLs if we renamed files
                if ($needsRepack) {
                    $xmlFiles = Get-ChildItem -Path $tpfExtractDir -Filter '*.xml' -File
                    foreach ($xml in $xmlFiles) {
                        $xmlContent = Get-Content $xml.FullName -Raw
                        
                        # More precise XML update to handle all numbering cases
                        $targetNumber = $baseUpper -replace '^[A-Z]+_[A-Z]+_', ''
                        $newXml = $xmlContent -replace '<n>([A-Z]+_[A-Z]+)_[0-9]+([^<>]+\.dds)<\/n>', "<n>`$1_$targetNumber`$2</n>"
                        
                        if ($newXml -ne $xmlContent) {
                            Write-Host "Patching XML: '$($xml.Name)' (updating file numbers to $targetNumber)"
                            Write-VerboseLog -message "TPF XML update: $($xml.Name) (Number: $targetNumber)" -logFile $logFile
                            if ($Execute) {
                                $newXml | Set-Content -Path $xml.FullName -Encoding UTF8 -NoNewline
                            }
                        }
                    } them,
  and extracts in the correct order so no step is skipped or deleted early.

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
        $localUnpackedGame = Join-Path $partsDir 'UnpackedGame'
        
        if (Test-Path $localUnpackedGame) { 
            $UnpackedGameDir = $localUnpackedGame
        }
        else {
            Write-Error "No UnpackedGame directory found in '$partsDir'. Please specify -UnpackedGameDir or set UnpackedGameDir environment variable."
            exit 1
        }
    }
}

$vanillaPartsDir = Join-Path $UnpackedGameDir 'parts'
Write-Host "INFO: Using vanilla parts dir: $vanillaPartsDir"

$logDir = Join-Path $partsDir '_logs'
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logDir 'Extract-And-Patch-LOD.log'
"[{0}] Starting Extract-And-Patch-LOD.ps1 Execute={1}`n" -f (Timestamp), $Execute |
    Out-File -FilePath $logFile -Encoding UTF8 -Append

if (-not $Execute) { Write-Warning 'DRY-RUN MODE: no changes will be made. Add -Execute to apply.' }

# Track TPF extract directories for delayed cleanup
$tpfExtractDirs = @()

# --- Main Processing Loop ---
$modPrimaryBnds = Get-ChildItem -Path $partsDir -Filter '*.partsbnd.dcx' -File | Where-Object { $_.BaseName -notmatch '_L$' }

$totalBnds = $modPrimaryBnds.Count
$currentBnd = 0

foreach ($bndFile in $modPrimaryBnds) {
    $currentBnd++
    $progress = [math]::Round(($currentBnd / $totalBnds) * 100)
    Write-Progress -Activity "Processing BNDs" -Status "$($bndFile.Name)" -PercentComplete $progress
    
    $base = $bndFile.Name -replace '\.partsbnd\.dcx$', ''
    $baseUpper = $base.ToUpper()
    if ($base -notmatch '_L$') {
        $lodFile = "${base}_L.partsbnd.dcx"
    } else {
        $lodFile = "${base}.partsbnd.dcx"
    }
    $modLodPath = Join-Path $partsDir $lodFile
    $renumbered = $false

    # --- 1. Ensure LOD BND is present (copy vanilla if missing) ---
    if (!(Test-Path $modLodPath)) {
        $vanillaLodPath = Join-Path $vanillaPartsDir $lodFile
        if (Test-Path $vanillaLodPath) {
            if ($Execute) {
                Write-Host "Copying vanilla $lodFile from $vanillaPartsDir"
                Copy-Item $vanillaLodPath $modLodPath -Force
            } else {
                Write-Host "WhatIf: would copy vanilla $lodFile from $vanillaPartsDir"
            }
            $ts = Timestamp
            "[$ts] Copied vanilla $lodFile" | Out-File -FilePath $logFile -Encoding UTF8 -Append
        } else {
            Write-Warning "Missing both modded and vanilla $lodFile. Skipping."
            $ts = Timestamp
            "[$ts] Missing both modded and vanilla $lodFile" | Out-File -FilePath $logFile -Encoding UTF8 -Append
            continue
        }
    }

    # --- 2. Extract modded BND (not recursive) if not already extracted ---
    $modExtractDir = Join-Path $partsDir ($base + '-partsbnd-dcx')
    if ($Execute -and !(Test-Path $modExtractDir)) {
        Push-Location $partsDir
        Write-Host "Extracting modded: '$($bndFile.Name)' -> '$modExtractDir'"
        & witchybnd -u $($bndFile.Name)
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path $modExtractDir)) {
            Write-Warning "ERROR: WitchyBND failed to extract modded BND or directory missing: $modExtractDir"
            $ts = Timestamp
            "[$ts] ERROR extracting $($bndFile.Name) or missing extract dir" | Out-File -FilePath $logFile -Encoding UTF8 -Append
            Pop-Location
            continue
        }
        Pop-Location
    }    # --- 3. Process TPFs: renumber, extract, and handle contents ---
    if (Test-Path $modExtractDir) {
        $tpfFiles = Get-ChildItem -Path $modExtractDir -Filter '*.tpf' -File
        foreach ($tpf in $tpfFiles) {
            # First ensure we're in the directory containing the TPF
            Push-Location $modExtractDir            # Check if TPF needs renumbering based on BND container vs TPF contents
            if ($tpf.Name -match '^([A-Z]+_[A-Z]+)_([0-9]+)(.*)\.tpf$') {
                $tpfPrefix = $matches[1]
                $tpfCurrentNumber = $matches[2]
                $tpfSuffix = $matches[3]
                
                # Get expected number from the BND container name (e.g., "1800" from "HD_M_1800")
                $expectedNumber = $baseUpper -replace '^[A-Z]+_[A-Z]+_', ''
                
                # Only rename if there's a mismatch between container and contents
                if ($tpfCurrentNumber -ne $expectedNumber) {
                    $newTpfName = "${tpfPrefix}_${expectedNumber}${tpfSuffix}.tpf"
                    Write-Host "Container/Content mismatch - Renumbering TPF: '$($tpf.Name)' -> '$newTpfName'"
                    Write-Host "  Container expects: $expectedNumber, TPF contains: $tpfCurrentNumber"
                    if ($Execute) {
                        $oldPath = $tpf.FullName
                        $newPath = Join-Path $modExtractDir $newTpfName
                        if (Test-Path $newPath) { Remove-Item $newPath -Force }
                        Rename-Item -Path $oldPath -NewName $newTpfName -Force
                        $tpf = Get-Item $newPath # Update TPF reference to renamed file
                        $needsRepack = $true
                        $renumbered = $true
                    }
                } else {
                    Write-Host "TPF numbering matches container - no renaming needed: '$($tpf.Name)'"
                }
            }
            
            # Now extract the TPF (witchybnd will create the -tpf directory and XML)
            Write-Host "Extracting TPF: '$($tpf.Name)'"
            Write-VerboseLog -message "Starting TPF extraction: $($tpf.Name)" -logFile $logFile
            
            & witchybnd -u $tpf.Name
            $tpfExtractDir = Join-Path $modExtractDir ("$($tpf.BaseName)-tpf")
              if ($LASTEXITCODE -eq 0 -and (Test-Path $tpfExtractDir)) {
                Write-VerboseLog -message "TPF extracted: $($tpf.Name) -> $tpfExtractDir" -logFile $logFile
                
                # Track for cleanup
                $tpfExtractDirs += $tpfExtractDir
                
                # Check if TPF is intentionally empty first
                if (Test-TpfEmpty -tpfExtractDir $tpfExtractDir -logFile $logFile) {
                    Write-Host "TPF is intentionally empty, skipping renumbering: '$($tpf.Name)'"
                    Write-VerboseLog -message "Skipped processing empty TPF: $($tpf.Name)" -logFile $logFile
                    continue
                }
                  # Process DDS files inside TPF - only rename if numbers don't match container
                foreach ($dds in $ddsFiles) {
                    if ($dds.Name -match '^([A-Z]+_[A-Z]+)_([0-9]+)(.+\.dds)$') {
                        $ddsPrefix = $matches[1]
                        $ddsCurrentNumber = $matches[2]
                        $ddsSuffix = $matches[3]
                        
                        # Get expected number from container BND
                        $expectedNumber = $baseUpper -replace '^[A-Z]+_[A-Z]+_', ''
                        
                        # Only rename if there's a mismatch
                        if ($ddsCurrentNumber -ne $expectedNumber) {
                            $needsRepack = $true
                            $newDdsName = "${ddsPrefix}_${expectedNumber}${ddsSuffix}"
                            Write-Host "Container/Content mismatch - Renumbering DDS: '$($dds.Name)' -> '$newDdsName'"
                            Write-Host "  Container expects: $expectedNumber, DDS contains: $ddsCurrentNumber"
                            if ($Execute) {
                                $oldPath = $dds.FullName
                                $newPath = Join-Path $tpfExtractDir $newDdsName
                                if (Test-Path $newPath) { Remove-Item $newPath -Force }
                                Rename-Item -Path $oldPath -NewName $newDdsName -Force
                            }
                        } else {
                            Write-Host "DDS numbering matches container - no renaming needed: '$($dds.Name)'"
                        }
                    }
                }

                # Update XML references if needed
                if ($needsRepack) {
                    $xmlFiles = Get-ChildItem -Path $tpfExtractDir -Filter '*.xml' -File
                    foreach ($xml in $xmlFiles) {
                        $xmlContent = Get-Content $xml.FullName -Raw
                        $targetNumber = $baseUpper -replace '^[A-Z]+_[A-Z]+_', ''
                        $newXml = $xmlContent -replace '<n>([A-Z]+_[A-Z]+)_[0-9]+([^<>]+\.dds)<\/n>', "<n>`$1_${targetNumber}`$2</n>"
                        
                        if ($newXml -ne $xmlContent) {
                            Write-Host "Patching XML: '$($xml.Name)' (updating file numbers to $targetNumber)"
                            Write-VerboseLog -message "TPF XML update: $($xml.Name) (Number: $targetNumber)" -logFile $logFile
                            if ($Execute) {
                                $newXml | Set-Content -Path $xml.FullName -Encoding UTF8 -NoNewline
                            }
                        }
                    }
                }
            } else {
                Write-Warning "Failed to extract TPF: $($tpf.Name)"
                Write-LogMessage -message "TPF extraction failed: $($tpf.Name)" -logFile $logFile -isError
            }
            
            Pop-Location
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
        }# Then repack the main BND
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

        # Create LOD dir if needed
        if (-not (Test-Path $lodDir)) {
            New-Item -Path $lodDir -ItemType Directory -Force | Out-Null
        }

        # NOW move files to LOD dir
        $packedFlver = Get-ChildItem -Path $modExtractDir -Filter '*.flver' -File | Select-Object -First 1
        $packedTpf   = Get-ChildItem -Path $modExtractDir -Filter '*.tpf'   -File | Select-Object -First 1
        if ($packedFlver) {
            $flverDest = Join-Path $lodDir ("$baseUpper`_L.flver")
            Write-Host "Moving FLVER to LOD: '$($packedFlver.Name)' -> '$([IO.Path]::GetFileName($flverDest))'"
            Move-Item $packedFlver.FullName $flverDest -Force
        }
        if ($packedTpf) {
            $tpfDest = Join-Path $lodDir ("$baseUpper`_L.tpf") 
            Write-Host "Moving TPF to LOD: '$($packedTpf.Name)' -> '$([IO.Path]::GetFileName($tpfDest))'"
            Move-Item $packedTpf.FullName $tpfDest -Force
            
            # Extract copied TPF in LOD dir
            Push-Location $lodDir
            & witchybnd -u $([IO.Path]::GetFileName($tpfDest))
            Pop-Location
        }

        # Clean up extracted dirs
        Remove-Item $modExtractDir -Recurse -Force
    }

    # --- 4. Extract/copy vanilla LOD BND as needed ---
    $lodDir = Join-Path $partsDir ($lodFile -replace '\.partsbnd\.dcx$', '-partsbnd-dcx')
    if ($Execute) {
        Push-Location $partsDir
        Write-Host "Extracting: '$lodFile' -> '$lodDir' (not recursive)"
        & witchybnd -u $lodFile
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path $lodDir)) {
            Write-Warning "ERROR: witchybnd failed on '$lodFile'"
            $ts = Timestamp
            "[$ts] ERROR extracting $lodFile" | Out-File -FilePath $logFile -Encoding UTF8 -Append
            Pop-Location
            continue
        }
        $ts = Timestamp
        "[$ts] Extracted: $lodFile" | Out-File -FilePath $logFile -Encoding UTF8 -Append
        Pop-Location
    } else {
        Write-Host "WhatIf: would extract '$lodFile' -> '$lodDir' (not recursive)"
    }

    # --- 5. Copy modded FLVER/TPF to LOD dir as _L.flver / _L.tpf, and extract the TPF in place ---
    if ($Execute -and (Test-Path $lodDir)) {
        $modFlver = Get-ChildItem -Path $partsDir -Filter "$base.flver" -File | Select-Object -First 1
        $modTpf = Get-ChildItem -Path $partsDir -Filter "$base.tpf" -File | Select-Object -First 1
        if ($modFlver) {
            $destFlver = Join-Path $lodDir ("$baseUpper`_L.flver")
            Write-Host "Copying modded FLVER: '$($modFlver.Name)' -> '$([IO.Path]::GetFileName($destFlver))'"
            Copy-Item $modFlver.FullName $destFlver -Force
        }
        if ($modTpf) {
            $destTpf = Join-Path $lodDir ("$baseUpper`_L.tpf")
            Write-Host "Copying modded TPF: '$($modTpf.Name)' -> '$([IO.Path]::GetFileName($destTpf))'"
            Copy-Item $modTpf.FullName $destTpf -Force
            # Extract copied TPF in-place (not recursive) for LOD DDS renaming
            Push-Location $lodDir
            & witchybnd -u $([IO.Path]::GetFileName($destTpf))
            Pop-Location
        }
    }    # --- 6. Add _L suffix to DDS files in extracted LOD TPF folder, update XMLs ---
    if (Test-Path $lodDir) {
        $tpfFiles = Get-ChildItem -Path $lodDir -Filter '*_L.tpf' -File
        foreach ($tpf in $tpfFiles) {
            $extractDir = Join-Path $lodDir ("$($tpf.BaseName)-tpf")
            if (Test-Path $extractDir) {
                # Check if LOD TPF is intentionally empty
                if (Test-TpfEmpty -tpfExtractDir $extractDir -logFile $logFile) {
                    Write-Host "LOD TPF is intentionally empty, skipping _L suffix processing: '$($tpf.Name)'"
                    Write-VerboseLog -message "Skipped LOD processing for empty TPF: $($tpf.Name)" -logFile $logFile
                    continue
                }
                
                $ddsFiles = Get-ChildItem -Path $extractDir -Filter '*.dds' -File
                foreach ($dds in $ddsFiles) {
                    if ($dds.Name -notmatch '_L\.dds$') {
                        $newName = [IO.Path]::GetFileNameWithoutExtension($dds.Name) + '_L.dds'
                        $newPath = Join-Path $extractDir $newName
                        Write-Host "LOD Add _L: '$($dds.Name)' -> '$newName'"
                        if ($Execute) {
                            if (Test-Path $newPath) { Remove-Item $newPath -Force }
                            Rename-Item -Path $dds.FullName -NewName $newName
                            $ts = Timestamp
                            "[$ts] LOD Add _L: $($dds.Name) -> $newName" | Out-File -FilePath $logFile -Encoding UTF8 -Append
                        }
                    }
                }
                # Update XMLs in the LOD extracted TPF
                $xmlFiles = Get-ChildItem -Path $extractDir -Filter '*.xml' -File
                foreach ($xml in $xmlFiles) {
                    $xmlContent = Get-Content $xml.FullName
                    $newXml = $xmlContent -replace '<name>([A-Za-z0-9_]+)\.dds</name>', '<name>$1_L.dds</name>'
                    if ($newXml -ne $xmlContent) {
                        Write-Host "LOD Patch XML for _L: '$($xml.Name)'"
                        if ($Execute) {
                            $newXml | Set-Content -Path $xml.FullName -Encoding UTF8
                            $ts = Timestamp
                            "[$ts] LOD Patch XML for _L: $($xml.Name)" | Out-File -FilePath $logFile -Encoding UTF8 -Append
                        }
                    }
                }            } else {
                # Try to extract the TPF if it exists but hasn't been extracted
                if ($Execute -and (Test-Path $tpf.FullName)) {
                    Push-Location $lodDir
                    Write-Host "Re-attempting TPF extraction: '$($tpf.Name)'"
                    & witchybnd -u $tpf.Name
                    if ($LASTEXITCODE -eq 0 -and (Test-TpfValid -tpfPath $tpf.FullName -expectedDir $extractDir -logFile $logFile)) {
                        Write-Host "Successfully re-extracted TPF: $($tpf.Name)"
                    } else {
                        Write-Warning "Failed to re-extract TPF: $($tpf.Name)"
                        Write-LogMessage -message "Failed to extract TPF: $($tpf.Name)" -logFile $logFile -isError
                    }
                    Pop-Location
                } else {
                    Write-Warning "Expected folder '$extractDir' not found and TPF extraction failed."
                    $ts = Timestamp
                    "[$ts] Missing extract folder and TPF extraction failed: $extractDir" | Out-File -FilePath $logFile -Encoding UTF8 -Append
                }
            }
        }
    }

    # --- 7. NOW clean up modded extract dir if needed ---
    if ($Execute -and (Test-Path $modExtractDir)) {
        Write-Host "Deleting extracted modded BND dir: '$modExtractDir'"
        Remove-Item $modExtractDir -Recurse -Force
    }
}

# --- Summary ---
if ($Execute) {
    Write-Host "`nExecute complete."
    $ts = Timestamp
    "[$ts] Execute complete.`n" | Out-File -FilePath $logFile -Encoding UTF8 -Append
} else {
    Write-Host "`nDry-run complete."
    $ts = Timestamp
    "[$ts] Dry-run complete.`n" | Out-File -FilePath $logFile -Encoding UTF8 -Append
}
