#ifndef MEMORIA_NATIVE_H
#define MEMORIA_NATIVE_H
#include <stdint.h>
#include <stddef.h>

typedef struct {
    int32_t pid, parent_pid;
    uint32_t uid, status, threads;
    uint64_t start_seconds, start_microseconds, user_ns, system_ns;
    uint64_t resident_bytes, footprint_bytes, disk_read_bytes, disk_write_bytes;
    uint64_t executable_device, executable_inode;
    int identity_error, task_error, resource_error, path_error;
    char name[256], path[4096];
} mm_process;
typedef struct { uint64_t user, system, idle, nice; } mm_cpu_ticks;
typedef struct {
    uint64_t total, free_bytes, active, inactive, wired, compressed, purgeable, speculative;
    uint64_t pageins, pageouts, swapins, swapouts, swap_total, swap_used;
    uint64_t page_size;
    int vm_error, swap_error;
} mm_memory;
typedef struct {
    int32_t fd, family, transport, state;
    uint16_t local_port, remote_port;
    char local_address[64], remote_address[64];
} mm_socket;
typedef struct {
    char name[64];
    uint32_t index, flags, type;
    uint64_t received, sent;
} mm_interface;
typedef struct { int32_t fd; char path[4096]; } mm_file;

int mm_list_pids(int32_t *buffer, int capacity);
int mm_read_process(int32_t pid, mm_process *result);
int mm_boot_session(char *buffer, size_t capacity);
int mm_cpu(mm_cpu_ticks *cores, int capacity);
int mm_read_memory(mm_memory *result);
int mm_sockets(int32_t pid, mm_socket *buffer, int capacity, int *denied);
int mm_interfaces(mm_interface *buffer, int capacity);
int mm_send_signal(int32_t pid, int signal_number);
int mm_arguments(int32_t pid, char *buffer, size_t capacity);
int mm_open_files(int32_t pid, mm_file *buffer, int capacity, int *denied, int *truncated);
#endif
