#!/usr/bin/env bash
set -euo pipefail

# Hardcoded encryption key
ENC_KEY="kafkakey"

# JAAS file path (default to config location on host)
JAAS_FILE="${1:-config/kafka_jaas.conf}"

# Function to decrypt XOR + Base64
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


# Count total user_ lines
total_users=$(grep -c '^[[:space:]]*user_' "$JAAS_FILE")
counter=0

tmpfile=$(mktemp)
while IFS= read -r line; do
  if [[ "$line" =~ ^[[:space:]]*user_[^=]+= ]]; then
    counter=$((counter+1))
    user=$(echo "$line" | cut -d '=' -f 1)
    enc=$(echo "$line" | cut -d '=' -f 2- | tr -d '[:space:]')
    dec_pwd=$(xor_b64_decode "$enc" "$ENC_KEY")
    if [[ $counter -eq $total_users ]]; then
      echo "  ${user}=\"${dec_pwd}\";" >> "$tmpfile"
    else
      echo "  ${user}=\"${dec_pwd}\"" >> "$tmpfile"
    fi
  else
    echo "$line" >> "$tmpfile"
  fi
done < "$JAAS_FILE"


DECRYPTED_FILE="${JAAS_FILE%.conf}_decrypt.conf"
mv -f "$tmpfile" "$DECRYPTED_FILE"
echo "JAAS file decrypted successfully at $DECRYPTED_FILE"
