#!/bin/bash
# Read the original purge scan/measurement plan without selecting or deleting.
set -euo pipefail
PAWLY_BRIDGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
if [[ -d "$PAWLY_BRIDGE_DIR/bin" ]]; then
    PAWLY_ENGINE_ROOT="$PAWLY_BRIDGE_DIR"
else
    PAWLY_ENGINE_ROOT="$(cd "$PAWLY_BRIDGE_DIR/../.." && pwd -P)"
fi
PAWLY_MODE="${1:-}"
PAWLY_SELECTION=()
PAWLY_ROOTS=()
case "$PAWLY_MODE" in
    inventory)
        [[ $# -eq 1 || $# -eq 2 ]] || exit 2
        [[ $# -eq 1 ]] || PAWLY_ROOTS=("$2")
        export MOLE_DRY_RUN=1
        ;;
    preview-selection | purge-selection)
        [[ "${2:-}" =~ ^[0-9]+$ && "$2" -gt 0 && "$2" -le 100 ]] || exit 2
        PAWLY_COUNT="$2"
        shift 2
        [[ $# -eq $((PAWLY_COUNT * 13)) ]] || exit 2
        PAWLY_SELECTION=("$@")
        # Immutable argv tuples: path, target/parent identities, activity, cloud,
        # bytes, unknown-size, lexical root + identities, physical root + identities.
        for ((PAWLY_I = 0; PAWLY_I < ${#PAWLY_SELECTION[@]}; PAWLY_I += 13)); do
            PAWLY_ROOTS+=("${PAWLY_SELECTION[$((PAWLY_I + 7))]}")
        done
        if [[ "$PAWLY_MODE" == preview-selection ]]; then
            export MOLE_DRY_RUN=1
        else unset MOLE_DRY_RUN; fi
        ;;
    *)
        echo "Unsupported project request" >&2
        exit 2
        ;;
esac
for PAWLY_ROOT in "${PAWLY_ROOTS[@]+"${PAWLY_ROOTS[@]}"}"; do
    [[ "$PAWLY_ROOT" == /* && -d "$PAWLY_ROOT" && ! -L "$PAWLY_ROOT" && "$PAWLY_ROOT" != *$'\n'* && "$PAWLY_ROOT" != *$'\t'* ]] || {
        echo "Choose an existing project folder" >&2
        exit 2
    }
done
export MOLE_TEST_NO_AUTH=1 MOLE_SKIP_MAIN=1 NO_COLOR=1
exec 3>&1
exec 1>&2
if [[ ${#PAWLY_ROOTS[@]} -gt 0 ]]; then
    source "$PAWLY_ENGINE_ROOT/bin/purge.sh" --scan-root "${PAWLY_ROOTS[0]}"
    PURGE_SEARCH_PATHS=("${PAWLY_ROOTS[@]}")
else
    source "$PAWLY_ENGINE_ROOT/bin/purge.sh"
fi
source "$PAWLY_ENGINE_ROOT/lib/core/history.sh"
# Original scan progress uses a cache directory. Confine preview bookkeeping to
# a tracked temporary directory; leave the user's persistent purge stats alone.
export XDG_CACHE_HOME="$(create_temp_dir)"
mkdir -p "$XDG_CACHE_HOME/mole"
PAWLY_REVIEW_EMITTED=false
mole_purge_review_emit() {
    PAWLY_REVIEW_EMITTED=true
    local i root_index binding
    printf '{"outcome":' >&3
    history_json_string "$PURGE_RUN_OUTCOME" >&3
    printf ',"items":[' >&3
    for ((i = 0; i < ${#item_paths[@]}; i++)); do
        [[ $i -eq 0 ]] || printf ',' >&3
        {
            printf '{"path":'
            history_json_string "${item_paths[$i]}"
            printf ',"project":'
            history_json_string "${item_project_paths[$i]}"
            printf ',"artifact":'
            history_json_string "${menu_options[$i]}"
            printf ',"bytes":%s' "$((${item_sizes[$i]} * 1024))"
            printf ',"unknownSize":%s' "${item_size_unknown_flags[$i]}"
            printf ',"activity":'
            history_json_string "${item_activity_states[$i]}"
            printf ',"age":'
            history_json_string "${item_age_labels[$i]}"
            printf ',"cloud":%s' "${item_cloud_flags[$i]}"
            printf ',"targetIdentity":'
            history_json_string "${item_expected_target_ids[$i]}"
            printf ',"parentIdentity":'
            history_json_string "${item_expected_parent_ids[$i]}"
            printf ',"scanRoot":'
            history_json_string "${scan_roots[${item_scan_root_indexes[$i]}]}"
            root_index="${item_scan_root_indexes[$i]}"
            printf ',"rootBindings":['
            local binding_index=0
            for binding in "${scan_roots[$root_index]}" "${scan_root_parent_ids[$root_index]}" "${scan_root_target_ids[$root_index]}" "${scan_root_physical_paths[$root_index]}" "${scan_root_physical_parent_ids[$root_index]}" "${scan_root_physical_target_ids[$root_index]}"; do
                [[ $binding_index -eq 0 ]] || printf ','
                history_json_string "$binding"
                binding_index=$((binding_index + 1))
            done
            printf ']}'
        } >&3
    done
    printf ']}\n' >&3
}
# Exact matching is all-or-nothing before deletion. A missing, resized, replaced,
# newly protected or differently active item invalidates the native review.
# This callback selects only; original per-item and final safe_remove guards stay.
mole_purge_select_reviewed() {
    [[ "$PURGE_RUN_OUTCOME" == completed ]] || {
        echo "Scan incomplete. Review again." >&2
        return 1
    }
    local offset i j root_index found
    local -a row=()
    local matched=""
    for ((offset = 0; offset < ${#PAWLY_SELECTION[@]}; offset += 13)); do
        found=false
        for ((i = 0; i < ${#item_paths[@]}; i++)); do
            [[ "${item_paths[$i]}" == "${PAWLY_SELECTION[$offset]}" ]] || continue
            root_index="${item_scan_root_indexes[$i]}"
            row=("${item_paths[$i]}" "${item_expected_target_ids[$i]}" "${item_expected_parent_ids[$i]}" "${item_activity_states[$i]}" "${item_cloud_flags[$i]}" "$((${item_sizes[$i]} * 1024))" "${item_size_unknown_flags[$i]}" "${scan_roots[$root_index]}" "${scan_root_parent_ids[$root_index]}" "${scan_root_target_ids[$root_index]}" "${scan_root_physical_paths[$root_index]}" "${scan_root_physical_parent_ids[$root_index]}" "${scan_root_physical_target_ids[$root_index]}")
            for ((j = 0; j < 13; j++)); do
                [[ "${row[$j]}" == "${PAWLY_SELECTION[$((offset + j))]}" ]] || {
                    echo "Project or artifact changed. Scan and review again." >&2
                    return 1
                }
            done
            [[ ",$matched," != *",$i,"* ]] || {
                echo "Duplicate selection refused." >&2
                return 1
            }
            [[ -z "$matched" ]] || matched+=","
            matched+="$i"
            found=true
            break
        done
        [[ "$found" == true ]] || {
            echo "Selected artifact is no longer available. Scan again." >&2
            return 1
        }
    done
    PURGE_SELECTION_RESULT="$matched"
    PAWLY_SELECTION_MATCHED=true
}
if [[ "$PAWLY_MODE" == inventory ]]; then
    clean_project_artifacts --review
    if [[ "$PAWLY_REVIEW_EMITTED" == false ]]; then
        printf '{"outcome":' >&3
        history_json_string "$PURGE_RUN_OUTCOME" >&3
        printf ',"items":[]}\n' >&3
    fi
else
    PAWLY_SELECTION_MATCHED=false
    export MOLE_CURRENT_COMMAND=purge MOLE_DELETE_MODE=permanent
    log_operation_session_start purge
    clean_project_artifacts --reviewed-selection
    [[ "$PAWLY_SELECTION_MATCHED" == true ]] || {
        echo "Selection unavailable. Scan again." >&2
        exit 1
    }
    log_operation_session_end purge "$(cat "$XDG_CACHE_HOME/mole/purge_count")" "$(cat "$XDG_CACHE_HOME/mole/purge_stats" 2> /dev/null || echo 0)"
    printf '{"outcome":' >&3
    history_json_string "$PURGE_RUN_OUTCOME" >&3
    printf ',"processed":%s}\n' "$(cat "$XDG_CACHE_HOME/mole/purge_count")" >&3
fi
