#!/bin/bash

# === Configuration ===
KEY="mykafkakey"
JAAS_ORIG="/opt/kafka/config/kafka_jaas.conf"
JAAS_DECRYPTED="/tmp/kafka_jaas_decrypted.conf"

# === XOR Decryption using shell and base64 ===
decrypt_password() {
  local encrypted_b64="$1"
  local key="$KEY"
  local decoded
  decoded=$(echo "$encrypted_b64" | base64 -d | xxd -p -c 256)

  local decrypted=""
  for ((i=0; i<${#decoded}; i+=2)); do
    byte_hex="${decoded:$i:2}"
    byte_val=$((16#${byte_hex}))
    key_char="${key:$(( (i/2) % ${#key} )):1}"
    key_val=$(printf "%d" "'$key_char")
    xor_val=$(( byte_val ^ key_val ))
    decrypted+=$(printf "\\x%02x" "$xor_val")
  done

  printf "$decrypted"
}

# === Export key ===
export KEY="$KEY"

# === Decrypt JAAS file ===
> "$JAAS_DECRYPTED"
while IFS= read -r line; do
  if [[ "$line" =~ ^user_([a-zA-Z0-9_]+)=(.*) ]]; then
    user="${BASH_REMATCH[1]}"
    encrypted_pw="${BASH_REMATCH[2]}"
    decrypted_pw=$(decrypt_password "$encrypted_pw")
    echo "user_$user=$decrypted_pw" >> "$JAAS_DECRYPTED"
  else
    echo "$line" >> "$JAAS_DECRYPTED"
  fi
done < "$JAAS_ORIG"

# === Set JAAS and Start Kafka ===
export KAFKA_OPTS="-Djava.security.auth.login.config=$JAAS_DECRYPTED $KAFKA_OPTS"

exec /opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/kraft/server.properties
