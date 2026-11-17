#!/usr/bin/env bash
# Show every account (slot and username, no passwords) and how much space each uses.
set -euo pipefail
source "$(dirname "$0")/common.sh"
sed -n 's/^SYNC_USER\([0-9]*\)=\([^:]*\):.*/\1 \2/p' .env | sort -n | while read -r slot user; do
  size=$(du -sh "data/$user" 2>/dev/null | cut -f1)
  printf '%3s  %-24s %s\n' "$slot" "$user" "${size:-not synced yet}"
done
