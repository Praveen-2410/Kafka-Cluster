#!/bin/bash

set -e

# Set working directory to the location of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

ENV_FILE="$PROJECT_ROOT/.env"

# Resolve base paths
BASE_DIR=$(pwd)/..
CONFIG_DIR="$BASE_DIR/config"
TEMPLATE_PATH="$CONFIG_DIR/server.properties.template"
COMPOSE_TEMPLATE_PATH="$BASE_DIR/docker-compose.single-node.yml.template"
COMPOSE_OUTPUT_PATH="$BASE_DIR/docker-compose.yml"
IMAGE_TAG_PATH="$BASE_DIR/image-tag.txt"

# Load .env
if [ ! -f "$ENV_PATH" ]; then
  echo "ERROR: .env file not found at $ENV_PATH"
  exit 1
fi
export $(grep -v '^#' "$ENV_PATH" | xargs)

# Load image tag
if [ -f "$IMAGE_TAG_PATH" ]; then
  export IMAGE_FULL=$(cat "$IMAGE_TAG_PATH")
else
  echo "ERROR: image-tag.txt not found!"
  exit 1
fi

# Arrays for each broker
BROKER_IDS=($BROKER_ID_1 $BROKER_ID_2 $BROKER_ID_3)
CONTAINER_NAMES=($SINGLE_NODE_CONTAINER_NAME_1 $SINGLE_NODE_CONTAINER_NAME_2 $SINGLE_NODE_CONTAINER_NAME_3)

INTERNAL_PORTS=($SINGLE_NODE_BROKER1_INTERNAL_PORT $SINGLE_NODE_BROKER2_INTERNAL_PORT $SINGLE_NODE_BROKER3_INTERNAL_PORT)
CONTROLLER_PORTS=($SINGLE_NODE_BROKER1_CONTROLLER_PORT $SINGLE_NODE_BROKER2_CONTROLLER_PORT $SINGLE_NODE_BROKER3_CONTROLLER_PORT)
EXTERNAL_PORTS=($SINGLE_NODE_BROKER1_EXTERNAL_PORT $SINGLE_NODE_BROKER2_EXTERNAL_PORT $SINGLE_NODE_BROKER3_EXTERNAL_PORT)

# Generate per-broker config
for i in 0 1 2; do
  BROKER_ID=${BROKER_IDS[$i]}
  BROKER_NAME="broker-$((i + 1))"
  INTERNAL_PORT=${INTERNAL_PORTS[$i]}
  CONTROLLER_PORT=${CONTROLLER_PORTS[$i]}
  EXTERNAL_PORT=${EXTERNAL_PORTS[$i]}

  BROKER_CONFIG_DIR="$BASE_DIR/$BROKER_NAME/config"
  mkdir -p "$BROKER_CONFIG_DIR"

  echo "Generating server.properties for $BROKER_NAME..."

  export NODE_ID=$BROKER_ID
  export INTERNAL_PORT
  export CONTROLLER_PORT
  export EXTERNAL_PORT

  envsubst < "$TEMPLATE_PATH" > "$BROKER_CONFIG_DIR/server.properties"
done

# Generate docker-compose.yml
echo "Generating docker-compose.yml from $COMPOSE_TEMPLATE_PATH..."
envsubst < "$COMPOSE_TEMPLATE_PATH" > "$COMPOSE_OUTPUT_PATH"

echo "All broker configs and docker-compose.yml generated successfully."
