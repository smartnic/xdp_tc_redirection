#!/usr/bin/env bash
set -euo pipefail


if [[ "${1-:-}" == "clean" ]]; then
  echo "⟳ Cleaning slate…"
  ip link set dev veth0 xdp off      2>/dev/null || true
  ip link del veth0                  2>/dev/null || true
  ip link del veth1                  2>/dev/null || true
  ip netns del test-ns               2>/dev/null || true
  umount /sys/fs/bpf                 2>/dev/null || true
  echo "✅ Clean complete."
  exit 0
fi

echo "0) Checking deps…"
./check-ebpf-deps.sh

echo "1) Compiling BPF programs…"
clang -O2 -g -target bpf -I/usr/include/$(uname -m)-linux-gnu \
  -c xdp_dispatcher.c -o xdp_dispatcher.o
clang -O2 -g -target bpf -I/usr/include/$(uname -m)-linux-gnu \
  -c tc_monitor.c      -o tc_monitor.o

echo "2) Mounting bpffs…"
sudo mkdir -p /sys/fs/bpf
sudo mount -t bpf bpf /sys/fs/bpf || true

echo "3) Creating veth pair & namespace…"
sudo ip netns add test-ns
sudo ip link add veth0 type veth peer name veth1
sudo ip link set veth1 netns test-ns
sudo ip addr add 192.168.1.1/24 dev veth0
sudo ip link set veth0 up
sudo ip netns exec test-ns ip addr add 192.168.1.2/24 dev veth1
sudo ip netns exec test-ns ip link set veth1 up
sudo ip netns exec test-ns ip link set lo up

echo "4) Attaching XDP dispatcher to veth0…"
sudo ip link set dev veth0 xdp obj xdp_dispatcher.o sec xdp

echo "5) Finding & populating cpumap (key=1→CPU1)…"
export MAP_ID=$(sudo bpftool map show \
  | grep 'cpumap.*cpu_map' \
  | tail -1 | cut -d: -f1)
echo "   MAP_ID=$MAP_ID"
sudo bpftool map pin id $MAP_ID /sys/fs/bpf/cpu_map
sudo bpftool map update id $MAP_ID \
     key   hex 01 00 00 00 \
     value hex 01 00 00 00 00 00 00 00

echo "6) Attaching TC monitor in namespace…"
sudo ip netns exec test-ns bash -c '
  tc qdisc del dev veth1 clsact 2>/dev/null || true
  tc qdisc add dev veth1 clsact
  tc filter add dev veth1 ingress prio 1 bpf \
     obj '"$PWD"'/tc_monitor.o sec classifier direct-action
'

echo "7) Clearing & tailing trace_pipe…"
sudo sh -c 'echo > /sys/kernel/debug/tracing/trace_pipe' || true
echo "→ Now in this terminal you’ll see TC MONITOR prints."
echo "→ In a 2nd terminal, run:"
echo "     sudo ip netns exec test-ns ping -I veth1 -c 5 192.168.1.1"
echo
sudo cat /sys/kernel/debug/tracing/trace_pipe
