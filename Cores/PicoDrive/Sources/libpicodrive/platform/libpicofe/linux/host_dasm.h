void host_dasm(void *addr, int len);
void host_dasm_new_symbol_(void *addr, const char *name);
#define host_dasm_new_symbol(sym) \
	host_dasm_new_symbol_(sym, #sym)
