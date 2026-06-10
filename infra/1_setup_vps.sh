#!/bin/bash
# ============================================================
# VPS Setup Script — Rumahweb Ubuntu 24.04
# Run as root after logging in for the first time:
#   ssh root@YOUR_VPS_IP
#   bash 1_setup_vps.sh
# ============================================================

set -e  # Stop if there is an error

echo "=== [1/6] Update system ==="
apt update && apt upgrade -y
apt install -y curl git ufw

echo "=== [2/6] Setup 2GB swap (to prevent OOM) ==="
if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
  echo "2GB Swap active."
else
  echo "Swap already exists, skipping."
fi

echo "=== [3/6] Install Docker ==="
apt install -y ca-certificates gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
echo "Docker installed: $(docker --version)"

echo "=== [4/6] Install ngrok (backup if you need a quick public URL) ==="
curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc \
  | tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
echo "deb https://ngrok-agent.s3.amazonaws.com buster main" \
  | tee /etc/apt/sources.list.d/ngrok.list
apt update && apt install -y ngrok

echo "=== [5/6] Create project folders ==="
mkdir -p /opt/chatbot/{n8n_data,qdrant_data}
chmod -R 777 /opt/chatbot/n8n_data   # n8n requires write permissions
echo "Folder /opt/chatbot is ready."

echo "=== [6/6] Setup firewall ==="
ufw allow OpenSSH
ufw allow 5678   # n8n
ufw allow 6333   # Qdrant
ufw --force enable
echo "Firewall active."

echo ""
echo "============================================ "
echo "Setup complete! Next steps:"
echo ""
echo "1. cd /opt/chatbot"
echo "2. Upload the 2_docker_compose.yml file to this folder"
echo "3. Edit docker-compose.yml — replace YOUR_VPS_IP"
echo "4. docker compose up -d"
echo "5. Check status: docker compose ps"
echo "============================================ "