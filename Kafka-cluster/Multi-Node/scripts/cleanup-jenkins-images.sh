#!/bin/bash
set -e

source ../.env

IMAGE_PREFIX="multi-node-npc-uae-kafka-${KAFKA_RELEASE}"
echo "Removing ALL Jenkins images with prefix: $IMAGE_PREFIX"

docker images --format '{{.Repository}}:{{.Tag}}' | grep "$IMAGE_PREFIX" | while read img; do
  echo "Removing: $img"
  sudo docker rmi -f "$img" || echo "Failed: $img"
done

echo "Jenkins image cleanup done."
