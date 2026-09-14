#!/bin/bash
# Read-only native maintenance catalog and per-task preview. Real execution
# remains in optimize_run_pass, including its authorization and outcome logging.
set -euo pipefail
PAWLY_BRIDGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
if [[ -d "$PAWLY_BRIDGE_DIR/bin" ]]; then
    PAWLY_ENGINE_ROOT="$PAWLY_BRIDGE_DIR"
else
    PAWLY_ENGINE_ROOT="$(cd "$PAWLY_BRIDGE_DIR/../.." && pwd -P)"
fi
[[ $# -eq 1 && "$1" == catalog || $# -eq 2 && "$1" == preview ]] || {
    echo "Unsupported maintenance request" >&2
    exit 2
}
export MOLE_DRY_RUN=1 MOLE_TEST_NO_AUTH=1 NO_COLOR=1
source "$PAWLY_ENGINE_ROOT/bin/optimize.sh"
source "$PAWLY_ENGINE_ROOT/lib/core/history.sh"
load_whitelist optimize
exec 3>&1
exec 1>&2
if [[ "$1" == catalog ]]; then
    printf '[' >&3
    for ((PAWLY_INDEX = 0; PAWLY_INDEX < ${#MOLE_OPTIMIZE_ACTIONS[@]}; PAWLY_INDEX++)); do
        [[ $PAWLY_INDEX -eq 0 ]] || printf ',' >&3
        PAWLY_EXCLUDED=false
        if is_whitelisted "${MOLE_OPTIMIZE_ACTIONS[$PAWLY_INDEX]}"; then PAWLY_EXCLUDED=true; fi
        {
            printf '{"id":'
            history_json_string "${MOLE_OPTIMIZE_ACTIONS[$PAWLY_INDEX]}"
            printf ',"name":'
            history_json_string "${MOLE_OPTIMIZE_HEALTH_NAMES[$PAWLY_INDEX]}"
            printf ',"detail":'
            history_json_string "${MOLE_OPTIMIZE_DESCRIPTIONS[$PAWLY_INDEX]}"
            printf ',"excluded":%s}' "$PAWLY_EXCLUDED"
        } >&3
    done
    printf ']\n' >&3
else
    optimize_catalog_index_for "$2" > /dev/null || {
        echo "Unknown maintenance task" >&2
        exit 2
    }
    PAWLY_PREVIEW_LOG="$(create_temp_file)"
    export MOLE_OPTIMIZE_SUDO_AVAILABLE=true
    optimize_outcomes_reset
    # Do not place execute_optimization in a conditional: retain errexit within
    # task handlers so an incomplete probe cannot produce a successful preview.
    execute_optimization "$2" > "$PAWLY_PREVIEW_LOG" 2>&1
    [[ "$(optimize_outcome_total)" -eq 1 ]] || {
        echo "Incomplete task preview" >&2
        exit 1
    }
    {
        printf '{"id":'
        history_json_string "$2"
        printf ',"outcome":'
        history_json_string "${MOLE_OPTIMIZE_RESULT_OUTCOMES[0]}"
        printf ',"detail":'
        history_json_string "$(cat "$PAWLY_PREVIEW_LOG")"
        printf '}\n'
    } >&3
fi
