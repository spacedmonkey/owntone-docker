#!/usr/bin/env bash
set -euo pipefail

# Creates the named pipes (FIFOs) for multiple audio services.
# Works on both Linux and macOS.
# Run this once before starting the containers.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPE_DIR="${SCRIPT_DIR}/pipes"

# Define the array of audio services you want to create pipes for
SERVICES=("spotify" "airplay" "audio-input")

OS="$(uname -s)"
case "${OS}" in
  Linux|Darwin)
    echo "Detected OS: ${OS}"
    ;;
  *)
    echo "Unsupported OS: ${OS}" >&2
    exit 1
    ;;
esac

# Create the pipes directory if it doesn't exist
if [ ! -d "${PIPE_DIR}" ]; then
  mkdir -p "${PIPE_DIR}"
  echo "Created directory: ${PIPE_DIR}"
fi

# Loop through each service to create its audio and metadata named pipes
for SERVICE in "${SERVICES[@]}"; do
  # Define paths for the current service
  PIPE_PATH="${PIPE_DIR}/${SERVICE}"
  PIPE_METADATA_PATH="${PIPE_DIR}/${SERVICE}.metadata"

  echo "--- Processing service: ${SERVICE} ---"

  # 1. Create the main audio named pipe
  if [ -p "${PIPE_PATH}" ]; then
    echo "Pipe already exists: ${PIPE_PATH}"
  else
    if [ -e "${PIPE_PATH}" ]; then
      echo "Removing existing non-pipe file at: ${PIPE_PATH}"
      rm "${PIPE_PATH}"
    fi
    mkfifo "${PIPE_PATH}"
    echo "Created named pipe: ${PIPE_PATH}"
  fi

  # 2. Create the metadata named pipe
  if [ -p "${PIPE_METADATA_PATH}" ]; then
    echo "Pipe already exists: ${PIPE_METADATA_PATH}"
  else
    if [ -e "${PIPE_METADATA_PATH}" ]; then
      echo "Removing existing non-pipe file at: ${PIPE_METADATA_PATH}"
      rm "${PIPE_METADATA_PATH}"
    fi
    mkfifo "${PIPE_METADATA_PATH}"
    echo "Created named pipe: ${PIPE_METADATA_PATH}"
  fi
done

echo "--------------------------------------"
chmod +x ./scripts/spotify-metadata.sh 2>/dev/null || echo "Note: ./scripts/spotify-metadata.sh not found, skipping chmod."

echo "Done. You can now run: docker compose up -d"
