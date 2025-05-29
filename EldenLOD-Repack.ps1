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
    [switch] $Execute
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

    # --- Find *_L.tpf and repack it if the extracted *-tpf dir exists ---
    $tpfFile = Get-ChildItem -Path $lodDir -Filter '*_L.tpf' -File | Select-Object -First 1
    if ($tpfFile) {
        $tpfExtractDir = Join-Path $lodDir ($tpfFile.BaseName + '-tpf')
        if (Test-Path $tpfExtractDir) {            # Validate and repack TPF
            if ($Execute) {
                if (Invoke-TpfRepack -tpfPath $tpfFile.FullName -tpfDir $tpfExtractDir -logFile $logFile) {
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
        Write-Warning "No *_L.tpf found in '$lodDir'!"
        $ts = Timestamp
        "[$ts] No *_L.tpf in $lodDir" | Out-File -FilePath $logFile -Encoding UTF8 -Append
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

    # --- Repack the BND directory into *_L.partsbnd.dcx ---
    if ($Execute) {
        Push-Location $lodDir
        Write-Host "Repacking: '$($bndLName)' from '$($lodDir)'"
        & witchybnd -r $lodDir
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "ERROR: witchybnd failed for '$bndLName'"
            $ts = Timestamp
            "[$ts] ERROR repacking $bndLName" | Out-File -FilePath $logFile -Encoding UTF8 -Append
        } else {
            $ts = Timestamp
            "[$ts] Repacked: $bndLName" | Out-File -FilePath $logFile -Encoding UTF8 -Append
        }
        Pop-Location
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