#include "types.h"
#include "cfg/cfg.h"

#if HOST_OS==OS_LINUX || HOST_OS == OS_DARWIN
#if HOST_OS == OS_DARWIN
	#define _XOPEN_SOURCE 1
	#define __USE_GNU 1
	#include <TargetConditionals.h>
#endif
#if !defined(TARGET_NACL32)
#include <poll.h>
#include <termios.h>
#endif  
//#include <curses.h>
#include <fcntl.h>
#include <semaphore.h>
#include <stdarg.h>
#include <signal.h>
#include <sys/param.h>
#include <sys/mman.h>
#include <sys/time.h>
#if !defined(TARGET_BSD) && !defined(_ANDROID) && !defined(TARGET_IPHONE) && !defined(TARGET_NACL32) && !defined(TARGET_EMSCRIPTEN) && !defined(TARGET_OSX) && !defined(TARGET_IPHONE_SIMULATOR)
  #include <sys/personality.h>
  #include <dlfcn.h>
#endif
#include <unistd.h>
#include "hw/sh4/dyna/blockmanager.h"

#include "linux/context.h"

#include "hw/sh4/dyna/ngen.h"

#if !defined(TARGET_NO_EXCEPTIONS)
bool ngen_Rewrite(unat& addr,unat retadr,unat acc);
u32* ngen_readm_fail_v2(u32* ptr,u32* regs,u32 saddr);
bool VramLockedWrite(u8* address);
bool BM_LockedWrite(u8* address);

#if HOST_OS == OS_DARWIN
void sigill_handler(int sn, siginfo_t * si, void *segfault_ctx) {
	
    rei_host_context_t ctx;
    
    context_from_segfault(&ctx, segfault_ctx);

	unat pc = (unat)ctx.pc;

#if FEAT_SHREC == DYNAREC_JIT
	bool dyna_cde = (pc>(unat)CodeCache) && (pc<(unat)(CodeCache + CODE_SIZE));
	printf("SIGILL @ %08X, fault_handler+0x%08X ... %08X -> was not in vram, %d\n", pc, pc - (unat)sigill_handler, (unat)si->si_addr, dyna_cde);
#endif

	printf("Entering infiniloop");

	for (;;);
	printf("PC is used here %08X\n", pc);
}
#endif

#if !defined(TARGET_NO_EXCEPTIONS)
void fault_handler (int sn, siginfo_t * si, void *segfault_ctx)
{
	rei_host_context_t ctx;

	context_from_segfault(&ctx, segfault_ctx);

	if (VramLockedWrite((u8*)si->si_addr) || BM_LockedWrite((u8*)si->si_addr))
		return;
	#if FEAT_SHREC == DYNAREC_JIT
	bool dyna_cde = ((unat)ctx.pc>(unat)CodeCache) && ((unat)ctx.pc<(unat)(CodeCache + CODE_SIZE));

	//ucontext_t* ctx=(ucontext_t*)ctxr;
	//printf("mprot hit @ ptr 0x%08X @@ code: %08X, %d\n",si->si_addr,ctx->uc_mcontext.arm_pc,dyna_cde);


	#if HOST_CPU==CPU_ARM
	if (dyna_cde) {
		ctx.pc = (u32)ngen_readm_fail_v2((u32*)ctx.pc, ctx.r, (unat)si->si_addr);

		context_to_segfault(&ctx, segfault_ctx);
	} else
	#elif HOST_CPU==CPU_X86
	if (ngen_Rewrite((unat&)ctx.pc, *(unat*)ctx.esp, ctx.eax)) {
		//remove the call from call stack
		ctx.esp += 4;
		//restore the addr from eax to ecx so it's valid again
		ctx.ecx = ctx.eax;

		context_to_segfault(&ctx, segfault_ctx);
	} else
	#elif HOST_CPU == CPU_X64
	//x64 has no rewrite support
	#else
	#error JIT: Not supported arch
	#endif
	#endif
	#if HOST_CPU==CPU_ARM || HOST_CPU==CPU_X86
	{
	#endif
		printf("SIGSEGV @ %p (fault_handler+0x%p) ... %p -> was not in vram\n", ctx.pc, ctx.pc - (unat)fault_handler, si->si_addr);
		die("segfault");
		signal(SIGSEGV, SIG_DFL);
	#if HOST_CPU==CPU_ARM || HOST_CPU==CPU_X86
	}
	#endif
}
#endif

