# Building Pawly

## Requirements

- macOS 14 or newer. The published app is built for Apple Silicon.
- Xcode with a Swift 6 toolchain. The initial public release was built with Swift 6.3.3.
- Go compatible with `go.mod` and its transitive modules. The release uses Go 1.27.1.
- Python 3 for collecting license notices and packaging source archives.
- Network access for the initial SwiftPM and Go dependency resolution.

Install the development tools from [Apple](https://developer.apple.com/xcode/) and
[Go](https://go.dev/dl/). A local developer toolchain is not included in the repo.
`script/build_pawly_engine.sh` uses `go` on PATH, an explicitly supplied `PAWLY_GO`,
or an existing `macos/.toolchain/go/bin/go`.

```bash
./script/build_and_run.sh --build
open dist/Pawly.app
```

This builds the native SwiftUI application and both Go helpers, copies the engine,
artwork and license notices, then verifies the ad-hoc signature. Swift packages
are pinned by `macos/Package.resolved`; Go dependencies by `go.mod` and `go.sum`.
The default app build enables Swift's release optimizer.

- `--stage`: build a separate bundle and print its location, keeping the current app intact.
- `--debug`: build without optimization and open the debugger.
- No flag: build and launch. Finish any cleanup before using this mode because it stops Pawly.

Build on an Intel Mac to experiment with an Intel build; this has not been verified
and the downloadable arm64 app cannot run on an Intel Mac. The deployment target
is macOS 14; runtime verification has been on macOS 26.5.2.

## Targeted checks

```bash
MOLE_TEST_NO_AUTH=1 swift test --package-path macos
MOLE_TEST_NO_AUTH=1 bats tests/pawly_maintenance.bats
```

Bats is needed for the second command. Tests use temporary fixtures and mocked
privileged operations. Never exercise cleanup against personal data as a build check.
Upstream maintenance scripts and their original tests remain in the repository.

## Release contents and corresponding source

Pawly releases use tags such as `pawly-v1.2.0`, separate from the upstream CLI's
`V*` release tags. The app and source download are attached to the same GitHub Release:

- `Pawly-1.2.0-macos-arm64.zip`: application bundle, GPL and dependency notices.
- `Pawly-1.2.0-source.tar.gz`: exact project tree and dependency source archives.
- `SHA256SUMS`: SHA-256 of both downloads.

The source archive includes a `DEPENDENCY_SOURCES.md` index. Its `dependencies/`
directory contains the Swift package sources at the pinned revisions and the Go
module source ZIPs used by the build. These are supplied for access to corresponding
source; the ordinary build still resolves the pinned dependencies through SwiftPM
and Go. Compilers, macOS SDKs and other system tools are not included.

The `Contents/Resources/Pawly-build.json` file records the release's source commit
and build configuration. `Contents/Resources/Licenses` includes dependency notices.

After committing the release source, build with `--stage`, then package the printed
bundle path (replace the example path with the actual staged path):

```bash
python3 script/package_pawly_release.py --version 1.2.0 --app dist/.pawly-build.EXAMPLE/Pawly.app
```

The packager requires a clean source tree and a matching release build. It writes
the three release assets under `dist/releases/pawly-v1.2.0/`.

## Signing

The community build has an ad-hoc code signature. It is not Apple notarized and
has no Developer ID certificate. This is disclosed beside the download. See
[Apple's opening guidance](https://support.apple.com/en-us/102445) for the operating
system's available options. Building locally is also supported. There is no need
to disable Gatekeeper globally or alter system security settings to compile it.
