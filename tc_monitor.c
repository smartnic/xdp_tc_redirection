#include <linux/bpf.h>
#include <bpf/bpf_helpers.h>
#include <linux/pkt_cls.h>
#include <linux/if_ether.h>
#include <linux/ip.h>
#include <netinet/in.h> 
#include <bpf/bpf_endian.h>

// This classifier runs on ingress and logs CPU + packet length
SEC("classifier")
int tc_cpu_monitor(struct __sk_buff *skb) {
    // which CPU is running this?
    __u32 cpu = bpf_get_smp_processor_id();
    // log the CPU and packet length
    bpf_printk("TC MONITOR: cpu=%d len=%d\n", cpu, skb->len);
    // let the packet continue through the stack
    return TC_ACT_OK;
}

char LICENSE[] SEC("license") = "GPL";
