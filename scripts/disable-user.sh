#!/usr/bin/env bash
# Lock a customer out without breaking the other accounts.
#
#   ./scripts/disable-user.sh <username>
#
# Their password is replaced by a random one nobody knows. Their cards stay on the
# server; run add-user.sh with their username to let them back in. Deleting the line
# instead would leave a gap in the numbering and lock out every account after it.
set -euo pipefail
source "$(dirname "$0")/common.sh"

[[ $# -eq 1 ]] || { sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
user=$1
slot=$(sed -n "s/^SYNC_USER\([0-9]*\)=${user}:.*/\1/p" .env | head -1)
[[ -n $slot ]] || { echo "no account named $user in .env"; exit 1; }
set_slot "$slot" "$user" "$(random_password 24)"
restart_server
echo "$user (slot $slot) disabled."
