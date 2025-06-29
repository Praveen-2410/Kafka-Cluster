#!/bin/bash
 
# ---------- Configuration ----------
BOOTSTRAP_SERVER="localhost:9094"
CONFIG="/opt/kafka/config/client-properties/client-admin.properties"
 
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
 
# ---------- Functions ----------
 
user_exists() {
  /opt/kafka/bin/kafka-configs.sh \
    --bootstrap-server "$BOOTSTRAP_SERVER" \
    --command-config "$CONFIG" \
    --describe --entity-type users | grep -q "User:$1"
}
 
create_user() {
  local user=$1
  local password=${USER_PASSWORDS[$user]}
 
  if user_exists "$user"; then
    echo "User '$user' already exists."
  else
    echo "Creating user: $user"
    /opt/kafka/bin/kafka-configs.sh \
      --bootstrap-server "$BOOTSTRAP_SERVER" \
      --command-config "$CONFIG" \
      --alter \
      --add-config "SCRAM-SHA-512=[iterations=4096,password=$password]" \
      --entity-type users --entity-name "$user"
  fi
}
 
topic_exists() {
  /opt/kafka/bin/kafka-topics.sh \
    --bootstrap-server "$BOOTSTRAP_SERVER" \
    --command-config "$CONFIG" \
    --list | grep -wq "$1"
}
 
create_topic() {
  local topic=$1
  if topic_exists "$topic"; then
    echo "Topic '$topic' already exists."
  else
    echo "Creating topic: $topic"
    /opt/kafka/bin/kafka-topics.sh \
      --bootstrap-server "$BOOTSTRAP_SERVER" \
      --command-config "$CONFIG" \
      --create --topic "$topic" --partitions 3 --replication-factor 3
  fi
}
 
grant_acl() {
  local topic=$1
  local user=$2
  local operation=$3
  echo "Granting $operation access to user '$user' on topic '$topic'"
  /opt/kafka/bin/kafka-acls.sh \
    --bootstrap-server "$BOOTSTRAP_SERVER" \
    --command-config "$CONFIG" \
    --add --allow-principal "User:$user" \
    --operation "$operation" \
    --topic "$topic"
}
 
# ---------- Execution ----------
 
echo "Starting Kafka User, Topic, and ACL Setup"
 
# Step 1: Create Users
for user in "${!USER_PASSWORDS[@]}"; do
  create_user "$user"
done
 
# Step 2: Create Topics
for topic in "${TOPICS[@]}"; do
  create_topic "$topic"
done
 
# Step 3: Apply ACLs
for topic in "${!READ_ACCESS[@]}"; do
  for user in ${READ_ACCESS[$topic]}; do
    grant_acl "$topic" "$user" Read
  done
done
 
for topic in "${!WRITE_ACCESS[@]}"; do
  for user in ${WRITE_ACCESS[$topic]}; do
    grant_acl "$topic" "$user" Write
  done
done
 
echo "Setup Complete."