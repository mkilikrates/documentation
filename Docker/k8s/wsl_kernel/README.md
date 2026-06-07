# Building a Custom WSL2 Kernel for eBPF, BPF LSM & Tetragon

If you want to run [Tetragon](https://tetragon.io/) (Cilium's eBPF-based security observability and runtime enforcement tool), or any solution that leans on eBPF, BPF LSM, kprobes and the full netfilter stack inside WSL2, you'll quickly find that the default Microsoft-compiled kernel (`6.6.x-microsoft-standard-WSL2`) is missing a lot of the options these tools need. This page shows how to build your own WSL2 kernel with all the right features enabled.

It doesn't really matter which Kubernetes flavor you run on top — k3s, kind, kubeadm — what matters is that the kernel underneath exposes BPF, LSM, kprobes and all three kube-proxy modes. Build the kernel once here, then reuse it for whatever cluster or eBPF tooling you're testing.

The [wsl-tetragon.config](./wsl-tetragon.config) fragment contains only the options that differ from the default WSL2 config (`arch/x86/configs/config-wsl`). Everything is set to `=y` (built-in) on purpose: WSL2 doesn't auto-run `depmod` or auto-load modules, so building everything into the kernel image avoids `modprobe`/`depmod` headaches entirely.

## Table of Contents

- [Why a custom kernel?](#why-a-custom-kernel)
- [What the config enables](#what-the-config-enables)
- [Build the kernel](#build-the-kernel)
- [Deploy the kernel to WSL2](#deploy-the-kernel-to-wsl2)
- [Mount bpffs and securityfs](#mount-bpffs-and-securityfs)
- [Restart WSL2](#restart-wsl2)
- [Related articles](#related-articles)

## Why a custom kernel?

The stock WSL2 kernel doesn't ship with the features needed for full eBPF tooling and all kube-proxy modes. In particular we need:

- **BTF + enforcement** for Tetragon and similar tools (`CONFIG_BPF_KPROBE_OVERRIDE`, `CONFIG_FUNCTION_ERROR_INJECTION`, `CONFIG_FPROBE`)
- **BPF LSM** in the active LSM list for LSM-based enforcement
- **All three kube-proxy modes** (iptables, IPVS, nftables) so you can test any of them, regardless of distro
- **Virtual network devices** (bridge, veth, dummy, vxlan, geneve, wireguard, etc.) for cluster networking and CNIs

It also **disables** a handful of ACPI hardware modules. WSL2 has no physical hardware, and these modules ship malformed BTF that breaks Tetragon's CO-RE relocations (`apply CO-RE relocations: load BTF for kmod ac: ...`). This is fixed upstream but not yet in stable Tetragon, so we turn them off for now.

## What the config enables

The fragment is grouped into sections so it's easy to scan:

| Section | What it does |
|---|---|
| Tetragon: BTF + Enforcement | `override_return` support, fprobe, BPF in the LSM list |
| Disable ACPI hardware modules | Avoids malformed BTF CO-RE issues under WSL2 |
| Networking virtual devices | bridge, dummy, geneve, ipvlan, macvlan, tun, vlan, wireguard |
| Bridge ebtables + core netfilter | Bridge filtering and conntrack helpers |
| Xtables matches/targets | Full iptables match/target set built-in |
| iptables / nftables / IPVS modes | All three kube-proxy modes built-in |
| BPF networking | `cls_bpf`, `act_bpf`, schedulers for tc/eBPF |
| XFRM / IPsec + crypto | Encrypted pod-to-pod traffic (WireGuard, ESP) |

> **Target kernel:** `linux-msft-wsl-6.18.y` (WSL2 kernel 6.18).

## Build the kernel

Clone the Microsoft WSL2 kernel source (shallow clone is fine):

```bash
git clone --depth 1 -b linux-msft-wsl-6.18.y https://github.com/microsoft/WSL2-Linux-Kernel.git
# or use latest by removing "-b linux-msft-wsl-6.18.y"
cd WSL2-Linux-Kernel
```

Start from the default WSL config:

```bash
cp arch/x86/configs/config-wsl .config
```

Merge the fragment (all changes are self-contained in the file):

```bash
./scripts/kconfig/merge_config.sh .config wsl-tetragon.config
```

Resolve dependencies:

```bash
make olddefconfig
```

Re-apply the fragment once more. `make olddefconfig` may re-enable some of the ACPI options we explicitly disabled, so we merge again to make sure our changes stick:

```bash
./scripts/kconfig/merge_config.sh .config wsl-tetragon.config
```

Build the kernel image. No `modules_install` is needed since everything critical is built-in:

```bash
make -j$(nproc) bzImage
```

## Deploy the kernel to WSL2

Copy the built image to a location your Windows host can read, then point your `.wslconfig` at it.

```bash
cp arch/x86/boot/bzImage /mnt/c/Users/<YourUser>/wsl-kernel/bzImage
```

On the Windows side, edit (or create) `.wslconfig` in your home directory (run `$HOME` in powershell to find it) and add:

```ini
[wsl2]
kernel=C:\\Users\\<YourUser>\\wsl-kernel\\bzImage
```

## Mount bpffs and securityfs

WSL2 doesn't mount these by default, and Tetragon (and most eBPF LSM tooling) needs both. Add them to `/etc/fstab` so they persist across restarts:

```bash
echo "bpffs /sys/fs/bpf bpf defaults 0 0" | sudo tee -a /etc/fstab
echo "securityfs /sys/kernel/security securityfs defaults 0 0" | sudo tee -a /etc/fstab
```

## Restart WSL2

From powershell, shut everything down so WSL picks up the new kernel:

```powershell
wsl --shutdown
```

Then start a new WSL session and confirm you're on the new kernel:

```bash
uname -r
```

## Related articles

You can follow my article series on LinkedIn to learn more about how to use this.

### Kubernetes Networking Demystified

#### en

- [Part 1](https://www.linkedin.com/pulse/kubernetes-networking-demystified-part-1-setting-up-rvj6e/)
- [Part 2](https://www.linkedin.com/pulse/kubernetes-networking-demystified-part-2-network-nicolia-dos-anjos--7ltqe/)
- [Part 3](https://www.linkedin.com/pulse/kubernetes-networking-demystified-part-3-under-hood-dopqe/)

#### pt-br

- [Parte 1](https://pt.linkedin.com/pulse/kubernetes-networking-desmistificado-parte-1-montando-hy1ke/)
- [Parte 2](https://www.linkedin.com/pulse/kubernetes-networking-desmistificado-parte-2-network-m7ote/)
- [Parte 3](https://www.linkedin.com/pulse/kubernetes-networking-desmistificado-parte-3-por-do-c84ce/)

### Kubernetes Security: From Network to Workload

#### en

- [Part 1](https://www.linkedin.com/pulse/kubernetes-security-from-network-workload-part-1-mtls-4bz6e/)
- [Part 2](https://www.linkedin.com/pulse/kubernetes-security-from-network-workload-part-2-nicolia-dos-anjos--veiue/)
- [Part 3](https://www.linkedin.com/pulse/kubernetes-security-from-network-workload-part-3-nicolia-dos-anjos--ce7ee/)
- Part 4 (upcoming)

#### pt-br

- [Parte 1](https://www.linkedin.com/pulse/kubernetes-security-da-rede-ao-workload-parte-1-mtls-m0sxe/)
- [Parte 2](https://www.linkedin.com/pulse/kubernetes-security-da-rede-ao-workload-parte-2-com-5uzee/)
- [Parte 3](https://www.linkedin.com/pulse/kubernetes-security-da-rede-ao-workload-parte-3-chain-onxne/)
- Parte 4 (upcoming)
