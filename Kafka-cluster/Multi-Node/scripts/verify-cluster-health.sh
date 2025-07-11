#!/bin/bash

# Load environment variables
source ../.env

set -e

CONTAINER_NAME=${CONTAINER_NAME_1:-kafka-broker-1}
BOOTSTRAP_INTERNAL="$BROKER1_IP:$INTERNAL_PORT"

echo "🔍 Waiting for container '$CONTAINER_NAME' to be running..."

# Wait for container to start
for attempt in {1..12}; do
  STATUS=$(sudo docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null || echo "false")
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
  sudo docker exec -i "$CONTAINER_NAME" /opt/kafka/bin/kafka-metadata-quorum.sh \
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
