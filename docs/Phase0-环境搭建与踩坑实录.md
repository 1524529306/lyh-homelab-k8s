# Phase 0 环境搭建与踩坑实录

> 时间:2026-08-05
> 目标:在 VMware 中搭好一台可用于 K8s 学习的 Ubuntu 实验机(Docker + 可联网 + 主机可 SSH)
> 定位:这是 `homelab-k8s` 的"地基"阶段。本文档记录**每一步做了什么、踩了什么坑、怎么解决、背后的原理**。

---

## 1. 环境基线

| 项 | 值 |
|---|---|
| 宿主机 | Windows,VMware Workstation Pro |
| 虚拟机 | Ubuntu 24.04 LTS Desktop(amd64) |
| VM 配置 | 4 vCPU / 4GB RAM / 40GB 瘦置备磁盘 |
| 网络 | VMware NAT(vmnet8),VM 固定内网 IP(本机示例 `192.168.211.128`) |
| 远程 | WindTerm(Windows)SSH 连 VM,用户 `lyh`,日常用 `sudo` 提权 |
| 关键原则 | 不启用 root 直登 SSH;普通用户 + sudo;操作留痕 |

---

## 2. 完成清单

- [x] VMware 内 Ubuntu 24.04 Desktop 安装完成
- [x] 虚拟机磁盘采用**瘦置备**(thin),装完实际占用远小于 40GB
- [x] 修复 VMware 虚拟网络(vmnet8 NAT 恢复正常,主机↔VM 双向 ping 通)
- [x] 主机经 WindTerm SSH 直连 VM(用户 lyh)
- [x] Ubuntu 软件源切换为阿里云镜像
- [x] Docker Engine 29.x 安装并验证(`hello-world` 出真实输出)
- [x] Docker 镜像源配置为 daocloud(该网络下唯一可解析的国内镜像)
- [ ] (下一步)安装 k3s / kind,进 Phase 1

---

## 3. 问题与解决方案(含原理)

### 3.1 GitHub push 443 连不上 → 走代理

**现象**:`git push` 报 `Failed to connect to github.com port 443`。

**原因**:GitHub 在国内网络直连不稳定(连接被重置)。

**解决**:
1. 开代理软件(浏览器能上 GitHub 说明代理 OK,但 **Git Bash 不走浏览器代理**,要单独配):
```bash
git config --global http.proxy http://127.0.0.1:7890   # 端口以你代理软件为准
git config --global https.proxy http://127.0.0.1:7890
```
2. push 时认证用 **Personal Access Token(PAT)**,不是密码(2021 年起 GitHub 不再接受密码认证)。

**原理**:代理 = 中间人转发;Git 默认不继承系统代理,必须显式配置。PAT = 细粒度授权凭据,可设有效期和权限范围,比密码安全。

---

### 3.2 Ubuntu 24.04 的源是 deb822 新格式

**现象**:网上教程让你改 `/etc/apt/sources.list`,但 24.04 里这个文件只有一行注释。

**原因**:Ubuntu 22.10 起,软件源从"单行格式"迁移到 **deb822 格式**,存放在:
```
/etc/apt/sources.list.d/ubuntu.sources
```

**解决**:直接覆盖该文件为阿里云镜像(完整内容见文末速查)。

**原理**:deb822 把"每个源"写成一个结构化的块(Types/URIs/Suites/Components/Signed-By),可读性好、支持多源,是 Debian 系的演进方向。**认准文件名 `ubuntu.sources`,别再改老文件。**

---

### 3.3 VMware 虚拟网络坏掉(vmnet8 变成 169.254.x.x)

**现象**:VM 能 ping 通主机,但主机 ping 不通 VM;SSH 超时。查 Windows `ipconfig`,发现 `VMware Network Adapter VMnet8` 的 IP 是 **169.254.x.x**。

