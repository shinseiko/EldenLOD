# Elden Ring LOD Processing Toolkit

A set of PowerShell scripts to automate copying, patching, and repacking LOD (Level of Detail) assets for Elden Ring mods. Designed for modders who want their creations to look right in seamless co-op and at all distances.

---

## 📦 Contents

- `Copy-To-LOD.ps1`  
  Copies base `.tpf` and `.flver` files into their corresponding `_L` folders, adding `_L` suffixes to filenames.

- `Extract-And-Patch-LOD.ps1`  
  Extracts `_L.tpf` archives using [WitchyBND](https://github.com/JKAnderson/WitchyBND), renames `.dds` textures with `_L` suffixes, and patches XML texture references as needed.

- `Repack-LOD.ps1`  
  Deletes old `_L.tpf` files, repacks updated folders with WitchyBND, and cleans up intermediate directories.

- `Run-All-LOD.ps1`  
  Orchestrates the above: Copy → Extract/Patch → Repack. By default, it performs a dry run; use `-Execute` to make actual changes.

---

## ✅ Usage

From PowerShell 5.x or 7.x+:

```powershell
.\Run-All-LOD.ps1 -partsDir "C:\Path\To\Your\parts" -Execute
```

- Omit `-Execute` to simulate all actions without modifying files (dry-run mode).
- `partsDir` should point to your Elden Ring mod's `parts` directory containing `.partsbnd.dcx` files.

---

## ⚠ Requirements

- PowerShell 5.x (Windows) or 7.x+ (cross-platform)
- [WitchyBND](https://github.com/JKAnderson/WitchyBND) in your system path

> **Note:** Some advanced PowerShell 7 features may not be available in 5.x. See [Known Issues](#known-issues) below.

---

## 📝 Logging & Safety

- All scripts log activity to a `_logs` subfolder inside your parts directory.
- By default, all scripts are non-destructive—use `-Execute` to apply changes after testing.

---

## 🐛 Known Issues

- **PowerShell 5.x support is experimental**. Some commands or parameters may fail—please [open an issue](https://github.com/youruser/EldenLOD/issues) if you hit a snag!
- Scripts assume WitchyBND is accessible via command line.
- Absolute paths are required; relative paths may not work as expected.
- Advanced Blender integration for true LOD mesh decimation is *planned* but not yet implemented.

---

## 🤝 Contributing

Pull requests, feature ideas, and bug reports are highly encouraged! See [CONTRIBUTING.md](CONTRIBUTING.md) or open an issue to join the discussion.

---

## 🚀 Future Plans

- One-click LOD mesh decimation via Blender
- Better cross-platform support (Linux, macOS)
- Auto-detection of missing LODs and reporting
- Maybe, just maybe: a GUI (when the backend is indestructible!)

---

**Happy modding!**  
*Praise the LOD!*
