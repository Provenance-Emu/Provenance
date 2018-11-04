#ifdef __cplusplus
extern "C"
{
#endif

int pollux_set(volatile unsigned short *memregs, const char *str);
int pollux_set_fromenv(volatile unsigned short *memregs,
	const char *env_var);

#ifdef __cplusplus
}
#endif
