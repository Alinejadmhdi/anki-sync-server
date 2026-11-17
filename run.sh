#!/usr/bin/env bash
# Start the sync server in the foreground with the settings and accounts from .env.
# systemd runs this; you can also run it by hand to test.
set -euo pipefail
cd "$(dirname "$0")"
set -a
source .env
set +a
export SYNC_BASE="$PWD/data" PYTHONUNBUFFERED=1
exec .venv/bin/python -m anki.syncserver
