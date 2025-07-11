#!/bin/bash

set -e
source ../.env

CONTAINER_NAME=${CONTAINER_NAME_1:-kafka-broker-1}
BOOTSTRAP_INTERNAL="$BROKER1_IP:$INTERNAL_PORT"
BOOTSTRAP_AUTH="$BROKER1_IP:$EXTERNAL_PORT"
ADMIN_USER="admin"
ADMIN_PASSWORD="admin-password"
CLIENT_CONFIG_PATH="/opt/kafka/config/client-properties/admin.properties"

echo "👤 Checking if admin user '$ADMIN_USER' exists..."

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
  echo "✅ Admin user already exists. Skipping creation."
fi

echo "🔐 Verifying admin ACLs..."

CURRENT_ACLS=$(sudo docker exec -i "$CONTAINER_NAME" \
  /opt/kafka/bin/kafka-acls.sh \
  --bootstrap-server "$BOOTSTRAP_AUTH" \
  --command-config "$CLIENT_CONFIG_PATH" \
  --list --principal User:"$ADMIN_USER" 2>/dev/null)

EXPECTED_PATTERN="User:$ADMIN_USER has Allow permission for operations: All on cluster, topics and groups"

# Check if current ACL contains required permissions
if echo "$CURRENT_ACLS" | grep -q "Operation: All" && echo "$CURRENT_ACLS" | grep -q "PermissionType: Allow"; then
  echo "✅ Admin user already has required ACLs. Skipping ACL update."
else
  echo "🔁 Updating Admin ACLs ..."

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
fi
