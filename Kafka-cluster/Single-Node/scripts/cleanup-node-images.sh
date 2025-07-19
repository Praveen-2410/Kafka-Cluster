#!/bin/bash

# Load environment variables
ENV_FILE="$(dirname "$0")/../remote-env.sh"
if [ ! -f "$ENV_FILE" ]; then
  echo "❌ remote-env.sh not found!"
  exit 1
fi

# ✅ Load all exported variables (this will work)
source "$ENV_FILE"

# Now verify if needed vars exist
if [ -z "$KAFKA_RELEASE" ] || [ -z "$NEXUS_REPO" ]; then
  echo "❌ Missing KAFKA_RELEASE or NEXUS_REPO in remote-env.sh"
  exit 1
fi


# Show currently available images
echo "All matching images:"
docker images --format '{{.Repository}}:{{.Tag}} {{.CreatedAt}}' | grep "${NEXUS_REPO}/npc-uae-kafka-${KAFKA_RELEASE}" | sort -k2 -r

# Delete older images, keeping only the 3 most recent
echo "Cleaning up..."
IMAGES_TO_DELETE=$(docker images --format '{{.Repository}}:{{.Tag}} {{.CreatedAt}}' | grep "${NEXUS_REPO}/single-node-npc-uae-kafka-${KAFKA_RELEASE}" | sort -k2 -r | tail -n +4 | awk '{print $1}')

for img in $IMAGES_TO_DELETE; do
  echo "Removing $img"
  docker rmi -f "$img" || echo "Failed to delete $img"
done

echo "Node image cleanup complete. Retained latest 3."
