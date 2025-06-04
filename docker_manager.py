#!/usr/bin/env python3
import argparse
import subprocess
import os
import sys
import shutil # Not strictly needed if not managing different .dockerignore files

# --- Configuration ---
APP_IMAGE_TAG_LOCAL = "cherryrecorder_client:latest"
APP_IMAGE_TAG_K8S = "cherryrecorder_client:k8s-latest"
APP_CONTAINER_NAME = "cherryrecorder_client-container"
APP_DOCKERFILE = "Dockerfile"

# --- Port Mapping (Host:Container) - Only for Local Mode ---
HOST_PORT_HTTP = "8080"  # Host port to access the web app
CONTAINER_PORT_HTTP = "80" # Nginx in Dockerfile listens on port 80

# --- Environment Variables File for Build Args ---
ENV_FILE_PATH_DEV = ".env.dev"  # Development environment (for K8s)
ENV_FILE_PATH_PROD = ".env.prod" # Production environment
ENV_FILE_PATH_DOCKER = ".env.docker" # Docker-specific (if exists)

# --- Default Build Arguments ---
DEFAULT_BUILD_ARGS = {
    "APP_ENV": "prod",
    "BASE_HREF": "/",
}

# K8s-specific overrides
K8S_BUILD_ARGS = {
    "CHAT_SERVER_IP": "cherryrecorder-server-svc",
    # WEB_API_BASE_URL is already correct in .env.dev
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
        choices=["app", "k8s"],
        default="app",
        help="Target to build: 'app' for local Docker, 'k8s' for Kubernetes deployment."
    )
    parser.add_argument(
        "--build-arg",
        action="append",
        help="Set build-time variables (e.g., WEB_MAPS_API_KEY=yourkey). Can be used multiple times."
    )
    parser.add_argument(
        "--env-file",
        help="Path to a .env file for Docker build arguments."
    )
    parser.add_argument(
        "--push",
        action="store_true",
        help="Push the built image to Docker Hub (requires docker login)."
    )
    parser.add_argument(
        "--dockerhub-username",
        help="Docker Hub username for tagging and pushing images."
    )

    args = parser.parse_args()
    
    # Determine default env file based on target
    if not args.env_file:
        if args.target == "k8s":
            args.env_file = ENV_FILE_PATH_DEV
        else:
            args.env_file = ENV_FILE_PATH_DOCKER if os.path.exists(ENV_FILE_PATH_DOCKER) else ENV_FILE_PATH_DEV

    try:
        print(f"--- Building for {args.target.upper()} target ---")
        
        # Set image tag based on target
        if args.target == "k8s":
            image_tag = APP_IMAGE_TAG_K8S
            if args.dockerhub_username:
                image_tag = f"{args.dockerhub_username}/{image_tag}"
        else:
            image_tag = APP_IMAGE_TAG_LOCAL
            
        dockerfile = APP_DOCKERFILE
        container_name = APP_CONTAINER_NAME

        # Only stop/remove container for local app mode
        if args.target == "app":
            print(f"Stopping and removing existing container '{container_name}' (if any)...")
            run_command(["docker", "kill", container_name], stderr=subprocess.DEVNULL, check=False)
            run_command(["docker", "rm", container_name], stderr=subprocess.DEVNULL, check=False)

        # Prepare build arguments
        build_args_cmd = ["docker", "build", "--pull", "-t", image_tag, "-f", dockerfile]

        # Load build args from .env file and defaults
        final_build_args = DEFAULT_BUILD_ARGS.copy()
        env_file_build_args = load_env_file(args.env_file)
        final_build_args.update(env_file_build_args) # .env file overrides defaults
        
        # Apply K8s-specific overrides
        if args.target == "k8s":
            final_build_args.update(K8S_BUILD_ARGS)
            print(f"Using K8s configuration from {args.env_file}")

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
        
        # Display build configuration
        print("\nBuild configuration:")
        for key, value in final_build_args.items():
            if "KEY" in key.upper():
                print(f"  {key}: ***hidden***")
            else:
                print(f"  {key}: {value}")

        # --- Build Docker Image ---
        if not run_command(build_args_cmd):
            sys.exit(1) # Exit if build fails

        # --- Push to Docker Hub (if requested) ---
        if args.push:
            if not args.dockerhub_username:
                print("ERROR: --dockerhub-username is required when using --push", file=sys.stderr)
                sys.exit(1)
            
            print(f"\nPushing image to Docker Hub...")
            if not run_command(["docker", "push", image_tag]):
                print("ERROR: Docker push failed!", file=sys.stderr)
                sys.exit(1)
            print(f"Successfully pushed: {image_tag}")
        
        # --- Run Docker Container (only for local app mode) ---
        if args.target == "app":
            run_args = [
                "docker", "run", "-d",
                "--name", container_name,
                "-p", f"{HOST_PORT_HTTP}:{CONTAINER_PORT_HTTP}",
                image_tag
            ]
            if not run_command(run_args):
                 print(f"ERROR: Docker run failed!", file=sys.stderr)
                 sys.exit(1)
            
            print(f"\nContainer '{container_name}' started successfully.")
            print(f"  Web app should be accessible at: http://localhost:{HOST_PORT_HTTP}{final_build_args.get('BASE_HREF', '/')}")
            print(f"  To view logs: docker logs {container_name} -f")
            print(f"  To stop:      docker kill {container_name} && docker rm {container_name}")
        elif args.target == "k8s":
            print(f"\nK8s image built successfully: {image_tag}")
            print("To deploy to Kubernetes:")
            print(f"  1. Update your deployment YAML with image: {image_tag}")
            print(f"  2. kubectl apply -f <your-deployment.yaml>")

        print("\nScript finished.")

    except Exception as e:
        print(f"\nAn unexpected error occurred: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
