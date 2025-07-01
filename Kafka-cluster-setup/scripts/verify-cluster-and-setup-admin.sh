#!/bin/bash

# Purpose: Check KRaft quorum, ensure admin user exists, and apply ACLs
# Usage: Run this on the host machine of Broker-1

set -e

# Load environment
source .env

CONTAINER_NAME=${CONTAINER_NAME_1:-kafka-broker-1}
BOOTSTRAP_SERVER="localhost:9092"
ADMIN_USER="admin"
ADMIN_PASSWORD="admin-password"
TRUSTSTORE_PATH="/opt/kafka/secrets/ca-truststore.p12"
CLIENT_CONFIG_PATH="/opt/kafka/config/client-properties/client-admin.properties"

# Step 1: Describe metadata quorum
echo "Checking KRaft quorum inside container: $CONTAINER_NAME..."
sudo docker exec -i "$CONTAINER_NAME" /opt/kafka/bin/kafka-metadata-quorum.sh \
  --bootstrap-server "$BOOTSTRAP_SERVER" describe --status \
  | grep -E "ClusterId|LeaderId|HighWatermark"

echo "Quorum healthy."

# Step 2: Check if admin user exists
echo "Checking if admin user exists..."
USER_EXISTS=$(sudo docker exec -i "$CONTAINER_NAME" \
  /opt/kafka/bin/kafka-configs.sh \
  --bootstrap-server "$BOOTSTRAP_SERVER" \
  --command-config "$CLIENT_CONFIG_PATH" \
  --describe --entity-type users \
  | grep -c "User:$ADMIN_USER")

if [[ "$USER_EXISTS" -eq 0 ]]; then
  echo "Creating admin user..."
  sudo docker exec -i "$CONTAINER_NAME" \
    /opt/kafka/bin/kafka-configs.sh \
    --bootstrap-server "$BOOTSTRAP_SERVER" \
    --command-config "$CLIENT_CONFIG_PATH" \
    --alter --add-config "SCRAM-SHA-512=[iterations=4096,password=$ADMIN_PASSWORD]" \
    --entity-type users --entity-name "$ADMIN_USER"
else
  echo "Admin user already exists."
fi

# Step 3: Check if admin has ACLs
echo "Checking if admin ACLs exist..."
ACL_EXISTS=$(sudo docker exec -i "$CONTAINER_NAME" \
  /opt/kafka/bin/kafka-acls.sh \
  --bootstrap-server "$BOOTSTRAP_SERVER" \
  --command-config "$CLIENT_CONFIG_PATH" \
  --list --principal User:"$ADMIN_USER" \
  | grep -c "Operation: All")

if [[ "$ACL_EXISTS" -eq 0 ]]; then
  echo "Granting full ACLs to admin user..."
  sudo docker exec -i "$CONTAINER_NAME" \
    /opt/kafka/bin/kafka-acls.sh \
    --bootstrap-server "$BOOTSTRAP_SERVER" \
    --command-config "$CLIENT_CONFIG_PATH" \
    --add \
    --allow-principal User:"$ADMIN_USER" \
    --operation All \
    --resource-pattern-type prefixed \
    --topic '*' \
    --group '*' \
    --cluster
else
  echo "Admin user already has full ACLs."
fi

echo "Cluster health verified and admin setup complete."