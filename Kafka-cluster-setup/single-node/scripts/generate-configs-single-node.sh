#!/bin/bash

set -e

# Load .env into environment
export $(grep -v '^#' .env | xargs)

# Paths
TEMPLATE_PATH="single-node/config/server.properties.template"
BASE_DIR=$(pwd)

# Broker details (arrays for clarity)
BROKER_IDS=($BROKER_ID_1 $BROKER_ID_2 $BROKER_ID_3)
CONTAINER_NAMES=($SINGLE_NODE_CONTAINER_NAME_1 $SINGLE_NODE_CONTAINER_NAME_2 $SINGLE_NODE_CONTAINER_NAME_3)

INTERNAL_PORTS=($BROKER1_INTERNAL_PORT $BROKER2_INTERNAL_PORT $BROKER3_INTERNAL_PORT)
CONTROLLER_PORTS=($BROKER1_CONTROLLER_PORT $BROKER2_CONTROLLER_PORT $BROKER3_CONTROLLER_PORT)
EXTERNAL_PORTS=($BROKER1_EXTERNAL_PORT $BROKER2_EXTERNAL_PORT $BROKER3_EXTERNAL_PORT)

# Generate config for each broker
for i in 0 1 2; do
  BROKER_ID=${BROKER_IDS[$i]}
  BROKER_NAME="broker-$((i + 1))"
  INTERNAL_PORT=${INTERNAL_PORTS[$i]}
  CONTROLLER_PORT=${CONTROLLER_PORTS[$i]}
  EXTERNAL_PORT=${EXTERNAL_PORTS[$i]}

  CONFIG_DIR="$BASE_DIR/$BROKER_NAME/config"
  mkdir -p "$CONFIG_DIR"

  echo "Generating server.properties for $BROKER_NAME..."

  # Export variables needed by envsubst
  export NODE_ID=$BROKER_ID
  export INTERNAL_PORT=$INTERNAL_PORT
  export CONTROLLER_PORT=$CONTROLLER_PORT
  export EXTERNAL_PORT=$EXTERNAL_PORT

  # Replace template variables
  envsubst < "$TEMPLATE_PATH" > "$CONFIG_DIR/server.properties"
done

echo "✅ All broker configs generated under broker-*/config/"