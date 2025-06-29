#!/bin/bash
 
# ---------- Configuration ----------
BOOTSTRAP_SERVER="localhost:9094"
CONFIG="/opt/kafka/config/client-properties/client-admin.properties"
 
# ---------- Users and Topics to Delete ----------
USERS_TO_DELETE=("du" "etis" "crdb" "tdra")
TOPICS_TO_DELETE=("npc-raw-msg" "etis-pos-data" "du-pos-data")
 
# ---------- Functions ----------
 
user_exists() {
  /opt/kafka/bin/kafka-configs.sh \
    --bootstrap-server "$BOOTSTRAP_SERVER" \
    --command-config "$CONFIG" \
    --describe --entity-type users | grep -q "User:$1"
}
 
delete_user() {
  local user=$1
  if user_exists "$user"; then
    echo "Deleting user: $user"
    /opt/kafka/bin/kafka-configs.sh \
      --bootstrap-server "$BOOTSTRAP_SERVER" \
      --command-config "$CONFIG" \
      --alter \
      --delete-config "SCRAM-SHA-512" \
      --entity-type users --entity-name "$user"
  else
    echo "User '$user' already deleted or doesn't exist."
  fi
}
 
topic_exists() {
  /opt/kafka/bin/kafka-topics.sh \
    --bootstrap-server "$BOOTSTRAP_SERVER" \
    --command-config "$CONFIG" \
    --list | grep -wq "$1"
}
 
delete_topic() {
  local topic=$1
  if topic_exists "$topic"; then
    echo "Deleting topic: $topic"
    /opt/kafka/bin/kafka-topics.sh \
      --bootstrap-server "$BOOTSTRAP_SERVER" \
      --command-config "$CONFIG" \
      --delete --topic "$topic"
  else
    echo "Topic '$topic' already deleted or doesn't exist."
  fi
}
 
# ---------- Execution ----------
 
echo "Starting Kafka User and Topic Cleanup"
 
for user in "${USERS_TO_DELETE[@]}"; do
  delete_user "$user"
done
 
for topic in "${TOPICS_TO_DELETE[@]}"; do
  delete_topic "$topic"
done
 
echo "Cleanup Complete."