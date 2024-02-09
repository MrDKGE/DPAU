# Docker Plex Auto Update (DPAU)

This script simply compares the current version of Plex with the latest version available on the Plex website.  
If the versions are different, the script will restart the Plex container.   
Make sure you are using a Plex image that will automatically update to the latest version on startup.  
For example one of these images: [plexinc/pms-docker](https://hub.docker.com/r/plexinc/pms-docker) or [linuxserver/plex](https://hub.docker.com/r/linuxserver/plex).

## Important

DPAU needs to be run on the same host as the Plex container.

## Environment Variables

To get the Plex token, you can follow the instructions [here](https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/).

| Variable            | Description                                   | Default   | Required |
|:--------------------|:----------------------------------------------|:----------|:---------|
| PLEX_TOKEN          | The Plex X-Plex-Token                         |           | Yes      |
| PLEX_BRANCH         | The branch of Plex to use (public / plexpass) | public    | No       |
| PLEX_PROTOCOL       | The protocol of the Plex host                 | http      | No       |
| PLEX_IP             | The IP of the Plex host                       | 127.0.0.1 | No       |
| PLEX_PORT           | The port of the Plex host                     | 32400     | No       |
| PLEX_CONTAINER_NAME | The name of the Plex container                | plex      | No       |
| FORCE_UPDATE        | Force an update of Plex (Mostly for testing)  | False     | No       |
| INTERVAL            | The interval to check for updates in minutes  | 360       | No       |

## Usage

Note: You will have to replace the environment variables with your own values.

#### Docker

Run the following command to start the container:

```
docker run -e PLEX_IP=192.168.X.X -e PLEX_TOKEN=XXXX -v /var/run/docker.sock:/var/run/docker.sock dkge/dpau:latest
```

#### Docker Compose

In the example below, DPAU will check for updates every 180 minutes using the plexpass branch.

```yaml
version: '3'

services:
  dpau:
    container_name: Plex-Auto-Update
    image: dkge/dpau:latest
    environment:
      - PLEX_IP=192.168.XX.XX
      - PLEX_TOKEN=XXXX
      - PLEX_BRANCH=plexpass
      - INTERVAL=180
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    restart: always
```

## Contributing

Contributions are welcome! If you'd like to improve this project, please open an issue to discuss a proposed change.

## Tested On

* Plex Media Server 1.40.0.7997-b09370ecd - [plexinc/pms-docker](https://hub.docker.com/r/plexinc/pms-docker)