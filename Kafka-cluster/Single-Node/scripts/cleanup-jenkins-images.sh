#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../../.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "❌ .env file not found at $ENV_FILE"
  exit 1
fi

source "$ENV_FILE"

IMAGE_PREFIX="single-node-npc-uae-kafka-${KAFKA_RELEASE}"
echo "Removing ALL Jenkins images with prefix: $IMAGE_PREFIX"

docker images --format '{{.Repository}}:{{.Tag}}' | grep "$IMAGE_PREFIX" | while read img; do
  echo "Removing: $img"
  docker rmi -f "$img" || echo "Failed: $img"
done

echo "✅ Jenkins image cleanup done."

