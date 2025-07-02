#!/bin/bash

set -e

# Load all variables from .env
source .env

# Determine broker number from input
BROKER_NUM=${1:-1}

# Map to the correct broker ID and IP
NODE_ID=$(eval echo \$BROKER_ID_${BROKER_NUM})
BROKER_IP=$(eval echo \$BROKER${BROKER_NUM}_IP)
CONTAINER_NAME=$(eval echo \$CONTAINER_NAME_${BROKER_NUM})

# Export them for envsubst
export NODE_ID BROKER_IP CONTAINER_NAME BROKER1_IP BROKER2_IP BROKER3_IP IMAGE_FULL

# Replace templates with actual values
envsubst < config/server.properties.template > config/server.properties
envsubst < docker-compose.yml.template > docker-compose.yml
