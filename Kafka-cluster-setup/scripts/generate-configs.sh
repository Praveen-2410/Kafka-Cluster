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
BROKER_NUM=${1:-1}#!/bin/bash
set -e

# Load environment variables
source .env

# Load image tag
if [ -f image-tag.txt ]; then
  export IMAGE_FULL=$(cat image-tag.txt)
else
  echo "ERROR: image-tag.txt not found!"
  exit 1
fi

# Broker Number (1, 2, 3) passed as argument
BROKER_NUM=${1:-1}

# Common for both single-node and multi-node
NODE_ID=$(eval echo \$BROKER_ID_${BROKER_NUM})
CONTAINER_NAME=$(eval echo \$CONTAINER_NAME_${BROKER_NUM})

# Resolve environment (SINGLE-NODE or MULTI-NODE)
IS_SINGLE_NODE=false
if [[ "$HOSTNAME" == *"10.90.80.70"* ]] || [[ "$HOSTNAME" == *"single-node"* ]] || [[ "$(hostname -I)" == *"$SINGLE_NODE_IP"* ]]; then
  IS_SINGLE_NODE=true
fi

if $IS_SINGLE_NODE; then
  echo "Setting up SINGLE-NODE Kafka Broker $BROKER_NUM"

  # Use dynamic ports for single-node
  INTERNAL_PORT=$(eval echo \$BROKER${BROKER_NUM}_INTERNAL_PORT)
  EXTERNAL_PORT=$(eval echo \$BROKER${BROKER_NUM}_EXTERNAL_PORT)
  CONTROLLER_PORT=$(eval echo \$BROKER${BROKER_NUM}_CONTROLLER_PORT)
  BROKER_IP=$SINGLE_NODE_IP

  CONFIG_DIR="config/broker-${BROKER_NUM}"
  DOCKER_COMPOSE="docker-compose.single-node.broker-${BROKER_NUM}.yml"

  mkdir -p "$CONFIG_DIR"

  export NODE_ID BROKER_IP CONTAINER_NAME INTERNAL_PORT EXTERNAL_PORT CONTROLLER_PORT \
         BROKER1_IP BROKER2_IP BROKER3_IP IMAGE_FULL NEXUS_HOST

  envsubst < config/server.properties.template > "${CONFIG_DIR}/server.properties"
  envsubst < docker-compose.yml.template > "$DOCKER_COMPOSE"

  echo "Generated config for SINGLE-NODE Broker-$BROKER_NUM at $CONFIG_DIR"

else
  echo "Setting up MULTI-NODE Kafka Broker $BROKER_NUM"

  BROKER_IP=$(eval echo \$BROKER${BROKER_NUM}_IP)
  INTERNAL_PORT=9092
  EXTERNAL_PORT=9093
  CONTROLLER_PORT=9094

  export NODE_ID BROKER_IP CONTAINER_NAME INTERNAL_PORT EXTERNAL_PORT CONTROLLER_PORT \
         BROKER1_IP BROKER2_IP BROKER3_IP IMAGE_FULL NEXUS_HOST

  envsubst < config/server.properties.template > config/server.properties
  envsubst < docker-compose.yml.template > docker-compose.yml

  echo "Generated config for MULTI-NODE Broker-$BROKER_NUM"

fi
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
