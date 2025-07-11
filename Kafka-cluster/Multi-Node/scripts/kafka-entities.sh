# kafka-entities.sh

# Format: declare associative arrays and lists

# Users and their passwords
declare -A USER_PASSWORDS=(
  [du]="du-password"
  [etis]="etis-password"
  [crdb]="crdb-password"
  [tdra]="tdra-password"
)

# List of topics to create
TOPICS=(
  "npc-raw-msg"
  "etis-pos-data"
  "du-pos-data"
)

# ACLs: Read permissions
declare -A READ_ACCESS=(
  ["npc-raw-msg"]="du etis"
  ["etis-pos-data"]="crdb tdra"
  ["du-pos-data"]="crdb tdra"
)

# ACLs: Write permissions
declare -A WRITE_ACCESS=(
  ["npc-raw-msg"]="crdb"
  ["etis-pos-data"]="du etis"
  ["du-pos-data"]="du etis"
)