#!/usr/bin/env bash
# ============================================================
# install-docker.sh — Ubuntu 24.04 一键安装 Docker(国内镜像)
# 适用:homelab-k8s Phase 0 实验机(Ubuntu 24.04 LTS Desktop/Server amd64)
# 用法:bash install-docker.sh
# 说明:已踩过的坑全处理掉:curl PATH / gpg tty / docker 组缺失 / daocloud 镜像源
# ============================================================
set -euo pipefail

echo "[1/6] 安装基础工具(curl/wget/git/openssh-server)..."
sudo apt update
sudo apt install -y curl wget git openssh-server || true
sudo systemctl enable --now ssh 2>/dev/null || true

echo "[2/6] 添加 Docker 官方 GPG key(阿里云镜像)..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg \
  | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg

echo "[3/6] 添加 Docker 软件源(阿里云, noble stable)..."
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.aliyun.com/docker-ce/linux/ubuntu noble stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update

echo "[4/6] 安装 Docker Engine..."
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "[5/6] 配置 docker 组(当前用户免 sudo 用 docker)..."
sudo groupadd docker 2>/dev/null || true
sudo usermod -aG docker "$USER"

echo "[6/6] 配置国内镜像源(daocloud, 该网络下唯一稳定可解析)..."
sudo mkdir -p /etc/docker
echo '{ "registry-mirrors": ["https://docker.m.daocloud.io"] }' | sudo tee /etc/docker/daemon.json
sudo systemctl restart docker

echo
echo "============================================================"
echo " 安装完成!接下来:"
echo "  1) 重开 SSH 会话(或 newgrp docker)让 docker 组生效"
echo "  2) 验证:"
echo "       docker version"
echo "       docker run --rm hello-world   # 必须看到完整 Hello from Docker! 段落"
echo "============================================================"
