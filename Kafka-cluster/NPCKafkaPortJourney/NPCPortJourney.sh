#!/bin/bash
 
# Define variables
BASE_DIR="/home/npc/NPCKafkaPortJourney"
LOG4J_CONFIG="$BASE_DIR/log4j.properties"
KAFKA_CONFIG="$BASE_DIR/kafka.properties"
JAR_FILE="$BASE_DIR/NPCPortJourney.jar"  # Replace with your actual JAR file
LIB_DIR="$BASE_DIR/lib"                  # Directory to hold other dependency JARs
LOG_FILE="/home/npc/logs/NPCPortJourney.log"
NATIVE_LIB_DIR="/usr/lib"               # Directory containing native .so files (optional)
 
# Check if the main JAR file exists
if [ ! -f "$JAR_FILE" ]; then
    echo "Error: $JAR_FILE not found. Ensure the application JAR is in $BASE_DIR." | tee -a "$LOG_FILE"
    exit 1
fi
 
# Check if the lib directory exists and contains JARs
if [ ! -d "$LIB_DIR" ] || [ -z "$(ls -1 "$LIB_DIR"/*.jar 2>/dev/null)" ]; then
    echo "Error: $LIB_DIR directory not found or contains no JARs." | tee -a "$LOG_FILE"
    exit 1
fi
 
# Build the classpath by including the main JAR and all the JARs in the LIB_DIR
CLASSPATH="$JAR_FILE"
for jar in "$LIB_DIR"/*.jar; do
    CLASSPATH="$CLASSPATH:$jar"
done
 
# Append the starting message to the log file
echo "[$(date)] Starting Kafka Consumer application..." | tee -a "$LOG_FILE"
 
# Run the Kafka consumer app
java \
  -Dlog4j.configuration=file:"$LOG4J_CONFIG" \
  -Dkafka.properties="$KAFKA_CONFIG" \
  -Djava.library.path="$NATIVE_LIB_DIR" \
  -cp "$CLASSPATH" \
  com.iconectiv.portJourneyConsumer.PortJourneyKafkaMain \
>> "$LOG_FILE" 2>&1