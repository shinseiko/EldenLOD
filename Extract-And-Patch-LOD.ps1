<#
.SYNOPSIS
  Extracts LOD TPFs, renames DDS files, and patches XML – dry-run by default.

.DESCRIPTION
  For each `*_L-partsbnd-dcx` folder under `$partsDir`:
    1. Finds the `*_L.tpf`
    2. (Dry‐run) Prints each step it would take, then moves on.
       (With `-Execute`) actually:
      • Extracts via `witchybnd -u`, which by default writes into `<basename>-tpf`
      • Renames all `.dds` → `*_L.dds` in that `<basename>-tpf` folder
      • Patches the `.xml` to reference `*_L.dds`
  Logs to `_logs\Extract-And-Patch-LOD.log`.

.PARAMETER partsDir
  Folder containing your `_L-partsbnd-dcx` directories. Defaults to current dir.
.PARAMETER Execute
  If present, performs operations; otherwise shows a dry-run preview.
#>
param(
    [string] $partsDir = (Get-Location).Path,
    [switch] $Execute
)

function Timestamp {
    [DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss')
}

$arrow = if ($PSVersionTable.PSVersion.Major -ge 7) { [char]0x2192 } else { '->' }

# 1) Normalize & verify
try {
    $partsDir = Convert-Path -Path $partsDir -ErrorAction Stop
} catch {
    Write-Error "Invalid partsDir: '$partsDir'. Please specify an existing folder."
    exit 1
}

# 2) Initialize log
$logDir = Join-Path $partsDir '_logs'
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}
$logFile = Join-Path $logDir 'Extract-And-Patch-LOD.log'
"[{0}] Starting Extract-And-Patch-LOD.ps1 Execute={1}`n" -f (Timestamp), $Execute |
    Out-File -FilePath $logFile -Encoding UTF8 -Append

if (-not $Execute) {
    Write-Warning 'DRY-RUN MODE: no changes will be made. Add -Execute to apply.'
}

# 3) Process each *_L-partsbnd-dcx directory
Get-ChildItem -Path $partsDir -Directory |
    Where-Object { $_.Name -like '*_L-partsbnd-dcx' } |
ForEach-Object {
    $lodDir = $_.FullName
    Write-Host "`n===== Processing $($_.Name) ====="

    # 3a) Locate the LOD TPF
    $tpf = Get-ChildItem -Path $lodDir -Filter '*_L.tpf' -File | Select-Object -First 1
    if (-not $tpf) {
        Write-Warning "No *_L.tpf found in '$lodDir' – skipping."
        $ts = Timestamp
        "[$ts] No *_L.tpf in $lodDir" | Out-File $logFile -Append
        continue
    }

    # 3b) Compute extract folder
    $baseName   = [IO.Path]::GetFileNameWithoutExtension($tpf.Name)
    $extractDir = Join-Path $lodDir ("$baseName-tpf")

    if (-not $Execute) {
        Write-Host "WhatIf: extract   '$($tpf.Name)' $arrow '$baseName-tpf'"
        Write-Host "WhatIf: rename    *.dds in '$baseName-tpf' → '*_L.dds'"
        Write-Host "WhatIf: patch     *.xml in '$baseName-tpf' to reference '*_L.dds'"
        continue
    }

    # 3c) Actual extraction
    Push-Location $lodDir
    Write-Host "Extracting: '$($tpf.Name)' $arrow '$baseName-tpf'"
    & witchybnd -u $tpf.FullName
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "ERROR: witchybnd failed on '$($tpf.Name)'"
        $ts = Timestamp
        "[$ts] ERROR extracting $($tpf.Name)" | Out-File $logFile -Append
        Pop-Location
        continue
    }
    "[$ts] Extracted: $($tpf.Name)" | Out-File $logFile -Append

    # 3d) Rename .dds files
    if (Test-Path $extractDir) {
        Get-ChildItem -Path $extractDir -Filter '*.dds' -File | ForEach-Object {
            $dds = $_
            $new = "{0}_L{1}" -f $dds.BaseName, $dds.Extension
            Write-Host "Renaming: '$($dds.Name)' $arrow '$new'"
            Rename-Item -Path $dds.FullName -NewName $new -Force
            $ts = Timestamp
            "[$ts] Renamed: $($dds.Name) → $new" | Out-File $logFile -Append
        }
    } else {
        Write-Warning "Expected folder '$extractDir' not found."
        $ts = Timestamp
        "[$ts] Missing extract folder: $extractDir" | Out-File $logFile -Append
    }

    # 3e) Patch XML
    if (Test-Path $extractDir) {
        $xml = Get-ChildItem -Path $extractDir -Filter '*.xml' -File | Select-Object -First 1
        if ($xml) {
            Write-Host "Patching XML: '$($xml.Name)'"
            $xmlContent = Get-Content $xml.FullName
            $patched = $xmlContent -replace '(<name>)([^<]+?)(\.dds</name>)','$1$2_L$3'
            $patched | Set-Content -Path $xml.FullName
            $ts = Timestamp
            "[$ts] Patched XML: $($xml.Name)" | Out-File $logFile -Append
        } else {
            Write-Warning "No XML found in '$extractDir'"
            $ts = Timestamp
            "[$ts] No XML in $extractDir" | Out-File $logFile -Append
        }
    }

    Pop-Location
}

# 4) Summary
if ($Execute) {
    Write-Host "`nExecute complete."
    $ts = Timestamp
    "[$ts] Execute complete.`n" | Out-File $logFile -Append
} else {
    Write-Host "`nDry-run complete."
    $ts = Timestamp
    "[$ts] Dry-run complete.`n" | Out-File $logFile -Append
}
