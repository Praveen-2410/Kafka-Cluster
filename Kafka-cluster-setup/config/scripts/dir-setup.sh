#!/bin/bash
# Creates required directory structure if it doesn't already exist

BASE_DIR="kafka-cluster"
CONFIG_DIR="$BASE_DIR/config"
DATA_DIR="$BASE_DIR/data"
CERT_DIR="$BASE_DIR/certs"
SCRIPT_DIR="$BASE_DIR/scripts"

for dir in "$BASE_DIR" "$CONFIG_DIR" "$DATA_DIR" "$CERT_DIR" "$SCRIPT_DIR"; do
  if [ ! -d "$dir" ]; then
    mkdir -p "$dir"
    echo "Created: $dir"
  fi
done

sudo chown -R ec2-user:ec2-user "$BASE_DIR"
sudo chmod -R 755 "$BASE_DIR"