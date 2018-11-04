/*
 * (C) Gražvydas "notaz" Ignotas, 2009-2010
 *
 * This work is licensed under the terms of any of these licenses
 * (at your option):
 *  - GNU GPL, version 2 or later.
 *  - GNU LGPL, version 2.1 or later.
 *  - MAME license.
 * See the COPYING file in the top-level directory.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <bfd.h>
#include <dis-asm.h>

#include "host_dasm.h"

extern char **g_argv;

static struct disassemble_info di;

#ifdef __arm__
#define print_insn_func print_insn_little_arm
#define BFD_ARCH bfd_arch_arm
#define BFD_MACH bfd_mach_arm_unknown
#define DASM_OPTS "reg-names-std"
#else
#define print_insn_func print_insn_i386_intel
#define BFD_ARCH bfd_arch_i386
#define BFD_MACH bfd_mach_i386_i386_intel_syntax
#define DASM_OPTS NULL
#endif

/* symbols */
static asymbol **symbols;
static long symcount, symstorage;
static int init_done;

/* Filter out (in place) symbols that are useless for disassembly.
   COUNT is the number of elements in SYMBOLS.
   Return the number of useful symbols.  */
static long
remove_useless_symbols (asymbol **symbols, long count)
{
  asymbol **in_ptr = symbols, **out_ptr = symbols;

  while (--count >= 0)
    {
      asymbol *sym = *in_ptr++;

      if (sym->name == NULL || sym->name[0] == '\0' || sym->name[0] == '$')
        continue;
      if (sym->flags & (BSF_DEBUGGING | BSF_SECTION_SYM))
        continue;
      if (bfd_is_und_section (sym->section)
          || bfd_is_com_section (sym->section))
        continue;
      if (sym->value + sym->section->vma == 0)
        continue;
/*
      printf("sym: %08lx %04x %08x v %08x \"%s\"\n",
        (unsigned int)sym->value, (unsigned int)sym->flags, (unsigned int)sym->udata.i,
        (unsigned int)sym->section->vma, sym->name);
*/
      *out_ptr++ = sym;
    }

  return out_ptr - symbols;
}

static void slurp_symtab(const char *filename)
{
  bfd *abfd;

  symcount = 0;

  abfd = bfd_openr(filename, NULL);
  if (abfd == NULL) {
    fprintf(stderr, "failed to open: %s\n", filename);
    goto no_symbols;
  }

  if (!bfd_check_format(abfd, bfd_object))
    goto no_symbols;

  if (!(bfd_get_file_flags(abfd) & HAS_SYMS))
    goto no_symbols;

  symstorage = bfd_get_symtab_upper_bound(abfd);
  if (symstorage <= 0)
    goto no_symbols;

  symbols = malloc(symstorage);
  if (symbols == NULL)
    goto no_symbols;

  symcount = bfd_canonicalize_symtab(abfd, symbols);
  if (symcount < 0)
    goto no_symbols;

  symcount = remove_useless_symbols(symbols, symcount);
//  bfd_close(abfd);
  return;

no_symbols:
  fprintf(stderr, "no symbols in %s\n", bfd_get_filename(abfd));
  if (symbols != NULL)
    free(symbols);
  symbols = NULL;
  if (abfd != NULL)
    bfd_close(abfd);
}

static const char *lookup_name(bfd_vma addr)
{
  asymbol **sptr = symbols;
  int i;

  for (i = 0; i < symcount; i++) {
    asymbol *sym = *sptr++;

    if (addr == sym->value + sym->section->vma)
      return sym->name;
  }

  return NULL;
}

/* Like target_read_memory, but slightly different parameters.  */
static int
dis_asm_read_memory(bfd_vma memaddr, bfd_byte *myaddr, unsigned int len,
                     struct disassemble_info *info)
{
  memcpy(myaddr, (void *)(int)memaddr, len);
  return 0;
}

static void
dis_asm_memory_error(int status, bfd_vma memaddr,
                      struct disassemble_info *info)
{
  fprintf(stderr, "memory_error %p\n", (void *)(int)memaddr);
}

static void
dis_asm_print_address(bfd_vma addr, struct disassemble_info *info)
{
  const char *name;

  printf("%08x", (int)addr);

  name = lookup_name(addr);
  if (name != NULL)
    printf(" <%s>", name);
}

static int insn_printf(void *f, const char *format, ...)
{
  va_list args;
  size_t n;

  va_start(args, format);
  n = vprintf(format, args);
  va_end(args);

  return n;
}

static void host_dasm_init(void)
{
  bfd_init();
  slurp_symtab(g_argv[0]);

  init_disassemble_info(&di, NULL, insn_printf);
  di.flavour = bfd_target_unknown_flavour;
  di.memory_error_func = dis_asm_memory_error; 
  di.print_address_func = dis_asm_print_address;
//  di.symbol_at_address_func = dis_asm_symbol_at_address;
  di.read_memory_func = dis_asm_read_memory;
  di.arch = BFD_ARCH;
  di.mach = BFD_MACH;
  di.endian = BFD_ENDIAN_LITTLE;
  di.disassembler_options = DASM_OPTS;
  disassemble_init_for_target(&di);
  init_done = 1;
}

void host_dasm(void *addr, int len)
{
  bfd_vma vma_end, vma = (bfd_vma)(long)addr;
  const char *name;

  if (!init_done)
    host_dasm_init();

  vma_end = vma + len;
  while (vma < vma_end) {
    name = lookup_name(vma);
    if (name != NULL)
      printf("%s:\n", name);

    printf("   %08lx ", (long)vma);
    vma += print_insn_func(vma, &di);
    printf("\n");
  }
}

void host_dasm_new_symbol_(void *addr, const char *name)
{
  bfd_vma vma = (bfd_vma)(long)addr;
  asymbol *sym, **tmp;

  if (!init_done)
    host_dasm_init();
  if (symbols == NULL)
    return;
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
  sym->section = symbols[0]->section;
  sym->value = vma - sym->section->vma;
  sym->name = name;
  symcount++;
}

