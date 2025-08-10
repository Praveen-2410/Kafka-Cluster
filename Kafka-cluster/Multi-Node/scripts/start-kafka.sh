TMP_JAAS="/tmp/kafka_jaas.conf.$$"
{
  head -n 2 /opt/kafka/config/kafka_jaas.conf
  /opt/kafka/scripts/decrypt.sh /opt/kafka/config/kafka_jaas.conf
  tail -n 2 /opt/kafka/config/kafka_jaas.conf | grep -v '^  user_'
} > "$TMP_JAAS"

chmod 0600 "$TMP_JAAS"
export KAFKA_OPTS="-Djava.security.auth.login.config=$TMP_JAAS $KAFKA_OPTS"

trap 'rm -f "$TMP_JAAS"' EXIT

exec /opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/kraft/server.properties
