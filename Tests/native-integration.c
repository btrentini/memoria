#include "MemoriaNative.h"
#include <arpa/inet.h>
#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/resource.h>
#include <sys/socket.h>
#include <sys/wait.h>
#include <time.h>
#include <pthread.h>
#include <unistd.h>

// Only a child created here is signalled. This tests collection, not the
// application's identity-bound action policy or privileged operations.
static void *burn_cpu(void *argument) {
    (void)argument;volatile uint64_t value=1;
    for (;;) value=value*1664525+1013904223;
    return NULL;
}
static uint64_t monotonic_ns(void) {
    struct timespec value={0};clock_gettime(CLOCK_MONOTONIC_RAW,&value);
    return (uint64_t)value.tv_sec*1000000000ULL+(uint64_t)value.tv_nsec;
}
int main(int argc,char **argv) {
    int workers=argc>1 ? atoi(argv[1]):1;
    if (workers<1 || workers>4) return 64;
    signal(SIGPIPE,SIG_IGN);
    int ready[2], go[2];
    if (pipe(ready) || pipe(go)) return 1;
    pid_t child=fork();
    if (child < 0) return 2;
    if (child == 0) {
        close(ready[0]); close(go[1]); alarm(8);
        int tcp=socket(AF_INET,SOCK_STREAM,0),udp=socket(AF_INET6,SOCK_DGRAM,0);
        struct sockaddr_in address={.sin_len=sizeof(address),.sin_family=AF_INET,.sin_port=0};
        inet_pton(AF_INET,"127.0.0.1",&address.sin_addr);
        struct sockaddr_in6 address6={.sin6_len=sizeof(address6),.sin6_family=AF_INET6,.sin6_port=0,.sin6_addr=IN6ADDR_LOOPBACK_INIT};
        int socket_error=tcp<0 || udp<0 || bind(tcp,(void*)&address,sizeof(address)) || listen(tcp,2) || bind(udp,(void*)&address6,sizeof(address6));
        socklen_t length=sizeof(address);
        if (!socket_error && getsockname(tcp,(void*)&address,&length)) socket_error=1;
        uint16_t port=socket_error ? 0:ntohs(address.sin_port);
        if (write(ready[1],&port,sizeof(port)) != sizeof(port)) _exit(5);
        char start;
        if (read(go[0],&start,1)!=1) _exit(6);
        size_t bytes=32*1024*1024;
        volatile unsigned char *memory=mmap(NULL,bytes,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANON,-1,0);
        if (memory==MAP_FAILED) _exit(7);
        for (size_t i=0;i<bytes;i+=4096) memory[i]=(unsigned char)(i/4096);
        pthread_t threads[3];
        for (int i=1;i<workers;i++) if (pthread_create(&threads[i-1],NULL,burn_cpu,NULL)) _exit(9);
        volatile unsigned long work=1;
        for (;;) {work=work*1664525+1013904223;memory[(work%8192)*4096]++;}
    }
    close(ready[1]); close(go[0]);
    uint16_t port=0;
    ssize_t received=read(ready[0],&port,sizeof(port));
    mm_process before,after;
    int before_error=mm_read_process(child,&before);
    uint64_t began=monotonic_ns();
    char start=1;
    if (write(go[1],&start,1)!=1) {int status=0;kill(child,SIGTERM);waitpid(child,&status,0);printf("Fixture setup unavailable: child status=%d, port_bytes=%zd, errno=%d\n",status,received,errno);return 8;}
    struct timespec delay={.tv_sec=1,.tv_nsec=100000000};
    while (nanosleep(&delay,&delay) != 0 && errno==EINTR) {}
    int after_error=mm_read_process(child,&after);
    uint64_t elapsed=monotonic_ns()-began;
    mm_socket endpoints[256];int denied=0;
    int count=mm_sockets(child,endpoints,256,&denied),tcp_found=0,udp6_found=0;
    for (int i=0;i<count;i++) {
        if (port>0 && endpoints[i].family==AF_INET && endpoints[i].transport==IPPROTO_TCP && endpoints[i].local_port==port) tcp_found=1;
        if (endpoints[i].family==AF_INET6 && endpoints[i].transport==IPPROTO_UDP && endpoints[i].local_port>0) udp6_found=1;
    }
    uint64_t cpu_before=before.user_ns+before.system_ns,cpu_after=after.user_ns+after.system_ns;
    double cpu_percent=elapsed>0 ? 100.0*(double)(cpu_after-cpu_before)/(double)elapsed:0;
    printf("workers=%d one_core_cpu_percent=%.2f elapsed_ns=%llu\n",workers,cpu_percent,(unsigned long long)elapsed);
    printf("child=%d port=%u before_error=%d after_error=%d cpu_delta_ns=%llu footprint_before=%llu footprint_after=%llu sockets=%d denied=%d tcp4=%d udp6=%d\n",
           child,port,before_error,after_error,(unsigned long long)(cpu_after-cpu_before),
           (unsigned long long)before.footprint_bytes,(unsigned long long)after.footprint_bytes,count,denied,tcp_found,udp6_found);
    if (port==0) puts("Socket fixture unavailable in session; CPU/memory verification remains independent. Socket acceptance is not a pass.");
    int signal_error=mm_send_signal(child,SIGTERM),status=0;
    waitpid(child,&status,0);
    struct rusage resource={0};
    int resource_error=getrusage(RUSAGE_CHILDREN,&resource);
    uint64_t independent_ns=(uint64_t)resource.ru_utime.tv_sec*1000000000ULL+(uint64_t)resource.ru_utime.tv_usec*1000ULL+
                            (uint64_t)resource.ru_stime.tv_sec*1000000000ULL+(uint64_t)resource.ru_stime.tv_usec*1000ULL;
    double ratio=independent_ns>cpu_before ? (double)(cpu_after-cpu_before)/(double)(independent_ns-cpu_before):0;
    printf("independent_getrusage_ns=%llu live_to_final_cpu_ratio=%.4f\n",(unsigned long long)independent_ns,ratio);
    close(ready[0]);close(go[1]);
    return received!=sizeof(port) || before_error || after_error || signal_error ||
        cpu_after<=cpu_before || (workers>1 && cpu_percent<=100) || resource_error || ratio<0.8 || ratio>1.05 || after.footprint_bytes<before.footprint_bytes+16*1024*1024 ||
        (port>0 && (!tcp_found || !udp6_found)) || !WIFSIGNALED(status) || WTERMSIG(status)!=SIGTERM;
}
