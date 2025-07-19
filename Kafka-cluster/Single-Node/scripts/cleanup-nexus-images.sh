#!/bin/bash
set -e

# Get full workspace root path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
ENV_FILE="$WORKSPACE_ROOT/remote-env.sh"

if [ ! -f "$ENV_FILE" ]; then
  echo "❌ remote-env.sh not found at $ENV_FILE"
  exit 1
fi

source "$ENV_FILE"

IMAGE_NAME="single-node-npc-uae-kafka-${KAFKA_RELEASE}"
REPO_PATH="uae-kafka/${IMAGE_NAME}"

echo "📦 Cleaning Nexus repo '$REPO_PATH' - Only keeping latest 5 tags"

# Get tags sorted descending
curl -s -u "$NEXUS_USERNAME:$NEXUS_PASSWORD" \
  "http://${NEXUS_HOST}/v2/${REPO_PATH}/tags/list" | \
  jq -r '.tags[]' | sort -r > tags.txt

if [ ! -s tags.txt ]; then
  echo "⚠️ No matching image tags found."
  exit 0
fi

# Delete all except the latest 5
TO_DELETE=$(tail -n +6 tags.txt)

for tag in $TO_DELETE; do
  DIGEST=$(curl -sI -u "$NEXUS_USERNAME:$NEXUS_PASSWORD" \
    -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
    "http://${NEXUS_HOST}/v2/${REPO_PATH}/manifests/$tag" |
    grep Docker-Content-Digest | awk '{print $2}' | tr -d $'\r')

  if [ -n "$DIGEST" ]; then
    echo "🗑️ Deleting tag: $tag ($DIGEST)"
    curl -s -X DELETE -u "$NEXUS_USERNAME:$NEXUS_PASSWORD" \
      "http://${NEXUS_HOST}/v2/${REPO_PATH}/manifests/$DIGEST"
  else
    echo "❌ Failed to find digest for $tag"
  fi
done

rm -f tags.txt
echo "✅ Nexus cleanup complete."
