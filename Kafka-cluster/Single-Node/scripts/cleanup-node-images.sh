#!/bin/bash
set -e

# Find REMOTE_DIR relative to this script's location
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REMOTE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Path to .env file
ENV_FILE="$REMOTE_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: .env file not found at $ENV_FILE"
  exit 1
fi

echo "Found .env at: $ENV_FILE"
source "$ENV_FILE"


# Show currently available images
echo "All matching images:"
podman images --format '{{.Repository}}:{{.Tag}} {{.CreatedAt}}' | grep "${NEXUS_REPO}/npc-uae-kafka-${KAFKA_RELEASE}" | sort -k2 -r

# Delete older images, keeping only the 3 most recent
echo "Cleaning up..."
IMAGES_TO_DELETE=$(podman images --format '{{.Repository}}:{{.Tag}} {{.CreatedAt}}' | grep "${NEXUS_REPO}/single-node-npc-uae-kafka-${KAFKA_RELEASE}" | sort -k2 -r | tail -n +4 | awk '{print $1}')

for img in $IMAGES_TO_DELETE; do
  echo "Removing $img"
  podman rmi -f "$img" || echo "Failed to delete $img"
done

echo "Node image cleanup complete. Retained latest 3."
