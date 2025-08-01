#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

ENV_FILE="$PROJECT_ROOT/remote-env.sh"

if [ ! -f "$ENV_FILE" ]; then
  echo "❌ ERROR: remote-env.sh not found!"
  exit 1
fi

source "$ENV_FILE"

CONTAINER_NAME="$SINGLE_NODE_CONTAINER_NAME_1"
BOOTSTRAP_INTERNAL="$SINGLE_NODE_IP:$SINGLE_NODE_BROKER1_INTERNAL_PORT"
BOOTSTRAP_AUTH="$SINGLE_NODE_IP:$SINGLE_NODE_BROKER1_EXTERNAL_PORT"
ADMIN_USER="admin"
ADMIN_PASSWORD="admin-password"
CLIENT_CONFIG_PATH="/opt/kafka/config/client-properties/admin.properties"

echo "Checking if admin user exists..."
USER_EXISTS=$( podman exec -i "$CONTAINER_NAME" \
  /opt/kafka/bin/kafka-configs.sh \
  --bootstrap-server "$BOOTSTRAP_INTERNAL" \
  --describe --entity-type users --entity-name "$ADMIN_USER" 2>/dev/null | \
  grep -q "SCRAM-SHA-512" && echo "1" || echo "0")

if [[ "$USER_EXISTS" -eq 1 ]]; then
  echo "Admin user already exists."
else
  echo "🔧 Creating admin user..."
   podman exec -i "$CONTAINER_NAME" \
    /opt/kafka/bin/kafka-configs.sh \
    --bootstrap-server "$BOOTSTRAP_INTERNAL" \
    --alter --add-config "SCRAM-SHA-512=[iterations=4096,password=$ADMIN_PASSWORD]" \
    --entity-type users --entity-name "$ADMIN_USER"
  echo "Admin user created."
fi

echo "Verifying admin ACLs..."

# Expected ACLs (must match the reconstructed format exactly)
EXPECTED_ACLS=$(cat <<EOF
(principal=User:admin, host=*, operation=ALL, permissionType=ALLOW, resourceType=GROUP, name=*, patternType=PREFIXED)
(principal=User:admin, host=*, operation=ALL, permissionType=ALLOW, resourceType=TOPIC, name=*, patternType=PREFIXED)
(principal=User:admin, host=*, operation=ALL, permissionType=ALLOW, resourceType=CLUSTER, name=kafka-cluster, patternType=LITERAL)
EOF
)

# Get actual ACLs
CURRENT_ACLS=$( podman exec -i "$CONTAINER_NAME" \
  /opt/kafka/bin/kafka-acls.sh \
  --bootstrap-server "$BOOTSTRAP_AUTH" \
  --command-config "$CLIENT_CONFIG_PATH" \
  --list --principal User:"$ADMIN_USER" 2>/dev/null)

# Normalize ACL output to unified format: (principal...), resourceType=..., etc.
normalize_acls() {
  local combined=""
  local current_resource=""
  while IFS= read -r line; do
    if [[ "$line" == *"ResourcePattern("* ]]; then
      current_resource=$(echo "$line" | sed -n 's/.*ResourcePattern(\(.*\)).*/\1/p')
    elif [[ "$line" =~ "\(principal=User:.*" ]]; then
      acl_line=$(echo "$line" | sed 's/^[[:space:]]*//')
      combined+="$acl_line, $current_resource"$'\n'
    fi
  done <<< "$1"
  echo "$combined" | sort
}

NORMALIZED_EXPECTED=$(normalize_acls "$EXPECTED_ACLS")
NORMALIZED_CURRENT=$(normalize_acls "$CURRENT_ACLS")

# Compare
if diff <(echo "$NORMALIZED_EXPECTED") <(echo "$NORMALIZED_CURRENT") >/dev/null; then
  echo "Admin user already has expected ACLs. Skipping ACL update."
else
  echo "Some ACLs are missing:"
  comm -23 <(echo "$NORMALIZED_EXPECTED") <(echo "$NORMALIZED_CURRENT") | while read -r missing; do
    echo "Missing ACL: $missing"
  done

  echo "Updating Admin ACLs..."

   podman exec -i "$CONTAINER_NAME" /opt/kafka/bin/kafka-acls.sh \
    --bootstrap-server "$BOOTSTRAP_AUTH" \
    --command-config "$CLIENT_CONFIG_PATH" \
    --add --allow-principal "User:$ADMIN_USER" \
    --operation All \
    --resource-pattern-type prefixed \
    --topic '*' \
    --group '*'

   podman exec -i "$CONTAINER_NAME" /opt/kafka/bin/kafka-acls.sh \
    --bootstrap-server "$BOOTSTRAP_AUTH" \
    --command-config "$CLIENT_CONFIG_PATH" \
    --add --allow-principal "User:$ADMIN_USER" \
    --operation All \
    --resource-pattern-type literal \
    --cluster

  echo "ACLs granted to admin user."
fi
