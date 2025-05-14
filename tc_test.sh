#!/usr/bin/env bash
set -euo pipefail


# 1) Clean slate
sudo ip netns exec test-ns tc qdisc del dev veth1 clsact 2>/dev/null || true
sudo tc           qdisc del dev veth0 clsact       2>/dev/null || true
sudo tc           qdisc del dev veth0 root         2>/dev/null || true
sudo ip netns del test-ns                          2>/dev/null || true
sudo ip link    del veth0                          2>/dev/null || true
sudo rm -f /sys/fs/bpf/out_ifindex                 2>/dev/null || true
sudo umount /sys/fs/bpf                            2>/dev/null || true

echo "✔️  Clean slate complete."

# 2) Dependency check
./check-ebpf-deps.sh

echo "✔️  Dependencies OK."

# 3) Compile
clang -O2 -g -target bpf -I/usr/include/x86_64-linux-gnu \
      -c tc_redirect.c -o tc_redirect.o

echo "✔️  Compiled tc_redirect.o."

# 4) Setup network namespace & veth pair
sudo ip netns add test-ns
sudo ip link add veth0 type veth peer name veth1
sudo ip link set veth1 netns test-ns

echo "✔️  Created namespace test-ns and veth0<->veth1."

# 5) Configure IPs
sudo ip addr add 192.168.1.1/24 dev veth0
sudo ip link set veth0 up
sudo ip netns exec test-ns ip link set lo up
sudo ip netns exec test-ns ip addr add 192.168.1.2/24 dev veth1
sudo ip netns exec test-ns ip link set veth1 up

echo "✔️  Configured IPs on veth0 and veth1."

# 6) Store interface index of veth0
export VETH0_IFINDEX=$(ip -o link show dev veth0 | awk '{print $1}' | tr -d ':')
echo "✔️  veth0 ifindex = $VETH0_IFINDEX"

# 7) Attach TC BPF program on veth1 (ingress)
sudo ip netns exec test-ns tc qdisc replace dev veth1 clsact
sudo ip netns exec test-ns tc filter replace dev veth1 ingress bpf da \
     obj tc_redirect.o sec tc

echo "✔️  Attached TC BPF program to veth1 ingress."

# 8) Mount bpffs, pin and update map
sudo mkdir -p /sys/fs/bpf
sudo mount -t bpf bpf /sys/fs/bpf
map_id=$(sudo bpftool map show | awk '/out_ifindex/ { id=$1 } END { print id }' | tr -d ':')
sudo bpftool map pin id "$map_id" /sys/fs/bpf/out_ifindex
sudo bpftool map update pinned /sys/fs/bpf/out_ifindex \
    key hex 00 00 00 00 \
    value hex $(printf "%02x 00 00 00" "$VETH0_IFINDEX")

echo "✔️  Pinned and populated out_ifindex map."

# 9) Reminders for user
cat << EOF

▶️  Now open two other terminals before proceeding:

   Terminal A (namespace):
     sudo ip netns exec test-ns tcpdump -i veth1 -n icmp

   Terminal B (ping source):
     ping -I veth0 192.168.1.2 -c 5

▶️  This terminal will now start tcpdump on veth0 (you should see ICMP packets received here):
EOF

# 10) Start tcpdump on veth0
sudo tcpdump -i veth0 -n icmp
