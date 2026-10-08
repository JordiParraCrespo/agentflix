# agentflix

Your own Netflix at home, built on Jellyfin (free and open source) with
automatic downloads. Search for a film or series, click **Request**, and it
appears in Jellyfin on your TV a little later, with subtitles.

| App | What it does | Address |
|---|---|---|
| **Jellyfin** | Media server: streams your library to TV, phone, browser, Chromecast | `http://SERVER_IP:8096` |
| **Seerr** | Netflix-style page to browse and request films/series | `http://SERVER_IP:5055` |
| **Radarr** | Finds, downloads, renames and upgrades **films** | `http://SERVER_IP:7878` |
| **Sonarr** | Same for **series**, including new episodes as they air | `http://SERVER_IP:8989` |
| **Prowlarr** | Manages download sources (indexers) for Radarr and Sonarr | `http://SERVER_IP:9696` |
| **Bazarr** | Downloads subtitles in your languages | `http://SERVER_IP:6767` |
| **qBittorrent** | Torrent client, only reachable through **Proton VPN** | `http://SERVER_IP:8080` |
| **Samba** | Network folders to copy your own files in | `\\SERVER_IP\media` |

```
Seerr ──request──▶ Radarr / Sonarr ──search──▶ Prowlarr
                        │
                        ├──send torrent──▶ qBittorrent ──▶ /data/torrents
                        │                  (inside Proton VPN)
                        │
                        └──hardlink + rename──▶ /data/media ──▶ Jellyfin ──▶ your TV
                                                    ▲
                                          Bazarr adds subtitles
```

## 1. Install Linux and Docker

Any always-on computer works: a mini-PC, an old laptop or desktop, or a NAS.

1. Install **Ubuntu Server 24.04 LTS** (or Debian) from a USB stick.
   Enable "OpenSSH server" during install so you can manage it from your laptop.
2. Install Docker:
   ```bash
   curl -fsSL https://get.docker.com | sh
   sudo usermod -aG docker $USER   # then log out and back in
   ```
3. Mount the disk for your films, for example at `/srv/data`. Ubuntu's docs
   explain how to add it to `/etc/fstab` so it mounts at boot. Downloads and
   the library must share **one** disk (`DATA` in `.env`) so hardlinks work.
4. Give the server a fixed IP in your router (look for "DHCP reservation").

## 2. Get your Proton VPN key

