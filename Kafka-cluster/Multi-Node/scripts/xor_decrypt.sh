#!/bin/bash
set -e
 
# Find REMOTE_DIR relative to this script's location
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REMOTE_DIR="$(dirname "$SCRIPT_DIR")"
 
# Input encrypted passwords file
ENCRYPTED_FILE="$REMOTE_DIR/config/kafka_encrypted_jaas.conf"
# Output decrypted JAAS file
DECRYPTED_FILE="$REMOTE_DIR/config/kafka_decrypted_jaas.conf"
 
tmpfile=$(mktemp)
 
echo "KafkaServer {" >> "$tmpfile"
echo "  org.apache.kafka.common.security.plain.PlainLoginModule required" >> "$tmpfile"
 
total_users=$(grep -c '^[[:space:]]*user_' "$ENCRYPTED_FILE")
count=0
 
while IFS= read -r line; do
    trimmed=$(echo "$line" | xargs)
    [[ -z "$trimmed" || ! "$trimmed" =~ ^user_ ]] && continue
 
    count=$((count+1))
    user=$(echo "$trimmed" | cut -d '=' -f 1)
    enc=$(echo "$trimmed" | cut -d '=' -f 2-)
 
    echo "Decrypting password for $user..."
 
    dec_pwd=$(java -cp "$REMOTE_DIR/xor_encrypt_decrypt/PasswordUtility.jar:$REMOTE_DIR/xor_encrypt_decrypt/xercesImpl.jar" \
        com.telcordia.util.PasswordEncryptor "d" "$enc")
 
    if [[ $count -eq $total_users ]]; then
        echo "  ${user}=\"${dec_pwd}\";" >> "$tmpfile"
    else
        echo "  ${user}=\"${dec_pwd}\"" >> "$tmpfile"
    fi

done < "$ENCRYPTED_FILE"
 
 
echo "};" >> "$tmpfile"
 
mv -f "$tmpfile" "$DECRYPTED_FILE"
echo "JAAS file generated at $DECRYPTED_FILE"
