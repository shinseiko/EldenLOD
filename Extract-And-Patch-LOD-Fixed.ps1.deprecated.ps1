<#
.SYNOPSIS
  Fixed version of Extract-And-Patch-LOD with proper file renumbering and error handling
#>
param(
    [string] $partsDir = (Get-Location).Path,
    [switch] $Execute,
    [string] $UnpackedGameDir = ""
)

# Import shared module 
$modulePath = Join-Path $PSScriptRoot 'EldenLOD.psm1'
Import-Module $modulePath -Force -ErrorAction Stop

# Setup and validation
try { $partsDir = Convert-Path -Path $partsDir -ErrorAction Stop }
catch { Write-Error "Invalid partsDir: '$partsDir'"; exit 1 }

if (-not $UnpackedGameDir -or -not (Test-Path $UnpackedGameDir)) {
    if ($env:UnpackedGameDir -and (Test-Path $env:UnpackedGameDir)) {
        $UnpackedGameDir = $env:UnpackedGameDir
    } else {
        $localUnpackedGame = Join-Path $partsDir 'UnpackedGame'
        if (Test-Path $localUnpackedGame) { 
            $UnpackedGameDir = $localUnpackedGame
        } else {
            Write-Error "No UnpackedGame directory found. Please specify -UnpackedGameDir or set UnpackedGameDir environment variable."
            exit 1
        }
    }
}

$vanillaPartsDir = Join-Path $UnpackedGameDir 'parts'
Write-Host "INFO: Using vanilla parts dir: $vanillaPartsDir"

$logDir = Join-Path $partsDir '_logs'
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logDir 'Extract-And-Patch-LOD-Fixed.log'
"[{0}] Starting Extract-And-Patch-LOD-Fixed.ps1 Execute={1}`n" -f (Timestamp), $Execute |
    Out-File -FilePath $logFile -Encoding UTF8 -Append

if (-not $Execute) { Write-Warning 'DRY-RUN MODE: no changes will be made. Add -Execute to apply.' }

# Main processing
$modPrimaryBnds = Get-ChildItem -Path $partsDir -Filter '*.partsbnd.dcx' -File | Where-Object { $_.BaseName -notmatch '_L$' }

