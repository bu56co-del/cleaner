# Pawly design and architecture

Pawly uses native SwiftUI on macOS 14+, with a small AppKit bridge around SwiftTerm.
The interface has cream/dark surfaces, coral actions, sage status accents, small
rounded panels and original generated kitten artwork. Chinese is the default;
English and appearance settings are available in Preferences.

## Presentation

Version 1.2 favors compact functional headings and native lists. Clean/project
results are grouped once when source data or search changes. App icons are loaded
when needed and reused. Health details are built when expanded. The operation
console takes keyboard focus on attachment, click and use of its control buttons.

The numbers shown come from actual engine reports. An incomplete scan remains
incomplete; unknown sizes are not displayed as measured zero. Logical bytes are
separate from immediately reclaimable storage.

## Execution

- `macos/Sources/Pawly`: views and observable stores.
- `macos/Sources/PawlyCore`: reports, scanners, command runner and engine clients.
- `macos/Sources/PawlySpawn`: owned process-group spawning and cancellation.
- `macos/Bridge`: closed argument adapters into the bundled Mole engine.
- `script`: build and packaging helpers.

Native views handle inventory, filtering and review. The existing engine handles
path/app protection, selected mutations, logs and authorization. Interactive final
operations use SwiftTerm inside Pawly. The separately installed Mole CLI and the
bundled engine are treated as distinct targets.

Cleanup recovery differs by feature; the app explains it before confirmation.
There is no automatic background cleaner. Any future cleanup change must preserve
the original engine's safety boundaries and preview/action consistency.

## Artwork

The kitten illustration and cat icon are Pawly artwork, not Mole assets.
The illustration was generated for this project: a cream kitten with orange
patches sweeping with a broom, in a warm picture-book style. Source artwork and
icon sizes are included under `macos/Sources/Pawly/Resources` and `macos/Resources`.
