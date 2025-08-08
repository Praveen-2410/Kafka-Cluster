#!/bin/bash
set -e

KEY="mykafkakey"
ENCRYPTED_FILE="/opt/kafka/config/kafka_jaas.conf"
TEMP_FILE="/tmp/kafka_jaas_runtime.conf"

xor_decrypt() {
  local key="$1"
  local input_b64="$2"
  local input
  input=$(echo "$input_b64" | base64 --decode)
  local output=""
  local key_len=${#key}
  local i=0

  while IFS= read -r -n1 char; do
    key_char=${key:i%key_len:1}
    xor_result=$(( $(printf '%d' "'$char") ^ $(printf '%d' "'$key_char") ))
    output+=$(printf "\\x%02x" "$xor_result")
    ((i++))
  done <<< "$input"

  echo -e "$output"
}

# Copy structure but replace encrypted passwords
while IFS= read -r line; do
  if [[ "$line" == user_* ]]; then
    user=$(echo "$line" | cut -d'=' -f1)
    enc_pass=$(echo "$line" | cut -d'=' -f2)
    dec_pass=$(xor_decrypt "$KEY" "$enc_pass")
    echo "$user=$dec_pass" >> "$TEMP_FILE"
  else
    echo "$line" >> "$TEMP_FILE"
  fi
done < "$ENCRYPTED_FILE"

# Start Kafka using temp JAAS file
KAFKA_OPTS="-Djava.security.auth.login.config=$TEMP_FILE" exec /opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/kraft/server.properties
