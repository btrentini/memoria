#include "MemoriaNative.h"
#include <libproc.h>
#include <sys/proc_info.h>
#include <sys/resource.h>
#include <sys/sysctl.h>
#include <sys/stat.h>
#include <mach/mach.h>
#include <mach/host_info.h>
#include <mach/mach_host.h>
#include <mach/vm_statistics.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <net/if_dl.h>
#include <arpa/inet.h>
#include <errno.h>
#include <signal.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>
#include <sys/time.h>
#include <mach/mach_time.h>
#include <pthread.h>

static int failure(void) { return errno ? errno : EIO; }
static mach_timebase_info_data_t cpu_timebase;
static pthread_once_t cpu_timebase_once=PTHREAD_ONCE_INIT;
static void initialise_cpu_timebase(void) { (void)mach_timebase_info(&cpu_timebase); }
static int cpu_nanoseconds(uint64_t ticks, uint64_t *nanoseconds) {
    pthread_once(&cpu_timebase_once,initialise_cpu_timebase);
    if (cpu_timebase.denom==0 || cpu_timebase.numer==0) return EIO;
    __uint128_t value=(__uint128_t)ticks*cpu_timebase.numer/cpu_timebase.denom;
    if (value>UINT64_MAX) return EOVERFLOW;
    *nanoseconds=(uint64_t)value;return 0;
}

int mm_open_files(int32_t pid, mm_file *buffer, int capacity, int *denied, int *truncated) {
    if (pid <= 0 || capacity <= 0 || capacity > 512 || !denied || !truncated) return -EINVAL;
    *denied=0;*truncated=0;
    struct proc_fdinfo fds[4096];
    errno=0;
    int bytes=proc_pidinfo(pid,PROC_PIDLISTFDS,0,fds,sizeof(fds));
    if (bytes<=0) return bytes==0 && errno==0 ? 0:-failure();
    if (bytes >= (int)sizeof(fds)) *truncated=1;
    int found=0;
    for (int i=0;i<bytes/(int)sizeof(fds[0]);i++) {
        if (fds[i].proc_fdtype != PROX_FDTYPE_VNODE) continue;
        if (found>=capacity) {*truncated=1;break;}
        struct vnode_fdinfowithpath vnode={0};errno=0;
        if (proc_pidfdinfo(pid,fds[i].proc_fd,PROC_PIDFDVNODEPATHINFO,&vnode,sizeof(vnode)) != sizeof(vnode)) {(*denied)++;continue;}
        buffer[found].fd=fds[i].proc_fd;
        strlcpy(buffer[found].path,vnode.pvip.vip_path,sizeof(buffer[found].path));found++;
    }
    return found;
}

int mm_list_pids(int32_t *buffer, int capacity) {
    if (capacity <= 0 || capacity > 131072) return -EINVAL;
    errno = 0;
    int bytes = proc_listpids(PROC_ALL_PIDS, 0, buffer, capacity * (int)sizeof(int32_t));
    return bytes < 0 || (bytes == 0 && errno != 0) ? -failure() : bytes / (int)sizeof(int32_t);
}

int mm_read_process(int32_t pid, mm_process *out) {
    memset(out, 0, sizeof(*out)); out->pid = pid;
    if (pid <= 0) return EINVAL;
    struct proc_bsdinfo b = {0};
    errno = 0;
    if (proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &b, sizeof(b)) != sizeof(b)) {
        out->identity_error = failure(); return out->identity_error;
    }
    out->parent_pid = b.pbi_ppid; out->uid = b.pbi_uid; out->status = b.pbi_status;
    out->start_seconds = b.pbi_start_tvsec; out->start_microseconds = b.pbi_start_tvusec;
    strlcpy(out->name, b.pbi_name[0] ? b.pbi_name : b.pbi_comm, sizeof(out->name));
    errno = 0;
    if (proc_pidpath(pid, out->path, sizeof(out->path)) <= 0) out->path_error = failure();
    else {
        struct stat st;
        if (stat(out->path, &st) == 0) {
            out->executable_device = st.st_dev; out->executable_inode = st.st_ino;
        } else out->path_error = failure();
    }
    struct proc_taskinfo t = {0}; errno = 0;
    if (proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &t, sizeof(t)) == sizeof(t)) {
        // PROC_PIDTASKINFO CPU fields use Mach absolute ticks, not nanoseconds.
        // Apple XNU recount tests apply the same timebase conversion.
        out->task_error=cpu_nanoseconds(t.pti_total_user,&out->user_ns);
        if (!out->task_error) out->task_error=cpu_nanoseconds(t.pti_total_system,&out->system_ns);
        out->resident_bytes = t.pti_resident_size; out->threads = t.pti_threadnum;
    } else out->task_error = failure();
    struct rusage_info_v2 r = {0}; errno = 0;
    if (proc_pid_rusage(pid, RUSAGE_INFO_V2, (rusage_info_t *)&r) == 0) {
        out->footprint_bytes = r.ri_phys_footprint;
        out->disk_read_bytes = r.ri_diskio_bytesread; out->disk_write_bytes = r.ri_diskio_byteswritten;
    } else out->resource_error = failure();
    // A process may exit or its PID may be reused during the multi-call snapshot.
    struct proc_bsdinfo after = {0}; errno = 0;
    if (proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &after, sizeof(after)) != sizeof(after)) return failure();
    if (b.pbi_start_tvsec != after.pbi_start_tvsec || b.pbi_start_tvusec != after.pbi_start_tvusec) return ESTALE;
    return 0;
}

