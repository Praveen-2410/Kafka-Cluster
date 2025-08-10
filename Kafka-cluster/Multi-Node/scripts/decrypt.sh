#!/usr/bin/env bash
set -euo pipefail

# Hardcoded encryption key
ENC_KEY="kafkakey"

JAAS_FILE="${1:-/opt/kafka/config/kafka_jaas.conf}"

# XOR + Base64 decryption function
xor_b64_decode() {
  local data="$1"
  local key="$2"
  python3 - <<PY
import base64
data = "$data"
key = "$key".encode('utf-8')
b = base64.b64decode(data)
out = bytearray()
for i, x in enumerate(b):
    out.append(x ^ key[i % len(key)])
print(out.decode('utf-8'))
PY
}

# Print decrypted JAAS file
while IFS= read -r line; do
  if [[ "$line" =~ ^[[:space:]]*user_([^=]+)=(.+)$ ]]; then
    user="${BASH_REMATCH[1]}"
    enc="${BASH_REMATCH[2]}"
    dec_pwd=$(xor_b64_decode "$enc" "$ENC_KEY")
    echo "  user_${user}=${dec_pwd}"
  else
    echo "$line"
  fi
done < "$JAAS_FILE"
