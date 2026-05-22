#!/bin/bash
###############################################################################
# verify-kernel.sh
#
# Run this after booting the custom WSL2 kernel to verify all required
# features are available for: Kind + iptables/IPVS/nftables + Tetragon kprobes
###############################################################################

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC}   $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; FAILURES=$((FAILURES+1)); }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

FAILURES=0

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
  # kprobes might still be available even without debugfs
  if grep -q "CONFIG_KPROBES=y" /proc/config.gz 2>/dev/null || \
     zgrep -q "CONFIG_KPROBES=y" /proc/config.gz 2>/dev/null; then
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
nft_modules=(nf_tables nft_ct nft_counter nft_nat nft_masq nft_reject nft_compat nft_fib_inet)
for mod in "${nft_modules[@]}"; do
  if modprobe "$mod" 2>/dev/null; then
    ok "NFT:  $mod"
  else
    fail "NFT:  $mod"
  fi
done
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

# Check FPROBE
if [ -f /proc/config.gz ]; then
  if zgrep -q "CONFIG_FPROBE=y" /proc/config.gz 2>/dev/null; then
    ok "FPROBE enabled (multi-kprobe / fentry/fexit support)"
  else
    fail "FPROBE not enabled — multi-kprobe and fentry/fexit hooks unavailable"
  fi
elif [ -f /boot/config-$(uname -r) ]; then
  if grep -q "CONFIG_FPROBE=y" /boot/config-$(uname -r) 2>/dev/null; then
    ok "FPROBE enabled (multi-kprobe / fentry/fexit support)"
  else
    fail "FPROBE not enabled — multi-kprobe and fentry/fexit hooks unavailable"
  fi
else
  warn "Cannot check FPROBE (no /proc/config.gz or /boot/config-*)"
fi

# Check BPF_STREAM_PARSER
if [ -f /proc/config.gz ]; then
  if zgrep -q "CONFIG_BPF_STREAM_PARSER=y" /proc/config.gz 2>/dev/null; then
    ok "BPF_STREAM_PARSER enabled (sockmap/sockhash support)"
  else
    fail "BPF_STREAM_PARSER not enabled — socket-level BPF monitoring unavailable"
  fi
elif [ -f /boot/config-$(uname -r) ]; then
  if grep -q "CONFIG_BPF_STREAM_PARSER=y" /boot/config-$(uname -r) 2>/dev/null; then
    ok "BPF_STREAM_PARSER enabled (sockmap/sockhash support)"
  else
    fail "BPF_STREAM_PARSER not enabled — socket-level BPF monitoring unavailable"
  fi
else
  warn "Cannot check BPF_STREAM_PARSER"
fi

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
