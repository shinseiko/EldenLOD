<#
.SYNOPSIS
  Runs Copy-To-LOD, Extract-And-Patch-LOD, and Repack-LOD in sequence,
  forwarding the -Execute switch when provided.
#>
param(
    [string]$partsDir = (Get-Location).Path,
    [switch]$Execute
)

# 1) Normalize & verify partsDir
try {
    $partsDir = Convert-Path -Path $partsDir -ErrorAction Stop
}
catch {
    Write-Error "Invalid partsDir: '$partsDir'. Please specify an existing folder."
    exit 1
}

function Timestamp {
    [DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss')
}

# 2) Prepare master log
$logDir    = Join-Path $partsDir '_logs'
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}
$masterLog = Join-Path $logDir 'Run-All-LOD.log'

# Write header
"[{0}] Starting Run-All-LOD.ps1 Execute={1}" -f (Timestamp), $Execute |
    Out-File -FilePath $masterLog -Encoding UTF8 -Append
# Blank line
"" | Out-File -FilePath $masterLog -Encoding UTF8 -Append

# 3) Tools list
$tools = @(
    'Copy-To-LOD.ps1',
    'Extract-And-Patch-LOD.ps1',
    'Repack-LOD.ps1'
)

# 4) Invoke each tool, forwarding -Execute if set
foreach ($tool in $tools) {

    $toolPath = Join-Path $PSScriptRoot $tool
    if (-not (Test-Path $toolPath)) {
        $msg = "[{0}] MISSING: {1}" -f (Timestamp), $tool
        Write-Warning $msg
        $msg | Out-File -FilePath $masterLog -Append
        continue
    }

    Write-Host "`nRunning: $tool"
    "[{0}] Launching {1}" -f (Timestamp), $tool |
        Out-File -FilePath $masterLog -Append

    try {
        if ($Execute) {
            & $toolPath -partsDir $partsDir -Execute
        }
        else {
            & $toolPath -partsDir $partsDir
        }

        "[{0}] Finished {1}" -f (Timestamp), $tool |
            Out-File -FilePath $masterLog -Append
    }
    catch {
        $msg = "[{0}] ERROR running {1}: {2}" -f (Timestamp), $tool, $_
        Write-Error $msg
        $msg | Out-File -FilePath $masterLog -Append
    }
}

# 5) Summary
Write-Host "`nAll tools complete."
"[{0}] Run-All-LOD.ps1 complete." -f (Timestamp) |
    Out-File -FilePath $masterLog -Encoding UTF8 -Append
# Final blank line
"" | Out-File -FilePath $masterLog -Encoding UTF8 -Append
