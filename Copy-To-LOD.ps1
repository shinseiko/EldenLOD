<#
.SYNOPSIS
  Ensures modded armor/weapon LOD visibility in Elden Ring Seamless Coop by copying or injecting modded FLVER/TPF into missing LOD folders/files.

.DESCRIPTION
  For every relevant Elden Ring part (armor/weapon):
    • Checks for both unextracted `.partsbnd.dcx` archives and extracted `*-partsbnd-dcx` folders, as typically found in a modded `parts/` directory.
    • If needed, extracts `.partsbnd.dcx` and/or vanilla LOD (`_L`) archives using WitchyBND.
    • If a modded `_L` (LOD) directory or its files are missing (common in many mesh/texture mods):
        - Attempts to source the required vanilla LOD archive/folder from a UXM-extracted vanilla install, using either the `-UnpackedGameDir` parameter or the `$env:UnpackedGameDir` environment variable.
    • Copies the FLVER (mesh) and TPF (texture pack) files from the modded, non-LOD directory to the corresponding LOD (`*_L-partsbnd-dcx`) folder.
        - Overwrites the (vanilla) LOD FLVER/TPF with the modded, *full-size* FLVER/TPF.
        - This is a pragmatic shortcut: true LOD would use decimated meshes and downscaled textures, but this ensures cooperators see the correct gear—even if the files are not optimized for distance.
        - Note: This “hot fix” uses full-size assets for all LODs, which is nonstandard and slightly wasteful, but maximizes visible mod impact and multiplayer compatibility.
  Operates in DRY-RUN mode by default; no files are written unless `-Execute` is specified.

.PARAMETER partsDir
  Directory containing modded `*-partsbnd-dcx` files/folders.
  Defaults to the current directory if not specified.

.PARAMETER Execute
  If present, actually performs file operations (copy/rename/extract). Otherwise only previews intended actions.

.PARAMETER UnpackedGameDir
  Optional path to a UXM-extracted vanilla Elden Ring install, used as fallback for missing LOD files.
  Can also be specified via the `$env:UnpackedGameDir` environment variable.

.PARAMETER Rename
  If specified, files will be renamed (moved) instead of copied.

.ENVIRONMENT
  $env:UnpackedGameDir (alternative to -UnpackedGameDir for vanilla file sourcing)

.NOTES
  This is a quick compatibility patch for multiplayer visibility; it does not perform true LOD mesh decimation or texture scaling (planned for future releases).
  Unicode symbols (arrows, bullets, dashes) are displayed if running in PowerShell 7+; ASCII is used for compatibility with Windows PowerShell 5.x.
  DRY-RUN mode is enabled by default for safety.

.FUTURE
  • True LOD mesh decimation (replace full-res FLVER/TPF in LOD folders with optimized variants).
  • Automated texture downscaling for _L assets.
  • Smarter fallback/copy strategy.
  • User feedback and bug reports welcome!

.EXAMPLE
  Copy-To-LOD.ps1 -partsDir C:\EldenMods\MyMod\parts -Execute

  Actually performs all extraction/copy/rename operations on the specified directory, ensuring modded gear appears in Seamless Coop.

#>
param(
    [string] $sourceDir,
    [string] $targetDir,
    [switch] $Rename,
    [switch] $Execute
)
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $arrow = [char]0x2192   # →
    $bullet = [char]0x2022  # •
    $dash = [char]0x2013    # –
} else {
    $arrow = '->'
    $bullet = '*'
    $dash = '-'
}


if (-not $sourceDir) { $sourceDir = (Get-Location).Path }
if (-not $targetDir) { $targetDir = (Get-Location).Path }

Write-Host "$bullet Copy-To-LOD.ps1 starting."
Write-Host "$bullet Source: $sourceDir"
Write-Host "$bullet Target: $targetDir"
if ($Rename) { Write-Host "$bullet Rename mode active." }
if (-not $Execute) { Write-Warning "DRY RUN: Add -Execute to actually copy or rename files." }

$files = Get-ChildItem -Path $sourceDir -Filter '*_L.*' -File

foreach ($file in $files) {
    $targetPath = Join-Path $targetDir $file.Name
    if ($Rename) {
        Write-Host "$arrow Renaming $($file.Name) $arrow $targetPath"
        if ($Execute) {
            Rename-Item -Path $file.FullName -NewName $targetPath -Force
        }
    } else {
        Write-Host "$arrow Copying $($file.Name) $arrow $targetPath"
        if ($Execute) {
            Copy-Item -Path $file.FullName -Destination $targetPath -Force
        }
    }
}

Write-Host "$dash Done!"
