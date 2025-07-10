#!/bin/bash
set -e

# Navigate to Multi-Node directory to ensure relative paths work
cd "$(dirname "$0")/.."

# Load common .env file from root
if [ ! -f ../../.env ]; then
  echo "ERROR: .env file not found at root!"
  exit 1
fi
source ../../.env

# Load image tag (assumed to be in Multi-Node folder after Jenkins injects it)
if [ -f image-tag.txt ]; then
  export IMAGE_FULL=$(cat image-tag.txt)
else
  echo "ERROR: image-tag.txt not found!"
  exit 1
fi

# Determine broker number
BROKER_NUM=${1:-1}

# Resolve broker-specific values
NODE_ID=$(eval echo \$BROKER_ID_${BROKER_NUM})
BROKER_IP=$(eval echo \$BROKER${BROKER_NUM}_IP)
CONTAINER_NAME=$(eval echo \$CONTAINER_NAME_${BROKER_NUM})

# Check required port variables
: "${INTERNAL_PORT:?INTERNAL_PORT not set in .env}"
: "${EXTERNAL_PORT:?EXTERNAL_PORT not set in .env}"
: "${CONTROLLER_PORT:?CONTROLLER_PORT not set in .env}"

# Export all variables for envsubst
export NODE_ID BROKER_IP CONTAINER_NAME IMAGE_FULL NEXUS_HOST \
  BROKER1_IP BROKER2_IP BROKER3_IP \
  INTERNAL_PORT EXTERNAL_PORT CONTROLLER_PORT

# Generate config/server.properties
envsubst < config/server.properties.template > config/server.properties

# Generate docker-compose.yml
envsubst < docker-compose.yml.template > docker-compose.yml

echo "✅ Config generated for broker-$BROKER_NUM at IP $BROKER_IP"
