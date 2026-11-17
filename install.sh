#!/usr/bin/env bash
# Install (or update) the Anki sync server on this machine and start it as a service.
#
#   ./install.sh
#
# Safe to run again: it keeps .env and data/, and upgrades Anki to ANKI_VERSION.
set -euo pipefail
cd "$(dirname "$0")"

# Keep this in step with the Anki version you and your customers use.
ANKI_VERSION=26.9.4
SERVICE=anki-sync

python3 -c 'import sys; sys.exit(sys.version_info < (3, 10))' \
  || { echo "Python 3.10 or newer is needed (found $(python3 --version))"; exit 1; }

echo "== Python environment"
[[ -d .venv ]] || python3 -m venv .venv \
  || { echo "venv failed - on Debian/Ubuntu: sudo apt install python3-venv"; exit 1; }
.venv/bin/pip install -q --upgrade pip
.venv/bin/pip install -q "anki==${ANKI_VERSION}"
echo "anki ${ANKI_VERSION} installed"

mkdir -p data
if [[ ! -f .env ]]; then
  cp .env.example .env
  chmod 600 .env
  echo "Created .env - accounts go there via scripts/add-user.sh"
fi
chmod +x run.sh scripts/*.sh

echo "== Service"
unit="[Unit]
Description=Anki sync server
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=$PWD/run.sh
Restart=always
RestartSec=5"

if [[ $EUID -eq 0 ]] || sudo -n true 2>/dev/null || { [[ -t 0 ]] && sudo -v; }; then
  printf '%s\nUser=%s\n\n[Install]\nWantedBy=multi-user.target\n' "$unit" "$(stat -c %U .)" \
    | sudo tee /etc/systemd/system/$SERVICE.service >/dev/null
  sudo systemctl daemon-reload
  sudo systemctl enable --now $SERVICE
  sudo systemctl restart $SERVICE
  echo "Running as a system service. Logs: sudo journalctl -u $SERVICE -f"
else
  mkdir -p ~/.config/systemd/user
  printf '%s\n\n[Install]\nWantedBy=default.target\n' "$unit" > ~/.config/systemd/user/$SERVICE.service
  systemctl --user daemon-reload
  systemctl --user enable --now $SERVICE
  systemctl --user restart $SERVICE
  echo "Running as a user service (no sudo). Logs: journalctl --user -u $SERVICE -f"
  echo "To keep it running after you log out, an admin must run: loginctl enable-linger $USER"
fi

source .env
up=false
for _ in {1..10}; do
  curl -fsS -o /dev/null "http://127.0.0.1:${SYNC_PORT}/health" 2>/dev/null && { up=true; break; }
  sleep 1
done
if $up; then
  echo "== Server is up on port ${SYNC_PORT}. Next: ./scripts/add-user.sh <username>"
else
  echo "== Server did not answer on port ${SYNC_PORT} yet - check the logs above."
fi
