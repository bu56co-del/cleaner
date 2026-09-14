#!/bin/bash
set -euo pipefail
PAWLY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PAWLY_GO="${PAWLY_GO:-}"
if [[ -z "$PAWLY_GO" ]]; then
    if [[ -x "$PAWLY_ROOT/macos/.toolchain/go/bin/go" ]]; then
        PAWLY_GO="$PAWLY_ROOT/macos/.toolchain/go/bin/go"
    else
        PAWLY_GO="$(command -v go || true)"
    fi
fi
if [[ -z "$PAWLY_GO" || ! -x "$PAWLY_GO" ]]; then
    echo "Go is required to build Pawly's bundled engine. Install Go from https://go.dev/dl/ or set PAWLY_GO to its absolute path." >&2
    exit 1
fi
cd "$PAWLY_ROOT"
export GOTOOLCHAIN=local
export GOPATH="$PAWLY_ROOT/macos/.toolchain/gopath"
export GOMODCACHE="$PAWLY_ROOT/.gomod"
export GOCACHE="$PAWLY_ROOT/.gocache"
"$PAWLY_GO" build -trimpath -o "$PAWLY_ROOT/bin/status-go" ./cmd/status
"$PAWLY_GO" build -trimpath -o "$PAWLY_ROOT/bin/analyze-go" ./cmd/analyze