qBittorrent runs inside a Proton VPN tunnel (using
[gluetun](https://github.com/qdm12/gluetun)). It has no other way to the
internet, so your real IP is never exposed to other peers, even if the VPN
drops. The rest of the apps use your normal connection. A paid Proton plan is
needed: the free plan doesn't allow P2P.

1. Go to <https://account.proton.me/u/0/vpn/WireGuard>.
2. Name it (e.g. `agentflix`), platform **GNU/Linux**, and under VPN options turn
   **NAT-PMP (Port Forwarding)** **on**.
3. Choose any server and click **Create**. Copy the `PrivateKey = ...` value.
   This key works for every Proton server.
4. You'll paste it into `WIREGUARD_PRIVATE_KEY` in `.env` in the next step.

gluetun connects only to Proton's P2P servers, asks for a forwarded port, and
sets it in qBittorrent automatically, so other peers can connect to you and
downloads and seeding run at full speed.

## 3. Configure and start

```bash
git clone https://github.com/JordiParraCrespo/agentflix.git && cd agentflix
cp .env.example .env
nano .env          # set DATA, CONFIG, PUID/PGID (from `id -u` / `id -g`),
                   # SAMBA_PASSWORD and WIREGUARD_PRIVATE_KEY
sudo ./setup.sh    # creates the folders with the right owner (and tells you if
                   # there's a GPU; if so, uncomment COMPOSE_FILE in .env)
docker compose up -d
docker compose ps  # everything should say "running"
```

If something keeps restarting: `docker compose logs <name>`.

## 4. Connect the apps (once, about 20 minutes)

Inside the stack, apps reach each other by name, e.g. `http://radarr:7878`.
Set a login on each app the first time it asks.

**qBittorrent** (`:8080`)
1. User `admin`. The temporary password is in `docker compose logs qbittorrent`.
   In **Tools → Options → Web UI**, set a new password and tick
   **Bypass authentication for clients on localhost**. That lets gluetun set
   the forwarded port automatically.
2. **Options → Downloads**: set **Default Torrent Management Mode** to
   **Automatic** and **Default Save Path** to `/data/torrents`. Torrents then
   land in `/data/torrents/movies` or `/data/torrents/tv` by category.

**Prowlarr** (`:9696`)
1. **Indexers → Add**: add the sources you're allowed to use.
2. **Settings → Apps**: add **Radarr** (`http://radarr:7878`) and **Sonarr**
   (`http://sonarr:8989`), pasting each app's API key from its
   **Settings → General**. Prowlarr then syncs the indexers to both.

**Radarr** (`:7878`) and **Sonarr** (`:8989`), same steps in each:
1. **Settings → Media Management → Add Root Folder**: `/data/media/movies`
   (Radarr) or `/data/media/tv` (Sonarr). Leave **Use Hardlinks** on.
2. **Settings → Download Clients → qBittorrent**: host **`gluetun`**, port
   `8080`, your login, category `movies` (Radarr) or `tv` (Sonarr).
3. **Settings → Profiles**: pick your quality (e.g. 1080p) and, under
   **Language**, Spanish/English/Any.

**Bazarr** (`:6767`)
1. **Settings → Sonarr / Radarr**: hosts `sonarr` / `radarr`, plus their API keys.
2. **Settings → Languages**: create a profile (e.g. Spanish + English) and set
   it as the default. **Settings → Providers**: add a few, e.g. OpenSubtitles.com.

**Jellyfin** (`:8096`)
1. Create your admin user and add libraries: **Movies → `/data/media/movies`**,
   **Shows → `/data/media/tv`**. Preferred language: Spanish.
2. **Hardware transcoding** (if your server has an Intel or AMD GPU):
   **Dashboard → Playback → Transcoding**, set **Hardware acceleration** to
   **Intel QuickSync (QSV)** or **VAAPI**, then tick the codecs your GPU
   supports. This needs the GPU passed to Jellyfin: uncomment the
   `COMPOSE_FILE` line in `.env` and run `docker compose up -d` again.
   (It's off by default because Jellyfin won't start on a server without
   `/dev/dri`.)
3. Create a user for each person in the house.

**Seerr** (`:5055`)
1. Choose **Jellyfin**, server `jellyfin`, port `8096`, and sign in with
   your Jellyfin admin. Click **Sync Libraries**, then enable Movies and Shows.
2. Add **Radarr** (`radarr`, 7878) and **Sonarr** (`sonarr`, 8989) with their
   API keys, root folders and quality profiles. Mark both as default.
3. Import your Jellyfin users so the family can log in and make requests.

Done. Request something in Seerr and watch it go through the queues in Radarr
or Sonarr, then appear in Jellyfin.

## 5. Watch

Install **Jellyfin** on your TV (Android TV / Google TV, LG webOS, Samsung
Tizen, Fire TV, Apple TV via Swiftfin or Infuse), phone or tablet, or open
`http://SERVER_IP:8096` in a browser. Apps on your home network find the server
automatically. It's all free, with no account and no subscription.

## Your own files

Copy them over the network share: on Windows open `\\SERVER_IP\media`, on Mac
use **Finder → Go → Connect to Server**, `smb://SERVER_IP/media`. User:
`media`, with your `SAMBA_PASSWORD`. Name them so Jellyfin recognises them:

```
movies/Big Buck Bunny (2008)/Big Buck Bunny (2008).mkv
tv/Show Name (2020)/Season 01/Show Name S01E01.mkv
```

Or put them in `torrents/` and use **Wanted → Manual Import** in Radarr or
Sonarr to rename and move them for you.

## Optional extras

**Watch away from home: Tailscale (recommended).** Install
[Tailscale](https://tailscale.com/download) on the server
(`curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up`) and
on your phone or laptop. Then `http://SERVER_NAME:8096` works from anywhere,
encrypted, without opening any port on your router. Free for personal use.

**Check the VPN.** These should show a Proton IP, not your home IP, and the
forwarded port:

```bash
docker compose exec qbittorrent curl -s https://ipinfo.io
docker compose logs gluetun | grep -i "port forwarded"
```

If qBittorrent doesn't start, the VPN isn't connected. That's on purpose:
qBittorrent never runs outside the VPN. Check `docker compose logs gluetun`.
`private key is not set` means `WIREGUARD_PRIVATE_KEY` is empty in `.env`, and
repeated `i/o timeout` errors usually mean the key is wrong or expired.

If qBittorrent's page stops loading after gluetun was restarted on its own
(for example after a crash), run `docker compose up -d` or
`docker compose restart qbittorrent`. qBittorrent lives inside gluetun's
network and needs to re-attach to the new one.

## Maintenance

```bash
docker compose pull && docker compose up -d   # update everything (no service
                                               # names, so qBittorrent follows gluetun)
docker image prune -f                          # free space from old versions
```

Back up the `CONFIG` folder: it holds all your settings and watch history.

Only download content you own or have the right to use.
