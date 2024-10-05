#!/bin/bash

# Default variables
function="install"
network="mainnet"

# Options processing
while test $# -gt 0; do
    case "$1" in
        -in|--install|-mn|--mainnet)
            function="install"
            ;;
        -up|--update)
            function="update"
            ;;
        -un|--uninstall)
            function="uninstall"
            ;;
        -sw|--switch)
            function="switch"
            ;;
        *)
            break
            ;;
    esac
    shift
done

# Function for checking empty input
check_empty() {
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

# Function for confirming input
confirm_input() {
    echo "You have entered the following information:"
    echo "Private Key: $PK"
    echo "MAINNET WSS: $MWSS"
    echo "MAINNET HTTP: $MHTTP"
    echo "SEPOLIA WSS: $SWSS"
    echo "SEPOLIA HTTP: $SHTTP"
    
    read -p "Is this information correct? (yes/no): " CONFIRM
    CONFIRM=$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')
    
    [ "$CONFIRM" == "yes" ] || [ "$CONFIRM" == "y" ]
}

# Function to handle the installation process
install() {
    cd $HOME
    . <(wget -qO- https://raw.githubusercontent.com/mgpwnz/VS/main/docker.sh)

    mkdir -p $HOME/tora

    while true; do
        PK=""; MWSS=""; MHTTP=""; SWSS=""; SHTTP=""

        check_empty PK "Private Key: "
        check_empty MWSS "MAINNET WSS: "
        check_empty MHTTP "MAINNET HTTP: "
        
        echo "Choose network configuration:"
        select network in "mainnet" "sepolia"; do
            case $network in
                mainnet)
                    check_empty SWSS "SEPOLIA WSS: "
                    check_empty SHTTP "SEPOLIA HTTP: "
                    break
                    ;;
                sepolia)
                    check_empty SWSS "SEPOLIA WSS: "
                    check_empty SHTTP "SEPOLIA HTTP: "
                    break
                    ;;
            esac
        done
        
        if confirm_input; then break; fi
    done

    # Set CONFIRM_CHAINS based on selected network
    if [ "$network" == "mainnet" ]; then
        CONFIRM_CHAINS='["mainnet"]'
    else
        CONFIRM_CHAINS='["sepolia"]'
    fi

    # Create docker-compose.yml
    cat <<EOF > $HOME/tora/docker-compose.yml
version: '3'
services:
  confirm:
    image: oraprotocol/tora:confirm
    container_name: ora-tora
    depends_on:
      - redis
      - openlm
    command: ["--confirm"]
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

    # Create .env file
    cat <<EOF > $HOME/tora/.env
PRIV_KEY="$PK"
TORA_ENV=production
MAINNET_WSS="$MWSS"
MAINNET_HTTP="$MHTTP"
SEPOLIA_WSS="$SWSS"
SEPOLIA_HTTP="$SHTTP"
REDIS_TTL=86400000
CONFIRM_CHAINS=$CONFIRM_CHAINS
CONFIRM_MODELS='[13]'
CONFIRM_USE_CROSSCHECK=true
CONFIRM_CC_POLLING_INTERVAL=3000
CONFIRM_CC_BATCH_BLOCKS_COUNT=300
CONFIRM_TASK_TTL=2592000000
CONFIRM_TASK_DONE_TTL=2592000000
CONFIRM_CC_TTL=2592000000
EOF

    # Memory setting
    sysctl vm.overcommit_memory=1
    # Run node
    docker compose -f $HOME/tora/docker-compose.yml up -d
}

# Function to switch between networks
switch_network() {
    if [ ! -f "$HOME/tora/.env" ]; then
        echo "Configuration file not found. Please run install first."
        return
    fi

    echo "Current configuration:"
    grep "CONFIRM_CHAINS" "$HOME/tora/.env"

    # Switch network configuration
    read -p "Choose network (mainnet/sepolia): " NETWORK
    NETWORK=$(echo "$NETWORK" | tr '[:upper:]' '[:lower:]')

    if [[ "$NETWORK" != "mainnet" && "$NETWORK" != "sepolia" ]]; then
        echo "Invalid choice. Please choose 'mainnet' or 'sepolia'."
        return
    fi

    # Update .env file with the new network choice
    sed -i "s/CONFIRM_CHAINS=.*/CONFIRM_CHAINS='[\"$NETWORK\"]'/" "$HOME/tora/.env"
    echo "Switched to $NETWORK configuration."
}

# Main functions for update and uninstall
update() {
    docker compose -f $HOME/tora/docker-compose.yml down
    docker compose -f $HOME/tora/docker-compose.yml pull
    docker compose -f $HOME/tora/docker-compose.yml up -d
}

uninstall() {
    if [ -d "$HOME/tora" ]; then
        read -r -p "Wipe all DATA? [y/N] " response
        case "$response" in
            [yY][eE][sS]|[yY]) 
                docker compose -f $HOME/tora/docker-compose.yml down -v
                rm -rf $HOME/tora
                ;;
            *)
                echo "Canceled"
                ;;
        esac
    fi
}

# Install wget if not present
sudo apt install wget -y &>/dev/null
cd

# Execute the selected function
if [ "$function" == "install" ]; then
    install
elif [ "$function" == "switch" ]; then
    switch_network
else
    $function
fi
