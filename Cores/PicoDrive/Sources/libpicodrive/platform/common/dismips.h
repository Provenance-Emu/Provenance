#ifndef DISMIPS_H
#define DISMIPS_H

int dismips(uintptr_t pc, uint32_t insn, char *buf, size_t buf_len, unsigned long *sym);

#endif /* DISMIPS_H */
