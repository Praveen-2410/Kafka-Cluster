#!/bin/bash

# Purpose: Create Kafka users, topics, and ACLs
set -e

# Load env and entity definitions
source ../.env
source kafka-entities.sh

CONTAINER_NAME=${CONTAINER_NAME_1:-kafka-broker-1}
BOOTSTRAP="${BROKER1_IP}:9094"
CONFIG="/opt/kafka/config/client-properties/admin.properties"

echo "CONTAINER_NAME: $CONTAINER_NAME"
echo "BOOTSTRAP: $BOOTSTRAP"
echo "Admin config: $CONFIG"

# Helper: Check if user exists
user_exists() {
  sudo docker exec "$CONTAINER_NAME" /opt/kafka/bin/kafka-configs.sh \
    --bootstrap-server "$BOOTSTRAP" \
    --command-config "$CONFIG" \
    --describe --entity-type users --entity-name "$1" 2>/dev/null |
    grep -q "SCRAM-SHA-512"
}

# Helper: Create user if not exists
create_user() {
  local user=$1
  local password=${USER_PASSWORDS[$user]}

  if user_exists "$user"; then
    echo "✅ User '$user' exists"
  else
    echo "➕ Creating user: $user"
    sudo docker exec "$CONTAINER_NAME" /opt/kafka/bin/kafka-configs.sh \
      --bootstrap-server "$BOOTSTRAP" \
      --command-config "$CONFIG" \
      --alter --add-config "SCRAM-SHA-512=[iterations=4096,password=$password]" \
      --entity-type users --entity-name "$user"
  fi
}

# Helper: Check if topic exists
topic_exists() {
  sudo docker exec "$CONTAINER_NAME" /opt/kafka/bin/kafka-topics.sh \
    --bootstrap-server "$BOOTSTRAP" \
    --command-config "$CONFIG" \
    --list 2>/dev/null | grep -Fxq "$1"
}

# Helper: Create topic if not exists
create_topic() {
  local topic=$1
  if topic_exists "$topic"; then
    echo "✅ Topic '$topic' already exists. Skipping."
    return 0
  fi

  echo "📦 Creating topic: $topic"
  sudo docker exec "$CONTAINER_NAME" /opt/kafka/bin/kafka-topics.sh \
    --bootstrap-server "$BOOTSTRAP" \
    --command-config "$CONFIG" \
    --create --topic "$topic" --partitions 3 --replication-factor 3 2>/dev/null \
  && echo "✅ Topic '$topic' created." \
  || echo "⚠️ Warning: Topic '$topic' may already exist or failed to create."
}


# Helper: Check if ACL exists
acl_exists() {
  local topic=$1
  local user=$2
  local op=$3

  sudo docker exec "$CONTAINER_NAME" /opt/kafka/bin/kafka-acls.sh \
    --bootstrap-server "$BOOTSTRAP" \
    --command-config "$CONFIG" \
    --list --topic "$topic" 2>/dev/null |
    grep -iq "User:$user.*operation=$op"
}

# Helper: Grant ACL if not already exists
grant_acl() {
  local topic=$1
  local user=$2
  local op=$3

  if acl_exists "$topic" "$user" "$op"; then
    echo "✅ ACL '$op' for '$user' on '$topic' exists"
  else
    echo "🔐 Granting $op to '$user' on '$topic'"
    sudo docker exec "$CONTAINER_NAME" /opt/kafka/bin/kafka-acls.sh \
      --bootstrap-server "$BOOTSTRAP" \
      --command-config "$CONFIG" \
      --add --allow-principal "User:$user" \
      --operation "$op" --topic "$topic"
  fi
}

echo "🚀 Kafka Users, Topics & ACLs Setup Starting..."

# 1. Create Users
for user in "${!USER_PASSWORDS[@]}"; do
  create_user "$user"
done

# 2. Create Topics
for raw_topic in "${TOPICS[@]}"; do
  topic=$(echo "$raw_topic" | sed 's/Optional\[//;s/\]//')
  create_topic "$topic"
done

# 3. Apply Read ACLs
for raw_topic in "${!READ_ACCESS[@]}"; do
  topic=$(echo "$raw_topic" | sed 's/Optional\[//;s/\]//')
  for user in ${READ_ACCESS[$topic]}; do
    grant_acl "$topic" "$user" "Read"
  done
done

# 4. Apply Write ACLs
for topic in "${!WRITE_ACCESS[@]}"; do
  for user in ${WRITE_ACCESS[$topic]}; do
    grant_acl "$topic" "$user" "Write"
  done
done

echo "🎉 Kafka ACL setup complete!"
