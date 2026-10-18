#!/usr/bin/env bash
# Wrapper: swift build|test cu iesirile pe volumul extern. Utilizare: scripts/mcsp.sh build [-c release] | test [filtre]
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/storage_env.sh
cmd="${1:?build|test}"; shift
exec swift "$cmd" --scratch-path "$MCSP_SCRATCH" "$@"
