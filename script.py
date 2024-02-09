import logging
import os
import re
import signal
import sys
import time
import xml.etree.ElementTree as ElementTree

import docker
import requests
import schedule
from packaging import version

# Setup basic logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Constants
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
    docker_client.ping()
except Exception as e:
    logging.error(f'Failed to access the Docker socket: {e}')
    sys.exit(1)

# Create a session for reuse
session = requests.Session()


def get_latest_plex_version():
    url = f"https://plex.tv/api/downloads/5.json?channel={CONFIG['PLEX_BRANCH']}&X-Plex-Token={CONFIG['PLEX_TOKEN']}"
    try:
        response = session.get(url)
        response.raise_for_status()
        data = response.json()
        return data['computer']['Linux']['version']
    except requests.RequestException as error:
        logging.error(f'Failed to get latest Plex version: {error}')
        return None


def get_current_plex_version():
    url = f"{CONFIG['PLEX_PROTOCOL']}://{CONFIG['PLEX_IP']}:{CONFIG['PLEX_PORT']}/?X-Plex-Token={CONFIG['PLEX_TOKEN']}"
    try:
        response = session.get(url)
        response.raise_for_status()
        root = ElementTree.fromstring(response.content)
        return root.attrib['version']
    except (requests.RequestException, ElementTree.ParseError) as error:
        logging.error(f'Failed to get current Plex version: {error}')
        return None


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
        logging.error(f'Plex container not found, please check the container name: {CONFIG["PLEX_CONTAINER_NAME"]}')
    except Exception as error:
        logging.error(f'Failed to restart Plex container: {error}')


def check_for_updates(force_update=False):
    latest_version = sanitize_version(get_latest_plex_version())
    current_version = sanitize_version(get_current_plex_version())
    if latest_version and current_version:
        logging.info(f'Latest Version: {latest_version}')
        logging.info(f'Current Version: {current_version}')
        if force_update or version.parse(latest_version) > version.parse(current_version):
            logging.info('Update available or forced. Restarting Plex container...')
            restart_plex_container()
        else:
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

    def scheduled_check():
        check_for_updates(force_update=False)

    if int(CONFIG['INTERVAL']) < 5:
        logging.error('Interval must be at least 5 minutes, recommended is 360 minutes (6 hours)')
        sys.exit(1)

    schedule.every(int(CONFIG['INTERVAL'])).minutes.do(scheduled_check)

    try:
        while True:
            idle_time = schedule.idle_seconds()
            if idle_time is not None:
                next_run = schedule.next_run()
                logging.info(f'Next update check will be at {next_run.strftime("%Y-%m-%d %H:%M:%S")}')
                time.sleep(max(0, idle_time))
            else:
                break
            schedule.run_pending()
    except KeyboardInterrupt:
        logging.info('Script interrupted by user')
    finally:
        logging.info('Exiting...')


if __name__ == '__main__':
    main()
