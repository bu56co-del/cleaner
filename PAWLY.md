# Pawly — A little cat to help tidy your Mac

Pawly 1.2 is an independent, cat-themed macOS interface using the Mole 1.53.0
engine in this repository. The app supports Traditional Chinese and English,
with cream, dark and system appearance options.

## Download and launch

Download the app from [GitHub Releases](https://github.com/bu56co-del/cleaner/releases/tag/pawly-v1.2.0).
The current download supports Apple Silicon and macOS 14 or newer. For a local
build, double-click `dist/Pawly.app`. The bundle includes the native Swift app,
Go engine helpers and artwork; using the app does not require a separate Terminal window.

To rebuild and launch:

```bash
./script/build_and_run.sh
```

To build without launching, use `./script/build_and_run.sh --build`. The default
build enables release optimization; `--debug` retains the debugging configuration.
Use `--stage` to prepare a separate bundle while the current app is cleaning,
without replacing resources that an operation is using.

Building requires macOS, a Swift 6 toolchain, Python 3 and a compatible Go version.
The build script can use Go on PATH or an existing project-local toolchain.
See [BUILDING.md](docs/pawly/BUILDING.md) for the complete requirements and steps.
SwiftTerm 1.20.0 is bundled with its resources and MIT license.

The download is ad-hoc signed, without Developer ID signing or Apple notarization.
macOS may block the first launch; see [Apple's opening guidance](https://support.apple.com/en-us/102445).

## Interface changes in 1.2

- The operation workspace acquires keyboard focus when opened. Arrow keys, Enter,
  Escape and text input continue to work after clicking the console or its controls.
- Headings, the sidebar and repeated slogans are simplified while retaining the
  cat theme. Health details are created when expanded.
- Cleanup and project screens use native grouped lists. Categories, search results
  and sorting are recalculated when their inputs change. App icons load lazily and are reused.
- Disk rows show clear names and sizes without a separately calculated ratio chart in every row.

## Features

| Screen | Capabilities |
| --- | --- |
| Quick cleanup | Review caches, old logs and old installers; move selected items to Trash |
| Deep clean | Full Mole scan, paths and sizes by category, exclusions and external volumes |
| Applications | Search installed apps; review size, source, related files and shared data before uninstalling |
| Projects | Discover projects, choose a scan scope, review artifact size and activity, select and confirm cleanup |
| Installers | Filter the engine's installer inventory by source and format, select files, review and move them to Trash |
| Maintenance | Preview and select from 21 engine tasks, manage exclusions and execute the selected tasks |
| Disk explorer | Disk overview, folder drill-down, size sorting, search, large files and Show in Finder |
| Health | Live CPU, memory, hardware, disk, network, power and process information; unavailable values remain unknown |
| History | Pawly operation history and Mole operation/file-handling records |
| Tools and settings | Exclusions, project locations, Touch ID, shell completion and management of a separately installed Mole CLI |

Lists, search, previews and primary cleanup controls use native macOS views.
Final deep cleanup and app uninstall, privileged maintenance, disk multi-selection
and Trash operations, and some settings use the original engine's interactive
screen inside Pawly. Both on-screen controls and keyboard input are supported.
This preserves Mole's existing checks, selection and authorization steps.

Quick cleanup and installer removal use Trash. Project-artifact cleanup removes
files permanently. Full deep cleanup includes permanent removal and emptying
Trash, with the behavior explained before execution. Preview sizes represent
measured logical data, not a promise of immediately reclaimable physical APFS space.

CLI updates require network access and affect only the separately installed CLI,
not the engine bundled with Pawly. CLI management controls are hidden when no
separate installation is available.

Use Command-R for a quick-cleanup scan and Command-O to explore a folder.
Appearance and language controls are in Settings.

## Verification and license

See [FULL_FEATURES.md](docs/pawly/FULL_FEATURES.md) for feature coverage and
[VERIFICATION.md](docs/pawly/VERIFICATION.md) for the verification scope.
Checks focus on interface integration, temporary fixtures and local interactions;
not every platform or real cleanup workflow has been verified.

Mole is licensed under GPL-3.0; see [LICENSE](LICENSE). SwiftTerm uses the MIT
license. Pawly uses its own name, icon and artwork and is not the official Mole
Mac app. Upstream license and trademark notices are included in the app.
Pawly as a whole is distributed under GPL-3.0, without warranty;
see [NOTICE.md](NOTICE.md).
