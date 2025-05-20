<#
.SYNOPSIS
  Copies base `.tpf` and `.flver` files into their matching LOD folders,
  extracting missing _L folders if needed. Can fallback to UXM-extracted vanilla.

.PARAMETER partsDir
  Directory containing modded `*-partsbnd-dcx` files/folders.

.PARAMETER Execute
  If present, actually performs the copy and extraction. Otherwise dry-run.

.PARAMETER UnpackedGameDir
  Optional path to the UXM-extracted Elden Ring install, to fallback for missing LOD files.

.ENVIRONMENT
  You may also set $env:UnpackedGameDir instead of passing -UnpackedGameDir.

#>

param(
    [string]$partsDir = (Get-Location).Path,
    [string]$UnpackedGameDir = $env:UnpackedGameDir,
    [switch]$Execute
)

# --- Normalize partsDir ---
try {
    $partsDir = Convert-Path -Path $partsDir -ErrorAction Stop
}
catch {
    Write-Error "Invalid partsDir: '$partsDir'"
    exit 1
}

# --- Arrow, timestamp, logging setup ---
$arrow = if ($PSVersionTable.PSVersion.Major -ge 7) { [char]0x2192 } else { '->' }
function Timestamp { [DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss') }

$logDir = Join-Path $partsDir "_logs"
New-Item -Path $logDir -ItemType Directory -Force | Out-Null
$logFile = Join-Path $logDir "Copy-To-LOD.log"
"[{0}] Starting Copy-To-LOD.ps1 Execute={1}" -f (Timestamp), $Execute |
    Out-File -FilePath $logFile -Encoding UTF8 -Append
"" | Out-File -FilePath $logFile -Append

if (-not $Execute) {
    Write-Warning 'DRY-RUN MODE: no extractions or copies will be performed. Add -Execute to apply changes.'
}

# --- Unpack missing DCX folders ---
$dcxFiles = Get-ChildItem -Path $partsDir -Filter '*.partsbnd.dcx' -File
foreach ($dcx in $dcxFiles) {
    $base = $dcx.Name -replace '\.partsbnd\.dcx$','-partsbnd-dcx'
    $targetDir = Join-Path $partsDir $base
    if (-not (Test-Path $targetDir)) {
        if ($Execute) {
            Write-Host "Extracting: '$($dcx.FullName)' $arrow '$base'"
            $proc = Start-Process -FilePath "witchybnd" -ArgumentList "-u", "--passive", "`"$($dcx.FullName)`"" `
                -Wait -PassThru -WindowStyle Hidden
            if ($proc.ExitCode -ne 0 -or -not (Test-Path $targetDir)) {
                Write-Warning "ERROR extracting '$($dcx.Name)'"
                "[{0}] ERROR extracting: {1}`nExitCode: {2}" -f (Timestamp), $dcx.Name, $proc.ExitCode |
                    Out-File -FilePath $logFile -Append
            } else {
                "[{0}] Extracted: {1}" -f (Timestamp), $dcx.Name |
                    Out-File -FilePath $logFile -Append
            }
        } else {
            Write-Host "WhatIf: would extract '$($dcx.Name)' $arrow create folder '$base'"
        }
    }
}

# --- Copy from modded base → LOD ---
$baseDirs = Get-ChildItem -Path $partsDir -Directory |
    Where-Object { $_.Name -match '^(.*?)\-partsbnd\-dcx$' -and $_.Name -notlike '*_L-partsbnd-dcx' }

foreach ($dirInfo in $baseDirs) {
    try {
        $baseName = $dirInfo.Name -replace '-partsbnd-dcx$',''
        $srcDir   = $dirInfo.FullName
        $dstDir   = Join-Path $partsDir "${baseName}_L-partsbnd-dcx"

        # Create LOD folder if missing, fallback to UnpackedGameDir
        if (-not (Test-Path $dstDir)) {
            $fallback = if ($UnpackedGameDir) {
                Join-Path $UnpackedGameDir "parts\$baseName`_L.partsbnd.dcx"
            }

            if ($fallback -and (Test-Path $fallback)) {
                Write-Host "Found fallback: $fallback"
                if ($Execute) {
                    $tempCopy = Join-Path $partsDir "$baseName`_L.partsbnd.dcx"
                    Copy-Item $fallback $tempCopy -Force
                    Push-Location $partsDir
                    & witchybnd -u --passive "$tempCopy"
                    Pop-Location
                    if (-not (Test-Path $dstDir)) {
                        Write-Warning "Fallback extract failed for '$fallback'"
                        "[{0}] Fallback extract failed: {1}" -f (Timestamp), $fallback |
                            Out-File -FilePath $logFile -Append
                        continue
                    }
                    Remove-Item $tempCopy -Force -ErrorAction SilentlyContinue
                    "[{0}] Fallback copied + extracted: {1}" -f (Timestamp), $fallback |
                        Out-File -FilePath $logFile -Append
                } else {
                    Write-Host "WhatIf: would copy + extract fallback '$fallback' → '$dstDir'"
                }
            } else {
                $msg = "Skipping ${baseName}: LOD folder not found at '$dstDir'"
                Write-Warning $msg
                $msg | Out-File -FilePath $logFile -Append
                continue
            }
        }

        foreach ($ext in '.tpf','.flver') {
            $srcFile = Join-Path $srcDir "$baseName$ext"
            $dstName = "${baseName}_L$ext"
            $dstFile = Join-Path $dstDir $dstName

            if (Test-Path $srcFile) {
                if ($Execute) {
                    Copy-Item $srcFile $dstFile -Force
                    Write-Host "Copied: $srcFile $arrow $dstFile"
                    "[{0}] Copied: {1} $arrow {2}" -f (Timestamp), $srcFile, $dstFile |
                        Out-File -FilePath $logFile -Append
                } else {
                    Write-Host "WhatIf: would copy '$srcFile' $arrow '$dstFile'"
                }
            } else {
                $msg = "Source missing: '$srcFile'"
                Write-Warning $msg
                $msg | Out-File -FilePath $logFile -Append
            }
        }

    } catch {
        $msg = "ERROR processing '$($dirInfo.Name)': $_"
        Write-Error $msg
        $msg | Out-File -FilePath $logFile -Append
    }
}

# --- Summary ---
if ($Execute) {
    Write-Host "`nExecute complete."
    "[{0}] Execute complete." -f (Timestamp) |
        Out-File -FilePath $logFile -Append
} else {
    Write-Host "`nDry-run complete."
    "[{0}] Dry-run complete." -f (Timestamp) |
        Out-File -FilePath $logFile -Append
}
