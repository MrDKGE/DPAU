# Docker Plex Auto Update (DPAU)

[![GitHub](https://img.shields.io/badge/GitHub-DPAU-blue)](https://github.com/MrDKGE/dpau)
[![GitHub last commit](https://img.shields.io/github/last-commit/MrDKGE/dpau)](https://github.com/MrDKGE/dpau)
[![Docker Pulls](https://img.shields.io/docker/pulls/dkge/dpau.svg)](https://hub.docker.com/r/dkge/dpau)
[![Docker Stars](https://img.shields.io/docker/stars/dkge/dpau.svg)](https://hub.docker.com/r/dkge/dpau)
[![Docker Image Size (tag)](https://img.shields.io/docker/image-size/dkge/dpau/latest)](https://hub.docker.com/r/dkge/dpau)
[![Docker Image Version (latest by date)](https://img.shields.io/docker/v/dkge/dpau)](https://hub.docker.com/r/dkge/dpau)

Automatically restarts your Plex container when updates are available.

**Requirements:**
- Runs on same host as Plex container
- Plex image that auto-updates on restart ([plexinc/pms-docker](https://hub.docker.com/r/plexinc/pms-docker) or [linuxserver/plex](https://hub.docker.com/r/linuxserver/plex))

## Quick Start

```bash
docker run -d \
  -e PLEX_TOKEN=YOUR_TOKEN \
  -e PLEX_IP=192.168.1.100 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  dkge/dpau:latest
```

**Get your token:** [Finding your X-Plex-Token](https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/)

## Configuration

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `PLEX_TOKEN` | Plex authentication token | - | ✅ |
| `PLEX_IP` | Plex server IP/hostname | 127.0.0.1 | No |
| `PLEX_PORT` | Plex server port | 32400 | No |
| `PLEX_PROTOCOL` | Protocol for Plex API (http/https) | http | No |
| `PLEX_CONTAINER_NAME` | Plex container name | plex | No |
| `PLEX_BRANCH` | Update channel (public/plexpass) | public | No |
| `INTERVAL` | Check interval in minutes | 360 | No |
| `FORCE_UPDATE` | Force restart regardless of version (true/false) | false | No |

## Docker Compose

```yaml
services:
  dpau:
    container_name: plex-auto-update
    image: dkge/dpau:latest
    environment:
      - PLEX_TOKEN=YOUR_TOKEN
      - PLEX_IP=192.168.1.100
      - PLEX_BRANCH=plexpass
      - INTERVAL=180
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    restart: unless-stopped
```

## Native Installation (Optional)

Run directly on host without Docker:

```bash
# Install dependencies (Ubuntu/Debian)
sudo apt install curl jq docker.io

# Run script
chmod +x update-plex.sh
export PLEX_TOKEN=YOUR_TOKEN PLEX_IP=192.168.1.100
./update-plex.sh
```

**Systemd service:** Create `/etc/systemd/system/dpau.service`

```ini
[Unit]
Description=Docker Plex Auto Update
After=docker.service

[Service]
Environment="PLEX_TOKEN=YOUR_TOKEN"
Environment="PLEX_IP=192.168.1.100"
ExecStart=/path/to/update-plex.sh
Restart=always

[Install]
WantedBy=multi-user.target
```

Enable: `sudo systemctl enable --now dpau.service`