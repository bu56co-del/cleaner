# Pawly: source, license and attribution

Pawly is an independent, free and open-source macOS interface. It is a modified
work based on the open-source [Mole CLI](https://github.com/tw93/Mole), maintained
here by [bu56co-del](https://github.com/bu56co-del). It is not affiliated with or
endorsed by the Mole project and is not the proprietary Mole for Mac application.

## License

Pawly as a whole is distributed under the **GNU General Public License, version 3**.
You may use, study, modify and redistribute it under that license. It comes
**without any warranty**, including merchantability or fitness for a particular
purpose. The complete, unchanged license is in [LICENSE](LICENSE).

Copyright in upstream components remains with their respective authors.
Pawly additions: Copyright (C) 2026 bu56co-del and contributors.
Third-party components retain their own compatible license notices, included in
the app's `Contents/Resources/Licenses` directory and the source release.

## Modified work notice — 14 September 2026

Base: Mole 1.53.0, commit
`d2a7a12cfbe4560b50c08011f66e469e5f3f5296`, by Tw93 and the Mole contributors.

Pawly adds the native SwiftUI application, its original cat artwork and icon,
Chinese/English interface, SwiftTerm operation console, adapters, tests and
packaging scripts under `macos/`, `script/`, and `tests/pawly_maintenance.bats`.
Changes were developed on 10–14 September 2026. The following upstream files
were adapted for the GUI while retaining the original command-line workflows:

| Modified file | Purpose |
| --- | --- |
| `bin/clean.sh` | Read-only progress checkpoints for preview results |
| `bin/installer.sh` | Allow safe sourcing of the installer catalog |
| `bin/optimize.sh` | Share the validated maintenance pass with native selection |
| `lib/clean/project.sh` | Explicit scan roots, preview rows and exact reviewed selections |
| `lib/manage/whitelist.sh` | Prevent configuration migration during preview |
| `lib/uninstall/batch.sh` | Expose a read-only related-file review |

The Go checksum file includes the transitive source modules distributed with
the release. README, project documentation, ignore rules and GitHub support/release metadata
are adapted to identify and distribute this independent project.

## Corresponding source

Every Pawly binary release links to its exact source commit and includes a
`Pawly-<version>-source.tar.gz` archive alongside the app. This contains the
project source, build scripts, dependency lockfiles and dependency source
archives. There is no source-access charge or registration requirement.
See [BUILDING.md](docs/pawly/BUILDING.md) for toolchain and build instructions.

## Third-party components

- **Mole** — Tw93 and contributors; GPL-3.0. See [LICENSE](LICENSE).
- **SwiftTerm 1.20.0** — Miguel de Icaza and contributors; MIT. Exact revision
  is pinned in `macos/Package.resolved`.
- **Swift Argument Parser** — Apple and contributors; Apache-2.0, with the
  bundled Swift exception. Used by SwiftTerm's development tooling, not as a
  Pawly runtime feature; its revision is also pinned in `Package.resolved`.
- **Go and Go modules** — respective authors. Exact modules are recorded in
  `go.mod` / `go.sum`; applicable license texts accompany the bundled helpers.

The app uses its own Pawly name, icon and generated kitten artwork.
The unchanged upstream [TRADEMARK.md](TRADEMARK.md) covers the Mole name and logo;
no trademark rights or endorsement are granted by this distribution.
