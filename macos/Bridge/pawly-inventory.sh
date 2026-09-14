#!/bin/bash
set -euo pipefail
PAWLY_BRIDGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
if [[ -d "$PAWLY_BRIDGE_DIR/bin" ]]; then
    PAWLY_ENGINE_ROOT="$PAWLY_BRIDGE_DIR"
else
    PAWLY_ENGINE_ROOT="$(cd "$PAWLY_BRIDGE_DIR/../.." && pwd -P)"
fi
[[ $# -eq 1 && "$1" == installers ]] || {
    echo "Unsupported inventory request" >&2
    exit 2
}
export MOLE_DRY_RUN=1 MOLE_TEST_NO_AUTH=1 NO_COLOR=1
source "$PAWLY_ENGINE_ROOT/bin/installer.sh"
source "$PAWLY_ENGINE_ROOT/lib/core/history.sh"
exec 3>&1
exec 1>&2
# Keep every diagnostic off the structured output channel.
if ! collect_installers >&2; then
    printf '[]\n' >&3
    exit 0
fi
printf '[' >&3
for ((PAWLY_INDEX = 0; PAWLY_INDEX < ${#INSTALLER_PATHS[@]}; PAWLY_INDEX++)); do
    [[ $PAWLY_INDEX -eq 0 ]] || printf ',' >&3
    {
        printf '{"path":'
        history_json_string "${INSTALLER_PATHS[$PAWLY_INDEX]}"
        printf ',"source":'
        history_json_string "${INSTALLER_SOURCES[$PAWLY_INDEX]}"
        printf ',"bytes":%s}' "${INSTALLER_SIZES[$PAWLY_INDEX]}"
    } >&3
done
printf ']\n' >&3
# cleanup() may print terminal control bytes. Keep those off JSON stdout too.
exec 1>&2