int mm_boot_session(char *buffer, size_t capacity) {
    if (!buffer || capacity < 2) return EINVAL;
    size_t size = capacity;
    if (sysctlbyname("kern.bootsessionuuid", buffer, &size, NULL, 0) == 0) { buffer[capacity-1] = 0; return 0; }
    // Public boot-time fallback. A wall-clock correction can conservatively invalidate identities,
    // but an estimated boot time or a process-local random token must never identify another boot.
    struct timeval boot = {0}; size = sizeof(boot);
    int mib[] = {CTL_KERN, KERN_BOOTTIME};
    if (sysctl(mib, 2, &boot, &size, NULL, 0) == 0 && boot.tv_sec > 0) {
        int length = snprintf(buffer, capacity, "boottime:%lld:%d", (long long)boot.tv_sec, boot.tv_usec);
        if (length > 0 && (size_t)length < capacity) return 0;
        buffer[0] = 0; return EOVERFLOW;
    }
    buffer[0] = 0; return failure();
}

int mm_cpu(mm_cpu_ticks *cores, int capacity) {
    natural_t count = 0; processor_info_array_t info = NULL; mach_msg_type_number_t size = 0;
    mach_port_t host = mach_host_self();
    kern_return_t kr = host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &count, &info, &size);
    mach_port_deallocate(mach_task_self(), host);
    if (kr != KERN_SUCCESS) return -(int)kr;
    int n = count < (natural_t)capacity ? (int)count : capacity;
    for (int i = 0; i < n; i++) {
        cores[i].user = (uint32_t)info[i*CPU_STATE_MAX+CPU_STATE_USER];
        cores[i].system = (uint32_t)info[i*CPU_STATE_MAX+CPU_STATE_SYSTEM];
        cores[i].idle = (uint32_t)info[i*CPU_STATE_MAX+CPU_STATE_IDLE];
        cores[i].nice = (uint32_t)info[i*CPU_STATE_MAX+CPU_STATE_NICE];
    }
    vm_deallocate(mach_task_self(), (vm_address_t)info, size * sizeof(integer_t));
    return n;
}

int mm_read_memory(mm_memory *m) {
    memset(m, 0, sizeof(*m));
    size_t size = sizeof(m->total);
    if (sysctlbyname("hw.memsize", &m->total, &size, NULL, 0) != 0) m->vm_error = failure();
    vm_statistics64_data_t v = {0}; mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
    mach_port_t host = mach_host_self(); vm_size_t page = 0;
    kern_return_t kr = host_page_size(host, &page);
    if (kr == KERN_SUCCESS) kr = host_statistics64(host, HOST_VM_INFO64, (host_info64_t)&v, &count);
    mach_port_deallocate(mach_task_self(), host);
    if (kr != KERN_SUCCESS) { m->vm_error = kr; return kr; }
    m->page_size = page;
    m->free_bytes = (uint64_t)v.free_count * page; m->active = (uint64_t)v.active_count * page;
    m->inactive = (uint64_t)v.inactive_count * page; m->wired = (uint64_t)v.wire_count * page;
    m->compressed = (uint64_t)v.compressor_page_count * page;
    m->purgeable = (uint64_t)v.purgeable_count * page; m->speculative = (uint64_t)v.speculative_count * page;
    m->pageins = v.pageins; m->pageouts = v.pageouts; m->swapins = v.swapins; m->swapouts = v.swapouts;
    struct xsw_usage swap = {0}; size = sizeof(swap);
    if (sysctlbyname("vm.swapusage", &swap, &size, NULL, 0) == 0) {
        m->swap_total = swap.xsu_total; m->swap_used = swap.xsu_used;
    } else m->swap_error = failure();
    return m->vm_error;
}

