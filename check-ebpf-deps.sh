#!/bin/bash

#shell script to check system dependencies which we'll need to run our programs.
deps=(
  "clang --version"
  "llvm-config --version"
  "bpftool version"
  "readelf --version"
  "gcc --version"
  "make --version"
  "iperf3 --version"
  "hping3 --version"
  "python3 -c \"import scapy; print(scapy.__version__)\""
  "which perf"
  "which trace-cmd"
)

for cmd in "${deps[@]}"; do
  echo "---- $cmd ----"
  eval $cmd &>/dev/null && echo "✓ OK" || echo "✗ missing"
  echo
done

echo "Kernel headers:"
ls /lib/modules/$(uname -r)/build &>/dev/null && echo "✓ OK" || echo "✗ install linux-headers-$(uname -r)"

echo
echo "Debugfs/pktgen:"
mount | grep debugfs &>/dev/null \
  && echo "debugfs mounted" \
  || echo "✗ mount it: sudo mount -t debugfs debugfs /sys/kernel/debug"
