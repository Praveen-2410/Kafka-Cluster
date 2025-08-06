#!/bin/bash

# Original and decrypted JAAS config files
JAAS_ORIG="/opt/kafka/config/kafka_jaas.conf"
JAAS_DECRYPTED="/tmp/kafka_jaas_decrypted.conf"

# HARDCODED DECRYPTION KEY (change this securely during deployment)
KEY="mykafkakey"

# Export for use in Perl
export KEY

# Function to decrypt using XOR + Base64
decrypt() {
  echo "$1" | base64 -d | perl -ne '
    $key = $ENV{"KEY"};
    $input = $_;
    for ($i = 0; $i < length($input); $i++) {
      $k = substr($key, $i % length($key), 1);
      $c = substr($input, $i, 1);
      print chr(ord($c) ^ ord($k));
    }
  '
}

# Process kafka_jaas.conf and decrypt password lines at runtime
sed -E 's/user_([a-zA-Z0-9_]+)=([a-zA-Z0-9+/=]+)/user_\1='"'"'$(decrypt \2)'"'"'/ge' "$JAAS_ORIG" > "$JAAS_DECRYPTED"

# Update KAFKA_OPTS to use the decrypted JAAS file
export KAFKA_OPTS="-Djava.security.auth.login.config=$JAAS_DECRYPTED $KAFKA_OPTS"

# Start Kafka
exec /opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/kraft/server.properties