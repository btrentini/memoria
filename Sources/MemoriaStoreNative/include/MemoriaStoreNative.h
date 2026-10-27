#ifndef MEMORIA_STORE_NATIVE_H
#define MEMORIA_STORE_NATIVE_H
#include <stdint.h>
typedef struct { uint64_t user, system, idle, nice; } ms_cpu;
typedef struct { uint64_t free_bytes, active, inactive, wired, compressed; } ms_memory;
typedef struct { char name[64]; uint32_t index, flags; uint64_t received, sent; } ms_interface;
int ms_cpu_read(ms_cpu *cores, int capacity);
int ms_memory_read(ms_memory *memory);
int ms_interfaces_read(ms_interface *interfaces, int capacity);
#endif
