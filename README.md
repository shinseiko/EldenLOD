# EldenLOD

**EldenLOD** is a PowerShell-driven tool that automates the repair and generation of Level of Detail (LOD) meshes for Elden Ring mods missing proper LODs. Works out-of-the-box on PowerShell 7.5.1. PowerShell 5.x support is a work in progress.

---

## Features

- Batch detection of missing LOD meshes in modded Elden Ring asset packs
- Automated LOD mesh generation and integration (planned/experimental)
- Detailed logging for debugging and workflow review
- Roadmap-driven: expanding compatibility, automation, and mesh processing features

---

## Installation

### Prerequisites

- PowerShell 7.5.1 or higher (Windows PowerShell 5.x support coming soon)
- [List any required third-party modules or tools here, e.g. Blender, SoulsFormats, WitchyBND]

### Steps

1. **Clone the repository:**
   git clone https://github.com/YourUsername/EldenLOD.git

2. **Navigate to the project directory:**
   cd EldenLOD

3. **(Optional) Install any dependencies:**
   [Insert any additional setup instructions here]

---

## Usage

Basic usage example:
    .\EldenLOD.ps1 -InputDir "C:\Path\To\YourMod"

**Options:**
- `-InputDir` — Path to the mod folder to scan for missing LODs.
- [Document any other flags or options here.]

---

## Roadmap

- [x] Initial LOD mesh detection
- [ ] PowerShell 5.x compatibility
- [ ] Automatic LOD mesh generation (via Blender integration or custom logic)
- [ ] GUI frontend
- [ ] Community contributions, presets, and scripting hooks

---

## Contributing

Pull requests are welcome! For major changes, please open an issue first to discuss what you’d like to change.
See CONTRIBUTING.md for guidelines (to be written!).

---

## License

This project is licensed under the MIT License.

---

## Acknowledgments

- FromSoftware for Elden Ring (all rights reserved to the original developers)
- [List any open source libraries/tools you use]
- Community contributors

---
