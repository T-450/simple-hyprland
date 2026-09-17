#!/usr/bin/env bash

set -Eeuo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
readonly REPO_DIR

# shellcheck source=scripts/lib/install.sh
source "$REPO_DIR/scripts/lib/install.sh"

main "$@"