**原因**:
- **169.254.0.0/16 是 APIPA(自动私有地址)**,表示这块虚拟网卡**没拿到 DHCP 租约**——vmnet8 的 NAT/DHCP 服务处于异常状态。
- VM 拿到的 IP(如 192.168.5.x)与主机 vmnet8(192.168.80.x)不在同一网段 → 主机无路由到 VM。

**解决**(还原默认网络):
1. VMware 菜单 → **编辑 → 虚拟网络编辑器**
2. 右下角 **更改设置**(需要管理员)→ **还原默认设置**
3. 重建 vmnet0/vmnet1/vmnet8,vmnet8 恢复为正常的 `192.168.x.x` 子网
4. VM 设置 → 网络适配器 → **NAT**
5. VM 内 `sudo dhclient -v` 重新拿 IP,主机 `ping` 验证

**原理**:APIPA 是"拿不到 DHCP 时的兜底",出现它 = 网络服务异常,别硬排查防火墙,先查虚拟网络服务本身。VMware 的 NAT 由 `vmnetdhcp.exe` / `vmnetnat.exe` 提供,"还原默认设置"会重建这些服务及其虚拟网卡。

---

### 3.4 网络模式怎么选:NAT / 桥接 / 仅主机

| 模式 | 主机↔VM | VM 上外网 | 说明 |
|---|---|---|---|
| **NAT(vmnet8)** | ✅(经虚拟网卡) | ✅(NAT 转发) | **学习环境首选**:隔离、稳定、有网 |
| 桥接(Bridged) | ✅(同网段) | ✅(直接走 LAN) | VM 暴露在局域网,IP 受公司 DHCP 影响 |
| 仅主机(Host-only) | ✅ | ❌ 无外网 | 装不了软件包,学习基本不用 |

**结论**:单机学习用 NAT 即可;桥接只有在"多机集群/让别人访问 VM"时才需要;host-only 无外网,不适合装 Docker/K8s。

---

### 3.5 Linux 用户体系:UID / root / sudo(顺带原理)

**现象**:终端里 `lyh@host:~$` 和 `root@host:~#` 的差别;`sudo` 为什么用 lyh 自己的密码。

**原理**:
1. **内核只认 UID 不认用户名**。`lyh` = UID 1000,`root` = UID 0(内核硬编码的超级用户,跳过所有权限检查)。
2. **`$` vs `#`**:普通用户提示符是 `$`,root 是 `#`,是"我现在权限多大"的视觉警告。
3. **lyh 属于 `sudo` 组**(RHEL 系叫 `wheel`),不是"root 的组"。在 sudo 组 = 有资格用 sudo 临时提权。
4. **Ubuntu 默认锁 root**(无可用密码),`passwd root` 解锁——这是策略不是必须。
5. **sudo 设计精髓**:不共享 root 密码,用你自己密码临时提权,命令写入 `/var/log/auth.log` 留痕。

**生产环境铁律**:禁 root 直登 SSH(`PermitRootLogin no`)、个人账号 + SSH 密钥、sudoers 按角色细粒度授权、堡垒机强制入口 + 全程审计。

---

### 3.6 Docker 安装连环坑(重点)

#### 坑 3.6.1:`curl` 不在 PATH / GPG 写入失败
- **现象**:`curl` 命令不存在;`gpg --dearmor` 报 `cannot open '/dev/tty'`。
- **原因**:装 Docker 前没装 `curl`(非交互 sudo 环境 PATH 不含它);gpg 在某些非交互环境下需要 tty。
- **解决**:
```bash
sudo apt install -y curl wget
# GPG 用 --batch 跳过交互提示
curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg
```

#### 坑 3.6.2:装完 docker 组不存在
- **现象**:`usermod -aG docker $USER` 报 `docker 组不存在`。
- **解决**:手动建组再添加:
```bash
sudo groupadd docker
sudo usermod -aG docker $USER
# 重开 SSH 会话(或 newgrp docker)后组才生效
```

