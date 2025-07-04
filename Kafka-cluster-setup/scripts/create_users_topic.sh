#!/bin/bash

# Purpose: Create Kafka users, topics, and assign ACLs securely via container
# Usage: Run from host – this script will exec into the Kafka container

set -e

# Load environment variables
source .env

CONTAINER_NAME=${CONTAINER_NAME_1:-kafka-broker-1}
BOOTSTRAP_SERVER="${BROKER1_IP}:9094"
CONFIG="/opt/kafka/config/client-properties/admin.properties"

# ---------- Users & Passwords ----------
declare -A USER_PASSWORDS=(
  [du]="du-password"
  [etis]="etis-password"
  [crdb]="crdb-password"
  [tdra]="tdra-password"
)

# ---------- Topic Declarations ----------
TOPICS=("npc-raw-msg" "etis-pos-data" "du-pos-data")

# ---------- Access Matrix ----------
declare -A READ_ACCESS=(
  ["npc-raw-msg"]="du etis"
  ["etis-pos-data"]="crdb tdra"
  ["du-pos-data"]="crdb tdra"
)

declare -A WRITE_ACCESS=(
  ["npc-raw-msg"]="crdb"
  ["etis-pos-data"]="du etis"
  ["du-pos-data"]="du etis"
)

# ---------- Container Check ----------
echo "🔍 Checking if container '$CONTAINER_NAME' is running..."
STATUS=$(sudo docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null || echo "false")
if [[ "$STATUS" != "true" ]]; then
  echo "❌ ERROR: Container $CONTAINER_NAME is not running."
  exit 1
fi

# ---------- Helper Functions ----------

user_exists() {
  sudo docker exec "$CONTAINER_NAME" /opt/kafka/bin/kafka-configs.sh \
    --bootstrap-server "$BOOTSTRAP_SERVER" \
    --command-config "$CONFIG" \
    --describe --entity-type users 2>/dev/null | grep -q "User:$1"
}

create_user() {
  local user=$1
  local password=${USER_PASSWORDS[$user]}

  if user_exists "$user"; then
    echo "✅ User '$user' already exists. Skipping."
  else
    echo "➕ Creating user: $user"
    sudo docker exec "$CONTAINER_NAME" /opt/kafka/bin/kafka-configs.sh \
      --bootstrap-server "$BOOTSTRAP_SERVER" \
      --command-config "$CONFIG" \
      --alter \
      --add-config "SCRAM-SHA-512=[iterations=4096,password=$password]" \
      --entity-type users --entity-name "$user"
    echo "✅ User '$user' created."
  fi
}

topic_exists() {
  sudo docker exec "$CONTAINER_NAME" /opt/kafka/bin/kafka-topics.sh \
    --bootstrap-server "$BOOTSTRAP_SERVER" \
    --command-config "$CONFIG" \
    --list 2>/dev/null | grep -wq "$1"
}

create_topic() {
  local topic=$1
  if topic_exists "$topic"; then
    echo "✅ Topic '$topic' already exists. Skipping."
  else
    echo "📦 Creating topic: $topic"
    if sudo docker exec "$CONTAINER_NAME" /opt/kafka/bin/kafka-topics.sh \
      --bootstrap-server "$BOOTSTRAP_SERVER" \
      --command-config "$CONFIG" \
      --create --topic "$topic" --partitions 3 --replication-factor 3 2>&1 | tee /tmp/topic-create.log |
      grep -q "Topic.*already exists"; then
      echo "⚠️ Warning: Topic '$topic' already exists."
    else
      echo "✅ Topic '$topic' created."
    fi
  fi
}

acl_exists() {
  local topic=$1
  local user=$2
  local operation=$3
  sudo docker exec "$CONTAINER_NAME" /opt/kafka/bin/kafka-acls.sh \
    --bootstrap-server "$BOOTSTRAP_SERVER" \
    --command-config "$CONFIG" \
    --list --topic "$topic" 2>/dev/null |
    grep -q "User:$user.*Operation:$operation"
}

grant_acl() {
  local topic=$1
  local user=$2
  local operation=$3
  if acl_exists "$topic" "$user" "$operation"; then
    echo "✅ ACL '$operation' for user '$user' on topic '$topic' already exists. Skipping."
  else
    echo "🔐 Granting $operation access to user '$user' on topic '$topic'"
    sudo docker exec "$CONTAINER_NAME" /opt/kafka/bin/kafka-acls.sh \
      --bootstrap-server "$BOOTSTRAP_SERVER" \
      --command-config "$CONFIG" \
      --add --allow-principal "User:$user" \
      --operation "$operation" \
      --topic "$topic"
  fi
}

# ---------- Execution ----------

echo "🚀 Starting Kafka User, Topic, and ACL Setup"

# Step 1: Create Users
for user in "${!USER_PASSWORDS[@]}"; do
  create_user "$user"
done

# Step 2: Create Topics
for topic in "${TOPICS[@]}"; do
  create_topic "$topic"
done

# Step 3: Apply Read ACLs
for topic in "${!READ_ACCESS[@]}"; do
  for user in ${READ_ACCESS[$topic]}; do
    grant_acl "$topic" "$user" Read
  done
done

# Step 4: Apply Write ACLs
for topic in "${!WRITE_ACCESS[@]}"; do
  for user in ${WRITE_ACCESS[$topic]}; do
    grant_acl "$topic" "$user" Write
  done
done

echo "🎉 Kafka user, topic, and ACL setup complete."
