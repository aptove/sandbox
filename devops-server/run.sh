#!/usr/bin/env bash
# run.sh — one-command startup for the devops-server container.
#
# Usage:
#   ./run.sh                          # interactive shell, no shared folder
#   HOST_SHARE_PATH=/path ./run.sh    # bind-mount host folder to /workspace
#   ./run.sh -- bash -c "node -e '...'"  # run a specific command
#
# Environment variables:
#   HOST_SHARE_PATH   Host directory to mount at /workspace (optional)
#   IMAGE             Override the image name/tag (optional)
set -euo pipefail

IMAGE="${IMAGE:-ghcr.io/aptove/devops-server:latest}"

# ── Detect runtime ────────────────────────────────────────────────────────────
if command -v container >/dev/null 2>&1; then
    RUNTIME="container"
elif command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    RUNTIME="docker"
else
    echo "error: neither Apple 'container' CLI nor 'docker' found on PATH." >&2
    exit 1
fi

echo "Using runtime: $RUNTIME"

# ── Build argument lists ──────────────────────────────────────────────────────
COMMON_FLAGS=(
    --rm
    --interactive
    --tty
    # Required for UFW (iptables) and Tailscale (tun device)
    --cap-add=NET_ADMIN
)

VOLUME_FLAGS=()
if [ -n "${HOST_SHARE_PATH:-}" ]; then
    if [ ! -d "$HOST_SHARE_PATH" ]; then
        echo "error: HOST_SHARE_PATH='$HOST_SHARE_PATH' does not exist or is not a directory." >&2
        exit 1
    fi
    echo "Mounting $HOST_SHARE_PATH -> /workspace"
    VOLUME_FLAGS=(-v "${HOST_SHARE_PATH}:/workspace")
fi

# Collect any extra args passed after --
USER_CMD=()
if [ $# -gt 0 ]; then
    # Strip a leading '--' separator if present
    if [ "$1" = "--" ]; then shift; fi
    USER_CMD=("$@")
fi

# ── Launch ────────────────────────────────────────────────────────────────────
if [ "$RUNTIME" = "docker" ]; then
    docker run \
        "${COMMON_FLAGS[@]}" \
        --device /dev/net/tun \
        "${VOLUME_FLAGS[@]}" \
        "$IMAGE" \
        "${USER_CMD[@]+"${USER_CMD[@]}"}"

elif [ "$RUNTIME" = "container" ]; then
    # Apple's container CLI uses the same flag names for volumes.
    # --device is not required on Apple container (virtualised network).
    container run \
        "${COMMON_FLAGS[@]}" \
        "${VOLUME_FLAGS[@]}" \
        "$IMAGE" \
        "${USER_CMD[@]+"${USER_CMD[@]}"}"
fi
