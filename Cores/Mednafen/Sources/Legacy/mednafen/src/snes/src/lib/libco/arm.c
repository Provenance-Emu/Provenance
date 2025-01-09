/*
  libco.arm (2015-06-18)
  author: byuu
  license: public domain
*/

#define LIBCO_C
#include "libco.h"

#include <assert.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

static thread_local unsigned long co_active_buffer[64];
static thread_local cothread_t co_active_handle = 0;
static void (*co_swap)(cothread_t, cothread_t) = 0;

force_text_section static const unsigned long co_swap_function[] = {
  0xe8a16ff0,  /* stmia r1!, {r4-r11,sp,lr} */
  0xe8b0aff0,  /* ldmia r0!, {r4-r11,sp,pc} */
  0xe12fff1e,  /* bx lr                     */
};

void co_init() {
}

cothread_t co_active() {
  if(!co_active_handle) co_active_handle = &co_active_buffer;
  return co_active_handle;
}

cothread_t co_create(unsigned int size, void (*entrypoint)(void)) {
  unsigned long* handle = 0;
  if(!co_swap) {
    co_init();
    co_swap = (void (*)(cothread_t, cothread_t))co_swap_function;
  }
  if(!co_active_handle) co_active_handle = &co_active_buffer;
  size += 256;
  size &= ~15;

  if(handle = (unsigned long*)malloc(size)) {
    unsigned long* p = (unsigned long*)((unsigned char*)handle + size);
    handle[8] = (unsigned long)p;
    handle[9] = (unsigned long)entrypoint;
  }

  return handle;
}

void co_delete(cothread_t handle) {
  free(handle);
}

void co_switch(cothread_t handle) {
  cothread_t co_previous_handle = co_active_handle;
  co_swap(co_active_handle = handle, co_previous_handle);
}

#ifdef __cplusplus
}
#endif
