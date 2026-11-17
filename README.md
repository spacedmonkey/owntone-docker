# owntone-docker

Docker Compose setup for [OwnTone](https://owntone.github.io/owntone-server/) with Spotify Connect (librespot) and AirPlay (shairport-sync) inputs fed into OwnTone through named pipes, plus [airptpd](https://github.com/owntone/libairptp) for AirPlay 2 timing.

## Services

| Service          | Image                              | Purpose                                                      |
|------------------|------------------------------------|--------------------------------------------------------------|
| `airptpd`        | built from `docker/airptpd`        | PTP daemon from libairptp; provides the AirPlay 2 clock to OwnTone |
| `owntone`        | `owntone/owntone:latest`           | Media server; plays the music library and the pipe inputs    |
| `librespot`      | `giof71/librespot:latest`          | Spotify Connect receiver (`Jukebox`), writes to the `spotify` pipe |
| `shairport-sync` | `mikebrady/shairport-sync:classic` | AirPlay receiver, writes to the `airplay` pipe               |

All services use `network_mode: host` so mDNS/Bonjour discovery works.

### airptpd

OwnTone needs PTP (UDP ports 319 and 320) to stream to AirPlay 2 speakers. OwnTone has its own copy of libairptp, but the `owntone/owntone:latest` image (29.2) bundles libairptp 0.5. Version 0.6 fixed a stack buffer overflow on malformed PTP packets. Running `airptpd` separately means the up-to-date daemon handles that network traffic instead, and OwnTone uses it automatically when it is found at startup.

- `airptpd` runs as an unprivileged user on the host network. Only `NET_BIND_SERVICE` is kept so it can bind 319/320.
- It publishes its state through POSIX shared memory (`/dev/shm/airptp_shm`). `owntone` reads it by joining the `airptpd` IPC namespace (`ipc: "service:airptpd"`).
- OwnTone only checks for the daemon at startup. It otherwise binds the ports itself. `owntone` therefore waits for the `airptpd` healthcheck, and Compose restarts `owntone` whenever `airptpd` restarts.
- Nothing else on the host may use ports 319/320 (for example `nqptp` or `ptp4l`).

The image is built from source on first `docker compose up`. To build another libairptp release, set `LIBAIRPTP_REF` and rebuild:

```sh
docker compose build --no-cache airptpd
```

## Configuration

Host paths, the Spotify receiver and the airptpd version are set with environment variables. Copy the example file and edit it:

```sh
cp .env.example .env
```

| Variable     | Default    | Used for                                                                |
|--------------|------------|-------------------------------------------------------------------------|
| `MUSIC_DIR`  | `./music`  | `/srv/media` (owntone)                                                  |
| `PIPES_DIR`  | `./pipes`  | `/srv/pipes` (owntone), `/mnt/pipe` (librespot), `/data` (shairport-sync) |
| `CONFIG_DIR` | `./config` | `owntone/` → `/etc/owntone`, `shairport/shairport-sync.conf` → `/etc/shairport-sync.conf` |
| `CACHE_DIR`  | `./cache`  | `owntone/` → `/var/cache/owntone`                                       |
| `SPOTIFY_DEVICE_NAME` | `Jukebox` | Name shown in the Spotify app                               |
| `SPOTIFY_DEVICE_TYPE` | `speaker` | Icon shown in the Spotify app (`speaker`, `avr`, `tv`, …)   |
| `SPOTIFY_BITRATE` | `320`  | Spotify stream bitrate: `96`, `160` or `320`                          |
| `SPOTIFY_INITIAL_VOLUME` | `100` | Initial Spotify volume, `0`–`100`                              |
| `LIBAIRPTP_REF` | `0.7`    | libairptp branch, tag or commit that airptpd is built from          |

Every variable has a default, so the stack also runs without a `.env` file. Relative paths are resolved from the directory containing `docker-compose.yml`.

Example `.env`:

```dotenv
MUSIC_DIR=/mnt/nas/music
PIPES_DIR=./pipes
CONFIG_DIR=./config
CACHE_DIR=./cache
SPOTIFY_DEVICE_NAME=Living Room
LIBAIRPTP_REF=0.7
```

If you move `CONFIG_DIR`, copy the contents of `./config` there first.

## Usage

1. Create the named pipes (reads `PIPES_DIR` from `.env`):

   ```sh
   ./setup-pipe.sh
   ```

   This creates `spotify`, `spotify.metadata`, `airplay` and `airplay.metadata` FIFOs.

2. Start the stack:

   ```sh
   docker compose up -d --build
   ```

3. Open the OwnTone web UI at `http://<host>:3689`.

## Files

- `docker/airptpd/Dockerfile` – builds `airptpd` from libairptp source
- `config/owntone/owntone.conf` – OwnTone config (library dirs `/srv/media` and `/srv/pipes`, pipe autostart)
- `config/shairport/shairport-sync.conf` – shairport-sync pipe and metadata output
- `scripts/spotify-metadata.sh` – librespot event hook that pushes track metadata and artwork to `spotify.metadata`
- `playlists/` – internet radio `.m3u` playlists; copy them into `MUSIC_DIR` to use them
