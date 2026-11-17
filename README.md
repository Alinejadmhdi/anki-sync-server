# Anki sync server

Your own replacement for AnkiWeb, running on your own server. Anki on the computer and AnkiDroid on the phone sync to it, and every customer gets their own username and password.

It runs Anki's official sync server (`python -m anki.syncserver`, Anki 26.9.4) inside a Python virtual environment, kept alive by systemd. No Docker is needed, which matters in Iran because Docker Hub refuses Iranian servers. Python packages come from PyPI, which works.

Nothing secret is in this repo. Accounts live in `.env` and the cards in `data/`, both only on the server.

## What's in here

| File | What it does |
|---|---|
| `install.sh` | Installs Anki into `.venv`, creates `.env`, sets up and starts the `anki-sync` service |
| `run.sh` | Starts the server with the settings from `.env` (systemd runs this) |
| `scripts/add-user.sh` | Creates an account, or changes an account's password |
| `scripts/disable-user.sh` | Locks an account out without touching the others |
| `scripts/list-users.sh` | Shows accounts and how much space each one uses |
| `scripts/backup.sh` | Saves everything to `backups/`, keeps the last 14 days |

## 1. Install on the server

You need Python 3.10 or newer (`python3 --version`). On Debian or Ubuntu, also `sudo apt install python3-venv git` if they're missing.

```bash
git clone https://github.com/Alinejadmhdi/anki-sync-server.git
```

```bash
cd anki-sync-server
```

```bash
./install.sh
```

The script picks the right kind of service by itself. With `sudo` it installs a normal system service that starts on boot. Without `sudo` it installs a user service. In that case it keeps running only while you're logged in, unless the server's admin runs `loginctl enable-linger <your-user>` once. The script prints which one it chose.

It ends with "Server is up on port 8080" if everything worked.

Open `.env` and set `PUBLIC_URL` to the address customers will use, for example `http://185.12.34.56:8080/`. That line only changes the message `add-user.sh` prints.

If the server has a firewall, open the port:

```bash
sudo ufw allow 8080/tcp
```

## 2. Accounts

Your own account first:

```bash
./scripts/add-user.sh mhdi
```

Then one per customer:

```bash
./scripts/add-user.sh sara
```

Each run makes a random password, saves it in `.env`, restarts the server (a second or two; anyone syncing at that moment just syncs again), and prints a block to send the customer:

```
Account ready (slot 2) - send this to the customer:
  Sync server: http://185.12.34.56:8080/
  Username:    sara
  Password:    yPaHX68pAVDPED2F
```

Want to choose the password yourself, or reset a forgotten one? Give it as the second word. The account keeps its cards.

```bash
./scripts/add-user.sh sara NewPassword123
```

Customer stopped paying:

```bash
./scripts/disable-user.sh sara
```

Their password becomes something nobody knows, and their cards stay on the server. `add-user.sh sara` lets them back in.

Don't delete account lines from `.env` by hand. The accounts are numbered `SYNC_USER1`, `SYNC_USER2`, ... and Anki stops reading at the first missing number, so removing `SYNC_USER3` would also lock out 4, 5, 6 and the rest. I tested this. That's why there's a disable script and no delete script.

```bash
./scripts/list-users.sh
```

## 3. Connecting AnkiDroid

Needs AnkiDroid 2.16 or newer.

1. Settings → **Sync** → **Custom sync server**.
2. Set **Sync url** to the server address, e.g. `http://185.12.34.56:8080/`. Leave the media url empty.
3. If you were logged into AnkiWeb, log out first (Settings → Sync → log out).
4. Tap sync and log in. The screen says "Email", but type the username.

AnkiDroid accepts plain `http://` addresses, so this works without a certificate. The catch is that the password then crosses the internet unencrypted. Section 6 has the HTTPS setup if you have a domain.

## 4. Connecting Anki on a computer

1. Tools → Preferences → **Syncing**.
2. Put the same address in **Self-hosted sync server**.
3. Restart Anki, press Sync and log in.

## 5. The first sync

The server starts empty, so the first sync of each account asks what to do. On the device that already has the cards, choose **Upload**. The button may still say AnkiWeb, but it goes to your server. On every other device of that account, choose **Download**.

After that, syncs are normal and only send what changed. In testing, a note added on one device showed up on another after one sync each, Persian text included.

## 6. HTTPS (optional, needs a domain)

Point a domain such as `anki.example.com` at the server's IP, then put Caddy in front of the sync server. Caddy gets and renews the certificate by itself. After [installing Caddy](https://caddyserver.com/docs/install), make `/etc/caddy/Caddyfile` contain:

```
anki.example.com {
    reverse_proxy 127.0.0.1:8080
}
```

```bash
sudo systemctl reload caddy
```

Then set `SYNC_HOST=127.0.0.1` in `.env` so port 8080 is no longer reachable from outside, change `PUBLIC_URL` to `https://anki.example.com/`, restart with `sudo systemctl restart anki-sync`, and give customers the https address. Ports 80 and 443 have to be open.

## Day to day

**Is it running?** `systemctl status anki-sync` (add `--user` if it was installed without sudo). Live logs come from `sudo journalctl -u anki-sync -f`, which is the first place to look when someone says sync fails.

**Backups.** `./scripts/backup.sh` pauses the server for a few seconds, packs `data/` and `.env` into `backups/anki-<date>.tgz`, and keeps the newest 14. To run it every night at 4:00, add a line with `sudo crontab -e` (or `crontab -e` for a user-service install):

```
0 4 * * * /full/path/to/anki-sync-server/scripts/backup.sh >/dev/null
```

Copy a backup to your own computer now and then, since a backup on the same disk won't survive the server dying:

```bash
scp user@server:anki-sync-server/backups/anki-2026-11-17.tgz .
```

**Big decks.** One upload can be up to 200 MB. If someone with lots of media gets an upload error, raise `MAX_SYNC_PAYLOAD_MEGS` in `.env` and restart the service. `list-users.sh` shows who uses how much disk.

**Updating Anki.** When Anki releases a new major version, change `ANKI_VERSION` at the top of `install.sh` (the current one is on https://pypi.org/project/anki/) and run `./install.sh` again. It keeps `.env` and `data/`.

**Getting updates of this repo.** `git pull`, then `./install.sh`.
