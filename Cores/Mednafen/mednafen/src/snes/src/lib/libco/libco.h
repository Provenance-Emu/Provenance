/*
  libco
  version: 0.17 (2015-06-18)
  author: byuu
  license: public domain
*/

#ifndef LIBCO_H
#define LIBCO_H

#ifdef LIBCO_C
  #ifdef LIBCO_MP
    #define thread_local __thread
  #else
    #define thread_local
  #endif

  #if defined(_MSC_VER)
   /* Untested */
   #define force_text_section __declspec(allocate(".text"))
  #elif defined(__APPLE__) && defined(__MACH__)
   #define force_text_section __attribute__((section("__TEXT,__text")))
  #else
   #define force_text_section __attribute__((section(".text")))
  #endif
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef void* cothread_t;

cothread_t co_active();
cothread_t co_create(unsigned int, void (*)(void));
void co_delete(cothread_t);
void co_switch(cothread_t);

#ifdef __cplusplus
}
#endif

/* ifndef LIBCO_H */
#endif
