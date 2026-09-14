#!/bin/bash
# Narrow adapter to Mole's existing recoverable deletion funnel.
# All arguments are literal argv values, never evaluated as shell code.
set -euo pipefail
BRIDGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
if [[ -d "$BRIDGE_DIR/lib/core" ]]; then
    ENGINE_ROOT="$BRIDGE_DIR"
else
    ENGINE_ROOT="$(cd "$BRIDGE_DIR/../.." && pwd -P)"
fi
refuse() {
    printf 'Pawly: %s\n' "$1" >&2
    exit 1
}
[[ $# -eq 5 ]] || refuse "Invalid request."
MODE="$1"
CATEGORY="$2"
TARGET="$3"
IDENTITY="$4"
PARENT_IDENTITY="$5"
case "$MODE" in preview | trash) ;; *) refuse "Unsupported action." ;; esac
[[ "$EUID" -ne 0 ]] || refuse "Administrator execution is not supported."
[[ "$HOME" == /* && "$HOME" != "/" && -d "$HOME" ]] || refuse "Home folder unavailable."
[[ "$TARGET" == /* && "$TARGET" != *$'\n'* && "$TARGET" != *$'\t'* ]] || refuse "Invalid target."
[[ "$IDENTITY" =~ ^[0-9]+:[0-9]+:[0-9]+$ ]] || refuse "Missing file identity."
[[ "$PARENT_IDENTITY" =~ ^[0-9]+:[0-9]+$ ]] || refuse "Missing parent identity."
[[ -e "$TARGET" && ! -L "$TARGET" ]] || refuse "File is missing or a symbolic link. Scan again."
parent="${TARGET%/*}"
component="$TARGET"
while [[ "$component" != "/" && -n "$component" ]]; do
    [[ ! -L "$component" ]] || refuse "Symbolic link paths are not supported."
    [[ "${component##*/}" != "." && "${component##*/}" != ".." ]] || refuse "Invalid path component."
    component="${component%/*}"
done
[[ "$TARGET" != *"//"* ]] || refuse "Invalid path."
[[ "$(/usr/bin/stat -f '%d:%i:%m' "$TARGET")" == "$IDENTITY" ]] || refuse "File changed since scanning. Scan again."
[[ "$(/usr/bin/stat -f '%d:%i' "$parent")" == "$PARENT_IDENTITY" ]] || refuse "Parent folder changed. Scan again."
name="${TARGET##*/}"
case "$CATEGORY" in
    caches)
        [[ "$parent" == "$HOME/Library/Caches" && "$name" != .* ]] || refuse "Outside the cache review scope."
        lower_name="$(printf '%s' "$name" | /usr/bin/tr '[:upper:]' '[:lower:]')"
        case "$lower_name" in
            *com.apple.* | *codex* | *claude* | *com.anthropic* | *opencode* | *huggingface* | *torch* | *orbstack* | *cloudkit*)
                refuse "This app or system cache is protected."
                ;;
        esac
        ;;
    logs)
        [[ "$TARGET" == "$HOME/Library/Logs/"* && -f "$TARGET" && "$name" == *.[lL][oO][gG] ]] || refuse "Outside the log review scope."
        [[ "$TARGET" != "$HOME/Library/Logs/mole/"* && "$TARGET" != "$HOME/Library/Logs/Pawly/"* ]] || refuse "Operation history is protected."
        [[ $(($(date +%s) - ${IDENTITY##*:})) -ge 1209600 ]] || refuse "Log is too recent."
        ;;
    installers)
        [[ "$parent" == "$HOME/Downloads" && -f "$TARGET" ]] || refuse "Outside the installer review scope."
        case "$name" in *.[dD][mM][gG] | *.[pP][kK][gG]) ;; *) refuse "Unsupported installer." ;; esac
        [[ $(($(date +%s) - ${IDENTITY##*:})) -ge 604800 ]] || refuse "Installer is too recent."
        ;;
    installerLibrary)
        # Use the upstream installer format classifier and exact root/depth list.
        # Sourcing loads definitions only; no scan, selection or cleanup runs.
        source "$ENGINE_ROOT/bin/installer.sh"
        [[ -f "$TARGET" ]] || refuse "Not a regular installer file."
        in_installer_scope=false
        for installer_root in "${INSTALLER_SCAN_PATHS[@]}"; do
            if [[ "$TARGET" == "$installer_root/"* ]]; then
                relative_installer="${TARGET#"$installer_root/"}"
                remaining_installer="${relative_installer#*/}"
                if [[ "$relative_installer" != */* || "$remaining_installer" != */* ]]; then
                    in_installer_scope=true
                    break
                fi
            fi
        done
        [[ "$in_installer_scope" == true ]] || refuse "Outside the installer scan scope."
        [[ "$(handle_candidate_file "$TARGET")" == "$TARGET" ]] || refuse "Unsupported installer contents."
        ;;
    *) refuse "Unknown category." ;;
esac
export NO_COLOR=1 MOLE_DELETE_MODE=trash MOLE_CURRENT_COMMAND=analyze
if [[ "$MODE" == "preview" ]]; then
    export MOLE_DRY_RUN=1 MOLE_TEST_NO_AUTH=1
else
    export MOLE_DRY_RUN=0
fi
# shellcheck source=lib/core/common.sh
source "$ENGINE_ROOT/lib/core/common.sh"
load_mole_whitelist "$HOME"
validate_path_for_deletion "$TARGET" || refuse "Mole protected this path."
if should_protect_path "$TARGET" || is_path_whitelisted "$TARGET"; then
    refuse "Protected by Mole or your keep list."
fi
_mole_reset_process_snapshot
cache_rc=0
_mole_should_refuse_live_user_cache_path "$TARGET" || cache_rc=$?
[[ "$cache_rc" -eq 1 ]] || refuse "Cache is active or its owner could not be checked."
if [[ "$CATEGORY" != "caches" ]]; then
    open_rc=0
    open_output="$(run_with_timeout 5 /usr/sbin/lsof -t -- "$TARGET" 2>&1)" || open_rc=$?
    [[ "$open_rc" -eq 1 && -z "$open_output" ]] || refuse "File is in use or could not be checked."
fi
[[ "$(/usr/bin/stat -f '%d:%i:%m' "$TARGET")" == "$IDENTITY" ]] || refuse "File changed during review."
[[ "$(/usr/bin/stat -f '%d:%i' "$parent")" == "$PARENT_IDENTITY" ]] || refuse "Folder changed during review."
# Sole mutation sink: upstream enforces Trash-only behavior and rebinds identities.
mole_delete "$TARGET" false "$IDENTITY" || refuse "Mole could not complete the operation; the item may be protected or in use."
if [[ "$MODE" == "trash" && (-e "$TARGET" || -L "$TARGET") ]]; then
    refuse "The original path still exists. No successful move is reported."
fi
printf 'PAWLY_OK\n'
