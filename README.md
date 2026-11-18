# owntone-docker

Docker Compose setup for [OwnTone](https://owntone.github.io/owntone-server/) with Spotify Connect (librespot) and AirPlay (shairport-sync) inputs fed into OwnTone through named pipes, plus [airptpd](https://github.com/owntone/libairptp) for AirPlay 2 timing.

## Services

| Service          | Image                              | Purpose                                                      |
|------------------|------------------------------------|--------------------------------------------------------------|
| `airptpd`        | built from `docker/airptpd`        | PTP daemon from libairptp; provides the AirPlay 2 clock to OwnTone |
| `owntone`        | `owntone/owntone:${OWNTONE_TAG}`   | Media server; plays the music library and the pipe inputs    |
| `librespot`      | `giof71/librespot:latest`          | Spotify Connect receiver (`Jukebox`), writes to the `spotify` pipe |
| `shairport-sync` | built from `docker/shairport-sync` | AirPlay receiver, writes to the `airplay` pipe               |

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

### shairport-sync

The AirPlay receiver is shairport-sync in Classic (AirPlay 1) mode, built from source with one patch, `docker/shairport-sync/claim-play-lock-before-thread.patch`.

Upstream starts each connection's thread before claiming the play lock for it. A client that connects and disconnects immediately can finish its thread, releasing the lock, before the lock is claimed, which leaves the lock held by a closed connection. OwnTone triggers this: it does a TCP connect test against every AirPlay receiver it discovers, including this one, before applying `exclude`. The receiver then either deadlocks (`allow_session_interruption = "yes"`) or refuses every connection as busy (`"no"`). The patch claims the lock before starting the thread.

`allow_session_interruption` is set to `"no"` so a probe can never cut off a stream that is playing. A second sender gets "busy" until the current one disconnects or `session_timeout` (60 s) passes.

## Configuration

Host paths, the Spotify receiver and the airptpd version are set with environment variables in `.env`. `./setup.sh` creates it from `.env.example` if it doesn't exist (see [Usage](#usage)).

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
| `OWNTONE_TAG` | `latest` | `owntone/owntone` image tag, e.g. `staging` for the newest build      |
| `SHAIRPORT_SYNC_REF` | `5.6.3` | shairport-sync tag or commit the AirPlay receiver is built from       |
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

1. Run the setup script:

   ```sh
   ./setup.sh
   ```

   This copies `.env.example` to `.env` (an existing `.env` is never overwritten) and creates the `spotify`, `spotify.metadata`, `airplay` and `airplay.metadata` FIFOs in `PIPES_DIR`.

2. Edit `.env` as needed. If you change `PIPES_DIR`, run `./setup.sh` again to create the pipes there.

3. Start the stack:

   ```sh
   docker compose up -d --build
   ```

4. Open the OwnTone web UI at `http://<host>:3689`.

## Files

- `setup.sh` – creates `.env` and the named pipes
- `docker/shairport-sync/` – builds the patched shairport-sync
- `docker/airptpd/Dockerfile` – builds `airptpd` from libairptp source
- `config/owntone/owntone.conf` – OwnTone config (library dirs `/srv/media` and `/srv/pipes`, pipe autostart)
- `config/shairport/shairport-sync.conf` – shairport-sync pipe and metadata output
- `scripts/spotify-metadata.sh` – librespot event hook that pushes track metadata and artwork to `spotify.metadata`
- `playlists/` – internet radio `.m3u` playlists; copy them into `MUSIC_DIR` to use them
