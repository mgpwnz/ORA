#!/bin/bash
# Default variables
function="install"
# Options
option_value(){ echo "$1" | sed -e 's%^--[^=]*=%%g; s%^-[^=]*=%%g'; }
while test $# -gt 0; do
        case "$1" in
        -in|--install)
            function="install"
            shift
            ;;
        -up|--update)
            function="update"
            shift
            ;;
        -un|--uninstall)
            function="uninstall"
            shift
            ;;
        *|--)
    break
	;;
	esac
done
install() {
#docker install
cd $HOME
. <(wget -qO- https://raw.githubusercontent.com/mgpwnz/VS/main/docker.sh)
#create dir and config
if [ ! -d $HOME/tora ]; then
  mkdir $HOME/tora
fi
sleep 1

function check_empty {
  local varname=$1
  while [ -z "${!varname}" ]; do
    read -p "$2" input
    if [ -n "$input" ]; then
      eval $varname=\"$input\"
    else
      echo "The value cannot be empty. Please try again."
    fi
  done
}

function confirm_input {
  echo "You have entered the following information:"
  echo "Private Key: $PK"
  echo "MAINNET WSS: $MWSS"
  echo "MAINNET HTTP: $MHTTP"
  echo "SEPOLIA WSS: $SWSS"
  echo "SEPOLIA HTTP: $SHTTP"
  
  read -p "Is this information correct? (yes/no): " CONFIRM
  CONFIRM=$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')
  
  if [ "$CONFIRM" != "yes" ] && [ "$CONFIRM" != "y" ]; then
    echo "Let's try again..."
    return 1 
  fi
  return 0 
}

while true; do
  PK=""
  MWSS=""
  MHTTP=""
  SWSS=""
  SHTTP=""
  
  check_empty PK "Private Key: "
  check_empty MWSS "MAINNET WSS: "
  check_empty MHTTP "MAINNET HTTP: "
  check_empty SWSS "SEPOLIA WSS: "
  check_empty SHTTP "SEPOLIA HTTP: "
  
  confirm_input
  if [ $? -eq 0 ]; then
    break 
  fi
done

echo "All data is confirmed. Proceeding..."

# Create script 
tee $HOME/tora/docker-compose.yml > /dev/null <<EOF
version: '3'
services:
  confirm:
    image: oraprotocol/tora:confirm
    container_name: ora-tora
    depends_on:
      - redis
      - openlm
    command: 
      - "--confirm"
    env_file:
      - ./.env
    environment:
      REDIS_HOST: 'redis'
      REDIS_PORT: 6379
      CONFIRM_MODEL_SERVER_13: 'http://openlm:5000/'
    networks:
      - private_network
  redis:
    image: oraprotocol/redis:latest
    container_name: ora-redis
    restart: always
    networks:
      - private_network
  openlm:
    image: oraprotocol/openlm:latest
    container_name: ora-openlm
    restart: always
    networks:
      - private_network
  diun:
    image: crazymax/diun:latest
    container_name: diun
    command: serve
    volumes:
      - "./data:/data"
      - "/var/run/docker.sock:/var/run/docker.sock"
    environment:
      - "TZ=Asia/Shanghai"
      - "LOG_LEVEL=info"
      - "LOG_JSON=false"
      - "DIUN_WATCH_WORKERS=5"
      - "DIUN_WATCH_JITTER=30"
      - "DIUN_WATCH_SCHEDULE=0 0 * * *"
      - "DIUN_PROVIDERS_DOCKER=true"
      - "DIUN_PROVIDERS_DOCKER_WATCHBYDEFAULT=true"
    restart: always

networks:
  private_network:
    driver: bridge

EOF
#env
tee $HOME/tora/.env > /dev/null <<EOF
############### Sensitive config ###############

# private key for sending out app-specific transactions
PRIV_KEY="$PK"

############### General config ###############

# general - execution environment
TORA_ENV=production

# general - provider url
MAINNET_WSS="$MWSS"
MAINNET_HTTP="$MHTTP"
SEPOLIA_WSS="$SWSS"
SEPOLIA_HTTP="$SHTTP"

# redis global ttl, comment out -> no ttl limit
REDIS_TTL=86400000 # 1 day in ms 

############### App specific config ###############

# confirm - general
CONFIRM_CHAINS='["sepolia"]' # sepolia | mainnet ｜ '["sepolia","mainnet"]'
CONFIRM_MODELS='[13]' # 13: OpenLM ,now only 13 supported
# confirm - crosscheck
CONFIRM_USE_CROSSCHECK=true
CONFIRM_CC_POLLING_INTERVAL=3000 # 3 sec in ms
CONFIRM_CC_BATCH_BLOCKS_COUNT=300 # default 300 means blocks in 1 hours on eth
# confirm - store ttl
CONFIRM_TASK_TTL=2592000000
CONFIRM_TASK_DONE_TTL = 2592000000 # comment out -> no ttl limit
CONFIRM_CC_TTL=2592000000 # 1 month in ms
EOF
#Run nnode
docker compose -f $HOME/tora/docker-compose.yml up -d
}
update() {
docker compose -f $HOME/tora/docker-compose.yml down
docker compose -f $HOME/tora/docker-compose.yml pull
docker compose -f $HOME/tora/docker-compose.yml up -d

}
uninstall() {
if [ ! -d "$HOME/tora" ]; then
    break
fi
read -r -p "Wipe all DATA? [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY]) 
docker compose -f $HOME/tora/docker-compose.yml down -v
rm -rf $HOME/tora
        ;;
    *)
	echo Canceled
	break
        ;;
esac
}
# Actions
sudo apt install wget -y &>/dev/null
cd
$function