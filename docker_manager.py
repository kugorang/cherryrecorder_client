#!/usr/bin/env python3
import argparse
import subprocess
import os
import sys

# --- Configuration ---
APP_IMAGE_TAG = "cherryrecorder-client:latest"
APP_CONTAINER_NAME = "cherryrecorder-client-container"
APP_DOCKERFILE = "Dockerfile"

# --- Port Mapping ---
HOST_PORT_HTTP = "3000"  # 서버와 충돌 방지를 위해 3000번 포트 사용
CONTAINER_PORT_HTTP = "80"

# --- Helper Functions ---
def run_command(command, check=True, **kwargs):
    """Runs a shell command and optionally checks for errors."""
    print(f"\n---> Running command: {' '.join(command)}")
    try:
        use_shell = sys.platform == "win32"
        result = subprocess.run(command, check=check, text=True, shell=use_shell, **kwargs)
        print(f"---> Command successful.")
        return True
    except subprocess.CalledProcessError as e:
        if check:
            print(f"ERROR: Command failed with exit code {e.returncode}", file=sys.stderr)
        return not check
    except FileNotFoundError:
        print(f"ERROR: Command not found: {command[0]}", file=sys.stderr)
        return False

# --- Main Script Logic ---
def main():
    parser = argparse.ArgumentParser(description="Build and run CherryRecorder Client using Docker.")
    parser.add_argument("--base-href", default="/", help="Base href for the web app (default: /).")
    parser.add_argument("--web-api-base-url", default="https://your-domain.com/api", help="API base URL")
    parser.add_argument("--ws-url", default="wss://your-domain.com/ws", help="WebSocket URL")
    parser.add_argument("--web-maps-api-key", required=True, help="Google Maps API key")
    
    args = parser.parse_args()

    try:
        # Stop and remove existing container
        print(f"Stopping and removing existing container '{APP_CONTAINER_NAME}' (if any)...")
        run_command(["docker", "kill", APP_CONTAINER_NAME], stderr=subprocess.DEVNULL, check=False)
        run_command(["docker", "rm", APP_CONTAINER_NAME], stderr=subprocess.DEVNULL, check=False)

        # Build Docker image
        build_args_cmd = [
            "docker", "build", "--pull",
            "-t", APP_IMAGE_TAG,
            "-f", APP_DOCKERFILE,
            "--build-arg", f"BASE_HREF={args.base_href}",
            "--build-arg", f"WEB_API_BASE_URL={args.web_api_base_url}",
            "--build-arg", f"WS_URL={args.ws_url}",
            "--build-arg", f"WEB_MAPS_API_KEY={args.web_maps_api_key}",
            "."
        ]
        
        if not run_command(build_args_cmd):
            sys.exit(1)

        # Run Docker container
        run_args = [
            "docker", "run", "-d",
            "--name", APP_CONTAINER_NAME,
            "-p", f"{HOST_PORT_HTTP}:{CONTAINER_PORT_HTTP}",
            APP_IMAGE_TAG
        ]
        
        if not run_command(run_args):
            sys.exit(1)
        
        print(f"\nContainer '{APP_CONTAINER_NAME}' started successfully.")
        print(f"  Web app: http://localhost:{HOST_PORT_HTTP}{args.base_href}")
        print(f"  Logs: docker logs {APP_CONTAINER_NAME} -f")
        print(f"  Stop: docker kill {APP_CONTAINER_NAME}")

    except Exception as e:
        print(f"\nAn unexpected error occurred: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
