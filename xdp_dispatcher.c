#include <linux/bpf.h>
#include <bpf/bpf_helpers.h>

struct {
    __uint(type, BPF_MAP_TYPE_CPUMAP);
    __uint(key_size, sizeof(__u32));
    __uint(value_size, sizeof(struct bpf_cpumap_val));
    __uint(max_entries, 4);
} cpu_map SEC(".maps");
//Most of this code is commented out for now, but it's left here as a reminder as to how to append data to a packet (use bpf_xdp_adjust_tail to adjust packet end)
//Reminder that if you adjust the packet's head, it will not be able to be processed properly by the system unless you have a tc hook/some other program to intercept and remove that head.
//Target_cpu can be programatically changed depending on the core you wish to send to.
SEC("xdp")
int xdp_prepend_and_redirect(struct xdp_md *ctx) {
    /*
    const int N = sizeof(__u32);  // how many bytes to insert
    void *data, *data_end;

    // 1) make room at the front
    if (bpf_xdp_adjust_head(ctx, -N) < 0)
        return XDP_ABORTED;

    // 2) reload pointers
    data     = (void *)(long)ctx->data;
    data_end = (void *)(long)ctx->data_end;

    // 3) bounds-check your new header area
    if (data + N > data_end)
        return XDP_ABORTED;

    // 4) write your header (here: 0xDEADBEEF)
    *(__u32 *)data = 0xDEADBEEF;
    */
   
    //can change depending on what CPU you want to send to
    __u32 target_cpu = 1;
    // 5) send the packet to CPU core 0 (or replace with any valid core ID)
    return bpf_redirect_map(&cpu_map, target_cpu, 0);
}

char _license[] SEC("license") = "GPL";
