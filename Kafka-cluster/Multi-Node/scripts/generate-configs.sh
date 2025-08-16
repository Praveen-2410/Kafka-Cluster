#!/bin/bash
set -e
 
# Find REMOTE_DIR relative to this script's location
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REMOTE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
 
# Path to .env file
ENV_FILE="$REMOTE_DIR/.env"
 
if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: .env file not found at $ENV_FILE"
  exit 1
fi
 
echo "Found .env at: $ENV_FILE"
source "$ENV_FILE"

# Load image tag
if [ -f image-tag.txt ]; then
  export IMAGE_FULL=$(cat image-tag.txt)
else
  echo "❌ ERROR: image-tag.txt not found!"
  exit 1
fi

# Determine broker number (1/2/3) passed via argument
BROKER_NUM=${1:-1}

# Resolve broker-specific details
NODE_ID=$(eval echo \$BROKER_ID_${BROKER_NUM})
BROKER_IP=$(eval echo \$BROKER${BROKER_NUM}_IP)
CONTAINER_NAME=$(eval echo \$CONTAINER_NAME_${BROKER_NUM})

# Ensure required ports exist
: "${INTERNAL_PORT:?INTERNAL_PORT not set}"
: "${EXTERNAL_PORT:?EXTERNAL_PORT not set}"
: "${CONTROLLER_PORT:?CONTROLLER_PORT not set}"

# Export required for envsubst
export NODE_ID BROKER_IP CONTAINER_NAME IMAGE_FULL NEXUS_HOST \
  BROKER1_IP BROKER2_IP BROKER3_IP \
  INTERNAL_PORT EXTERNAL_PORT CONTROLLER_PORT \
  KAFKA_ADMIN_PASSWORD  KAFKA_DU_PASSWORD KAFKA_ETIS_PASSWORD KAFKA_CRDB_PASSWORD KAFKA_TDRA_PASSWORD \


# Generate config/server.properties
envsubst < config/server.properties.template > config/server.properties

# Generate podman-compose.yml
envsubst < podman-compose.yml.template > podman-compose.yml

# Generate podman-compose.yml
envsubst < config/kafka_jaas.conf.template > config/kafka_encrypted_jaas.conf

echo "✅ Config generated for broker-$BROKER_NUM at IP $BROKER_IP"