#### 坑 3.6.3:镜像源只有 daocloud 能解析(本机网络环境)
- **现象**:`docker run hello-world` 报连不上 `registry-1.docker.io`。
- **原因**:Docker Hub 在国内直连不通;但**阿里云/腾讯云镜像站在这台 VM 的 DNS 下也解析不了**(systemd-resolved 的 127.0.0.53),只有 `docker.m.daocloud.io` 能解析。
- **解决**:`/etc/docker/daemon.json` 配 daocloud:
```json
{ "registry-mirrors": ["https://docker.m.daocloud.io"] }
```
- **验证**:`docker run --rm hello-world` **必须看到完整 "Hello from Docker!" 段落**,别被终端里"粘贴的教程文字"骗了。

#### 坑 3.6.4:`systemctl restart docker` 报 Interactive authentication required
- **现象**:SSH 非交互会话里 `sudo systemctl restart docker` 失败。
- **原因**:systemd 的 polkit 认证要求"登录会话",纯 sudo 不满足。
- **解决**:用 `sudo -i` 进入 login shell 再执行 systemctl。
- **说明**:终端正常交互登录时一般不会遇到,属于"远程自动化执行"特有的坑。

---

### 3.7 快照机制原理:写时复制(Copy-on-Write)

**现象**:VMware 拍快照几乎瞬间完成,回滚也快,占空间还小。

**原理**:快照**不是复制整盘**,而是:
1. 把基础磁盘 `base.vmdk` 标记为**只读**;
2. 新建差异盘 `delta.vmdk`,��后所有写入都进 delta;
3. 读数据时:先查 delta,没命中再读 base;
4. **回滚 = 丢弃 delta**,状态回到快照时刻;删除快照 = 把 delta 合并回 base。

**应用**:装机前拍 `00-fresh`,装 Docker 后拍 `01-docker`,装 k3s 后拍 `02-k3s`——任何一步翻车,秒级回滚。

---

## 4. 标准操作速查(可直接复用)

### 4.1 源(阿里云,Ubuntu 24.04 deb822 格式)
```bash
sudo tee /etc/apt/sources.list.d/ubuntu.sources <<'EOF'
Types: deb
URIs: http://mirrors.aliyun.com/ubuntu/
Suites: noble noble-updates noble-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: http://mirrors.aliyun.com/ubuntu/
Suites: noble-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
sudo apt update
```

### 4.2 Docker(正确姿势,含所有坑)
```bash
# 工具
sudo apt install -y curl wget git openssh-server
sudo systemctl enable --now ssh

# GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg

# 源
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.aliyun.com/docker-ce/linux/ubuntu noble stable" | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt update

# 安装
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# docker 组
sudo groupadd docker 2>/dev/null || true
sudo usermod -aG docker $USER

# 镜像源(daocloud)
sudo mkdir -p /etc/docker
echo '{ "registry-mirrors": ["https://docker.m.daocloud.io"] }' | sudo tee /etc/docker/daemon.json
sudo systemctl restart docker

# 验证(重开 SSH 后)
docker version
docker run --rm hello-world    # 必须看到完整 Hello from Docker! 段落
```

> 一键脚本见 `scripts/install-docker.sh`。

### 4.3 快照节奏
```
00-fresh  装完 Ubuntu 24.04 后立刻拍(关机态,最小)
01-docker Docker 验证通过后拍
02-k3s    k3s Ready 后拍
```

---

## 5. 安全提醒(AI/自动化操作边界)

- 本次教训:AI 在"只让排查 Docker"的请求下擅自装到了 k3s,被用户叫停并回滚。
- **规则**:学习环境自己动手 + AI 文字指导;远程自动化(如 AI SSH)只做用户明确要求的那件事,且应走堡垒机/审计/短期凭据,不长期持有 root 密码。
- 文档与脚本用于**复现正确姿势**,不是鼓励跳过理解。
