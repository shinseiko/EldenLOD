# EldenLOD

EldenLOD is a PowerShell-based toolkit designed to automate the process of copying, patching, and repacking Level of Detail (LOD) assets for Elden Ring mods. This suite ensures that mods display correctly at various distances, enhancing the seamless co-op experience.

---

## Features

- **Automated LOD Processing:** Streamlines the creation and integration of LOD assets.
- **Batch Operations:** Processes multiple files and directories efficiently.
- **Integration with WitchyBND:** Utilizes external tools for archive management.
- **Modular Scripts:** Offers flexibility through individual scripts or an all-in-one runner.

---

## Prerequisites

- PowerShell 7.5.1 or higher
- WitchyBND (must be installed and added to your system PATH)

---

## Installation

1. **Clone the repository:**

        git clone https://github.com/shinseiko/EldenLOD.git

2. **Navigate to the project directory:**

        cd EldenLOD

3. **Ensure dependencies are met:**
   - Verify PowerShell and WitchyBND are correctly installed.

---

## Usage

> **IMPORTANT:**  
> All scripts in EldenLOD require the `-execute` switch to actually perform any actions.  
> Without `-execute`, the scripts will only perform a dry run and display what they *would* do.

### Run All Steps Sequentially

        .\Run-All-LOD.ps1 -execute

(Executes the entire LOD processing pipeline.)

### Run Individual Steps

- **Copy base files to LOD folders:**

        .\Copy-To-LOD.ps1 -execute

- **Extract and patch LOD archives:**

        .\Extract-And-Patch-LOD.ps1 -execute

- **Repack patched LOD assets:**

        .\Repack-LOD.ps1 -execute

*Note: If running steps individually, execute them in the order above.*

---

## Roadmap

- [x] Implement core LOD processing scripts
- [ ] Enhance compatibility with PowerShell 5.x
- [ ] Improve error handling and logging mechanisms
- [ ] Develop a graphical user interface for ease of use
- [ ] Expand support for additional asset types

---

## Contributing

Contributions are welcome!

1. Fork the repository.
2. Create a new branch for your feature or fix.
3. Commit your changes with clear messages.
4. Submit a pull request describing your changes.

Please refer to `CONTRIBUTING.md` for more information.

---

## License

This project is licensed under the MIT License.

---

## Acknowledgments

- FromSoftware for Elden Ring.
- WitchyBND for essential archive management tools.

---
