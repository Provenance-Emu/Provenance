int  sh2_drc_init(SH2 *sh2);
void sh2_drc_finish(SH2 *sh2);
void sh2_drc_wcheck_ram(unsigned int a, int val, int cpuid);
void sh2_drc_wcheck_da(unsigned int a, int val, int cpuid);

#ifdef DRC_SH2
void sh2_drc_mem_setup(SH2 *sh2);
void sh2_drc_flush_all(void);
void sh2_drc_frame(void);
#else
#define sh2_drc_mem_setup(x)
#define sh2_drc_flush_all()
#define sh2_drc_frame()
#endif

#define BLOCK_INSN_LIMIT 128

/* op_flags */
#define OF_DELAY_OP   (1 << 0)
#define OF_BTARGET    (1 << 1)
#define OF_T_SET      (1 << 2) // T is known to be set
#define OF_T_CLEAR    (1 << 3) // ... clear

void scan_block(unsigned int base_pc, int is_slave,
		unsigned char *op_flags, unsigned int *end_pc,
		unsigned int *end_literals);
