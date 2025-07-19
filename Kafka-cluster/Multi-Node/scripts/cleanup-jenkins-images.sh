#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(dirname "$PROJECT_ROOT")"

ENV_FILE="$ROOT_DIR/remote-env.sh"

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

