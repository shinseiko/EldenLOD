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

    # --- Find the correct *_L.tpf and repack it if the extracted *-tpf dir exists ---
    $tpfName = "${bndBase}_L.tpf"
    $tpfFile = Get-ChildItem -Path $lodDir -Filter $tpfName -File | Select-Object -First 1
    if ($tpfFile) {
        $tpfExtractDir = Join-Path $lodDir ($tpfFile.BaseName + '-tpf')
        if (Test-Path $tpfExtractDir) {            # Validate and repack TPF
            if ($Execute) {
                if (Invoke-TpfRepack -tpfPath $tpfFile.FullName -tpfDir $tpfExtractDir -logFile $logFile -NoRenumber:$NoRenumber) {
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

    # --- Repack the BND directory into *_L.partsbnd.dcx ---
    if ($Execute) {
        Push-Location $lodDir
        Write-Host "Repacking: '$($bndLName)' from '$($lodDir)'"
        
        # Create temporary non-LOD TPF for WitchyBND
        $tempTpf = $null
        if ($tpfFile) {
            $nonLodName = $tpfFile.Name -replace '_L\.tpf$', '.tpf'
            $tempTpf = Join-Path $lodDir $nonLodName
            Write-Host "Creating temporary TPF copy: '$nonLodName'"
            Copy-Item -Path $tpfFile.FullName -Destination $tempTpf -Force
        }
        
        # Perform the repack
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

# Summary
if ($Execute) {
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