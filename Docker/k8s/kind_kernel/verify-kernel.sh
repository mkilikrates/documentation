#!/bin/bash
###############################################################################
# verify-kernel.sh
#
# Dual-purpose script:
#   1. PREPARE mode: Apply config fragment + sed fixes to a .config file
#      Usage: ./verify-kernel.sh <.config> <fragment.config>
#
#   2. VERIFY mode: Check the running kernel for all required features
#      Usage: ./verify-kernel.sh
#
###############################################################################

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC}   $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; FAILURES=$((FAILURES+1)); }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }

FAILURES=0

###############################################################################
# PREPARE MODE: Apply fragment to .config
###############################################################################
if [ $# -ge 2 ]; then
  CONFIG_FILE="$1"
  FRAGMENT_FILE="$2"

  echo "=============================================="
  echo " Prepare .config for Full Tetragon Support"
  echo "=============================================="
  echo ""

  if [ ! -f "$CONFIG_FILE" ]; then
    fail "Config file not found: $CONFIG_FILE"
    exit 1
  fi
  if [ ! -f "$FRAGMENT_FILE" ]; then
    fail "Fragment file not found: $FRAGMENT_FILE"
    exit 1
  fi

  info "Base config: $CONFIG_FILE"
  info "Fragment:    $FRAGMENT_FILE"
  echo ""

  # Step 1: Merge the fragment
  echo "=== Step 1: Merging fragment ==="
  if [ -f "scripts/kconfig/merge_config.sh" ]; then
    ./scripts/kconfig/merge_config.sh "$CONFIG_FILE" "$FRAGMENT_FILE"
    ok "Fragment merged via merge_config.sh"
  else
    # Fallback: simple cat-based merge (append fragment, let olddefconfig resolve)
    cat "$FRAGMENT_FILE" >> "$CONFIG_FILE"
    ok "Fragment appended to .config (merge_config.sh not found in cwd)"
  fi
  echo ""

  # Step 2: Force-enable options that merge_config.sh fails to override
  echo "=== Step 2: Applying sed fixes for enforcement options ==="

  # Convert ALL netfilter/iptables/nftables modules from =m to =y
  # This prevents module loading failures in WSL2 (Docker, iptables, ip6tables)
  sed -i -E 's/^(CONFIG_(IP_NF|IP6_NF|NF_|NETFILTER_XT|NFT_).*)=m$/\1=y/' .config
  ok "All netfilter/iptables/nftables modules forced to =y (built-in)"

  sed -i 's/# CONFIG_FUNCTION_ERROR_INJECTION is not set/CONFIG_FUNCTION_ERROR_INJECTION=y/' .config
  sed -i 's/# CONFIG_BPF_KPROBE_OVERRIDE is not set/CONFIG_BPF_KPROBE_OVERRIDE=y/' .config

  # Also ensure BPF LSM is in the LSM list
  if grep -q 'CONFIG_LSM=".*tomoyo"' .config; then
    sed -i 's/CONFIG_LSM="landlock,lockdown,yama,loadpin,safesetid,integrity,selinux,apparmor,tomoyo"/CONFIG_LSM="landlock,lockdown,yama,loadpin,safesetid,integrity,selinux,apparmor,bpf"/' .config
    ok "LSM list updated: replaced 'tomoyo' with 'bpf'"
  elif grep -q 'CONFIG_LSM=' .config && ! grep -q 'bpf' .config; then
    sed -i 's/\(CONFIG_LSM="[^"]*\)"/\1,bpf"/' .config
    ok "LSM list updated: appended 'bpf'"
  else
    ok "LSM list already contains 'bpf' or was set by fragment"
  fi

  ok "FUNCTION_ERROR_INJECTION forced to =y"
  ok "BPF_KPROBE_OVERRIDE forced to =y"
  echo ""

  # Step 3: Verify the critical options are set
  echo "=== Step 3: Verifying .config ==="
  PREP_FAILURES=0

  check_config() {
    if grep -q "^${1}=y" .config; then
      ok "$1=y"
    else
      fail "$1 NOT set!"
      PREP_FAILURES=$((PREP_FAILURES+1))
    fi
  }

  check_config "CONFIG_FPROBE"
  check_config "CONFIG_BPF_STREAM_PARSER"
  check_config "CONFIG_FUNCTION_ERROR_INJECTION"
  check_config "CONFIG_BPF_KPROBE_OVERRIDE"
  check_config "CONFIG_BPF"
  check_config "CONFIG_BPF_SYSCALL"
  check_config "CONFIG_BPF_JIT"
  check_config "CONFIG_BPF_LSM"
  check_config "CONFIG_BPF_EVENTS"
  check_config "CONFIG_DEBUG_INFO_BTF"
  check_config "CONFIG_KPROBES"
  check_config "CONFIG_KPROBE_EVENTS"
  check_config "CONFIG_UPROBES"
  check_config "CONFIG_FTRACE_SYSCALLS"

  if grep -q 'CONFIG_LSM=.*bpf' .config; then
    ok "CONFIG_LSM contains 'bpf'"
  else
    fail "CONFIG_LSM does not contain 'bpf'"
    PREP_FAILURES=$((PREP_FAILURES+1))
  fi
  echo ""

  if [ $PREP_FAILURES -eq 0 ]; then
    echo -e "${GREEN}=== .config is ready! Next steps: ===${NC}"
    echo ""
    echo "  make olddefconfig"
    echo "  grep 'BPF_KPROBE_OVERRIDE' .config   # verify it survived"
    echo "  make -j\$(nproc) bzImage"
    echo ""
  else
    echo -e "${RED}=== $PREP_FAILURES option(s) failed. Check output above. ===${NC}"
    exit 1
  fi

  exit 0
fi

###############################################################################
# VERIFY MODE: Check the running kernel
###############################################################################

echo "=============================================="
echo " WSL2 Custom Kernel Verification"
echo "=============================================="
echo ""

echo "=== Kernel Version ==="
uname -r
echo ""

###############################################################################
echo "=== BTF Support (Tetragon) ==="
if [ -f /sys/kernel/btf/vmlinux ]; then
  ok "BTF available at /sys/kernel/btf/vmlinux ($(wc -c < /sys/kernel/btf/vmlinux) bytes)"
else
  fail "BTF not found — Tetragon will not work"
fi
echo ""

###############################################################################
echo "=== Kprobes (Tetragon kprobe policies) ==="
if [ -f /proc/sys/debug/kprobes-optimization ] || [ -f /sys/kernel/debug/kprobes/enabled ]; then
  if [ -f /sys/kernel/debug/kprobes/enabled ]; then
    ENABLED=$(cat /sys/kernel/debug/kprobes/enabled 2>/dev/null || echo "unknown")
    if [ "$ENABLED" = "1" ]; then
      ok "Kprobes enabled"
    else
      warn "Kprobes file exists but value=$ENABLED (may need: echo 1 > /sys/kernel/debug/kprobes/enabled)"
    fi
  else
    ok "Kprobes available (optimization file present)"
  fi
else
  if [ -f /proc/config.gz ] && zgrep -q "CONFIG_KPROBES=y" /proc/config.gz 2>/dev/null; then
    ok "Kprobes compiled in (from /proc/config.gz)"
  else
    fail "Kprobes not available"
  fi
fi
echo ""

###############################################################################
echo "=== BPF Subsystem ==="
if [ -d /sys/fs/bpf ]; then
  ok "BPF filesystem available"
else
  warn "BPF filesystem not mounted (try: mount -t bpf bpf /sys/fs/bpf)"
fi

if command -v bpftool &>/dev/null; then
  if bpftool btf show 2>/dev/null | grep -q vmlinux; then
    ok "bpftool can read vmlinux BTF"
  else
    warn "bpftool present but cannot read vmlinux BTF"
  fi
else
  warn "bpftool not installed (optional, for debugging)"
fi
echo ""

###############################################################################
echo "=== IPVS Modules (kube-proxy IPVS mode) ==="
ipvs_modules=(ip_vs ip_vs_rr ip_vs_wrr ip_vs_sh ip_vs_lc ip_vs_mh)
for mod in "${ipvs_modules[@]}"; do
  if modprobe "$mod" 2>/dev/null; then
    ok "IPVS: $mod"
  else
    fail "IPVS: $mod"
  fi
done
echo ""

###############################################################################
echo "=== nftables Modules (kube-proxy nftables mode) ==="
nft_modules=(nf_tables nft_ct nft_nat nft_masq nft_reject nft_compat nft_fib_inet)
for mod in "${nft_modules[@]}"; do
  if modprobe "$mod" 2>/dev/null; then
    ok "NFT:  $mod"
  else
    fail "NFT:  $mod"
  fi
done
# nft_counter may be built into nf_tables in kernel 6.x+ (not a separate module)
if modprobe nft_counter 2>/dev/null; then
  ok "NFT:  nft_counter (module)"
else
  warn "NFT:  nft_counter (built into nf_tables core in 6.18+)"
fi
echo ""

###############################################################################
echo "=== iptables Modules (kube-proxy iptables mode) ==="
ipt_modules=(ip_tables iptable_nat iptable_filter iptable_mangle ip6_tables ip6table_nat ip6table_filter)
for mod in "${ipt_modules[@]}"; do
  if modprobe "$mod" 2>/dev/null; then
    ok "IPT:  $mod"
  else
    fail "IPT:  $mod"
  fi
done
echo ""

###############################################################################
echo "=== Container / Kind Basics ==="
basics=(overlay br_netfilter veth bridge vxlan dummy)
for mod in "${basics[@]}"; do
  if modprobe "$mod" 2>/dev/null; then
    ok "$mod"
  else
    fail "$mod"
  fi
done
echo ""

###############################################################################
echo "=== Conntrack ==="
if modprobe nf_conntrack 2>/dev/null; then
  ok "nf_conntrack"
  if [ -f /proc/sys/net/netfilter/nf_conntrack_max ]; then
    ok "conntrack_max = $(cat /proc/sys/net/netfilter/nf_conntrack_max)"
  fi
else
  fail "nf_conntrack"
fi
echo ""

###############################################################################
echo "=== Full Tetragon Support ==="

# Helper to check kernel config from /proc/config.gz or /boot/config-*
check_kernel_config() {
  local option="$1"
  local description="$2"
  if [ -f /proc/config.gz ]; then
    if zgrep -q "${option}=y" /proc/config.gz 2>/dev/null; then
      ok "$description"
      return 0
    else
      fail "$description"
      return 1
    fi
  elif [ -f "/boot/config-$(uname -r)" ]; then
    if grep -q "${option}=y" "/boot/config-$(uname -r)" 2>/dev/null; then
      ok "$description"
      return 0
    else
      fail "$description"
      return 1
    fi
  else
    warn "Cannot check $option (no /proc/config.gz or /boot/config-*)"
    return 2
  fi
}

check_kernel_config "CONFIG_FPROBE" "FPROBE enabled (multi-kprobe / fentry/fexit support)"
check_kernel_config "CONFIG_BPF_STREAM_PARSER" "BPF_STREAM_PARSER enabled (sockmap/sockhash support)"
check_kernel_config "CONFIG_BPF_KPROBE_OVERRIDE" "BPF_KPROBE_OVERRIDE enabled (override_return enforcement)"

# Check BPF in LSM list
if [ -f /sys/kernel/security/lsm ]; then
  LSM_LIST=$(cat /sys/kernel/security/lsm 2>/dev/null)
  if echo "$LSM_LIST" | grep -q "bpf"; then
    ok "BPF LSM enabled (enforcement via LSM hooks): $LSM_LIST"
  else
    fail "BPF not in LSM list: $LSM_LIST — Tetragon LSM enforcement unavailable"
  fi
else
  warn "Cannot read /sys/kernel/security/lsm"
fi
echo ""

###############################################################################
echo "=== Tetragon Probe (if installed) ==="
if command -v tetra &>/dev/null; then
  echo "Running 'tetra probe config'..."
  tetra probe config 2>&1 || warn "tetra probe config failed (may need root)"
else
  warn "tetra CLI not installed — install with: helm install tetragon cilium/tetragon"
fi
echo ""

###############################################################################
echo "=== Summary ==="
if [ $FAILURES -eq 0 ]; then
  echo -e "${GREEN}All checks passed! Kernel is ready for Kind + all proxy modes + Tetragon.${NC}"
else
  echo -e "${RED}${FAILURES} check(s) failed. Review output above.${NC}"
fi

exit $FAILURES