int mm_sockets(int32_t pid, mm_socket *buffer, int capacity, int *denied) {
    *denied = 0;
    errno = 0;
    int bytes = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, NULL, 0);
    if (bytes <= 0) return bytes == 0 && errno == 0 ? 0 : -failure();
    if (bytes > 4*1024*1024) return -EOVERFLOW;
    bytes += 32 * sizeof(struct proc_fdinfo);
    struct proc_fdinfo *fds = calloc(1, bytes);
    if (!fds) return -ENOMEM;
    int actual = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, fds, bytes), n = 0;
    if (actual <= 0) { int e = failure(); free(fds); return -e; }
    if (actual >= bytes) (*denied)++; // bounded/truncated scan, not complete coverage
    for (int i=0; i<actual/(int)sizeof(*fds); i++) {
        if (fds[i].proc_fdtype != PROX_FDTYPE_SOCKET) continue;
        if (n >= capacity) { (*denied)++; break; }
        struct socket_fdinfo s = {0}; errno = 0;
        if (proc_pidfdinfo(pid, fds[i].proc_fd, PROC_PIDFDSOCKETINFO, &s, sizeof(s)) != sizeof(s)) { (*denied)++; continue; }
        if (s.psi.soi_family != AF_INET && s.psi.soi_family != AF_INET6) continue;
        if (s.psi.soi_protocol != IPPROTO_TCP && s.psi.soi_protocol != IPPROTO_UDP) continue;
        struct in_sockinfo *in = s.psi.soi_kind == SOCKINFO_TCP ? &s.psi.soi_proto.pri_tcp.tcpsi_ini : &s.psi.soi_proto.pri_in;
        mm_socket *o = &buffer[n]; memset(o, 0, sizeof(*o));
        o->fd = fds[i].proc_fd; o->family = s.psi.soi_family; o->transport = s.psi.soi_protocol;
        o->state = s.psi.soi_kind == SOCKINFO_TCP ? s.psi.soi_proto.pri_tcp.tcpsi_state : -1;
        o->local_port = ntohs((uint16_t)in->insi_lport); o->remote_port = ntohs((uint16_t)in->insi_fport);
        const void *la = o->family == AF_INET ? (void *)&in->insi_laddr.ina_46.i46a_addr4 : (void *)&in->insi_laddr.ina_6;
        const void *ra = o->family == AF_INET ? (void *)&in->insi_faddr.ina_46.i46a_addr4 : (void *)&in->insi_faddr.ina_6;
        if (!inet_ntop(o->family, la, o->local_address, sizeof(o->local_address)) ||
            !inet_ntop(o->family, ra, o->remote_address, sizeof(o->remote_address))) { (*denied)++; continue; }
        n++;
    }
    free(fds); return n;
}

int mm_interfaces(mm_interface *buffer, int capacity) {
    struct ifaddrs *list = NULL; if (getifaddrs(&list) != 0) return -failure();
    int n = 0;
    for (struct ifaddrs *p = list; p && n < capacity; p = p->ifa_next) {
        if (!p->ifa_addr || p->ifa_addr->sa_family != AF_LINK || !p->ifa_data) continue;
        struct if_data *d = p->ifa_data; mm_interface *o = &buffer[n++]; memset(o, 0, sizeof(*o));
        strlcpy(o->name, p->ifa_name, sizeof(o->name)); o->index = if_nametoindex(p->ifa_name);
        o->flags = p->ifa_flags; o->type = d->ifi_type; o->received = d->ifi_ibytes; o->sent = d->ifi_obytes;
    }
    freeifaddrs(list); return n;
}

int mm_send_signal(int32_t pid, int signal_number) {
    if (pid <= 1 || pid == getpid() || (signal_number != SIGTERM && signal_number != SIGKILL)) return EINVAL;
    if (kill(pid, signal_number) == 0) return 0;
    return errno;
}

int mm_arguments(int32_t pid, char *buffer, size_t capacity) {
    if (pid <= 0 || capacity > 262144) return -EINVAL;
    int mib[] = {CTL_KERN, KERN_PROCARGS2, pid}; size_t size = capacity;
    if (sysctl(mib, 3, buffer, &size, NULL, 0) != 0) return -failure();
    return (int)size;
}
