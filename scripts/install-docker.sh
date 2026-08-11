#!/usr/bin/env bash
# ============================================================
# install-docker.sh — Ubuntu 22.04 一键安装 Docker(国内镜像)
# 适用:VMware/裸机 Ubuntu 22.04 LTS Desktop/Server amd64
# 用法:bash install-docker.sh
#
# 思路(线性 5 步,每步独立可验证):
#   1. 用原 Ubuntu 源装 openssh-server —— 确保后续 SSH 可用
#   2. 切换为阿里云镜像源 —— 装东西速度起飞
#   3. 安装基础工具(curl/wget/git 等)
#   4. 配置 Docker 源 + 安装
#   5. 配置 docker 组 + 镜像源(daocloud) + 验证
# ============================================================
set -euo pipefail

# ---------- [1] 用原源装 SSH ----------
echo "[1/5] 用原源装 openssh-server(确保 SSH 可用)..."
sudo apt update
sudo apt install -y openssh-server
sudo systemctl enable --now ssh

# ---------- [2] 切换阿里云源 ----------
echo "[2/5] 切换为阿里云镜像源(deb822 格式, Ubuntu 22.04)..."
sudo tee /etc/apt/sources.list.d/ubuntu.sources <<'EOF'
Types: deb
URIs: http://mirrors.aliyun.com/ubuntu/
Suites: jammy jammy-updates jammy-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: http://mirrors.aliyun.com/ubuntu/
Suites: jammy-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
sudo apt update

# ---------- [3] 装基础工具 ----------
echo "[3/5] 安装基础工具 curl/wget/git..."
sudo apt install -y curl wget git vim net-tools

# ---------- [4] Docker 源 + 安装 ----------
echo "[4/5] 配置 Docker 源 + 安装 Docker Engine..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg \
  | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg

echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.aliyun.com/docker-ce/linux/ubuntu jammy stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# ---------- [5] 用户组 + 镜像源 + 验证 ----------
echo "[5/5] 配置 docker 组 + 镜像源(daocloud)..."
sudo groupadd docker 2>/dev/null || true
sudo usermod -aG docker "$USER"

sudo mkdir -p /etc/docker
echo '{ "registry-mirrors": ["https://docker.m.daocloud.io"] }' | sudo tee /etc/docker/daemon.json
sudo systemctl restart docker

cat <<'NOTE'

============================================================
安装完成。接下来:
  1) 重开 SSH 会话(让 docker 组生效),或跑: newgrp docker
  2) 验证:
       docker version
       docker run --rm hello-world    # 必须看到完整 Hello from Docker! 段落
============================================================
NOTE