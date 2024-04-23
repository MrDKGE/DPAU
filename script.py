import logging
import os
import re
import signal
import sys
import time
import xml.etree.ElementTree as ElementTree
import docker
import requests
from packaging import version
import schedule

# Setup basic logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Constants and Configuration
ENV_VARS = {
    'PLEX_BRANCH': 'public',
    'PLEX_TOKEN': None,  # Must be provided
    'PLEX_PROTOCOL': 'http',
    'PLEX_IP': '127.0.0.1',
    'PLEX_PORT': '32400',
    'PLEX_CONTAINER_NAME': 'plex',
    'FORCE_UPDATE': 'False',
    'INTERVAL': '360',
}
CONFIG = {var: os.getenv(var, default) for var, default in ENV_VARS.items()}

# Validate essential environment variables
if not CONFIG['PLEX_TOKEN']:
    logging.error('PLEX_TOKEN is not set')
    sys.exit(1)

# Initialize Docker client
try:
    docker_client = docker.from_env()
except docker.errors.DockerException as e:
    logging.error(f'Failed to initialize Docker client: {e}')
    sys.exit(1)

# Create a session for reuse
session = requests.Session()


def get_plex_version(url):
    try:
        response = session.get(url)
        response.raise_for_status()
        return response
    except requests.RequestException as error:
        logging.error(f'Request failed: {error}')
        time.sleep(5)
        return get_plex_version(url)


def get_latest_plex_version():
    url = f"https://plex.tv/api/downloads/5.json?channel={CONFIG['PLEX_BRANCH']}&X-Plex-Token={CONFIG['PLEX_TOKEN']}"
    response = get_plex_version(url)
    data = response.json()
    return data['computer']['Linux']['version']


def get_current_plex_version():
    url = f"{CONFIG['PLEX_PROTOCOL']}://{CONFIG['PLEX_IP']}:{CONFIG['PLEX_PORT']}/?X-Plex-Token={CONFIG['PLEX_TOKEN']}"
    response = get_plex_version(url)
    root = ElementTree.fromstring(response.content)
    return root.attrib['version']


def sanitize_version(version_string):
    match = re.match(r'^\d+\.\d+\.\d+\.\d+', version_string)
    if match:
        return match.group()
    logging.error(f'Invalid version string: {version_string}')
    return None


def restart_plex_container():
    try:
        container = docker_client.containers.get(CONFIG['PLEX_CONTAINER_NAME'])
        container.restart()
        logging.info('Plex container restarted')
    except docker.errors.NotFound:
        logging.error(f'Plex container not found: {CONFIG["PLEX_CONTAINER_NAME"]}')
    except docker.errors.ContainerError as error:
        logging.error(f'Failed to restart Plex container: {error}')


def check_for_updates(force_update=False):
    latest_version = sanitize_version(get_latest_plex_version())
    current_version = sanitize_version(get_current_plex_version())
    if latest_version and current_version and (force_update or version.parse(latest_version) > version.parse(current_version)):
        logging.info(('Forcing update' if force_update else 'New version available') + ', restarting Plex container...')
        restart_plex_container()
    elif latest_version and current_version:
        logging.info('Plex is up to date.')
    else:
        logging.error('Failed to compare Plex versions.')


def handle_sigterm(signum, frame):
    logging.info('Received SIGTERM, shutting down...')
    sys.exit(0)


def main():
    # Register the SIGTERM signal handler
    signal.signal(signal.SIGTERM, handle_sigterm)

    force_update = CONFIG['FORCE_UPDATE'].lower() == 'true'
    check_for_updates(force_update=force_update)

    interval = int(CONFIG['INTERVAL'])
    if interval < 5:
        logging.error('Interval must be at least 5 minutes.')
        sys.exit(1)

    schedule.every(interval).minutes.do(lambda: check_for_updates(force_update=False))

    try:
        while True:
            schedule.run_pending()
            time.sleep(60)  # Sleep at least 60 seconds to avoid high CPU usage
    except KeyboardInterrupt:
        logging.info('Script interrupted by user')
    finally:
        logging.info('Exiting...')


if __name__ == '__main__':
    main()
