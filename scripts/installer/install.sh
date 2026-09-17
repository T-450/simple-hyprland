#!/usr/bin/env bash

set -Eeuo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
exec "$REPO_DIR/install.sh" "$@"
