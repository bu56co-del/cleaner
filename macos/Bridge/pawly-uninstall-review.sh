#!/bin/bash
# Serializer only: called under the original batch's completed scan scope.
mole_uninstall_review_emit() {
    source "$PAWLY_ENGINE_DIR/lib/core/history.sh"
    local detail name path bundle kb files system sensitive sudo_flag brew cask diagnostic review helpers sibling app_identity original_bundle siblings info_identity
    local list kind encoded file shared=false
    [[ ${#app_details[@]} -eq 1 ]] || return 1
    detail="${app_details[0]}"
    IFS='|' read -r name path bundle kb files system sensitive sudo_flag brew cask diagnostic review helpers sibling app_identity original_bundle siblings info_identity <<< "$detail"
    [[ "$sibling" == none ]] || shared=true
    {
        printf '{"path":'
        history_json_string "$path"
        printf ',"identity":'
        history_json_string "$PAWLY_APP_IDENTITY"
        printf ',"sensitive":%s,"needsAdmin":%s,"shared":%s,"files":[' "${sensitive:-false}" "${sudo_flag:-false}" "$shared"
        printf '{"path":'
        history_json_string "$path"
        printf ',"kind":"app"}'
        for kind in related system review; do
            case "$kind" in related) encoded="$files" ;; system) encoded="$system" ;; review) encoded="$review" ;; esac
            list=$(decode_file_list "$encoded" "$name") || return 1
            while IFS= read -r file; do
                [[ -n "$file" ]] || continue
                printf ',{"path":'
                history_json_string "$file"
                printf ',"kind":'
                history_json_string "$kind"
                printf '}'
            done <<< "$list"
        done
        printf ']}\n'
    } >&3
}
