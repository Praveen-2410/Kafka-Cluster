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

# Determine broker number (default: 1)
BROKER_NUM=${1:-1}

# Resolve broker-specific variables
NODE_ID=$(eval echo \$BROKER_ID_${BROKER_NUM})
BROKER_IP=$(eval echo \$BROKER${BROKER_NUM}_IP)
CONTAINER_NAME=$(eval echo \$CONTAINER_NAME_${BROKER_NUM})

# Export for envsubst usage
export NODE_ID BROKER_IP CONTAINER_NAME BROKER1_IP BROKER2_IP BROKER3_IP IMAGE_FULL NEXUS_HOST

# Generate config files
envsubst < config/server.properties.template > config/server.properties
envsubst < docker-compose.yml.template > docker-compose.yml
