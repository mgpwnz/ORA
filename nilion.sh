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
if [ ! -d $HOME/nillion/verifier ]; then
  mkdir -p $HOME/nillion/verifier
fi
sleep 1
# Створюємо тимчасовий файл
temp_file=$(mktemp)

# Запускаємо docker-команду та записуємо вивід у тимчасовий файл
docker run -v ./nillion/verifier:/var/tmp nillion/verifier:v1.0.1 initialise > "$temp_file"

# Виводимо рядок із "Verifier account id:" у консоль
grep "Verifier account id:" "$temp_file"
#Вивід приватного ключа
cat $HOME/nillion/verifier/credentials.json
#Запуск ноди
docker run -v ./nillion/verifier:/var/tmp nillion/verifier:v1.0.1 verify --rpc-endpoint "https://testnet-nillion-rpc.lavenderfive.com"

# Create script 
tee $HOME/nillion/docker-compose.yml > /dev/null <<EOF
version: '3.8'

services:
  verifier:
    image: nillion/verifier:v1.0.1
    volumes:
      - ./nillion/verifier:/var/tmp
    command: verify --rpc-endpoint "https://testnet-nillion-rpc.lavenderfive.com"

EOF

#Run nnode
docker compose -f $HOME/nillion/docker-compose.yml up -d
}
update() {
docker compose -f $HOME/nillion/docker-compose.yml down
docker compose -f $HOME/nillion/docker-compose.yml pull
docker compose -f $HOME/nillion/docker-compose.yml up -d

}
uninstall() {
if [ ! -d "$HOME/nillion" ]; then
    break
fi
read -r -p "Wipe all DATA? [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY]) 
docker compose -f $HOME/nillion/docker-compose.yml down -v
rm -rf $HOME/nillion
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