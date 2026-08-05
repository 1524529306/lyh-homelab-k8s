# homelab-k8s

> 本地 K8s + 可观测性 + CI/CD 实验台。
> 包含:从裸机环境(Docker)到 K8s 集群再到监控自动化的全部可复现材料。

## 目录
- 📄 **Phase 0 环境搭建实录(踩坑 + 原理)**:[docs/Phase0-环境搭建与踩坑实录.md](docs/Phase0-环境搭建与踩坑实录.md)
- 🔧 **Docker 一键安装脚本(国内镜像)**:[scripts/install-docker.sh](scripts/install-docker.sh)

## 实验环境
- **宿主机**:Windows + VMware Workstation Pro
- **实验机**:VMware 内一台 **Ubuntu 24.04 LTS Desktop** 虚拟机(4C4G,40GB 瘦置备)
- **网络**:VMware NAT(vmnet8);主机 SSH 进 VM,普通用户 + sudo,不启 root 直登
- **运行时**:Docker Engine 29.x + 待装 k3s(或 kind)

### 环境准备(推荐用脚本)
```bash
bash scripts/install-docker.sh          # 一键装 Docker + 配置 daocloud 镜像源
# 装 k3s(单节点,最轻量)
curl -sfL https://get.k3s.io | sh -
sudo k3s kubectl get node               # 看到 Ready 即成功
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
