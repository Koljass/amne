#!/bin/bash
set -e

# Установка зависимостей
apt-get update -y && apt-get install -y curl ufw qrencode jq

# Получение последней версии Xray
XRAY_VERSION=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | jq -r .tag_name)
echo "Устанавливаем Xray версии $XRAY_VERSION"
wget -q "https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/Xray-linux-64.zip" -O /tmp/xray.zip
unzip -q /tmp/xray.zip -d /usr/local/bin/
chmod +x /usr/local/bin/xray

# Генерация ключей
UUID=$(cat /proc/sys/kernel/random/uuid)
SHORT_ID=$(openssl rand -hex 8)
SNI="www.google.com"

# Создание конфигурации
mkdir -p /usr/local/etc/xray
cat > /usr/local/etc/xray/config.json <<EOF
{
  "inbounds": [{
    "port": 443,
    "protocol": "vless",
    "settings": {
      "clients": [{
        "id": "$UUID",
        "flow": "xtls-rprx-vision"
      }],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "tcp",
      "security": "reality",
      "realitySettings": {
        "show": false,
        "dest": "$SNI:443",
        "xver": 0,
        "serverNames": ["$SNI"],
        "privateKey": "$(xray x25519 | grep Private | awk '{print $3}')",
        "shortIds": ["$SHORT_ID"]
      }
    }
  }],
  "outbounds": [{
    "protocol": "freedom"
  }]
}
EOF

# Настройка systemd
cat > /etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray Service
After=network.target

[Service]
User=root
ExecStart=/usr/local/bin/xray run -config /usr/local/etc/xray/config.json
Restart=on-failure
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable xray
systemctl start xray

# Настройка файрвола
ufw allow 22/tcp
ufw allow 443/tcp
ufw --force enable

# Вывод результата
PUBLIC_IP=$(curl -s ifconfig.me)
VLESS_URL="vless://${UUID}@${PUBLIC_IP}:443?type=tcp&security=reality&sni=${SNI}&fp=chrome&pbk=$(xray x25519 | grep Public | awk '{print $3}')&sid=${SHORT_ID}&flow=xtls-rprx-vision#MyVPS"

echo ""
echo "✅ Готово! Ваш сервер VLESS Reality настроен."
echo "IP сервера: $PUBLIC_IP"
echo "Ссылка для подключения (скопируйте в приложение на iPhone):"
echo "$VLESS_URL"
echo ""
echo "Или отсканируйте QR-код ниже:"
qrencode -t ansiutf8 "$VLESS_URL"