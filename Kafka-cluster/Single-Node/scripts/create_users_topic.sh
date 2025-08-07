#!/bin/bash

# Purpose: Create Kafka users, topics, and ACLs
set -e

# Load environment and entities
source ../.env
source kafka-entities.sh

CONTAINER_NAME="$SINGLE_NODE_CONTAINER_NAME_1"
BOOTSTRAP="${SINGLE_NODE_IP}:${SINGLE_NODE_BROKER1_EXTERNAL_PORT}"
CONFIG="/opt/kafka/config/client-properties/admin.properties"

echo "CONTAINER_NAME: $CONTAINER_NAME"
echo "BOOTSTRAP: $BOOTSTRAP"
echo "Admin config: $CONFIG"

# 🔧 Helper: Remove Optional[...] wrappers
sanitize_topic_name() {
  echo "$1" | sed 's/Optional\[//;s/\]//'
}

# ✅ Check if user exists
user_exists() {
   podman exec "$CONTAINER_NAME" /opt/kafka/bin/kafka-configs.sh \
    --bootstrap-server "$BOOTSTRAP" \
    --command-config "$CONFIG" \
    --describe --entity-type users --entity-name "$1" 2>/dev/null |
    grep -q "SCRAM-SHA-512"
}

# ✅ Create user if not exists
create_user() {
  local user=$1
  local password=${USER_PASSWORDS[$user]}

  if user_exists "$user"; then
    echo "✅ User '$user' exists"
  else
    echo "➕ Creating user: $user"
     podman exec "$CONTAINER_NAME" /opt/kafka/bin/kafka-configs.sh \
      --bootstrap-server "$BOOTSTRAP" \
      --command-config "$CONFIG" \
      --alter --add-config "SCRAM-SHA-512=[iterations=4096,password=$password]" \
      --entity-type users --entity-name "$user"
  fi
}

topic_exists() {
  local topic
  topic=$(sanitize_topic_name "$1")

   podman exec "$CONTAINER_NAME" /opt/kafka/bin/kafka-topics.sh \
    --bootstrap-server "$BOOTSTRAP" \
    --command-config "$CONFIG" \
    --describe --topic "$topic" >/dev/null 2>&1
}


# ✅ Create topic if not exists
create_topic() {
  local topic
  topic=$(sanitize_topic_name "$1")

# Check if topic exists
  if topic_exists "$topic"; then
    echo "✅ Topic '$topic' already exists. Skipping."
    return 0
  fi

  echo "📦 Creating topic: $topic"
  if  podman exec "$CONTAINER_NAME" /opt/kafka/bin/kafka-topics.sh \
      --bootstrap-server "$BOOTSTRAP" \
      --command-config "$CONFIG" \
      --create --topic "$topic" \
      --partitions 3 --replication-factor 3; then
    echo "✅ Successfully created topic '$topic'"
  else
    echo "❌ Failed to create topic '$topic'"
    exit 1
  fi
}


# ✅ Check if ACL exists
acl_exists() {
  local topic=$(sanitize_topic_name "$1")
  local user=$2
  local op=$3

   podman exec "$CONTAINER_NAME" /opt/kafka/bin/kafka-acls.sh \
    --bootstrap-server "$BOOTSTRAP" \
    --command-config "$CONFIG" \
    --list --topic "$topic" 2>/dev/null |
    grep -iq "User:$user.*operation=$op"
}

# ✅ Grant ACL if not already exists
grant_acl() {
  local topic=$(sanitize_topic_name "$1")
  local user=$2
  local op=$3

  if acl_exists "$topic" "$user" "$op"; then
    echo "✅ ACL '$op' for '$user' on '$topic' exists"
  else
    echo "🔐 Granting $op to '$user' on '$topic'"
     podman exec "$CONTAINER_NAME" /opt/kafka/bin/kafka-acls.sh \
      --bootstrap-server "$BOOTSTRAP" \
      --command-config "$CONFIG" \
      --add --allow-principal "User:$user" \
      --operation "$op" --topic "$topic"
  fi
}

echo "🚀 Kafka Users, Topics & ACLs Setup Starting..."

# 1️⃣ Create Users
for user in "${!USER_PASSWORDS[@]}"; do
  create_user "$user"
done

# 2️⃣ Create Topics
for topic in "${TOPICS[@]}"; do
  create_topic "$topic"
done

# 3️⃣ Apply Read ACLs
for topic in "${!READ_ACCESS[@]}"; do
  for user in ${READ_ACCESS[$topic]}; do
    grant_acl "$topic" "$user" "Read"
  done
done

# 4️⃣ Apply Write ACLs
for topic in "${!WRITE_ACCESS[@]}"; do
  for user in ${WRITE_ACCESS[$topic]}; do
    grant_acl "$topic" "$user" "Write"
  done
done

echo "🎉 Kafka ACL setup complete!"
