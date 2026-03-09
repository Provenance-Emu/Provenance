int  sh2_drc_init(SH2 *sh2);
void sh2_drc_finish(SH2 *sh2);
void sh2_drc_wcheck_ram(u32 a, unsigned len, SH2 *sh2);
void sh2_drc_wcheck_da(u32 a, unsigned len, SH2 *sh2);

#ifdef DRC_SH2
void sh2_drc_mem_setup(SH2 *sh2);
void sh2_drc_flush_all(void);
#else
#define sh2_drc_mem_setup(x)
#define sh2_drc_flush_all()
#define sh2_drc_frame()
#endif

#define BLOCK_INSN_LIMIT 1024

/* op_flags */
#define OF_DELAY_OP   (1 << 0)
#define OF_BTARGET    (1 << 1)
#define OF_LOOP       (3 << 2) // NONE, IDLE, DELAY, POLL loop
#define OF_B_IN_DS    (1 << 4)
#define OF_DELAY_INSN (1 << 5) // DT, (TODO ADD+CMP?)
#define OF_POLL_INSN  (1 << 6) // MOV @(...),Rn (no post increment), TST @(...)
#define OF_BASIC_LOOP (1 << 7) // pinnable loop without any branches in it

#define OF_IDLE_LOOP  (1 << 2)
#define OF_DELAY_LOOP (2 << 2)
#define OF_POLL_LOOP  (3 << 2)

u16 scan_block(u32 base_pc, int is_slave, u8 *op_flags, u32 *end_pc,
		u32 *base_literals, u32 *end_literals);

#if defined(DRC_SH2) && defined(__GNUC__) && !defined(__clang__)
// direct access to some host CPU registers used by the DRC if gcc is used.
// XXX MUST match SHR_SR definitions in cpu/drc/emit_*.c; should be moved there
// XXX yuck, there's no portable way to determine register size. Use long long
//     if target is 64 bit and data model is ILP32 or LLP64(windows), else long
#if defined(__arm__)
#define	DRC_SR_REG	"r10"
#define DRC_REG_LL	0	// 32 bit
#elif defined(__aarch64__)
#define	DRC_SR_REG	"r28"
#define DRC_REG_LL	(__ILP32__ || _WIN32)
#elif defined(__mips__)
#define	DRC_SR_REG	"s6"
#define DRC_REG_LL	(_MIPS_SZPTR > _MIPS_SZLONG) // (_MIPS_SIM == _ABIN32)
#elif defined(__riscv__) || defined(__riscv)
#define	DRC_SR_REG	"s11"
#define DRC_REG_LL	0	// no ABI for (__ILP32__ && __riscv_xlen != 32)
#elif defined(__powerpc__) || defined(__ppc__) || defined(__PPC__)
#define	DRC_SR_REG	"r28"
#define DRC_REG_LL	0	// no ABI for __ILP32__
//i386 only has 8 registers and reserving one of them causes too much spilling
//#elif defined(__i386__)
//#define	DRC_SR_REG	"edi"
//#define DRC_REG_LL	0	// 32 bit
#elif defined(__x86_64__)
#define	DRC_SR_REG	"rbx"
#define DRC_REG_LL	(__ILP32__ || _WIN32)
#endif
#endif

#ifdef DRC_SR_REG
// XXX this is more clear but produces too much overhead for slow platforms
extern void REGPARM(1) (*sh2_drc_save_sr)(SH2 *sh2);
extern void REGPARM(1) (*sh2_drc_restore_sr)(SH2 *sh2);

// NB: sh2_sr MUST have register size if optimizing with -O3 (-fif-conversion)
#if DRC_REG_LL
#define	DRC_DECLARE_SR	register long long	_sh2_sr asm(DRC_SR_REG)
#else
#define	DRC_DECLARE_SR	register long		_sh2_sr asm(DRC_SR_REG)
#endif
// NB: save/load SR register only when DRC is executing and not in DMA access
#define DRC_SAVE_SR(sh2) \
    if (likely((sh2->state & (SH2_IN_DRC|SH2_STATE_SLEEP)) == SH2_IN_DRC)) \
	sh2->sr = (s32)_sh2_sr
//      host_call(sh2_drc_save_sr, (SH2 *))(sh2)
#define DRC_RESTORE_SR(sh2) \
    if (likely((sh2->state & (SH2_IN_DRC|SH2_STATE_SLEEP)) == SH2_IN_DRC)) \
	_sh2_sr = (s32)sh2->sr
//      host_call(sh2_drc_restore_sr, (SH2 *))(sh2)
#else
#define	DRC_DECLARE_SR
#define DRC_SAVE_SR(sh2)
#define DRC_RESTORE_SR(sh2)
#endif
