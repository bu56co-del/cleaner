#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-run}"
case "$MODE" in run | --build | --stage | --verify | --debug | --logs | --telemetry) ;; *)
    echo "Usage: $0 [--build|--stage|--verify|--debug|--logs|--telemetry]" >&2
    exit 2
    ;;
esac
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Pawly"
BUNDLE_ID="com.yaka.pawly"
DIST_DIR="$ROOT_DIR/dist"
mkdir -p "$DIST_DIR"
STAGING_DIR="$(mktemp -d "$DIST_DIR/.pawly-build.XXXXXX")"
APP_BUNDLE="$STAGING_DIR/Pawly.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
if [[ "$MODE" != "--build" && "$MODE" != "--stage" ]]; then
    pkill -x "$APP_NAME" > /dev/null 2>&1 || true
fi
cd "$ROOT_DIR"
"$ROOT_DIR/script/build_pawly_engine.sh"
# The app users run should include Swift's optimizer (especially SwiftTerm).
# Keep debug symbols and unoptimized code available through --debug.
CONFIGURATION=release
if [[ "$MODE" == "--debug" ]]; then CONFIGURATION=debug; fi
swift build -c "$CONFIGURATION" --package-path "$ROOT_DIR/macos" --scratch-path "$ROOT_DIR/macos/.build"
BIN_DIR="$(swift build -c "$CONFIGURATION" --package-path "$ROOT_DIR/macos" --scratch-path "$ROOT_DIR/macos/.build" --show-bin-path)"
mkdir -p "$APP_CONTENTS/MacOS" "$APP_CONTENTS/Resources/engine/lib"
cp "$BIN_DIR/Pawly" "$APP_CONTENTS/MacOS/Pawly"
ditto "$BIN_DIR/Pawly_Pawly.bundle" "$APP_CONTENTS/Resources/Pawly_Pawly.bundle"
cp "$ROOT_DIR/macos/Sources/Pawly/Resources/mascot.png" "$APP_CONTENTS/Resources/mascot.png"
ditto "$ROOT_DIR/lib" "$APP_CONTENTS/Resources/engine/lib"
ditto "$ROOT_DIR/bin" "$APP_CONTENTS/Resources/engine/bin"
cp "$ROOT_DIR/mole" "$APP_CONTENTS/Resources/engine/mole"
cp "$ROOT_DIR/macos/Bridge/pawly-bridge.sh" "$APP_CONTENTS/Resources/engine/pawly-bridge.sh"
cp "$ROOT_DIR/macos/Bridge/pawly-console.sh" "$APP_CONTENTS/Resources/engine/pawly-console.sh"
cp "$ROOT_DIR/macos/Bridge/pawly-projects.sh" "$APP_CONTENTS/Resources/engine/pawly-projects.sh"
cp "$ROOT_DIR/macos/Bridge/pawly-clean-preview.sh" "$APP_CONTENTS/Resources/engine/pawly-clean-preview.sh"
cp "$ROOT_DIR/macos/Bridge/pawly-uninstall-review.sh" "$APP_CONTENTS/Resources/engine/pawly-uninstall-review.sh"
cp "$ROOT_DIR/macos/Bridge/pawly-maintenance.sh" "$APP_CONTENTS/Resources/engine/pawly-maintenance.sh"
cp "$ROOT_DIR/macos/Bridge/pawly-inventory.sh" "$APP_CONTENTS/Resources/engine/pawly-inventory.sh"
ditto "$BIN_DIR/SwiftTerm_SwiftTerm.bundle" "$APP_CONTENTS/Resources/SwiftTerm_SwiftTerm.bundle"
# SwiftTerm locates resource bundles under Contents/Resources without invoking
# SwiftPM's checkout-dependent Bundle.module fallback.
/usr/bin/install -m 644 "$ROOT_DIR/macos/.build/checkouts/SwiftTerm/LICENSE" "$APP_CONTENTS/Resources/SwiftTerm-LICENSE"
cp "$ROOT_DIR/LICENSE" "$APP_CONTENTS/Resources/LICENSE"
cp "$ROOT_DIR/TRADEMARK.md" "$APP_CONTENTS/Resources/UPSTREAM-TRADEMARK.md"
cp "$ROOT_DIR/NOTICE.md" "$APP_CONTENTS/Resources/NOTICE.md"
python3 "$ROOT_DIR/script/collect_pawly_licenses.py" "$APP_CONTENTS/Resources/Licenses"
python3 - "$ROOT_DIR" "$APP_CONTENTS/Resources/Pawly-build.json" "$CONFIGURATION" << 'PY'
import json, pathlib, subprocess, sys
root, output, configuration = sys.argv[1:]
commit = subprocess.check_output(["git", "-C", root, "rev-parse", "HEAD"], text=True).strip()
dirty = bool(subprocess.check_output(["git", "-C", root, "status", "--porcelain"], text=True).strip())
pathlib.Path(output).write_text(json.dumps({"source_commit": commit, "source_dirty": dirty,
    "source_url": "https://github.com/bu56co-del/cleaner/tree/" + commit,
    "configuration": configuration}, indent=2) + "\n")
PY
if [[ -f "$ROOT_DIR/macos/Resources/Pawly.icns" ]]; then
    cp "$ROOT_DIR/macos/Resources/Pawly.icns" "$APP_CONTENTS/Resources/Pawly.icns"
fi
cat > "$APP_CONTENTS/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Pawly</string>
<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
<key>CFBundleName</key><string>Pawly</string>
<key>CFBundleDisplayName</key><string>Pawly</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.2</string>
<key>CFBundleVersion</key><string>3</string>
<key>CFBundleIconFile</key><string>Pawly</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSAppleEventsUsageDescription</key><string>Pawly uses Finder to reveal files and perform confirmed moves to Trash.</string>
<key>NSHumanReadableCopyright</key><string>Pawly · GPL-3.0. Includes Mole open-source components.</string>
</dict></plist>
PLIST
codesign --force --deep --sign - "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"
# Prepare an update without replacing resources used by a running cleanup.
if [[ "$MODE" == "--stage" ]]; then
    echo "Staged: $APP_BUNDLE"
    exit 0
fi
# Assemble and verify a new bundle before replacing the runnable app. Preserve
# the prior generated bundle in this build's staging directory for recovery.
if [[ -d "$DIST_DIR/Pawly.app" ]]; then
    mv "$DIST_DIR/Pawly.app" "$STAGING_DIR/Pawly.previous.app"
fi
mv "$APP_BUNDLE" "$DIST_DIR/Pawly.app"
APP_BUNDLE="$DIST_DIR/Pawly.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
case "$MODE" in
    --build) echo "Built: $APP_BUNDLE" ;;
    --debug) lldb -- "$APP_CONTENTS/MacOS/Pawly" ;;
    --logs)
        /usr/bin/open -n "$APP_BUNDLE"
        /usr/bin/log stream --info --style compact --predicate 'process == "Pawly"'
        ;;
    --telemetry)
        /usr/bin/open -n "$APP_BUNDLE"
        /usr/bin/log stream --info --style compact --predicate 'subsystem == "com.yaka.pawly"'
        ;;
    --verify)
        /usr/bin/open -n "$APP_BUNDLE"
        sleep 2
        pgrep -x Pawly > /dev/null
        echo "Pawly launched."
        ;;
    run) /usr/bin/open -n "$APP_BUNDLE" ;;
esac
