#!/bin/bash

# Purpose: Ensure Kafka container is up, check KRaft quorum, setup admin user and ACLs
# Usage: Run on host where Broker-1 is running

set -e

# Load environment variables
source .env

CONTAINER_NAME=${CONTAINER_NAME_1:-kafka-broker-1}
BOOTSTRAP_INTERNAL="$SINGLE_NODE_IP:$BROKER1_INTERNAL_PORT"
BOOTSTRAP_AUTH="$SINGLE_NODE_IP:$BROKER1_EXTERNAL_PORT"
ADMIN_USER="admin"
ADMIN_PASSWORD="admin-password"
CLIENT_CONFIG_PATH="/opt/kafka/config/client-properties/admin.properties"

echo "🔍 Waiting for container '$CONTAINER_NAME' to be running..."

# Wait up to 60s (12 × 5s) for the container to be running
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

# Retry quorum check (wait for controller election)
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

# Admin user check
echo "👤 Checking if admin user exists..."
USER_EXISTS=$(sudo docker exec -i "$CONTAINER_NAME" \
  /opt/kafka/bin/kafka-configs.sh \
  --bootstrap-server "$BOOTSTRAP_INTERNAL" \
  --describe --entity-type users 2>/dev/null | grep -c "User:$ADMIN_USER" || true)

if [[ "$USER_EXISTS" -eq 0 ]]; then
  echo "🔧 Creating admin user..."
  sudo docker exec -i "$CONTAINER_NAME" \
    /opt/kafka/bin/kafka-configs.sh \
    --bootstrap-server "$BOOTSTRAP_INTERNAL" \
    --alter --add-config "SCRAM-SHA-512=[iterations=4096,password=$ADMIN_PASSWORD]" \
    --entity-type users --entity-name "$ADMIN_USER"
  echo "✅ Admin user created."
else
  echo "✅ Admin user already exists."
fi

# Admin ACL check
echo "🔐 Checking if admin ACLs exist..."
ACL_EXISTS=$(sudo docker exec -i "$CONTAINER_NAME" \
  /opt/kafka/bin/kafka-acls.sh \
  --bootstrap-server "$BOOTSTRAP_AUTH" \
  --command-config "$CLIENT_CONFIG_PATH" \
  --list --principal User:"$ADMIN_USER" 2>/dev/null | grep -c "Operation: All" || true)

if [[ "$ACL_EXISTS" -eq 0 ]]; then
  echo "🔧 Granting full ACLs to admin user..."
  sudo docker exec -i "$CONTAINER_NAME" \
    /opt/kafka/bin/kafka-acls.sh \
    --bootstrap-server "$BOOTSTRAP_AUTH" \
    --command-config "$CLIENT_CONFIG_PATH" \
    --add \
    --allow-principal User:"$ADMIN_USER" \
    --operation All \
    --resource-pattern-type prefixed \
    --topic '*' \
    --group '*' \
    --cluster
  echo "✅ ACLs granted to admin user."
else
  echo "✅ Admin user already has full ACLs."
fi

echo "🎉 Cluster quorum validated and admin setup complete."
