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
    # Docker install
    cd "$HOME"
    . <(wget -qO- https://raw.githubusercontent.com/mgpwnz/VS/main/docker.sh)

    # Create directory if it doesn't exist
    if [ ! -d "$HOME/nillion/verifier" ]; then
      mkdir -p "$HOME/nillion/verifier"
    fi
    sleep 1

    # Check for backup and restore if available
    if [ -f "$HOME/backup_nillion/credentials.json" ]; then
        cp "$HOME/backup_nillion/credentials.json" "$HOME/nillion/verifier/"
        echo "Backup of credentials.json restored to $HOME/nillion/verifier/"
    else
        # Run docker initialise command if no backup is available
        docker run -v "$HOME/nillion/verifier:/var/tmp" nillion/verifier:v1.0.1 initialise &>/dev/null
    fi

    # Display private key if exists and create backup
    if [ -f "$HOME/nillion/verifier/credentials.json" ]; then
        cat "$HOME/nillion/verifier/credentials.json"
        
        # Create backup directory if it doesn't exist
        mkdir -p "$HOME/backup_nillion"
        
        # Copy credentials.json to backup folder if not already backed up
        if [ ! -f "$HOME/backup_nillion/credentials.json" ]; then
            cp "$HOME/nillion/verifier/credentials.json" "$HOME/backup_nillion/"
            echo "Backup of credentials.json created in $HOME/backup_nillion/"
        fi
    else
        echo "Error: credentials.json not found."
        return 1
    fi

    # Pause the script and wait for user input
    read -p "Press Enter to continue..."

    # Start node
    docker run -v "$HOME/nillion/verifier:/var/tmp" nillion/verifier:v1.0.1 verify --rpc-endpoint "https://testnet-nillion-rpc.lavenderfive.com"

    # Create docker-compose.yml file
    tee "$HOME/nillion/docker-compose.yml" > /dev/null <<EOF
version: '3.8'

services:
  verifier:
    image: nillion/verifier:v1.0.1
    volumes:
      - $HOME/nillion/verifier:/var/tmp
    command: verify --rpc-endpoint "https://testnet-nillion-rpc.lavenderfive.com"
EOF

    # Run node with docker-compose
    docker compose -f "$HOME/nillion/docker-compose.yml" up -d
}

update() {
    docker compose -f "$HOME/nillion/docker-compose.yml" down
    docker compose -f "$HOME/nillion/docker-compose.yml" pull
    docker compose -f "$HOME/nillion/docker-compose.yml" up -d
}

uninstall() {
    if [ ! -d "$HOME/nillion" ]; then
        echo "No installation found to remove."
        return
    fi
    read -r -p "Wipe all DATA? [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY])
            docker compose -f "$HOME/nillion/docker-compose.yml" down -v
            rm -rf "$HOME/nillion"
            ;;
        *)
            echo "Canceled"
            ;;
    esac
}

# Ensure wget is installed
sudo apt install wget -y &>/dev/null
cd

# Execute the selected function
$function
