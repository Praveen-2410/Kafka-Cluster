#!/bin/bash
set -e

# Find REMOTE_DIR relative to this script's location
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REMOTE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
 
USERS=("user_etis" "user_du" "user_admin" "user_crdb" "user_tdra")
 
# Temp file for storing output
tmpfile=$(mktemp)
 
echo "Creating JAAS config with encrypted passwords..."
echo "-----------------------------------------------"
 
for user in "${USERS[@]}"; do
    # Prompt for password (no echo)
    read -s -p "Enter password for ${user}: " password
    echo
    if [[ -z "$password" ]]; then
        echo "ERROR: Password cannot be empty for ${user}"
        exit 1
    fi
 
    # Encrypt password
    encrypted_pwd=$(java -cp "$REMOTE_DIR/xor_encrypt_decrypt/PasswordUtility.jar:$REMOTE_DIR/xor_encrypt_decrypt/xercesImpl.jar" \
        com.telcordia.util.PasswordEncryptor "e" "$password")
 
    echo "${user}=${encrypted_pwd}" >> "$tmpfile"
done
 
ENCRYPTED_FILE="/home/npc/encrypted_passwords"
mv -f "$tmpfile" "$ENCRYPTED_FILE"
 
echo "User passswords encrypted successfully at $ENCRYPTED_FILE"