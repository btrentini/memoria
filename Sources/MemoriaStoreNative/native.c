#include "MemoriaStoreNative.h"
#include <mach/mach.h>
#include <mach/processor_info.h>
#include <mach/vm_statistics.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <net/if_dl.h>
#include <errno.h>
#include <string.h>

int ms_cpu_read(ms_cpu *cores, int capacity) {
    if (!cores || capacity <= 0) return -EINVAL;
    natural_t count=0; processor_info_array_t info=NULL; mach_msg_type_number_t size=0;
    mach_port_t host=mach_host_self();
    kern_return_t result=host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &count, &info, &size);
    mach_port_deallocate(mach_task_self(),host);
    if (result != KERN_SUCCESS) return -(int)result;
    if (count > (natural_t)capacity || size < count*CPU_STATE_MAX) {
        vm_deallocate(mach_task_self(),(vm_address_t)info,size*sizeof(integer_t)); return -EOVERFLOW;
    }
    for (natural_t i=0;i<count;i++) {
        cores[i].user=(uint32_t)info[i*CPU_STATE_MAX+CPU_STATE_USER];
        cores[i].system=(uint32_t)info[i*CPU_STATE_MAX+CPU_STATE_SYSTEM];
        cores[i].idle=(uint32_t)info[i*CPU_STATE_MAX+CPU_STATE_IDLE];
        cores[i].nice=(uint32_t)info[i*CPU_STATE_MAX+CPU_STATE_NICE];
    }
    vm_deallocate(mach_task_self(),(vm_address_t)info,size*sizeof(integer_t));
    return (int)count;
}
int ms_memory_read(ms_memory *memory) {
    if (!memory) return EINVAL;
    memset(memory,0,sizeof(*memory));
    vm_statistics64_data_t info={0}; mach_msg_type_number_t count=HOST_VM_INFO64_COUNT;
    mach_port_t host=mach_host_self(); vm_size_t page=0;
    kern_return_t result=host_page_size(host,&page);
    if (result == KERN_SUCCESS) result=host_statistics64(host,HOST_VM_INFO64,(host_info64_t)&info,&count);
    mach_port_deallocate(mach_task_self(),host);
    if (result != KERN_SUCCESS) return (int)result;
    memory->free_bytes=(uint64_t)info.free_count*page;
    memory->active=(uint64_t)info.active_count*page;
    memory->inactive=(uint64_t)info.inactive_count*page;
    memory->wired=(uint64_t)info.wire_count*page;
    memory->compressed=(uint64_t)info.compressor_page_count*page;
    return 0;
}
int ms_interfaces_read(ms_interface *interfaces, int capacity) {
    if (!interfaces || capacity <= 0) return -EINVAL;
    struct ifaddrs *list=NULL;
    if (getifaddrs(&list) != 0) return -(errno ? errno:EIO);
    int count=0;
    for (struct ifaddrs *p=list;p;p=p->ifa_next) {
        if (!p->ifa_addr || p->ifa_addr->sa_family != AF_LINK || !p->ifa_data) continue;
        if (count == capacity) {freeifaddrs(list);return -EOVERFLOW;}
        struct if_data *data=p->ifa_data;
        ms_interface *out=&interfaces[count++]; memset(out,0,sizeof(*out));
        strlcpy(out->name,p->ifa_name,sizeof(out->name));
        out->index=((struct sockaddr_dl *)p->ifa_addr)->sdl_index;
        out->flags=p->ifa_flags; out->received=data->ifi_ibytes; out->sent=data->ifi_obytes;
    }
    freeifaddrs(list); return count;
}
