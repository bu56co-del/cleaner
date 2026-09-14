#!/bin/bash
# Native view of the canonical deep-clean dry-run ledger; never executes cleanup.
set -euo pipefail
PAWLY_BRIDGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
if [[ -d "$PAWLY_BRIDGE_DIR/bin" ]]; then
    PAWLY_ENGINE_ROOT="$PAWLY_BRIDGE_DIR"
else PAWLY_ENGINE_ROOT="$(cd "$PAWLY_BRIDGE_DIR/../.." && pwd -P)"; fi
[[ $# -eq 0 ]] || exit 2
export MOLE_DRY_RUN=1 MOLE_TEST_NO_AUTH=1 NO_COLOR=1
exec 3>&1
exec 1>&2
source "$PAWLY_ENGINE_ROOT/bin/clean.sh"
source "$PAWLY_ENGINE_ROOT/lib/core/history.sh"
# A checkpoint is a whole deduplicated snapshot, one JSON object per line.
# It remains a partial preview until the final completed record arrives.
mole_clean_preview_checkpoint() {
    local PAWLY_STATUS="${1:-1}"
    {
        printf '{"complete":'
        if [[ $PAWLY_STATUS -eq 0 ]]; then printf true; else printf false; fi
        printf ',"systemIncluded":%s,"items":[' "$SYSTEM_CLEAN"
        PAWLY_INDEX=0
        while IFS= read -r -d '' PAWLY_ID && IFS= read -r -d '' PAWLY_SIZE && IFS= read -r -d '' PAWLY_COUNT && IFS= read -r -d '' PAWLY_KNOWN && IFS= read -r -d '' PAWLY_SECTION && IFS= read -r -d '' PAWLY_PATH; do
            [[ "$PAWLY_SIZE" =~ ^[0-9]+$ && "$PAWLY_COUNT" =~ ^[0-9]+$ ]] || exit 1
            [[ $PAWLY_INDEX -eq 0 ]] || printf ','
            printf '{"id":'
            history_json_string "$PAWLY_ID"
            printf ',"path":'
            history_json_string "$PAWLY_PATH"
            printf ',"section":'
            history_json_string "$PAWLY_SECTION"
            printf ',"bytes":%s,"count":%s,"known":%s}' "$((PAWLY_SIZE * 1024))" "$PAWLY_COUNT" "$PAWLY_KNOWN"
            PAWLY_INDEX=$((PAWLY_INDEX + 1))
        done < <(emit_deduplicated_dry_run_ledger)
        printf ']}\n'
    } >&3

}
CLEAN_PREVIEW_FINAL_FILE="$(create_temp_file)"
start_cleanup
PAWLY_STATUS=0
perform_cleanup || PAWLY_STATUS=$?
mole_clean_preview_checkpoint "$PAWLY_STATUS"
