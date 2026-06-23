#!/usr/bin/env bash
set -euo pipefail

# Creates the named pipe (FIFO) for spotifyd audio output.
# Works on both Linux and macOS.
# Run this once before starting the containers.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPE_DIR="${SCRIPT_DIR}/spotify-pipe"
PIPE_PATH="${PIPE_DIR}/spotify.pcm"

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

# Create the directory if it doesn't exist
if [ ! -d "${PIPE_DIR}" ]; then
  mkdir -p "${PIPE_DIR}"
  echo "Created directory: ${PIPE_DIR}"
fi

# Create the named pipe
if [ -p "${PIPE_PATH}" ]; then
  echo "Pipe already exists: ${PIPE_PATH}"
else
  # Remove any regular file that might be in the way
  if [ -e "${PIPE_PATH}" ]; then
    echo "Removing existing non-pipe file at: ${PIPE_PATH}"
    rm "${PIPE_PATH}"
  fi
  mkfifo "${PIPE_PATH}"
  echo "Created named pipe: ${PIPE_PATH}"
fi

echo "Done. You can now run: docker compose up -d"
