FROM apache/kafka:4.0.0

# Switch to root to create directories and copy files
USER root

RUN mkdir -p /home/npc

COPY KafkaOperatorConsumer-du /home/npc/KafkaOperatorConsumer-du
COPY NPCKafkaPortJourney /home/npc/NPCKafkaPortJourney

RUN chmod -R 755 /home/npc \
    && chown -R appuser:appuser /home/npc

# Switch back to appuser for normal operation
USER appuser