foreach ($bndFile in $modPrimaryBnds) {
    $base = $bndFile.Name -replace '\.partsbnd\.dcx$', ''
    $baseUpper = $base.ToUpper()
    $lodFile = "${base}_L.partsbnd.dcx"
    $modLodPath = Join-Path $partsDir $lodFile
    
    Write-Host "`n===== Processing: $($bndFile.Name) ====="
    
    # 1. Ensure LOD BND exists (copy vanilla if missing)
    if (!(Test-Path $modLodPath)) {
        $vanillaLodPath = Join-Path $vanillaPartsDir $lodFile
        if (Test-Path $vanillaLodPath) {
            if ($Execute) {
                Write-Host "Copying vanilla $lodFile"
                Copy-Item $vanillaLodPath $modLodPath -Force
            } else {
                Write-Host "Would copy vanilla $lodFile"
            }
        } else {
            Write-Warning "Missing both modded and vanilla $lodFile. Skipping."
            continue
        }
    }
      # 2. Extract modded BND (skip if already extracted)
    $modExtractDir = Join-Path $partsDir ($base + '-partsbnd-dcx')
    if (!(Test-Path $modExtractDir)) {
        if ($Execute) {
            Push-Location $partsDir
            Write-Host "Extracting modded BND: '$($bndFile.Name)'"
            & witchybnd -u $($bndFile.Name) 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0 -or -not (Test-Path $modExtractDir)) {
                Write-Error "Failed to extract modded BND: $($bndFile.Name)"
                Pop-Location
                continue
            }
            Pop-Location
        } else {
            Write-Host "Would extract modded BND: '$($bndFile.Name)'"
        }
    } else {
        Write-Host "Modded BND already extracted: '$($bndFile.Name)'"
    }
    
    # 3. Process TPFs in extracted directory
    if (Test-Path $modExtractDir) {
        $hasRenumbering = $false
        $tpfFiles = Get-ChildItem -Path $modExtractDir -Filter '*.tpf' -File
        
        foreach ($tpf in $tpfFiles) {
            Push-Location $modExtractDir
            
            # Check if TPF needs renumbering
            $originalTpfName = $tpf.Name
            $targetNumber = $baseUpper -replace '^[A-Z]+_[A-Z]+_', ''
            
            if ($tpf.Name -match '^([A-Z]+_[A-Z]+)_([0-9]+)(.*)\.tpf$') {
                $tpfPrefix = $matches[1]
                $currentNumber = $matches[2]
                $tpfSuffix = $matches[3]
                
                if ($currentNumber -ne $targetNumber) {
                    $newTpfName = "${tpfPrefix}_${targetNumber}${tpfSuffix}.tpf"
                    Write-Host "Renumbering TPF: '$originalTpfName' -> '$newTpfName'"
                    
                    if ($Execute) {
                        Rename-Item -Path $tpf.FullName -NewName $newTpfName -Force
                        $tpf = Get-Item (Join-Path $modExtractDir $newTpfName)
                        $hasRenumbering = $true
                    }
                }
            }
              # Extract TPF
            Write-Host "Extracting TPF: '$($tpf.Name)'"
            & witchybnd -u $tpf.Name 2>&1 | Out-Null
            
            $tpfExtractDir = Join-Path $modExtractDir ("$($tpf.BaseName)-tpf")
            if ($LASTEXITCODE -eq 0 -and (Test-Path $tpfExtractDir)) {
                # Check if TPF is intentionally empty
                if (Test-TpfEmpty -tpfExtractDir $tpfExtractDir -logFile $logFile) {
                    Write-Host "TPF is intentionally empty, skipping file processing: '$($tpf.Name)'"
                    continue
                }
                
                # Check and fix DDS files
                $ddsFiles = Get-ChildItem -Path $tpfExtractDir -Filter '*.dds' -File
                $xmlNeedsUpdate = $false
                
                foreach ($dds in $ddsFiles) {
                    if ($dds.Name -match '^([A-Z]+_[A-Z]+)_([0-9]+)(.+\.dds)$') {
                        $ddsPrefix = $matches[1]
                        $ddsNumber = $matches[2]
                        $ddsSuffix = $matches[3]
                        
                        if ($ddsNumber -ne $targetNumber) {
                            $newDdsName = "${ddsPrefix}_${targetNumber}${ddsSuffix}"
                            Write-Host "Renumbering DDS: '$($dds.Name)' -> '$newDdsName'"
                            
                            if ($Execute) {
                                Rename-Item -Path $dds.FullName -NewName $newDdsName -Force
                                $hasRenumbering = $true
                                $xmlNeedsUpdate = $true
                            }
                        }
                    }
                }
                
                # Update XML if needed
                if ($xmlNeedsUpdate -and $Execute) {
                    $xmlFiles = Get-ChildItem -Path $tpfExtractDir -Filter '*.xml' -File
                    foreach ($xml in $xmlFiles) {
                        $xmlContent = Get-Content $xml.FullName -Raw
                        $newXml = $xmlContent -replace '<n>([A-Z]+_[A-Z]+)_[0-9]+([^<>]+\.dds)</n>', "<n>`$1_${targetNumber}`$2</n>"
                        
                        if ($newXml -ne $xmlContent) {
                            Write-Host "Updating XML: '$($xml.Name)'"
                            $newXml | Set-Content -Path $xml.FullName -Encoding UTF8 -NoNewline
                        }
                    }
                }
                
                # Repack TPF if changes were made
                if ($hasRenumbering -and $Execute) {
                    Write-Host "Repacking TPF: '$($tpf.Name)'"
                    & witchybnd -r $tpf.Name 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        Remove-Item $tpfExtractDir -Recurse -Force
                    } else {
                        Write-Warning "Failed to repack TPF: $($tpf.Name)"
                    }
                }
            }
            
            Pop-Location
        }
        
        # Repack main BND if changes were made
        if ($hasRenumbering -and $Execute) {
            Push-Location $partsDir
            Write-Host "Repacking modded BND: '$($bndFile.Name)'"
            & witchybnd -r ($base + '-partsbnd-dcx') 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Successfully repacked: $($bndFile.Name)"
            } else {
                Write-Warning "Failed to repack BND: $($bndFile.Name)"
            }
            Pop-Location
        }
    }
      # 4. Extract LOD BND (skip if already extracted)
    $lodDir = Join-Path $partsDir ($lodFile -replace '\.partsbnd\.dcx$', '-partsbnd-dcx')
    if (!(Test-Path $lodDir)) {
        if ($Execute) {
            Push-Location $partsDir
            Write-Host "Extracting LOD BND: '$lodFile'"
            & witchybnd -u $lodFile 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0 -or -not (Test-Path $lodDir)) {
                Write-Warning "Failed to extract LOD BND: $lodFile"
                Pop-Location
                continue
            }
            Pop-Location
        } else {
            Write-Host "Would extract LOD BND: '$lodFile'"
        }
    } else {
        Write-Host "LOD BND already extracted: '$lodFile'"
    }
    
    # 5. Copy modded files to LOD directory
    if ($Execute -and (Test-Path $lodDir)) {
        $modFlver = Get-ChildItem -Path $partsDir -Filter "$base.flver" -File | Select-Object -First 1
        $modTpf = Get-ChildItem -Path $partsDir -Filter "$base.tpf" -File | Select-Object -First 1
        
        if ($modFlver) {
            $destFlver = Join-Path $lodDir ("$baseUpper`_L.flver")
            Write-Host "Copying FLVER to LOD: '$($modFlver.Name)'"
            Copy-Item $modFlver.FullName $destFlver -Force
        }
        
        if ($modTpf) {
            $destTpf = Join-Path $lodDir ("$baseUpper`_L.tpf")
            Write-Host "Copying TPF to LOD: '$($modTpf.Name)'"
            Copy-Item $modTpf.FullName $destTpf -Force
            
            # Extract TPF for LOD processing
            Push-Location $lodDir
            & witchybnd -u $([IO.Path]::GetFileName($destTpf)) 2>&1 | Out-Null
            Pop-Location
        }
    }
    
    # 6. Add _L suffix to LOD TPF files
    if (Test-Path $lodDir) {
        $lodTpfFiles = Get-ChildItem -Path $lodDir -Filter '*_L.tpf' -File
        foreach ($lodTpf in $lodTpfFiles) {
            $lodTpfExtractDir = Join-Path $lodDir ("$($lodTpf.BaseName)-tpf")
            if (Test-Path $lodTpfExtractDir) {
                $lodDdsFiles = Get-ChildItem -Path $lodTpfExtractDir -Filter '*.dds' -File
                foreach ($lodDds in $lodDdsFiles) {
                    if ($lodDds.Name -notmatch '_L\.dds$') {
                        $newLodName = [IO.Path]::GetFileNameWithoutExtension($lodDds.Name) + '_L.dds'
                        Write-Host "Adding _L suffix: '$($lodDds.Name)' -> '$newLodName'"
                        if ($Execute) {
                            Rename-Item -Path $lodDds.FullName -NewName $newLodName -Force
                        }
                    }
                }
                
                # Update LOD XML
                if ($Execute) {
                    $lodXmlFiles = Get-ChildItem -Path $lodTpfExtractDir -Filter '*.xml' -File
                    foreach ($lodXml in $lodXmlFiles) {
                        $lodXmlContent = Get-Content $lodXml.FullName -Raw
                        $newLodXml = $lodXmlContent -replace '<n>([A-Za-z0-9_]+)\.dds</n>', '<n>$1_L.dds</n>'
                        if ($newLodXml -ne $lodXmlContent) {
                            Write-Host "Updating LOD XML: '$($lodXml.Name)'"
                            $newLodXml | Set-Content -Path $lodXml.FullName -Encoding UTF8 -NoNewline
                        }
                    }
                }
            }
        }
    }
    
    # Clean up extracted modded directory
    if ($Execute -and (Test-Path $modExtractDir)) {
        Write-Host "Cleaning up: $modExtractDir"
        Remove-Item $modExtractDir -Recurse -Force
    }
}

Write-Host "`nProcessing complete!"
