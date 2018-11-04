#include "context.h"

#if defined(_ANDROID)
	#include <asm/sigcontext.h>
#else
	#if HOST_OS == OS_DARWIN
		#define _XOPEN_SOURCE 1
		#define __USE_GNU 1
	#endif

  #if !defined(TARGET_NO_EXCEPTIONS)
    #include <ucontext.h>
  #endif
#endif


//////

#define MCTX(p) (((ucontext_t *)(segfault_ctx))->uc_mcontext p)
template <typename Ta, typename Tb>
void bicopy(Ta& rei, Tb& seg, bool to_segfault) {
	if (to_segfault) {
		seg = rei;
	}
	else {
		rei = seg;
	}
}

void context_segfault(rei_host_context_t* reictx, void* segfault_ctx, bool to_segfault) {

#if !defined(TARGET_NO_EXCEPTIONS)
#if HOST_CPU == CPU_ARM
	#if defined(__FreeBSD__)
		bicopy(reictx->pc, MCTX(.__gregs[_REG_PC]), to_segfault);

		for (int i = 0; i < 15; i++)
			bicopy(reictx->r[i], MCTX(.__gregs[i]), to_segfault);
	#elif HOST_OS == OS_LINUX
		bicopy(reictx->pc, MCTX(.arm_pc), to_segfault);
		u32* r =(u32*) &MCTX(.arm_r0);

		for (int i = 0; i < 15; i++)
			bicopy(reictx->r[i], r[i], to_segfault);

	#elif HOST_OS == OS_DARWIN
		bicopy(reictx->pc, MCTX(->__ss.__pc), to_segfault);

		for (int i = 0; i < 15; i++)
			bicopy(reictx->r[i], MCTX(->__ss.__r[i]), to_segfault);
	#else
		#error HOST_OS
	#endif
#elif HOST_CPU == CPU_X86
	#if defined(__FreeBSD__)
		bicopy(reictx->pc, MCTX(.mc_eip), to_segfault);
		bicopy(reictx->esp, MCTX(.mc_esp), to_segfault);
		bicopy(reictx->eax, MCTX(.mc_eax), to_segfault);
		bicopy(reictx->ecx, MCTX(.mc_ecx), to_segfault);
	#elif HOST_OS == OS_LINUX
		bicopy(reictx->pc, MCTX(.gregs[REG_EIP]), to_segfault);
		bicopy(reictx->esp, MCTX(.gregs[REG_ESP]), to_segfault);
		bicopy(reictx->eax, MCTX(.gregs[REG_EAX]), to_segfault);
		bicopy(reictx->ecx, MCTX(.gregs[REG_ECX]), to_segfault);
	#elif HOST_OS == OS_DARWIN
		bicopy(reictx->pc, MCTX(->__ss.__eip), to_segfault);
		bicopy(reictx->esp, MCTX(->__ss.__esp), to_segfault);
		bicopy(reictx->eax, MCTX(->__ss.__eax), to_segfault);
		bicopy(reictx->ecx, MCTX(->__ss.__ecx), to_segfault);
	#else
		#error HOST_OS
	#endif
#elif HOST_CPU == CPU_X64
	#if defined(__FreeBSD__) || defined(__DragonFly__)
		bicopy(reictx->pc, MCTX(.mc_rip), to_segfault);
	#elif defined(__NetBSD__)
		bicopy(reictx->pc, MCTX(.__gregs[_REG_RIP]), to_segfault);
	#elif HOST_OS == OS_LINUX
		bicopy(reictx->pc, MCTX(.gregs[REG_RIP]), to_segfault);
	#else
		#error HOST_OS
	#endif
#elif HOST_CPU == CPU_MIPS
	bicopy(reictx->pc, MCTX(.pc), to_segfault);
#elif HOST_CPU == CPU_GENERIC
    //nothing!
#else
	#error Unsupported HOST_CPU
#endif
	#endif
	
}

void context_from_segfault(rei_host_context_t* reictx, void* segfault_ctx) {
	context_segfault(reictx, segfault_ctx, false);
}

void context_to_segfault(rei_host_context_t* reictx, void* segfault_ctx) {
	context_segfault(reictx, segfault_ctx, true);
}
