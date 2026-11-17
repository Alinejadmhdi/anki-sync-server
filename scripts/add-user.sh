#!/usr/bin/env bash
# Add a sync account, or change the password of an existing one.
#
#   ./scripts/add-user.sh <username> [password]
#
# A new username gets the next free slot; an existing one keeps its slot and gets
# the new password. Without a password one is generated. Restarts the server.
set -euo pipefail
source "$(dirname "$0")/common.sh"

if [[ $# -lt 1 ]]; then
  sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
fi
user=$1 pass=${2:-$(random_password)}
[[ $user =~ ^[A-Za-z0-9._@-]+$ ]] || { echo "username: letters, digits and . _ @ - only"; exit 1; }
[[ $pass != *[:\|[:space:]]* ]] || { echo "password can't contain ':', '|' or spaces"; exit 1; }
[[ -f .env ]] || { echo ".env not found - run ./install.sh first"; exit 1; }

slot=$(sed -n "s/^SYNC_USER\([0-9]*\)=${user}:.*/\1/p" .env | head -1)
if [[ -z $slot ]]; then
  slot=1
  while grep -q "^SYNC_USER${slot}=" .env; do slot=$((slot + 1)); done
fi
set_slot "$slot" "$user" "$pass"
restart_server

source .env
cat <<EOF

Account ready (slot $slot) - send this to the customer:
  Sync server: ${PUBLIC_URL:-http://<server-ip>:${SYNC_PORT}/}
  Username:    $user
  Password:    $pass
EOF
