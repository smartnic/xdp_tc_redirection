#include <linux/bpf.h>
#include <bpf/bpf_helpers.h>
#include <linux/pkt_cls.h>
#include <linux/if_ether.h>
#include <linux/ip.h>
#include <netinet/in.h> 
#include <bpf/bpf_endian.h>

struct {
    __uint(type, BPF_MAP_TYPE_ARRAY);
    __uint(max_entries, 1);
    __type(key, __u32);
    __type(value, __u32);
    __uint(pinning, LIBBPF_PIN_BY_NAME);
} out_ifindex SEC(".maps");

SEC("tc")
int redirect_if(struct __sk_buff *skb) {
    __u32 key = 0;
    __u32 *ifidx = bpf_map_lookup_elem(&out_ifindex, &key);
    
    if (!ifidx) {
        return TC_ACT_OK;
    }

    // Parse Ethernet header
    void *data = (void *)(long)skb->data;
    void *data_end = (void *)(long)skb->data_end;
    
    struct ethhdr *eth = data;
    if (data + sizeof(*eth) > data_end) {
        return TC_ACT_OK;
    }

    // Filter IPv4 traffic only
    if (eth->h_proto != bpf_htons(ETH_P_IP)) {
        return TC_ACT_OK;
    }

    // Parse IP header
    struct iphdr *ip = data + sizeof(*eth);
    if (data + sizeof(*eth) + sizeof(*ip) > data_end) {
        return TC_ACT_OK;
    }

    // Filter ICMP traffic only
    if (ip->protocol != IPPROTO_ICMP) {
        return TC_ACT_OK;
    }

    // Redirect to egress path of target interface
    bpf_printk("Redirecting to ifindex %d", *ifidx);
    return bpf_redirect(*ifidx, 0);
}

char __license[] SEC("license") = "GPL";
