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
| **BTF (Tetragon)** | ✅ | `DEBUG_INFO_BTF=y` (Required. Note: `DEBUG_INFO_BTF_MODULES` should be disabled under WSL2 to avoid module split BTF issues) |
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

### What's MISSING for full Tetragon support (requires custom build):

| Feature | Status | Impact |
|---|---|---|
| `CONFIG_FPROBE` | ❌ Not set | Required for multi-kprobe and fentry/fexit hooks (more efficient than kprobes on 6.x+) |
| `CONFIG_BPF_STREAM_PARSER` | ❌ Not set | Required for sockmap/sockhash BPF programs (socket-level monitoring) |
| `CONFIG_BPF_KPROBE_OVERRIDE` | ❌ Not set | **CRITICAL for enforcement** — enables `override_return` action in TracingPolicy (block syscalls/functions) |
| `CONFIG_FUNCTION_ERROR_INJECTION` | ❌ Not set | Dependency of `BPF_KPROBE_OVERRIDE` |
| `CONFIG_LSM` with `bpf` | ⚠️ Missing `bpf` | Default LSM list does not include `bpf` — needed for BPF LSM enforcement (override/sigkill via LSM hooks) |

---

## Kubernetes 1.35 Compatibility Check

Kubernetes 1.35 ("Timbernetes") introduces breaking changes. Here's the validation against WSL2 6.18:

| K8s 1.35 Requirement | WSL2 6.18 | Status |
|---|---|---|
| **Cgroups v2 ONLY** (v1 support removed — kubelet refuses to start on v1) | `# CONFIG_MEMCG_V1 is not set` | ✅ Already cgroups v2 only |
| **Kernel ≥ 4.19** | 6.18 | ✅ |
| **nftables proxy mode** (recommended, replaces IPVS) | `NF_TABLES=y` built-in, kernel ≥ 5.13 | ✅ |
| **IPVS proxy** (deprecated in 1.35, will be removed) | `IP_VS=m`, all schedulers | ✅ Still usable |
| **Namespaced net sysctls** (tcp_keepalive_time, tcp_fin_timeout, etc.) | Kernel ≥ 4.5/4.6/4.15 | ✅ All supported |
| **net.ipv4.tcp_rmem / tcp_wmem** (since K8s 1.32) | Kernel ≥ 4.15 | ✅ |
| **Recursive read-only mounts** (GA in 1.35) | Kernel ≥ 5.12 | ✅ |
| **Swap support with noswap** (if using swap) | Kernel ≥ 6.3 | ✅ |
| **User namespaces for pods** | `USER_NS=y` | ✅ |
| **Seccomp** | `SECCOMP=y`, `SECCOMP_FILTER=y` | ✅ |
| **AppArmor** | In LSM list | ✅ |
| **PSI metrics** (Pressure Stall Information) | `CONFIG_PSI=y` | ✅ |

### Important Notes for K8s 1.35:

1. **IPVS is deprecated** — nftables is the recommended proxy mode going forward. Plan to migrate.
2. **containerd 1.x reaches end of life** — ensure you're running containerd 2.x.
3. **cgroup v1 will cause kubelet startup failure** — our kernel has v1 disabled, so we're safe.

> **Verdict**: The WSL2 6.18 kernel is fully compatible with Kubernetes 1.35. No additional kernel options needed beyond our Tetragon additions.

---

## Custom Build Required for Full Tetragon

To enable **all** Tetragon features (fprobe, BPF stream parser, BPF LSM enforcement), you need to build a custom kernel. The good news is only a few changes are needed on top of the default config.

### Quick Summary of Changes:

```diff
+ CONFIG_FPROBE=y
+ CONFIG_BPF_STREAM_PARSER=y
+ CONFIG_FUNCTION_ERROR_INJECTION=y
+ CONFIG_BPF_KPROBE_OVERRIDE=y
- CONFIG_LSM="landlock,lockdown,yama,loadpin,safesetid,integrity,selinux,apparmor,tomoyo"
+ CONFIG_LSM="landlock,lockdown,yama,loadpin,safesetid,integrity,selinux,apparmor,bpf"
- CONFIG_DEBUG_INFO_BTF_MODULES=y
+ # CONFIG_DEBUG_INFO_BTF_MODULES is not set
+ # (Disable split BTF for modules to prevent WSL2 kmod BTF parsing errors in Tetragon)
```

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

## Build Steps

### Step 1 — Clone the WSL2 Kernel Source

