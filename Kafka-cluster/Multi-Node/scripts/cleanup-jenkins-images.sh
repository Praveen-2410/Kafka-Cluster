#!/bin/bash
set -e

# Get full workspace root path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$WORKSPACE_ROOT/remote-env.sh"

if [ ! -f "$ENV_FILE" ]; then
  echo "❌ remote-env.sh not found at $ENV_FILE"
  exit 1
fi

source "$ENV_FILE"

IMAGE_PREFIX="multi-node-npc-uae-kafka-${KAFKA_RELEASE}"
echo "Removing ALL Jenkins images with prefix: $IMAGE_PREFIX"

docker images --format '{{.Repository}}:{{.Tag}}' | grep "$IMAGE_PREFIX" | while read img; do
  echo "Removing: $img"
  docker rmi -f "$img" || echo "Failed: $img"
done

echo "✅ Jenkins image cleanup done."

