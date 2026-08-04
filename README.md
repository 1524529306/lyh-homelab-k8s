# homelab-k8s

> 本地 K8s + 可观测性 + CI/CD 实验台。转型规划的 Phase 1–3 硬证据仓库。
> 用途:简历「项目经验」栏的实打实内容——证明你真上手过容器编排、监控、流水线,不依赖公司平台。

## 实验环境(2026-08-04 确定)
- **宿主机**:Windows + VMware
- **实验机**:VMware 里一台 Ubuntu 22.04 虚拟机(2C4G 起,能跑多节点就 4C8G)
- **运行时**:Docker Engine + k3s(或 kind)在 Ubuntu 内运行

### 环境准备命令(Ubuntu 22.04 虚拟机内执行)
```bash
# 1. 安装 Docker
sudo apt-get update
sudo apt-get install -y docker.io
sudo systemctl enable --now docker
sudo usermod -aG docker $USER   # 退出重登生效
docker run hello-world          # 出 Hello from Docker 即成功

# 2. 装 k3s(单节点,最轻量)
curl -sfL https://get.k3s.io | sh -
# 多节点可加 WORKER 节点,先单节点练手
sudo k3s kubectl get node       # 看到 Ready 即成功

# 备选:用 kind(纯容器跑 K8s,适合只练 kubectl)
# curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
# chmod +x ./kind && sudo mv ./kind /usr/local/bin/
# kind create cluster --name homelab
```

## 阶段计划
### Phase 1|K8s 核心(目标:CKA)
- [ ] 部署一个静态页 / 小应用到 k3s
- [ ] 配好 liveness / readiness 探针
- [ ] 用 Service + Ingress 对外暴露
- [ ] 实践滚动更新与回滚
- [ ] 用 PV/PVC 挂存储
- [ ] 报考并通过 **CKA**

### Phase 2|可观测性 + 自动化
- [ ] 装 Prometheus + Grafana + Alertmanager + Loki,监控本集群
- [ ] 配 3 条真实告警(CPU/内存/Pod 重启)
- [ ] Ansible 批量管理 + 2 个 Python 脚本
- [ ] GitHub Actions:推代码 → 自动构建 → 自动部署到 k3s

### Phase 3|上云 + 进阶
- [ ] 在阿里云复刻同一套架构(VPC/安全组/CLB)
- [ ] 考一张云证书(阿里云 ACE / 腾讯云 TCP)
- [ ] (可选)部署 Ollama/vLLM 推理服务,体验 AI 基础设施运维

## 架构图(Phase 2 完成后画,先占位)
```
浏览器 → Ingress → Service → Pod(应用)
                ↘ Prometheus → Grafana(面板)
                     ↑  Alertmanager(告警)
```
