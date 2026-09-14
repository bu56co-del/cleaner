<div align="center">
  <img src="macos/Sources/Pawly/Resources/mascot.png" alt="Pawly kitten sweeping" width="180">
  <h1>Pawly</h1>
  <p>A little cat to help tidy your Mac.</p>
  <p>Free, open-source macOS cleanup interface · Traditional Chinese / English</p>
  <p><a href="https://github.com/bu56co-del/cleaner/releases/tag/pawly-v1.2.0">Download Pawly 1.2</a> · <a href="docs/pawly/BUILDING.md">Build from source</a> · <a href="LICENSE">GPL-3.0</a></p>
</div>

Pawly is an independent cat-themed macOS interface built around the open-source
[Mole CLI](https://github.com/tw93/Mole). Review files in native lists, inspect
what an operation will change, then choose what to clean. Some final operations
use an embedded terminal that supports both keyboard input and on-screen buttons.

This is **not the official Mole Mac app** and is not endorsed by the Mole project.
Pawly's interface, artwork, adapters and build scripts are open source, together
with the modified engine. See [attribution and modification notices](NOTICE.md).

## Download

**[Download from GitHub Releases](https://github.com/bu56co-del/cleaner/releases/tag/pawly-v1.2.0)**

- **Apple Silicon (M1 or newer), macOS 14+.** This release does not include an Intel binary.
- Download `Pawly-1.2.0-macos-arm64.zip`, extract it, and move `Pawly.app` to Applications.
- This community build is **ad-hoc signed, not Developer ID signed or Apple notarized**.
  macOS may block its first launch. After checking the download's source and
  checksum, follow [Apple's instructions for opening an unnotarized app](https://support.apple.com/en-us/102445).
- The release includes `SHA256SUMS` and a corresponding source archive.
  No account, subscription or license key is required to use Pawly.

## What it does

| Feature | What you can review |
| --- | --- |
| Quick cleanup | App caches, old logs and downloaded installers; selected items go to Trash |
| Deep clean | The engine's broader cleanup preview, categories, exclusions and external volumes |
| Applications | Installed apps, size, exact paths and related-file previews before uninstalling |
| Projects | Build artifacts grouped by project, size and recent activity |
| Installers | Installer files by source and format, with individual selection |
| Maintenance | 21 tasks with individual previews and explicit execution |
| Disk explorer | Folder drill-down, search, size sorting and large files |
| Health | Live CPU, memory and process information, with expandable hardware details |
| History & tools | Local operation history, exclusions, scan locations and optional CLI tools |

The interface supports **Traditional Chinese and English**, light/dark appearance,
and direct keyboard input in the operation workspace. Version 1.2 simplifies the
layout, reuses list calculations and app icons, and uses an optimized release build.

**Review the recovery method before confirming.** Quick cleanup and the installer
workflow use Trash. Project cleanup permanently removes rebuildable artifacts;
deep clean can permanently remove files and empty Trash. Some maintenance tasks
request administrator access. Logical file sizes are not a promise of immediately
reclaimable APFS disk space. Keep backups of important data.

The app does not install a background agent or run automatic cleaning. Most
inspection is local; explicitly selected CLI updates and some owner-tool operations
can use the network. See [feature details](PAWLY.md) and [verification limits](docs/pawly/VERIFICATION.md).

## Build

Install Xcode with Swift 6 support, Python 3, and a Go version compatible with
`go.mod` and its modules. Then:

```bash
git clone https://github.com/bu56co-del/cleaner.git
cd cleaner
./script/build_and_run.sh --build
open dist/Pawly.app
```

The helper finds Go on your PATH, or uses a local toolchain if you already have one.
There is no bundled developer toolchain in this repository.
See [BUILDING.md](docs/pawly/BUILDING.md) for details and verification commands.

## License and credits

Distributed as a whole under **GNU GPL version 3**, without warranty.
Original Mole code remains credited to Tw93 and contributors. SwiftTerm and other
third-party components retain their own license notices. [NOTICE.md](NOTICE.md)
lists modifications and source availability; [TRADEMARK.md](TRADEMARK.md) retains
the upstream brand policy. Use Pawly's own name and artwork when referring to this app.

Pawly issues belong in [this repository](https://github.com/bu56co-del/cleaner/issues).
For the original terminal toolkit, see [Mole upstream](https://github.com/tw93/Mole).
