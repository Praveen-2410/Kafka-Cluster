#!/usr/bin/env bash
set -euo pipefail

# Hardcoded encryption key
ENC_KEY="kafkakey"

# Output JAAS file path (encrypted passwords)
OUTFILE="$(pwd)/kafka_jaas.conf"

# Predefined users
USERS=("admin" "du" "etis" "crdb" "tdra")

# XOR + Base64 encryption function
xor_b64() {
  local plaintext="$1"
  local key="$2"
  python3 - <<PY
import base64
p = "$plaintext".encode('utf-8')
k = "$key".encode('utf-8')
out = bytearray()
for i, b in enumerate(p):
    out.append(b ^ k[i % len(k)])
print(base64.b64encode(bytes(out)).decode('ascii'))
PY
}

echo "Generating encrypted kafka_jaas.conf..."
{
  echo "KafkaServer {"
  echo "  org.apache.kafka.common.security.plain.PlainLoginModule required"
  for user in "${USERS[@]}"; do
    read -s -p "Enter password for user '$user': " pwd
    enc_pwd=$(xor_b64 "$pwd" "$ENC_KEY")
    echo "  user_${user}=${enc_pwd}"
  done
  echo "};"
} > "$OUTFILE"

sudo chmod 0600 "$OUTFILE"
echo "Encrypted JAAS file written to $OUTFILE"
