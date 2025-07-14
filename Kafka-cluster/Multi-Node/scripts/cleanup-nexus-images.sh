#!/bin/bash
set -e

# Load env vars
source ../.env

IMAGE_PREFIX="multi-node-npc-uae-kafka-${KAFKA_RELEASE}"

echo "Cleaning Nexus... Only keeping 5 images for: $IMAGE_PREFIX"

curl -s -u "$NEXUS_USERNAME:$NEXUS_PASSWORD" \
  "http://${NEXUS_HOST}/v2/${NEXUS_REPO}/tags/list" | \
  jq -r '.tags[]' | grep "$IMAGE_PREFIX" | sort -r > tags.txt

if [ ! -s tags.txt ]; then
  echo "No matching images found."
  exit 0
fi

TO_DELETE=$(tail -n +6 tags.txt)

for tag in $TO_DELETE; do
  DIGEST=$(curl -sI -u "$NEXUS_USERNAME:$NEXUS_PASSWORD" \
    -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
    "http://${NEXUS_HOST}/v2/${NEXUS_REPO}/manifests/$tag" |
    grep Docker-Content-Digest | awk '{print $2}' | tr -d $'\r')

  if [ -n "$DIGEST" ]; then
    echo "🗑️ Deleting $tag ($DIGEST)"
    curl -s -X DELETE -u "$NEXUS_USERNAME:$NEXUS_PASSWORD" \
      "http://${NEXUS_HOST}/v2/${NEXUS_REPO}/manifests/$DIGEST"
  else
    echo "Failed to find digest for $tag"
  fi
done

rm -f tags.txt
echo "Nexus cleanup done."