#!/bin/bash

# Script: cluster-id-format.sh
# Purpose: Generate cluster ID (if needed) and format metadata storage on all 3 Kafka brokers.
# Usage: Run from broker-1 (or Jenkins over SSH). Assumes docker, sudo access, and env values.

set -e

### Load ENV variables ###
source .env

### Constants ###
DATA_DIR="kafka-cluster/data"
CONFIG_PATH="kafka-cluster/config/server.properties"
DATE_SUFFIX=$(date +%Y%m%d%H%M%S)
BACKUP_DIR="kafka-cluster/data-dir-backup-$DATE_SUFFIX"
DOCKER_IMAGE="apache/kafka:4.0.0"
FORMAT_CMD="/opt/kafka/bin/kafka-storage.sh format"
CLUSTER_ID_CMD="/opt/kafka/bin/kafka-storage.sh random-uuid"
KAFKA_CONFIG_DOCKER_PATH="/opt/kafka/config/kraft/server.properties"
SSH_OPTS="-o StrictHostKeyChecking=no"

### List of brokers (must match env file) ###
BROKERS=(
  "$BROKER1_IP"
  "$BROKER2_IP"
  "$BROKER3_IP"
)

USER=${REMOTE_USER:-ec2-user}  # fallback to ec2-user if REMOTE_USER not defined

### Check data dir existence ###
check_data_dir() {
  local ip=$1
  echo "Checking $DATA_DIR on $ip..."
  ssh $SSH_OPTS "$USER@$ip" "test -d ~/$DATA_DIR && [ -n \"\$(ls -A ~/$DATA_DIR 2>/dev/null)\" ]"
}

### Get cluster ID from meta.properties ###
get_cluster_id() {
  local ip=$1
  ssh $SSH_OPTS "$USER@$ip" "grep cluster.id ~/$DATA_DIR/meta.properties | cut -d'=' -f2"
}

### Backup existing data dir ###
backup_data_dir() {
  local ip=$1
  echo "Backing up data dir on $ip..."
  ssh $SSH_OPTS "$USER@$ip" "mkdir -p ~/$BACKUP_DIR && cp -r ~/$DATA_DIR/* ~/$BACKUP_DIR/ && rm -rf ~/$DATA_DIR/*"
}

### Format broker ###
format_broker() {
  local ip=$1
  echo "Formatting broker at $ip..."
  ssh $SSH_OPTS "$USER@$ip" "sudo docker run --rm -v ~/$CONFIG_PATH:$KAFKA_CONFIG_DOCKER_PATH -v ~/$DATA_DIR:/var/lib/kafka/data $DOCKER_IMAGE $FORMAT_CMD -t $CLUSTER_ID -c $KAFKA_CONFIG_DOCKER_PATH"
}

echo "=== Kafka Cluster ID & Metadata Format Script ==="

# Step 1: Check all brokers for existing data
EXISTING_CLUSTER_IDS=()

for ip in "${BROKERS[@]}"; do
  if check_data_dir "$ip"; then
    echo "Data directory found on $ip"
    EXISTING_CLUSTER_IDS+=("$(get_cluster_id "$ip")")
  else
    echo "No existing data directory on $ip"
  fi
done

# Step 2: Determine action based on existing IDs
if [ ${#EXISTING_CLUSTER_IDS[@]} -eq 0 ]; then
  echo "No data directories found. Generating fresh cluster ID..."
  CLUSTER_ID=$(sudo docker run --rm $DOCKER_IMAGE $CLUSTER_ID_CMD)
elif [ $(printf "%s\n" "${EXISTING_CLUSTER_IDS[@]}" | sort -u | wc -l) -eq 1 ]; then
  CLUSTER_ID="${EXISTING_CLUSTER_IDS[0]}"
  echo "All brokers already formatted with cluster ID: $CLUSTER_ID"
  exit 0
else
  echo "Mismatched cluster IDs found. Backing up and reinitializing..."
  CLUSTER_ID=$(sudo docker run --rm $DOCKER_IMAGE $CLUSTER_ID_CMD)
  for ip in "${BROKERS[@]}"; do
    backup_data_dir "$ip"
  done
fi

# Step 3: Format metadata on all brokers
for ip in "${BROKERS[@]}"; do
  format_broker "$ip"
done

echo "Cluster ID: $CLUSTER_ID"
echo "Metadata formatted successfully on all brokers"
