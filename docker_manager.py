#!/usr/bin/env python3
import argparse
import subprocess
import os
import sys
import shutil # Not strictly needed if not managing different .dockerignore files

# --- Configuration ---
APP_IMAGE_TAG = "cherryrecorder-client:k8s-latest"
APP_CONTAINER_NAME = "cherryrecorder-client-container"
APP_DOCKERFILE = "Dockerfile"

# --- Port Mapping (Host:Container) - Only for Application Mode ---
HOST_PORT_HTTP = "8080"  # Host port to access the web app
CONTAINER_PORT_HTTP = "80" # Nginx in Dockerfile listens on port 80

# --- Environment Variables File for Build Args - Only for Application Mode ---
# These will be passed as --build-arg to 'docker build'
# For sensitive data like API keys, consider alternative handling for production.
# For local development, using an .env file for build args can be convenient.
ENV_FILE_PATH = ".env.docker" # Use a specific .env file for Docker build args

# --- Default Build Arguments (can be overridden by .env.docker or command-line) ---
DEFAULT_BUILD_ARGS = {
    "APP_ENV": "prod",
    "BASE_HREF": "/cherryrecorder_client/", # Should match GitHub Pages if deploying there
    # WEB_API_BASE_URL, CHAT_SERVER_IP, WEB_MAPS_API_KEY should be in .env.docker or passed via CLI
}

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
            print(f"ERROR details: {e}", file=sys.stderr)
        else:
            print(f"---> Command finished with non-zero exit code {e.returncode} (check=False, ignored).")
        return not check
    except FileNotFoundError:
        print(f"ERROR: Command not found: {command[0]}", file=sys.stderr)
        print("Ensure Docker CLI is installed and in your PATH.", file=sys.stderr)
        return False

def load_env_file(file_path):
    """Loads environment variables from a .env file for build arguments."""
    env_vars = {}
    if os.path.exists(file_path):
        print(f"Loading build arguments from: {file_path}")
        with open(file_path, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    env_vars[key.strip()] = value.strip()
    else:
        print(f"INFO: Build arguments file not found at {file_path}. Using defaults or command-line args.")
    return env_vars

# --- Main Script Logic ---
def main():
    parser = argparse.ArgumentParser(description="Build and run CherryRecorder Client using Docker.")
    parser.add_argument(
        "--target",
        choices=["app"], # Simplified for client, can be extended
        default="app",
        help="Target to build and run: 'app' (default)."
    )
    parser.add_argument(
        "--build-arg",
        action="append",
        help="Set build-time variables (e.g., WEB_MAPS_API_KEY=yourkey). Can be used multiple times."
    )
    parser.add_argument(
        "--env-file",
        default=ENV_FILE_PATH,
        help=f"Path to a .env file for Docker build arguments (default: {ENV_FILE_PATH})."
    )

    args = parser.parse_args()

    try:
        if args.target == "app":
            print("--- Running in APPLICATION mode ---")
            image_tag = APP_IMAGE_TAG
            dockerfile = APP_DOCKERFILE
            container_name = APP_CONTAINER_NAME

            # Stop and remove existing app container
            print(f"Stopping and removing existing container '{container_name}' (if any)...")
            run_command(["docker", "kill", container_name], stderr=subprocess.DEVNULL, check=False)
            run_command(["docker", "rm", container_name], stderr=subprocess.DEVNULL, check=False)

            # Prepare build arguments
            build_args_cmd = ["docker", "build", "--pull", "-t", image_tag, "-f", dockerfile]

            # Load build args from .env file and defaults
            final_build_args = DEFAULT_BUILD_ARGS.copy()
            env_file_build_args = load_env_file(args.env_file)
            final_build_args.update(env_file_build_args) # .env file overrides defaults

            # Override with command-line --build-arg values
            if args.build_arg:
                for barg in args.build_arg:
                    if '=' in barg:
                        key, value = barg.split('=', 1)
                        final_build_args[key.strip()] = value.strip()
                    else:
                        print(f"WARNING: Ignoring malformed --build-arg: {barg}", file=sys.stderr)
            
            # Add --build-arg for each processed argument
            for key, value in final_build_args.items():
                build_args_cmd.extend(["--build-arg", f"{key}={value}"])
            
            build_args_cmd.append(".") # Docker context

            # --- Build Docker Image ---
            if not run_command(build_args_cmd):
                sys.exit(1) # Exit if build fails

            # --- Run Docker Container ---
            run_args = [
                "docker", "run", "-d",
                "--name", container_name,
                "-p", f"{HOST_PORT_HTTP}:{CONTAINER_PORT_HTTP}",
                image_tag
            ]
            if not run_command(run_args):
                 print(f"ERROR: Docker run failed for target '{args.target}'!", file=sys.stderr)
                 sys.exit(1) # Exit if run fails
            
            print(f"\nContainer '{container_name}' started successfully.")
            print(f"  Web app should be accessible at: http://localhost:{HOST_PORT_HTTP}{final_build_args.get('BASE_HREF', '/')}")
            print(f"  To view logs: docker logs {container_name} -f")
            print(f"  To stop:      docker kill {container_name} && docker rm {container_name}")

        else:
            print(f"ERROR: Unknown target '{args.target}'", file=sys.stderr)
            sys.exit(1)

        print("\nScript finished.")

    except Exception as e:
        print(f"\nAn unexpected error occurred: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main() 