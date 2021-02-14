
#include "3ds_utils.h"

typedef int (*ctr_callback_type)(void);

int srvGetServiceHandle(unsigned int* out, const char* name);
int svcCloseHandle(unsigned int handle);
int svcBackdoor(ctr_callback_type);


static void ctr_enable_all_svc_kernel(void)
{
   __asm__ volatile("cpsid aif");

   unsigned int*  svc_access_control = *(*(unsigned int***)0xFFFF9000 + 0x22) - 0x6;

   svc_access_control[0]=0xFFFFFFFE;
   svc_access_control[1]=0xFFFFFFFF;
   svc_access_control[2]=0xFFFFFFFF;
   svc_access_control[3]=0x3FFFFFFF;
}

static void ctr_enable_all_svc(void)
{
   svcBackdoor((ctr_callback_type)ctr_enable_all_svc_kernel);
}

static void ctr_clean_invalidate_kernel(void)
{
   __asm__ volatile(
      "mrs r1, cpsr\n"
      "cpsid aif\n"                  // disable interrupts
      "mov r0, #0\n"
      "mcr p15, 0, r0, c7, c10, 0\n" // clean dcache
      "mcr p15, 0, r0, c7, c10, 4\n" // DSB
      "mcr p15, 0, r0, c7, c5, 0\n"  // invalidate icache+BTAC
      "msr cpsr_cx, r1\n"            // restore interrupts
      ::: "r0", "r1");
}

void ctr_flush_invalidate_cache(void)
{
//   __asm__ volatile("svc 0x2E\n\t");
//   __asm__ volatile("svc 0x4B\n\t");
   svcBackdoor((ctr_callback_type)ctr_clean_invalidate_kernel);
}

int ctr_svchack_init(void)
{
   extern unsigned int __service_ptr;

   if(__service_ptr)
      return 0;

   /* CFW */
   ctr_enable_all_svc();
   return 1;
}

