# WSL2 Kernel for Kind + All Proxy Modes + Tetragon (kprobes)

Run Kind clusters on Docker with all kube-proxy modes (iptables, IPVS, nftables) and Tetragon with kprobe-based tracing policies.

---

## Good News: WSL2 Kernel 6.18 Has Everything You Need!

After reviewing the [default config-wsl for the 6.18 branch](https://github.com/microsoft/WSL2-Linux-Kernel/blob/linux-msft-wsl-6.18.y/arch/x86/configs/config-wsl), **no custom kernel build is required** if you're running the 6.18 kernel.

### What's already enabled in `linux-msft-wsl-6.18.y`:

| Feature | Status | Key Config Options |
|---|---|---|
| **iptables proxy** | ✅ | `IP_NF_IPTABLES=m`, `IP_NF_NAT=m`, `IP_NF_FILTER=m`, full xt matches |
| **IPVS proxy** | ✅ | `IP_VS=m`, `IP_VS_RR/WRR/SH/MH/LC/DH/SED/NQ=m`, `IP_VS_NFCT=y` |
| **nftables proxy** | ✅ | `NF_TABLES=y` (built-in!), `NFT_NAT=y`, `NFT_MASQ=y`, `NFT_CT=m` |
| **Overlay FS** | ✅ | `OVERLAY_FS=y` (built-in) |
| **Container networking** | ✅ | `VETH=y`, `BRIDGE=m`, `VXLAN=y`, `GENEVE=m`, `IPVLAN=m`, `MACVLAN=m`, `DUMMY=m` |
| **Namespaces** | ✅ | `NET_NS=y`, `PID_NS=y`, `USER_NS=y`, `IPC_NS=y`, `UTS_NS=y` |
| **Cgroups v2** | ✅ | Full unified hierarchy, `MEMCG=y`, `CGROUP_BPF=y`, `CGROUP_PIDS=y` |
| **BPF/eBPF** | ✅ | `BPF=y`, `BPF_SYSCALL=y`, `BPF_JIT=y`, `BPF_JIT_ALWAYS_ON=y`, `BPF_LSM=y` |
| **BTF (Tetragon)** | ✅ | `DEBUG_INFO_BTF=y`, `DEBUG_INFO_BTF_MODULES=y` |
| **Kprobes (Tetragon)** | ✅ | `KPROBES=y`, `KRETPROBES=y`, `KPROBE_EVENTS=y`, `OPTPROBES=y` |
| **Uprobes (Tetragon)** | ✅ | `UPROBES=y`, `UPROBE_EVENTS=y` |
| **Ftrace/Tracing** | ✅ | `FTRACE=y`, `FTRACE_SYSCALLS=y`, `DYNAMIC_FTRACE=y`, `TRACEPOINTS=y` |
| **Perf + BPF events** | ✅ | `PERF_EVENTS=y`, `BPF_EVENTS=y` |
| **Seccomp** | ✅ | `SECCOMP=y`, `SECCOMP_FILTER=y` |
| **Audit** | ✅ | `AUDIT=y`, `AUDITSYSCALL=y` |
| **Conntrack** | ✅ | `NF_CONNTRACK=y` (built-in), full protocol support |
| **IP Sets** | ✅ | `IP_SET=m` with all hash/bitmap types |
| **Wireguard** | ✅ | `WIREGUARD=m` |
| **Security/LSM** | ✅ | SELinux, AppArmor, Landlock, Yama, BPF LSM |

### Only minor gaps (not needed for your use case):

| Feature | Status | Impact |
|---|---|---|
| `FPROBE` | ❌ Not set | Only needed for some newer Tetragon features, not kprobes |
| `BPF_STREAM_PARSER` | ❌ Not set | Socket-level BPF, not needed for kprobe policies |

---

## Do I Need a Custom Build?

**No**, if you use the WSL2 6.18 kernel. Just ensure you're on the latest kernel:

```powershell
# Check your current WSL kernel version
wsl uname -r
# Should show 6.18.x-microsoft-standard-WSL2
```

If you're on an older kernel (5.15 or 6.1), you have two options:
1. **Update WSL** (recommended): `wsl --update` in PowerShell
2. **Build a custom kernel** using the fragment below (only if stuck on older WSL)

---

## Option A: Just Update WSL (Recommended)

```powershell
# Update WSL to get the latest kernel
wsl --update

# Restart WSL
wsl --shutdown
wsl

# Verify
wsl uname -r
```

If you're on Windows 11 with recent updates, WSL should ship with kernel 6.6+ or 6.18.

---

## Option B: Build Custom Kernel (Only if on Older WSL)

If you cannot update and are stuck on kernel 5.15.x, follow these steps:

---

## References

| Resource | URL |
|---|---|
| WSL2 Kernel Source | https://github.com/microsoft/WSL2-Linux-Kernel |
| WSL2 config-wsl (6.6.y) | https://github.com/microsoft/WSL2-Linux-Kernel/blob/linux-msft-wsl-6.6.y/arch/x86/configs/config-wsl |
| Tetragon FAQ (kernel reqs) | https://tetragon.io/docs/installation/faq/ |
| Tetragon kprobe hooks | https://tetragon.cilium.io/docs/concepts/tracing-policy/hooks/ |
| K8s IPVS proxy README | https://github.com/kubernetes/kubernetes/blob/master/pkg/proxy/ipvs/README.md |
| K8s nftables KEP | https://github.com/kubernetes/enhancements/blob/master/keps/sig-network/3866-nftables-proxy/README.md |
| EKS IPVS best practices | https://docs.aws.amazon.com/eks/latest/best-practices/ipvs.html |
| BCC kernel config reference | https://github.com/iovisor/bcc/blob/master/docs/kernel_config.md |
| Enable eBPF on WSL2 (gist) | https://gist.github.com/MarioHewardt/5759641727aae880b29c8f715ba4d30f |
| awslabs/amazon-eks-ami | https://github.com/awslabs/amazon-eks-ami |

---

## Step 1 — Clone the WSL2 Kernel Source

```bash
# Use the 6.6 LTS branch (good balance of features and stability)
git clone --depth 1 -b linux-msft-wsl-6.6.y https://github.com/microsoft/WSL2-Linux-Kernel.git
cd WSL2-Linux-Kernel
```

> **Note**: Kernel 6.6+ is recommended. nftables proxy mode requires ≥ 5.13, and Tetragon BTF support works best on 5.8+. The 6.6 LTS branch gives you all of these.

---

## Step 2 — Start with the Default WSL2 Config

```bash
cp arch/x86/configs/config-wsl .config
```

---

## Step 3 — Apply the Kind + IPVS + nftables + Tetragon Fragment

Create `kind-tetragon.config` with the contents from the section below, then merge:

```bash
./scripts/kconfig/merge_config.sh .config kind-tetragon.config
```

---

## Kernel Config Fragment: `kind-tetragon.config`

```ini
###############################################################################
# KIND / DOCKER BASICS
###############################################################################

# Overlay filesystem (container image layers)
CONFIG_OVERLAY_FS=m

# Namespaces (container isolation)
CONFIG_NAMESPACES=y
CONFIG_USER_NS=y
CONFIG_NET_NS=y
CONFIG_PID_NS=y
CONFIG_IPC_NS=y
CONFIG_UTS_NS=y
CONFIG_CGROUP_NS=y

# Cgroups v2 (Kind requires cgroups v2 with unified hierarchy)
CONFIG_CGROUPS=y
CONFIG_CGROUP_FREEZER=y
CONFIG_CGROUP_PIDS=y
CONFIG_CGROUP_DEVICE=y
CONFIG_CPUSETS=y
CONFIG_CGROUP_CPUACCT=y
CONFIG_MEMCG=y
CONFIG_CGROUP_SCHED=y
CONFIG_CGROUP_BPF=y
CONFIG_CGROUP_MISC=y

# Virtual ethernet (pod-to-pod and container networking)
CONFIG_VETH=m
CONFIG_BRIDGE=m
CONFIG_VXLAN=m
CONFIG_GENEVE=m
CONFIG_IPVLAN=m
CONFIG_MACVLAN=m
CONFIG_DUMMY=m
CONFIG_TUN=m
CONFIG_WIREGUARD=m

###############################################################################
# KUBE-PROXY MODE: IPTABLES
###############################################################################

CONFIG_NETFILTER=y
CONFIG_NF_CONNTRACK=m
CONFIG_NETFILTER_XTABLES=m
CONFIG_NETFILTER_XT_MATCH_CONNTRACK=m
CONFIG_NETFILTER_XT_MATCH_MULTIPORT=m
CONFIG_NETFILTER_XT_MATCH_STATISTIC=m
CONFIG_NETFILTER_XT_MATCH_COMMENT=m
CONFIG_NETFILTER_XT_MATCH_RECENT=m
CONFIG_NETFILTER_XT_MATCH_MARK=m
CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=m
CONFIG_NETFILTER_XT_TARGET_MARK=m
CONFIG_NETFILTER_XT_TARGET_REDIRECT=m
CONFIG_NETFILTER_XT_TARGET_MASQUERADE=m
CONFIG_NF_NAT=m
CONFIG_IP_NF_IPTABLES=m
CONFIG_IP_NF_FILTER=m
CONFIG_IP_NF_NAT=m
CONFIG_IP_NF_MANGLE=m
CONFIG_IP_NF_RAW=m
CONFIG_IP6_NF_IPTABLES=m
CONFIG_IP6_NF_FILTER=m
CONFIG_IP6_NF_MANGLE=m
CONFIG_IP6_NF_RAW=m
CONFIG_IP6_NF_NAT=m
CONFIG_BRIDGE_NETFILTER=m

###############################################################################
# KUBE-PROXY MODE: IPVS
###############################################################################

CONFIG_IP_VS=m
CONFIG_IP_VS_PROTO_TCP=y
CONFIG_IP_VS_PROTO_UDP=y
CONFIG_IP_VS_PROTO_SCTP=y
CONFIG_IP_VS_RR=m
CONFIG_IP_VS_WRR=m
CONFIG_IP_VS_SH=m
CONFIG_IP_VS_LC=m
CONFIG_IP_VS_DH=m
CONFIG_IP_VS_LBLC=m
CONFIG_IP_VS_LBLCR=m
CONFIG_IP_VS_SED=m
CONFIG_IP_VS_NQ=m
CONFIG_IP_VS_MH=m
CONFIG_IP_VS_NFCT=y
CONFIG_IP_VS_FTP=m

###############################################################################
# KUBE-PROXY MODE: NFTABLES (requires kernel >= 5.13)
###############################################################################

CONFIG_NF_TABLES=m
CONFIG_NF_TABLES_INET=y
CONFIG_NF_TABLES_NETDEV=y
CONFIG_NFT_CT=m
CONFIG_NFT_COUNTER=m
CONFIG_NFT_LOG=m
CONFIG_NFT_LIMIT=m
CONFIG_NFT_MASQ=m
CONFIG_NFT_REDIR=m
CONFIG_NFT_NAT=m
CONFIG_NFT_REJECT=m
CONFIG_NFT_COMPAT=m
CONFIG_NFT_HASH=m
CONFIG_NFT_FIB=m
CONFIG_NFT_FIB_INET=m
CONFIG_NFT_FIB_IPV4=m
CONFIG_NFT_FIB_IPV6=m
CONFIG_NF_TABLES_IPV4=y
CONFIG_NF_TABLES_IPV6=y
CONFIG_NFT_CHAIN_NAT=m
CONFIG_NFT_CHAIN_ROUTE_IPV4=m
CONFIG_NFT_CHAIN_ROUTE_IPV6=m

###############################################################################
# TETRAGON: eBPF + KPROBES + BTF
###############################################################################

# Core BPF
CONFIG_BPF=y
CONFIG_BPF_SYSCALL=y
CONFIG_BPF_JIT=y
CONFIG_BPF_JIT_ALWAYS_ON=y
CONFIG_BPF_STREAM_PARSER=y
CONFIG_BPF_LSM=y
CONFIG_BPF_UNPRIV_DEFAULT_OFF=y

# BTF (required for Tetragon CO-RE and kprobe argument parsing)
CONFIG_DEBUG_INFO=y
CONFIG_DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT=y
CONFIG_DEBUG_INFO_BTF=y
CONFIG_DEBUG_INFO_BTF_MODULES=y
CONFIG_PAHOLE_HAS_SPLIT_BTF=y

# Kprobes (required for Tetragon kprobe-based policies)
CONFIG_KPROBES=y
CONFIG_KPROBE_EVENTS=y
CONFIG_KRETPROBES=y
CONFIG_HAVE_KPROBES=y
CONFIG_HAVE_KRETPROBES=y

# Tracepoints (for Tetragon tracepoint policies)
CONFIG_TRACEPOINTS=y
CONFIG_TRACING=y
CONFIG_FTRACE=y
CONFIG_FTRACE_SYSCALLS=y
CONFIG_FUNCTION_TRACER=y
CONFIG_DYNAMIC_FTRACE=y
CONFIG_FPROBE=y

# Perf events (BPF perf buffer)
CONFIG_PERF_EVENTS=y

# BPF ring buffer (preferred over perf buffer in newer kernels)
CONFIG_BPF_EVENTS=y

# Uprobe support (for Tetragon uprobe policies)
CONFIG_UPROBES=y
CONFIG_UPROBE_EVENTS=y

# LSM BPF (for Tetragon LSM enforcement hooks)
CONFIG_SECURITY=y
CONFIG_SECURITYFS=y
CONFIG_LSM="lockdown,yama,loadpin,safesetid,integrity,bpf"

# Cgroup BPF (for container-aware filtering)
CONFIG_CGROUP_BPF=y

###############################################################################
# SECCOMP (Pod Security Standards)
###############################################################################

CONFIG_SECCOMP=y
CONFIG_SECCOMP_FILTER=y

###############################################################################
# STORAGE (for Kind persistent volumes and testing)
###############################################################################

CONFIG_EXT4_FS=y
CONFIG_XFS_FS=m
CONFIG_FUSE_FS=m
CONFIG_TMPFS=y
CONFIG_TMPFS_POSIX_ACL=y

###############################################################################
# MISC NETWORKING
###############################################################################

CONFIG_IP_MULTICAST=y
CONFIG_NET_SCH_HTB=m
CONFIG_NET_SCH_INGRESS=m
CONFIG_NET_CLS_BPF=m
CONFIG_NET_CLS_ACT=y
CONFIG_NET_ACT_BPF=m
CONFIG_NET_ACT_MIRRED=m
CONFIG_INET_ESP=m
CONFIG_XFRM_USER=m
CONFIG_XFRM_ALGO=m

###############################################################################
# AUDIT (for observability / Tetragon audit events)
###############################################################################

CONFIG_AUDIT=y
CONFIG_AUDITSYSCALL=y

###############################################################################
# KERNEL MODULE LOADING (for runtime module loading in Kind nodes)
###############################################################################

CONFIG_MODULES=y
CONFIG_MODULE_UNLOAD=y
CONFIG_MODULE_FORCE_UNLOAD=y
```

---

## Step 4 — Build

```bash
# Install build dependencies (Ubuntu/Debian in WSL)
sudo apt update && sudo apt install -y \
  build-essential flex bison \
  libssl-dev libelf-dev \
  bc dwarves pkg-config \
  python3 pahole

# Resolve new config symbols
make olddefconfig

# Build the kernel image
make -j$(nproc) bzImage

# Optional: build modules if you want loadable modules
make -j$(nproc) modules
```

> **Important**: `dwarves` (which provides `pahole`) is required for `CONFIG_DEBUG_INFO_BTF=y`. Without it the build will fail.

---

## Step 5 — Install the Custom Kernel

Copy the built kernel to a Windows-accessible path:

```bash
# From inside WSL
cp arch/x86/boot/bzImage /mnt/c/Users/<YourUser>/wsl-kernel/bzImage
```

Create or edit `%USERPROFILE%\.wslconfig`:

```ini
[wsl2]
kernel=C:\\Users\\<YourUser>\\wsl-kernel\\bzImage
```

Restart WSL:

```powershell
wsl --shutdown
wsl
```

---

## Step 6 — Verify

```bash
# Check kernel version
uname -r

# Verify BTF is available (required for Tetragon)
ls /sys/kernel/btf/vmlinux

# Verify kprobes are enabled
cat /sys/kernel/debug/kprobes/enabled
# Should output "1"

# Load IPVS modules
sudo modprobe ip_vs
sudo modprobe ip_vs_rr
sudo modprobe ip_vs_wrr
sudo modprobe ip_vs_sh

# Verify IPVS
sudo lsmod | grep ip_vs

# Load nftables
sudo modprobe nf_tables

# Verify nftables
nft list ruleset

# Load iptables
sudo modprobe ip_tables
sudo modprobe iptable_nat

# Verify iptables
sudo iptables -L -n
```

---

## Step 7 — Test with Kind

### Create a Kind cluster with iptables proxy mode (default)

```bash
kind create cluster --name iptables-test
kubectl get nodes
```

### Create a Kind cluster with IPVS proxy mode

```yaml
# kind-ipvs.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: ClusterConfiguration
    apiServer:
      extraArgs:
        "feature-gates": ""
  - |
    kind: KubeProxyConfiguration
    mode: ipvs
```

```bash
kind create cluster --name ipvs-test --config kind-ipvs.yaml
```

### Create a Kind cluster with nftables proxy mode

```yaml
# kind-nftables.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: KubeProxyConfiguration
    mode: nftables
```

```bash
kind create cluster --name nftables-test --config kind-nftables.yaml
```

---

## Step 8 — Test Tetragon with kprobe Policies

### Install Tetragon via Helm

```bash
helm repo add cilium https://helm.cilium.io
helm repo update
helm install tetragon cilium/tetragon -n kube-system

# Wait for pods to be ready
kubectl rollout status -n kube-system ds/tetragon
```

### Deploy a kprobe-based tracing policy

```yaml
# policy-kprobe-tcp-connect.yaml
apiVersion: cilium.io/v1alpha1
kind: TracingPolicy
metadata:
  name: "monitor-tcp-connect"
spec:
  kprobes:
  - call: "tcp_connect"
    syscall: false
    args:
    - index: 0
      type: "sock"
    selectors:
    - matchActions:
      - action: Sigkill
        # Or just observe:
        # action: Post
```

```bash
kubectl apply -f policy-kprobe-tcp-connect.yaml

# Watch Tetragon events
kubectl logs -n kube-system -l app.kubernetes.io/name=tetragon -c export-stdout -f | \
  tetra getevents -o compact
```

### Verify kprobe is attached

```bash
# Inside the Kind node (docker exec into it)
docker exec -it <kind-node-container> cat /sys/kernel/debug/kprobes/list | grep tcp_connect
```

---

## Module Verification Script

```bash
#!/bin/bash
# verify-kernel.sh — Run after booting the custom WSL2 kernel

echo "=== Kernel Version ==="
uname -r

echo ""
echo "=== BTF Support (Tetragon) ==="
if [ -f /sys/kernel/btf/vmlinux ]; then
  echo "[OK] BTF available at /sys/kernel/btf/vmlinux"
else
  echo "[FAIL] BTF not found"
fi

echo ""
echo "=== Kprobes (Tetragon) ==="
if [ -f /sys/kernel/debug/kprobes/enabled ]; then
  ENABLED=$(cat /sys/kernel/debug/kprobes/enabled 2>/dev/null)
  if [ "$ENABLED" = "1" ]; then
    echo "[OK] Kprobes enabled"
  else
    echo "[WARN] Kprobes file exists but value=$ENABLED"
  fi
else
  echo "[FAIL] Kprobes not available"
fi

echo ""
echo "=== Proxy Mode Modules ==="

# IPVS
ipvs_modules=(ip_vs ip_vs_rr ip_vs_wrr ip_vs_sh)
for mod in "${ipvs_modules[@]}"; do
  if modprobe "$mod" 2>/dev/null; then
    echo "[OK]   IPVS: $mod"
  else
    echo "[FAIL] IPVS: $mod"
  fi
done

# nftables
nft_modules=(nf_tables nft_ct nft_counter nft_nat nft_masq)
for mod in "${nft_modules[@]}"; do
  if modprobe "$mod" 2>/dev/null; then
    echo "[OK]   NFT:  $mod"
  else
    echo "[FAIL] NFT:  $mod"
  fi
done

# iptables
ipt_modules=(ip_tables iptable_nat iptable_filter ip6_tables ip6table_nat)
for mod in "${ipt_modules[@]}"; do
  if modprobe "$mod" 2>/dev/null; then
    echo "[OK]   IPT:  $mod"
  else
    echo "[FAIL] IPT:  $mod"
  fi
done

echo ""
echo "=== Container / Kind Basics ==="
basics=(overlay br_netfilter veth bridge vxlan)
for mod in "${basics[@]}"; do
  if modprobe "$mod" 2>/dev/null; then
    echo "[OK]   $mod"
  else
    echo "[FAIL] $mod"
  fi
done

echo ""
echo "=== BPF ==="
if [ -d /sys/fs/bpf ]; then
  echo "[OK] BPF filesystem mounted"
else
  echo "[WARN] BPF filesystem not mounted (mount with: mount -t bpf bpf /sys/fs/bpf)"
fi

if bpftool btf show 2>/dev/null | grep -q vmlinux; then
  echo "[OK] bpftool can read vmlinux BTF"
else
  echo "[INFO] bpftool not installed or BTF not readable (install bpftool for full verification)"
fi
```

---

## Troubleshooting

| Problem | Solution |
|---|---|
| `BTF discovery: candidate btf file does not exist` | Ensure `CONFIG_DEBUG_INFO_BTF=y` and `pahole` was available during build |
| IPVS modules not found | Check `CONFIG_IP_VS=m` and all schedulers are set to `=m` |
| nftables: `Operation not supported` | Ensure kernel ≥ 5.13 and `CONFIG_NF_TABLES=m` |
| Kind: `cpu.weight: no such file or directory` | Ensure cgroups v2 unified hierarchy is enabled (default in WSL2 6.x) |
| Tetragon: kprobe attach fails | Verify `/sys/kernel/debug/kprobes/enabled` = 1 |
| Build fails at BTF generation | Install `dwarves` ≥ 1.24 and `pahole` |

---

## Notes

- The nftables proxy mode is GA as of Kubernetes 1.31+ and recommended as the successor to both iptables and IPVS modes.
- Tetragon requires kernel ≥ 4.19, but for full kprobe + BTF + ringbuf support, 5.8+ is recommended (6.6 is ideal).
- The `CONFIG_LSM` line must include `bpf` for Tetragon's LSM enforcement hooks to work.
- This config does NOT include ENA driver or other EC2-specific hardware drivers (not needed for WSL2).
