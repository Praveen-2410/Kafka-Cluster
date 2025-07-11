#!/bin/bash

# Purpose: Ensure Kafka container is up, check KRaft quorum, setup admin user and ACLs
# Usage: Run on host where Broker-1 is running

set -e

# Load environment variables
source ../.env

CONTAINER_NAME=${CONTAINER_NAME_1:-kafka-broker-1}
BOOTSTRAP_INTERNAL="$BROKER1_IP:$INTERNAL_PORT"
BOOTSTRAP_AUTH="$BROKER1_IP:$EXTERNAL_PORT"
ADMIN_USER="admin"
ADMIN_PASSWORD="admin-password"
CLIENT_CONFIG_PATH="/opt/kafka/config/client-properties/admin.properties"

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
echo "🔐 Verifying admin ACLs..."

# Define the expected ACLs as a string
read -r -d '' EXPECTED_ACLS <<EOF
(principal=User:admin, host=*, operation=ALL, permissionType=ALLOW, resourceType=GROUP, name=*, patternType=PREFIXED)
(principal=User:admin, host=*, operation=ALL, permissionType=ALLOW, resourceType=TOPIC, name=*, patternType=PREFIXED)
(principal=User:admin, host=*, operation=ALL, permissionType=ALLOW, resourceType=CLUSTER, name=kafka-cluster, patternType=LITERAL)
EOF

# Fetch current ACLs from Kafka
CURRENT_ACLS=$(sudo docker exec -i "$CONTAINER_NAME" \
  /opt/kafka/bin/kafka-acls.sh \
  --bootstrap-server "$BOOTSTRAP_AUTH" \
  --command-config "$CLIENT_CONFIG_PATH" \
  --list --principal User:"$ADMIN_USER" 2>/dev/null)

# Normalize both (strip whitespace, sort)
normalize_acls() {
  echo "$1" | grep "(principal=" | sed 's/^[[:space:]]*//' | sort
}

NORMALIZED_EXPECTED=$(normalize_acls "$EXPECTED_ACLS")
NORMALIZED_CURRENT=$(normalize_acls "$CURRENT_ACLS")

if [[ "$NORMALIZED_CURRENT" == "$NORMALIZED_EXPECTED" ]]; then
  echo "✅ Admin user already has expected ACLs. Skipping ACL update."
else
  echo "🔁 Updating Admin ACLs..."

  # First, remove existing ACLs for admin user (optional, if you want clean replacement)
  sudo docker exec -i "$CONTAINER_NAME" \
    /opt/kafka/bin/kafka-acls.sh \
    --bootstrap-server "$BOOTSTRAP_AUTH" \
    --command-config "$CLIENT_CONFIG_PATH" \
    --remove --force --principal User:"$ADMIN_USER" \
    --topic '*' --group '*' --cluster

  # Re-apply full expected ACLs
  sudo docker exec -i "$CONTAINER_NAME" \
    /opt/kafka/bin/kafka-acls.sh \
    --bootstrap-server "$BOOTSTRAP_AUTH" \
    --command-config "$CLIENT_CONFIG_PATH" \
    --add --allow-principal User:"$ADMIN_USER" \
    --operation All \
    --resource-pattern-type prefixed \
    --topic '*' \
    --group '*' \
    --cluster

  echo "✅ ACLs granted to admin user."
fi
