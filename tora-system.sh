#!/bin/bash

# Параметри
COMPOSE_FILE="$HOME/tora/docker-compose.yml"
CHECK_SCRIPT="/usr/local/bin/check_and_start_node.sh"
SERVICE_FILE="/etc/systemd/system/check_node.service"

# Створення скрипту для перевірки та запуску контейнера
echo "Створюю скрипт перевірки стану контейнера..."
cat << EOF | sudo tee $CHECK_SCRIPT > /dev/null
#!/bin/bash
if [ -n "\$(docker compose -f "$COMPOSE_FILE" ps -q)" ]; then
  echo "Нода працює."
else
  echo "Нода не запущена. Запускаю..."
  docker compose -f "$COMPOSE_FILE" up -d
fi
EOF

# Надаємо права на виконання
sudo chmod +x $CHECK_SCRIPT

# Створення systemd-сервісу
echo "Створюю systemd сервіс..."
cat << EOF | sudo tee $SERVICE_FILE > /dev/null
[Unit]
Description=Перевірка та запуск ноди Docker Compose
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=$CHECK_SCRIPT

[Install]
WantedBy=multi-user.target
EOF

# Створення таймера для періодичного запуску скрипту
TIMER_FILE="/etc/systemd/system/check_node.timer"
echo "Створюю таймер для періодичного запуску..."
cat << EOF | sudo tee $TIMER_FILE > /dev/null
[Unit]
Description=Перевірка та запуск ноди кожні 5 хвилин

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min
Unit=check_node.service

[Install]
WantedBy=timers.target
EOF

# Перезапуск systemd і активація сервісу та таймера
echo "Перезапускаю systemd та активую таймер і сервіс..."
sudo systemctl daemon-reload
sudo systemctl enable --now check_node.timer

echo "Установка завершена. Таймер налаштовано на перевірку кожні 5 хвилин."