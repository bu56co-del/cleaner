# Pawly verification scope

Pawly 1.2 was checked on an Apple Silicon Mac running macOS 26.5.2 with
Xcode Swift 6.3.3. The app targets macOS 14 and newer; that deployment target
is not a claim of runtime testing on every supported OS release.

## Checks performed

On 14 September 2026:

| Check | Result |
| --- | --- |
| `MOLE_TEST_NO_AUTH=1 swift test --package-path macos` | 33 tests passed, no failures |
| `MOLE_TEST_NO_AUTH=1 bats tests/pawly_maintenance.bats` | 5 tests passed, no failures |
| `python3 scripts/audit_destructive_sinks.py` | Passed over 58 shell files |
| License collection from pinned dependencies | 46 component notices collected |

These tests cover fixture-based cleanup boundaries, command execution, project
review scope, selected maintenance and presentation behavior. Privileged work is
mocked or disabled; these results do not represent deletion of personal data.

Native UI smoke checks for the 1.2 source changes covered console arrow keys,
Enter, Escape, text input, Control-C and focus after clicking the on-screen
controls; application filtering and icons; disk-search filtering; and collapsed
health details. This is a short interaction check, not a measured performance
benchmark. No numeric speed improvement is claimed.

The release packaging process verifies the app's code signature, architecture,
license files, clean source commit and release configuration. The distributed
bundle records its exact commit in `Contents/Resources/Pawly-build.json`; the
release provides `SHA256SUMS` for the app and matching source archive.

## Limits

- The newly added license links compile, but their native launch smoke check was
  blocked by the local automation approval layer. The notice files were verified
  directly in the bundle.
- The downloadable app is Apple Silicon only. Intel and other macOS versions
  have not been runtime-verified.
- The community build is ad-hoc signed, without Developer ID signing or Apple
  notarization. See the download instructions before opening it.
- The upstream Mole Bats/Go suite was not rerun in full for this GUI publication.
  Existing upstream tests remain available in the repository.
- Deep cleanup and project-artifact removal may permanently delete the exact
  reviewed targets. Trash recovery does not apply to every engine operation.
- Permission-limited or slow scans may return partial results. Logical file sizes
  are not a promise of physical APFS space reclaimed.
- Reusing upstream protection helpers and passing targeted tests is not a claim
  of a complete security audit or proof against every filesystem race.
