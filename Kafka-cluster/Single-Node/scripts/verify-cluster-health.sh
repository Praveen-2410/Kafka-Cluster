#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

ENV_FILE="$PROJECT_ROOT/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "❌ ERROR: .env not found!"
  exit 1
fi

source "$ENV_FILE"

CONTAINER_NAME="$SINGLE_NODE_CONTAINER_NAME_1"
BOOTSTRAP_INTERNAL="$SINGLE_NODE_IP:$SINGLE_NODE_BROKER1_INTERNAL_PORT"

echo "🔍 Waiting for container '$CONTAINER_NAME' to be running..."

# Wait for container to start
for attempt in {1..12}; do
  STATUS=$( podman inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null || echo "false")
  if [[ "$STATUS" == "true" ]]; then
    echo "✅ Container $CONTAINER_NAME is running."
    break
  else
    echo "⏳ Attempt $attempt: Container not running yet, retrying in 5s..."
    sleep 5
  fi
done

# Final check
if [[ "$STATUS" != "true" ]]; then
  echo "❌ ERROR: Container $CONTAINER_NAME is not running after timeout."
  exit 1
fi

echo "🔍 Verifying KRaft quorum status inside $CONTAINER_NAME..."

# Retry quorum check
QUORUM_READY=0
for attempt in {1..5}; do
  set +e
   podman exec -i "$CONTAINER_NAME" /opt/kafka/bin/kafka-metadata-quorum.sh \
    --bootstrap-server "$BOOTSTRAP_INTERNAL" describe --status > /tmp/quorum-status.txt
  STATUS=$?
  set -e

  if [[ "$STATUS" -eq 0 ]]; then
    echo "✅ Quorum established."
    grep -E "ClusterId|LeaderId|HighWatermark" /tmp/quorum-status.txt
    QUORUM_READY=1
    break
  else
    echo "⏳ Attempt $attempt: Quorum not ready, retrying in 10s..."
    sleep 10
  fi
done

if [[ "$QUORUM_READY" -eq 0 ]]; then
  echo "❌ ERROR: Quorum check failed after 5 retries."
  exit 1
fi

echo "🎉 Kafka cluster is running and quorum is healthy."
