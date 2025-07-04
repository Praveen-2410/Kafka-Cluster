#!/bin/bash
set -e

# Load variables from .env
source .env

# Load image tag (built in Jenkins)
if [ -f image-tag.txt ]; then
  export IMAGE_FULL=$(cat image-tag.txt)
else
  echo "ERROR: image-tag.txt not found!"
  exit 1
fi

# Args
BROKER_NUM=${1:-1}
MODE=${2:-multi}   # Default to "multi" node mode unless specified as "single"

# Resolve broker-specific base values
NODE_ID=$(eval echo \$BROKER_ID_${BROKER_NUM})
CONTAINER_NAME=$(eval echo \$CONTAINER_NAME_${BROKER_NUM})

if [ "$MODE" == "single" ]; then
  BROKER_IP=$SINGLE_NODE_IP
  INTERNAL_PORT=$(eval echo \$BROKER${BROKER_NUM}_INTERNAL_PORT)
  EXTERNAL_PORT=$(eval echo \$BROKER${BROKER_NUM}_EXTERNAL_PORT)
  CONTROLLER_PORT=$(eval echo \$BROKER${BROKER_NUM}_CONTROLLER_PORT)
else
  BROKER_IP=$(eval echo \$BROKER${BROKER_NUM}_IP)
  INTERNAL_PORT=9092
  EXTERNAL_PORT=9094
  CONTROLLER_PORT=9093
fi

# Export for envsubst
export NODE_ID BROKER_IP CONTAINER_NAME IMAGE_FULL NEXUS_HOST
export BROKER1_IP BROKER2_IP BROKER3_IP
export BROKER1_CONTROLLER_PORT BROKER2_CONTROLLER_PORT BROKER3_CONTROLLER_PORT
export INTERNAL_PORT EXTERNAL_PORT CONTROLLER_PORT

# Generate files
envsubst < config/server.properties.template > broker-${BROKER_NUM}/config/server.properties
envsubst < docker-compose.yml.template > docker-compose.yml

echo "✔️ Config generated for broker $BROKER_NUM in $MODE mode."
