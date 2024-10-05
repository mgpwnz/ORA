#!/bin/bash
# Default variables
function="install"
# Options
option_value(){ echo "$1" | sed -e 's%^--[^=]*=%%g; s%^-[^=]*=%%g'; }

while test $# -gt 0; do
    case "$1" in
        -in|--install) function="install" ;;
        -s|--sepolia) function="sepolia" ;;
        -up|--update) function="update" ;;
        -mn|--mainnet) function="mainnet" ;;
        -un|--uninstall) function="uninstall" ;;
        *) break ;;
    esac
    shift
done

check_empty() {
    local varname=$1
    while [ -z "${!varname}" ]; do
        read -p "$2" input
        [ -n "$input" ] && eval $varname=\"$input\" || echo "The value cannot be empty. Please try again."
    done
}

confirm_input() {
    echo "You have entered the following information:"
    echo "Private Key: $PK"
    echo "MAINNET WSS: $MWSS"
    echo "MAINNET HTTP: $MHTTP"
    echo "SEPOLIA WSS: $SWSS"
    echo "SEPOLIA HTTP: $SHTTP"
    
    read -p "Is this information correct? (yes/no): " CONFIRM
    [ "${CONFIRM,,}" == "yes" ] || [ "${CONFIRM,,}" == "y" ]
}

gather_input() {
    PK=""; MWSS=""; MHTTP=""; SWSS=""; SHTTP=""
    check_empty PK "Private Key: "
    check_empty MWSS "MAINNET WSS: "
    check_empty MHTTP "MAINNET HTTP: "
    check_empty SWSS "SEPOLIA WSS: "
    check_empty SHTTP "SEPOLIA HTTP: "
    while ! confirm_input; do echo "Let's try again..."; gather_input; done
    echo "All data is confirmed. Proceeding..."
}

create_env_file() {
    tee $HOME/tora/.env > /dev/null <<EOF
############### Sensitive config ###############
PRIV_KEY="$PK"
############### General config ###############
TORA_ENV=production
MAINNET_WSS="$MWSS"
MAINNET_HTTP="$MHTTP"
SEPOLIA_WSS="$SWSS"
SEPOLIA_HTTP="$SHTTP"
REDIS_TTL=86400000 # 1 day in ms 
############### App specific config ###############
CONFIRM_CHAINS=$1
CONFIRM_MODELS='[13]'
CONFIRM_USE_CROSSCHECK=true
CONFIRM_CC_POLLING_INTERVAL=3000
CONFIRM_CC_BATCH_BLOCKS_COUNT=300
CONFIRM_TASK_TTL=2592000000
EOF
}

create_compose_file() {
    tee $HOME/tora/docker-compose.yml > /dev/null <<EOF
version: '3'
services:
  confirm:
    image: oraprotocol/tora:confirm
    container_name: ora-tora
    depends_on:
      - redis
      - openlm
    command: "--confirm"
    env_file: ./.env
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
      - "DIUN_WATCH_WORKERS=5"
      - "DIUN_WATCH_SCHEDULE=0 0 * * *"
    restart: always
networks:
  private_network:
    driver: bridge
EOF
}

install() {
    cd $HOME
    . <(wget -qO- https://raw.githubusercontent.com/mgpwnz/VS/main/docker.sh)
    [ ! -d $HOME/tora ] && mkdir $HOME/tora
    sleep 1
    gather_input
    create_compose_file
    create_env_file '["mainnet"]'
    sysctl vm.overcommit_memory=1
    docker compose -f $HOME/tora/docker-compose.yml up -d
}

sepolia() {
    install
    create_env_file '["sepolia"]'
    docker compose -f $HOME/tora/docker-compose.yml up -d
}

update() {
    docker compose -f $HOME/tora/docker-compose.yml down
    docker compose -f $HOME/tora/docker-compose.yml pull
    docker compose -f $HOME/tora/docker-compose.yml up -d
}

uninstall() {
    [ ! -d "$HOME/tora" ] && return
    read -r -p "Wipe all DATA? [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            docker compose -f $HOME/tora/docker-compose.yml down -v
            rm -rf $HOME/tora ;;
        *) echo "Canceled";;
    esac
}

# Actions
sudo apt install wget -y &>/dev/null
cd
$function
