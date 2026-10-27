#include "MemoriaNative.h"
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <signal.h>

int main(void) {
    mm_cpu_ticks cores[256];
    int count = mm_cpu(cores,256);
    mm_memory memory;
    int memory_error = mm_read_memory(&memory);
    mm_process self;
    int self_error = mm_read_process(getpid(),&self);
    char boot[128];
    int boot_error = mm_boot_session(boot,sizeof(boot));
    printf("cpu_cores=%d memory_error=%d memory_bytes=%llu self_error=%d boot_error=%d\n",
           count,memory_error,(unsigned long long)memory.total,self_error,boot_error);
    if (count <= 0 || memory_error || self_error) {
        puts("Basic native provider acceptance failed.");
        return 2;
    }
    if (boot_error) puts("Boot identity unavailable in this environment; application actions must remain disabled.");
    pid_t child = fork();
    if (child == 0) {sleep(10);_exit(0);}
    if (child < 0) return 3;
    usleep(50000);
    mm_process target;
    int error = mm_read_process(child,&target);
    int signal_error = mm_send_signal(child,SIGTERM);
    int status=0;
    waitpid(child,&status,0);
    printf("child_inspection_error=%d signal_error=%d exit_signal=%d\n",error,signal_error,WTERMSIG(status));
    return error || signal_error || !WIFSIGNALED(status) || WTERMSIG(status) != SIGTERM;
}
