#!/usr/bin/env bash
set -euo pipefail

# Hardcoded encryption key
ENC_KEY="kafkakey"

# JAAS file path (default to container location)
JAAS_FILE="${1:-/opt/kafka/config/kafka_jaas.conf}"

# XOR + Base64 decryption function
xor_b64_decode() {
  local data="$1"
  local key="$2"
  python3 - <<PY
import base64
try:
    b = base64.b64decode("$data")
except Exception as e:
    raise SystemExit(f"Invalid base64 for: $data -> {e}")
key = "$key".encode('utf-8')
out = bytearray()
for i, x in enumerate(b):
    out.append(x ^ key[i % len(key)])
print(out.decode('utf-8'))
PY
}

# Read JAAS file, decrypt user_ passwords
while IFS= read -r line; do
  if [[ "$line" =~ ^[[:space:]]*user_[^=]+= ]]; then
    user=$(echo "$line" | cut -d '=' -f 1)
    enc=$(echo "$line" | cut -d '=' -f 2- | tr -d '[:space:]' | sed 's/[^A-Za-z0-9+/=]//g')
    if [ -n "$enc" ]; then
      dec_pwd=$(xor_b64_decode "$enc" "$ENC_KEY")
      echo "  ${user}=${dec_pwd}"
    else
      echo "$line"
    fi
  else
    echo "$line"
  fi
done < "$JAAS_FILE"
