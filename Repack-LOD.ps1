<#
.SYNOPSIS
  Repackages LOD TPFs and binders into updated `.tpf` and `.dcx` files, then cleans up.

.DESCRIPTION
  For each `_L-partsbnd-dcx` folder under `$partsDir`:
    1. Deletes any existing `<BaseName>.tpf`.
    2. Rebuilds the TPF via `witchybnd -r <BaseName>-tpf`.
    3. Deletes the `<BaseName>-tpf` folder.
    4. Rebuilds the LOD binder via `witchybnd -r <BaseName>_L-partsbnd-dcx`.
    5. Deletes any `.bak` files.
    6. Deletes the LOD binder folder.
    7. Deletes the original base binder folder `<BaseName>-partsbnd-dcx`.
    8. Logs all steps to `_logs\Repack-LOD.log`.
  Dry-run by default; pass `-Execute` to apply changes.
#>
param(
    [string] $partsDir = (Get-Location).Path,
    [switch] $Execute
)

function Timestamp { [DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss') }
$arrow = if ($PSVersionTable.PSVersion.Major -ge 7) { [char]0x2192 } else { '->' }

# 1) Normalize & verify
try {
    $partsDir = Convert-Path $partsDir -ErrorAction Stop
} catch {
    Write-Error "Invalid partsDir: '$partsDir'."
    exit 1
}

# 2) Initialize log
$logDir  = Join-Path $partsDir '_logs'
if (-not (Test-Path $logDir)) { New-Item $logDir -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logDir 'Repack-LOD.log'
"[{0}] Starting Repack-LOD.ps1 Execute={1}`n" -f (Timestamp), $Execute |
    Out-File $logFile -Encoding UTF8 -Append

if (-not $Execute) {
    Write-Warning 'DRY-RUN MODE: no files will be deleted or repacked. Add -Execute to apply.'
}

# 3) Process each *_L-partsbnd-dcx folder
Get-ChildItem -Path $partsDir -Directory |
  Where-Object Name -like '*_L-partsbnd-dcx' |
ForEach-Object {
    $lodDir  = $_.FullName
    $folder  = $_.Name
    Write-Host "`n===== Processing $folder ====="
    "[$(Timestamp)] Processing: $folder" | Out-File $logFile -Append

    # Derive names
    $baseL      = $folder -replace '-partsbnd-dcx$',''         # e.g. "AM_M_1810_L"
    $base       = $baseL -replace '_L$',''                     # e.g. "AM_M_1810"
    $tpfFile    = Join-Path $lodDir "$baseL.tpf"
    $tpfdDir    = Join-Path $lodDir ("$baseL-tpf")
    $origBinder = Join-Path $partsDir ("$base-partsbnd-dcx")

    if (-not $Execute) {
        if (Test-Path $tpfFile) {
            Write-Host "WhatIf: delete TPF '$baseL.tpf'"
        }
        Write-Host "WhatIf: repack TPF from '$baseL-tpf' → '$baseL.tpf'"
        Write-Host "WhatIf: remove folder '$baseL-tpf'"
        Write-Host "WhatIf: repack binder '$folder' → '${folder}.dcx'"
        Write-Host "WhatIf: delete backups '*.bak'"
        Write-Host "WhatIf: remove LOD binder folder '$folder'"
        Write-Host "WhatIf: remove original binder folder '$base-partsbnd-dcx'"
        return
    }

    # 3a) Delete existing TPF
    if (Test-Path $tpfFile) {
        Remove-Item $tpfFile -Force
        Write-Host "Deleted old TPF: '$baseL.tpf'"
        "[$(Timestamp)] Deleted TPF: $baseL.tpf" | Out-File $logFile -Append
    }

    # 3b) Repack TPF
    if (Test-Path $tpfdDir) {
        Write-Host "Repacking TPF: '$baseL-tpf' $arrow '$baseL.tpf'"
        "[$(Timestamp)] Repacking TPF: $baseL-tpf → $baseL.tpf" |
            Out-File $logFile -Append

        Push-Location $lodDir
        & witchybnd -r "$baseL-tpf"
        Pop-Location
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "ERROR repacking TPF '$baseL-tpf'"
            "[$(Timestamp)] ERROR repacking TPF: $baseL-tpf" |
                Out-File $logFile -Append
            return
        }
        Write-Host "Repacked TPF: '$baseL.tpf'"
        "[$(Timestamp)] Repacked TPF: $baseL.tpf" | Out-File $logFile -Append

        Remove-Item $tpfdDir -Recurse -Force
        Write-Host "Removed TPF folder: '$baseL-tpf'"
        "[$(Timestamp)] Removed TPF folder: $baseL-tpf" | Out-File $logFile -Append
    }

    # 3c) Repack LOD binder
    Write-Host "Repacking binder: '$folder'"
    "[$(Timestamp)] Repacking binder: $folder" | Out-File $logFile -Append

    & witchybnd -r $folder
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "ERROR repacking binder '$folder'"
        "[$(Timestamp)] ERROR repacking binder: $folder" | Out-File $logFile -Append
    } else {
        Write-Host "Repacked binder: '$folder'"
        "[$(Timestamp)] Repacked binder: $folder" | Out-File $logFile -Append
    }

    # 3d) Delete .bak files
    Get-ChildItem -Path $partsDir -Filter '*.bak' -File | ForEach-Object {
        Remove-Item $_.FullName -Force
        Write-Host "Deleted backup: '$($_.Name)'"
        "[$(Timestamp)] Deleted backup: $($_.Name)" | Out-File $logFile -Append
    }

    # 3e) Remove LOD binder folder
    Remove-Item $lodDir -Recurse -Force
    Write-Host "Removed LOD binder folder: '$folder'"
    "[$(Timestamp)] Removed LOD binder folder: $folder" | Out-File $logFile -Append

    # 3f) Remove original binder folder
    if (Test-Path $origBinder) {
        Remove-Item $origBinder -Recurse -Force
        Write-Host "Removed original binder folder: '$base-partsbnd-dcx'"
        "[$(Timestamp)] Removed original binder folder: $base-partsbnd-dcx" |
            Out-File $logFile -Append
    }
}

# 4) Summary
if ($Execute) {
    Write-Host "`nExecute complete. Only original .dcx and new LOD .dcx remain."
    "[$(Timestamp)] Execute complete.`n" | Out-File $logFile -Append
}
else {
    Write-Host "`nDry-run complete."
    "[$(Timestamp)] Dry-run complete.`n" | Out-File $logFile -Append
}
