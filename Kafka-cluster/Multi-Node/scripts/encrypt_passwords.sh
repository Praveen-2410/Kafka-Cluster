#!/bin/bash

# Predefined list of Kafka users
USERS=("admin" "du" "etis" "crdb" "tdra")

# Prompt for the encryption key
read -sp "Enter encryption key: " KEY
echo

# Function to XOR and Base64 encode a password
xor_encrypt() {
  local key="$1"
  local input="$2"
  local output=""
  local key_len=${#key}
  local i=0

  while IFS= read -r -n1 char; do
    key_char=${key:i%key_len:1}
    xor_result=$(( $(printf '%d' "'$char") ^ $(printf '%d' "'$key_char") ))
    output+=$(printf '\\x%02x' "$xor_result")
    ((i++))
  done <<< "$input"

  # Convert to binary and Base64 encode
  echo -e "$output" | base64
}

# Encrypt passwords for each user
for user in "${USERS[@]}"; do
  read -sp "Enter password for $user: " password
  echo
  encrypted=$(xor_encrypt "$KEY" "$password")
  echo "$user=$encrypted"
done