#endif
void install_fault_handler (void)
{
#if !defined(TARGET_NO_EXCEPTIONS)
	struct sigaction act, segv_oact;
	memset(&act, 0, sizeof(act));
	act.sa_sigaction = fault_handler;
	sigemptyset(&act.sa_mask);
	act.sa_flags = SA_SIGINFO;
	sigaction(SIGSEGV, &act, &segv_oact);
#if HOST_OS == OS_DARWIN
    //this is broken on osx/ios/mach in general
    sigaction(SIGBUS, &act, &segv_oact);
    
    act.sa_sigaction = sigill_handler;
    sigaction(SIGILL, &act, &segv_oact);
#endif
#endif
}

#if !defined(TARGET_NO_THREADS)

//Thread class
cThread::cThread(ThreadEntryFP* function,void* prm)
{
	Entry=function;
	param=prm;
}

void cThread::Start()
{
		pthread_create( (pthread_t*)&hThread, NULL, Entry, param);
}

void cThread::WaitToEnd()
{
	pthread_join((pthread_t)hThread,0);
}

//End thread class
#endif

//cResetEvent Calss
cResetEvent::cResetEvent(bool State,bool Auto)
{
	//sem_init((sem_t*)hEvent, 0, State?1:0);
	verify(State==false&&Auto==true);
	pthread_mutex_init(&mutx, NULL);
	pthread_cond_init(&cond, NULL);
}
cResetEvent::~cResetEvent()
{
	//Destroy the event object ?

}
void cResetEvent::Set()//Signal
{
	pthread_mutex_lock( &mutx );
	state=true;
    pthread_cond_signal( &cond);
	pthread_mutex_unlock( &mutx );
}
void cResetEvent::Reset()//reset
{
	pthread_mutex_lock( &mutx );
	state=false;
	pthread_mutex_unlock( &mutx );
}
void cResetEvent::Wait(u32 msec)//Wait for signal , then reset
{
	verify(false);
}
void cResetEvent::Wait()//Wait for signal , then reset
{
	pthread_mutex_lock( &mutx );
	if (!state)
	{
		pthread_cond_wait( &cond, &mutx );
	}
	state=false;
	pthread_mutex_unlock( &mutx );
}

//End AutoResetEvent

#include <errno.h>

void VArray2::LockRegion(u32 offset,u32 size)
{
	#if !defined(TARGET_NO_EXCEPTIONS)
	u32 inpage=offset & PAGE_MASK;
	u32 rv=mprotect (data+offset-inpage, size+inpage, PROT_READ );
	if (rv!=0)
	{
		printf("mprotect(%8s,%08X,R) failed: %d | %d\n",data+offset-inpage,size+inpage,rv,errno);
		die("mprotect  failed ..\n");
	}

	#else
//		printf("VA2: LockRegion\n");
	#endif
}

void print_mem_addr()
{
    FILE *ifp, *ofp;

    char outputFilename[] = "/data/data/com.reicast.emulator/files/mem_alloc.txt";

    ifp = fopen("/proc/self/maps", "r");

    if (ifp == NULL) {
        fprintf(stderr, "Can't open input file /proc/self/maps!\n");
        exit(1);
    }

    ofp = fopen(outputFilename, "w");

    if (ofp == NULL) {
        fprintf(stderr, "Can't open output file %s!\n",
                outputFilename);
#if HOST_OS == OS_LINUX
        ofp = stderr;
#else
        exit(1);
#endif
    }

    char line [ 512 ];
    while (fgets(line, sizeof line, ifp) != NULL) {
        fprintf(ofp, "%s", line);
    }

    fclose(ifp);
    if (ofp != stderr)
        fclose(ofp);
}

