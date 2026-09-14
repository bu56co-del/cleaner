#!/bin/bash
# Closed adapter for the bundled Mole interactive workflows. Never evaluate UI text.
set -euo pipefail
PAWLY_ENGINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION="${1:-}"
MODE="${2:-}"
[[ "$MODE" == "preview" || "$MODE" == "run" ]] || {
    echo "Invalid operation mode" >&2
    exit 2
}
[[ $# -eq 2 || $# -eq 4 ]] || {
    echo "Invalid operation arguments" >&2
    exit 2
}
if [[ "$MODE" == "preview" ]]; then
    export MOLE_DRY_RUN=1 MOLE_TEST_NO_AUTH=1
fi
case "$ACTION" in
    deepClean)
        if [[ $# -eq 4 ]]; then
            [[ "$3" == /Volumes/* && -d "$3" && ! -L "$3" ]] || {
                echo "Choose an external volume under /Volumes" >&2
                exit 2
            }
            exec /bin/bash "$PAWLY_ENGINE_DIR/bin/clean.sh" --external "$3"
        fi
        exec /bin/bash "$PAWLY_ENGINE_DIR/bin/clean.sh"
        ;;
    uninstall | uninstallReview)
        if [[ "$ACTION" == uninstallReview ]]; then
            [[ "$MODE" == preview && $# -eq 4 ]] || exit 2
            exec 3>&1
            exec 1>&2
        fi
        if [[ $# -eq 2 ]]; then exec /bin/bash "$PAWLY_ENGINE_DIR/bin/uninstall.sh"; fi
        # Match only the exact inventory path, never the CLI's fuzzy name matcher.
        PAWLY_APP_PATH="$3"
        PAWLY_APP_IDENTITY="$4"
        [[ "$PAWLY_APP_PATH" == /* && "$PAWLY_APP_PATH" == *.app && ! -L "$PAWLY_APP_PATH" ]] || exit 2
        [[ "$PAWLY_APP_PATH" != *$'\n'* && "$PAWLY_APP_PATH" != *'|'* ]] || exit 2
        [[ "$(/usr/bin/stat -f '%d:%i:%m' "$PAWLY_APP_PATH" 2> /dev/null)" == "$PAWLY_APP_IDENTITY" ]] || {
            echo "App changed. Refresh the application list." >&2
            exit 1
        }
        source "$PAWLY_ENGINE_DIR/bin/uninstall.sh"
        export MOLE_CURRENT_COMMAND=uninstall MOLE_DELETE_MODE=trash
        log_operation_session_start uninstall
        PAWLY_APPS_FILE="$(scan_applications)" || exit 1
        load_applications "$PAWLY_APPS_FILE" || exit 1
        selected_apps=()
        for PAWLY_APP_DATA in "${apps_data[@]+"${apps_data[@]}"}"; do
            IFS='|' read -r _ PAWLY_SCANNED_PATH _ <<< "$PAWLY_APP_DATA"
            if [[ "$PAWLY_SCANNED_PATH" == "$PAWLY_APP_PATH" ]]; then selected_apps+=("$PAWLY_APP_DATA"); fi
        done
        [[ ${#selected_apps[@]} -eq 1 ]] || {
            echo "App unavailable or protected; refresh the application list." >&2
            exit 1
        }
        [[ "$(/usr/bin/stat -f '%d:%i:%m' "$PAWLY_APP_PATH" 2> /dev/null)" == "$PAWLY_APP_IDENTITY" ]] || {
            echo "App changed during scan." >&2
            exit 1
        }
        if [[ "$ACTION" == uninstallReview ]]; then
            source "$PAWLY_ENGINE_DIR/pawly-uninstall-review.sh"
            batch_uninstall_applications --review
        else
            batch_uninstall_applications
        fi
        ;;
    purge)
        if [[ $# -eq 2 ]]; then exec /bin/bash "$PAWLY_ENGINE_DIR/bin/purge.sh"; fi
        [[ "$3" == /* && -d "$3" && ! -L "$3" && "$3" != *$'\n'* && "$3" != *$'\t'* ]] || {
            echo "Choose an existing project folder" >&2
            exit 2
        }
        export MOLE_SKIP_MAIN=1
        source "$PAWLY_ENGINE_DIR/bin/purge.sh" --scan-root "$3"
        unset MOLE_SKIP_MAIN
        main
        ;;
    installer) exec /bin/bash "$PAWLY_ENGINE_DIR/bin/installer.sh" ;;
    optimize)
        if [[ $# -eq 2 ]]; then exec /bin/bash "$PAWLY_ENGINE_DIR/bin/optimize.sh"; fi
        [[ "$3" =~ ^[a-z0-9_]+(,[a-z0-9_]+)*$ ]] || {
            echo "Invalid maintenance selection" >&2
            exit 2
        }
        source "$PAWLY_ENGINE_DIR/bin/optimize.sh"
        IFS=',' read -r -a PAWLY_OPTIMIZE_SELECTION <<< "$3"
        optimize_run_pass "${PAWLY_OPTIMIZE_SELECTION[@]}"
        ;;
    analyze)
        if [[ $# -eq 4 ]]; then
            [[ "$3" == /* && -d "$3" ]] || exit 2
            exec "$PAWLY_ENGINE_DIR/bin/analyze-go" "$3"
        fi
        exec "$PAWLY_ENGINE_DIR/bin/analyze-go"
        ;;
    cleanWhitelist) exec /bin/bash "$PAWLY_ENGINE_DIR/bin/clean.sh" --whitelist ;;
    optimizeWhitelist) exec /bin/bash "$PAWLY_ENGINE_DIR/bin/optimize.sh" --whitelist ;;
    purgePaths) exec /bin/bash "$PAWLY_ENGINE_DIR/bin/purge.sh" --paths ;;
    touchID)
        if [[ "$MODE" == "preview" ]]; then exec /bin/bash "$PAWLY_ENGINE_DIR/bin/touchid.sh" status; fi
        exec /bin/bash "$PAWLY_ENGINE_DIR/bin/touchid.sh"
        ;;
    completion) exec /bin/bash "$PAWLY_ENGINE_DIR/bin/completion.sh" ;;
    cliUpdate | cliRemove)
        [[ $# -eq 4 && -x "$3" && ! -L "$3" ]] || exit 2
        # Only separately installed CLI locations. Never self-modify bundled
        # resources or accept an arbitrary executable from a GUI text field.
        case "$3" in
            /opt/homebrew/Cellar/mole/*/bin/mole | /opt/homebrew/Cellar/mole/*/libexec/mole | /usr/local/Cellar/mole/*/bin/mole | /usr/local/Cellar/mole/*/libexec/mole | /usr/local/bin/mole | /usr/local/bin/mo | "$HOME"/.local/bin/mole | "$HOME"/.local/bin/mo | /opt/homebrew/bin/mole | /opt/homebrew/bin/mo) ;;
            *)
                echo "Unsupported standalone CLI location. Manage this installation in Terminal." >&2
                exit 2
                ;;
        esac
        [[ "$3" != *'.app/'* && "$(/usr/bin/stat -f '%d:%i:%m' "$3")" == "$4" ]] || {
            echo "CLI changed. Refresh its status." >&2
            exit 1
        }
        if [[ "$ACTION" == cliUpdate ]]; then
            if [[ "$MODE" == preview ]]; then exec "$3" --version; else exec "$3" update; fi
        else
            if [[ "$MODE" == preview ]]; then exec "$3" remove --dry-run; else exec "$3" remove; fi
        fi
        ;;
    *)
        echo "Unsupported Pawly operation" >&2
        exit 2
        ;;
esac
