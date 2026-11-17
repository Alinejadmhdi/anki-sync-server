# Shared helpers for the scripts in this folder (sourced, not run).
cd "$(dirname "${BASH_SOURCE[0]}")/.."
SERVICE=anki-sync

# Run systemctl <action> on the service, whichever way install.sh set it up.
# Returns 1 if there is no service (the server was started by hand with ./run.sh).
service() {
  if systemctl cat "$SERVICE" >/dev/null 2>&1; then
    if [[ $EUID -eq 0 ]]; then systemctl "$1" "$SERVICE"; else sudo systemctl "$1" "$SERVICE"; fi
  elif systemctl --user cat "$SERVICE" >/dev/null 2>&1; then
    systemctl --user "$1" "$SERVICE"
  else
    return 1
  fi
}

# Restart the server so it picks up changes to .env.
restart_server() {
  if service restart; then
    echo "Server restarted."
  else
    echo "No anki-sync service found - restart ./run.sh yourself so the change takes effect."
  fi
}

random_password() {
  head -c 40 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c "${1:-16}"
}

# Write SYNC_USER<slot>=<user>:<pass> into .env, replacing that slot if it exists.
set_slot() {
  local line="SYNC_USER$1=$2:$3"
  if grep -q "^SYNC_USER$1=" .env; then
    sed -i "s|^SYNC_USER$1=.*|$line|" .env
  else
    echo "$line" >> .env
  fi
}
