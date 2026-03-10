/*
 * DRC host disassembler interface for MIPS/ARM32 for use without binutils
 * (C) irixxxx, 2018-2021
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#if defined __mips__
#include "dismips.c"
#define disasm dismips
#elif defined __arm__
#include "disarm.c"
#define disasm disarm
#endif

/* symbols */
typedef struct { const char *name; void *value; } asymbol;

static asymbol **symbols;
static long symcount, symstorage = 8;

static const char *lookup_name(void *addr)
{
  asymbol **sptr = symbols;
  int i;

  for (i = 0; i < symcount; i++) {
    asymbol *sym = *sptr++;

    if (addr == sym->value)
      return sym->name;
  }

  return NULL;
}

#ifdef disasm
void host_dasm(void *addr, int len)
{
  void *end = (char *)addr + len;
  const char *name;
  char buf[64];
  unsigned long insn, symaddr;

  while (addr < end) {
    name = lookup_name(addr);
    if (name != NULL)
      printf("%s:\n", name);

    insn = *(unsigned long *)addr;
    printf("   %08lx %08lx ", (long)addr, insn);
    if(disasm((uintptr_t)addr, insn, buf, sizeof(buf), &symaddr))
    {
      if (symaddr)
        name = lookup_name((void *)symaddr);
      if (symaddr && name)
        printf("%s <%s>\n", buf, name);
      else if (symaddr && !name)
        printf("%s <unknown>\n", buf);
      else
        printf("%s\n", buf);
    } else
      printf("unknown (0x%08lx)\n", insn);
    addr = (char *)addr + sizeof(long);
  }
}
#else
void host_dasm(void *addr, int len)
{
  uint8_t *end = (uint8_t *)addr + len;
  char buf[64];
  uint8_t *p = addr;
  int i = 0, o = 0;

  o = snprintf(buf, sizeof(buf), "%p:	", p);
  while (p < end) {
    o += snprintf(buf+o, sizeof(buf)-o, "%02x ", *p++);
    if (++i >= 16) {
      buf[o] = '\0';
      printf("%s\n", buf);
      o = snprintf(buf, sizeof(buf), "%p:	", p);
      i = 0;
    }
  }
  if (i) {
    buf[o] = '\0';
    printf("%s\n", buf);
  }
}
#endif

void host_dasm_new_symbol_(void *addr, const char *name)
{
  asymbol *sym, **tmp;

  if (symbols == NULL)
    symbols = malloc(symstorage);
  if (symstorage <= symcount * sizeof(symbols[0])) {
    tmp = realloc(symbols, symstorage * 2);
    if (tmp == NULL)
      return;
    symstorage *= 2;
    symbols = tmp;
  }

  symbols[symcount] = calloc(sizeof(*symbols[0]), 1);
  if (symbols[symcount] == NULL)
    return;

  // a HACK (should use correct section), but ohwell
  sym = symbols[symcount];
  sym->value = addr;
  sym->name = name;
  symcount++;
}