```bash
# Use the 6.18 branch (latest, has most features already)
git clone --depth 1 -b linux-msft-wsl-6.18.y https://github.com/microsoft/WSL2-Linux-Kernel.git
cd WSL2-Linux-Kernel
```

---

### Step 2 — Start with the Default WSL2 Config

```bash
cp arch/x86/configs/config-wsl .config
```

---

### Step 3 — Apply the Full Tetragon Fragment

The `kind-tetragon.config` file in this directory adds `FPROBE`, `BPF_STREAM_PARSER`, `BPF_KPROBE_OVERRIDE`, and `bpf` to the LSM list:

```bash
./scripts/kconfig/merge_config.sh .config /path/to/kind-tetragon.config

# IMPORTANT: Force ALL netfilter/iptables modules from =m to =y (built-in)
# WSL2 doesn't auto-load modules — this prevents Docker/iptables failures
sed -i -E 's/^(CONFIG_(IP_NF|IP6_NF|NF_|NETFILTER_XT|NFT_).*)=m$/\1=y/' .config

# Force enforcement options that merge_config.sh fails to override
sed -i 's/# CONFIG_FUNCTION_ERROR_INJECTION is not set/CONFIG_FUNCTION_ERROR_INJECTION=y/' .config
sed -i 's/# CONFIG_BPF_KPROBE_OVERRIDE is not set/CONFIG_BPF_KPROBE_OVERRIDE=y/' .config

# Disable ACPI hardware modules (malformed BTF crashes Tetragon CO-RE under WSL2)
sed -i 's/CONFIG_ACPI_AC=m/# CONFIG_ACPI_AC is not set/' .config
sed -i 's/CONFIG_ACPI_BATTERY=m/# CONFIG_ACPI_BATTERY is not set/' .config
sed -i 's/CONFIG_ACPI_FAN=m/# CONFIG_ACPI_FAN is not set/' .config
sed -i 's/CONFIG_ACPI_VIDEO=m/# CONFIG_ACPI_VIDEO is not set/' .config
sed -i 's/CONFIG_ACPI_BUTTON=m/# CONFIG_ACPI_BUTTON is not set/' .config

# Disable split BTF for modules (Tetragon has all required drivers as built-in)
sed -i 's/CONFIG_DEBUG_INFO_BTF_MODULES=y/# CONFIG_DEBUG_INFO_BTF_MODULES is not set/' .config

# Verify critical options:
grep -E "FUNCTION_ERROR_INJECTION|BPF_KPROBE_OVERRIDE|DEBUG_INFO_BTF_MODULES" .config
# Expected output:
#   CONFIG_FUNCTION_ERROR_INJECTION=y
#   CONFIG_BPF_KPROBE_OVERRIDE=y
#   # CONFIG_DEBUG_INFO_BTF_MODULES is not set
```

---

### Step 4 — Build

```bash
# Install build dependencies (Ubuntu/Debian in WSL)
sudo apt update && sudo apt install -y \
  build-essential flex bison \
  libssl-dev libelf-dev \
  bc dwarves pkg-config \
  python3 pahole

# Resolve new config symbols (should keep FUNCTION_ERROR_INJECTION and BPF_KPROBE_OVERRIDE)
make olddefconfig

# Double-check it survived olddefconfig:
grep "BPF_KPROBE_OVERRIDE" .config
# Must show: CONFIG_BPF_KPROBE_OVERRIDE=y

# Build the kernel image (no modules_install needed — everything is built-in!)
make -j$(nproc) bzImage
```

> **Important**: `dwarves` (which provides `pahole`) is required for `CONFIG_DEBUG_INFO_BTF=y`. Without it the build will fail.

---

### Step 5 — Install the Custom Kernel

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

### Step 6 — Verify

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

### Step 7 — Test with Kind

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

### Step 8 — Test Tetragon with kprobe Policies

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
| Tetragon error: `offset ... is not the beginning of a string` | Malformed split BTF for ACPI hardware modules (`ac`, `button`, etc.) in WSL2. Ensure `CONFIG_DEBUG_INFO_BTF_MODULES` is disabled (or removed) and ACPI modules are disabled via `.config` changes. |

---

## Notes

- The nftables proxy mode is GA as of Kubernetes 1.31+ and recommended as the successor to both iptables and IPVS modes.
- Tetragon requires kernel ≥ 4.19, but for full kprobe + BTF + ringbuf support, 5.8+ is recommended (6.6 is ideal).
- The `CONFIG_LSM` line must include `bpf` for Tetragon's LSM enforcement hooks to work.
- This config does NOT include ENA driver or other EC2-specific hardware drivers (not needed for WSL2).