void VArray2::UnLockRegion(u32 offset,u32 size)
{
	#if !defined(TARGET_NO_EXCEPTIONS)
	u32 inpage=offset & PAGE_MASK;
	u32 rv=mprotect (data+offset-inpage, size+inpage, PROT_READ | PROT_WRITE);
	if (rv!=0)
	{
        print_mem_addr();
		printf("mprotect(%8p,%08X,RW) failed: %d | %d\n",data+offset-inpage,size+inpage,rv,errno);
		die("mprotect  failed ..\n");
	}
	#else
//		printf("VA2: UnLockRegion\n");
	#endif
}
double os_GetSeconds()
{
	timeval a;
	gettimeofday (&a,0);
	static u64 tvs_base=a.tv_sec;
	return a.tv_sec-tvs_base+a.tv_usec/1000000.0;
}

#if TARGET_IPHONE && (HOST_CPU == CPU_ARM)
void os_DebugBreak() {
//    __asm__("trap");
}
#elif HOST_OS != OS_LINUX
void os_DebugBreak()
{
	__builtin_trap();
}
#endif

void enable_runfast()
{
	#if HOST_CPU==CPU_ARM && !defined(ARMCC) && !defined(TARGET_IPHONE) && !defined(TARGET_IPHONE_SIMULATOR)
	static const unsigned int x = 0x04086060;
	static const unsigned int y = 0x03000000;
	int r;
	asm volatile (
		"fmrx	%0, fpscr			\n\t"	//r0 = FPSCR
		"and	%0, %0, %1			\n\t"	//r0 = r0 & 0x04086060
		"orr	%0, %0, %2			\n\t"	//r0 = r0 | 0x03000000
		"fmxr	fpscr, %0			\n\t"	//FPSCR = r0
		: "=r"(r)
		: "r"(x), "r"(y)
	);

	printf("ARM VFP-Run Fast (NFP) enabled !\n");
	#endif
}

void linux_fix_personality() {
        #if HOST_OS == OS_LINUX && !defined(_ANDROID) && !defined(TARGET_OS_MAC) && !defined(TARGET_IPHONE) && !defined(TARGET_IPHONE_SIMULATOR) && !defined(TARGET_NACL32) && !defined(TARGET_EMSCRIPTEN)
          printf("Personality: %08X\n", personality(0xFFFFFFFF));
          personality(~READ_IMPLIES_EXEC & personality(0xFFFFFFFF));
          printf("Updated personality: %08X\n", personality(0xFFFFFFFF));
        #endif
}

void linux_rpi2_init() {
#if !defined(TARGET_BSD) && !defined(_ANDROID) && !defined(TARGET_NACL32) && !defined(TARGET_EMSCRIPTEN) && defined(TARGET_VIDEOCORE)
	void* handle;
	void (*rpi_bcm_init)(void);

	handle = dlopen("libbcm_host.so", RTLD_LAZY);
	
	if (handle) {
		printf("found libbcm_host\n");
		*(void**) (&rpi_bcm_init) = dlsym(handle, "bcm_host_init");
		if (rpi_bcm_init) {
			printf("rpi2: bcm_init\n");
			rpi_bcm_init();
		}
	}
#endif
}

void common_linux_setup()
{
	linux_fix_personality();
	linux_rpi2_init();

	enable_runfast();
	install_fault_handler();
//	signal(SIGINT, exit);

	settings.profile.run_counts=0;
	
	printf("Linux paging: %ld %08X %08X\n",sysconf(_SC_PAGESIZE),PAGE_SIZE,PAGE_MASK);
	verify(PAGE_MASK==(sysconf(_SC_PAGESIZE)-1));
}
#endif
