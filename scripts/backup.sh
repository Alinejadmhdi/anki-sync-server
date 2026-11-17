#!/usr/bin/env bash
# Copy everyone's collections and media into backups/anki-YYYY-MM-DD.tgz and keep the last 14.
# The server is paused while copying (a few seconds) so the databases aren't caught mid-write.
# Schedule it daily with cron (see README).
set -euo pipefail
source "$(dirname "$0")/common.sh"
mkdir -p backups
out="backups/anki-$(date +%F).tgz"

paused=false
service stop 2>/dev/null && paused=true
trap '$paused && service start' EXIT
tar czf "$out" data .env

ls -1t backups/anki-*.tgz | tail -n +15 | xargs -r rm --
echo "$out ($(du -h "$out" | cut -f1))"
