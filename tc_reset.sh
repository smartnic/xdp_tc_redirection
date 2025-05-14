#!/bin/bash

#Run this after doing the tests in tc_instructions.txt
set -e

# 1) Detach any TC filters
sudo ip netns exec test-ns tc qdisc del dev veth1 clsact 2>/dev/null || true
sudo tc           qdisc del dev veth0 clsact       2>/dev/null || true
sudo tc           qdisc del dev veth0 root         2>/dev/null || true

# 2) Delete the namespace & veth pair
sudo ip netns del test-ns                          2>/dev/null || true
sudo ip link    del veth0                          2>/dev/null || true

# 3) Unpin & delete any maps in bpffs, then unmount
if mountpoint -q /sys/fs/bpf; then
  sudo find /sys/fs/bpf -maxdepth 1 -type f -exec rm -f {} \;
  sudo umount /sys/fs/bpf
else
  sudo rm -rf /sys/fs/bpf/*
fi

echo "✔️ Clean slate complete."
