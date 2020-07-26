

/**
 * Cyclone 68000 configuration file
**/


/*
 * If this option is enabled, Microsoft ARMASM compatible output is generated
 * (output file -  Cyclone.asm). Otherwise GNU as syntax is used (Cyclone.s).
 */
#define USE_MS_SYNTAX               0

/*
 * Enable this option if you are going to use Cyclone to emulate Genesis /
 * Mega Drive system. As VDP chip in these systems had control of the bus,
 * several instructions were acting differently, for example TAS did'n have
 * the write-back phase. That will be emulated, if this option is enabled.
 */
#define CYCLONE_FOR_GENESIS         0

/*
 * This option compresses Cyclone's jumptable. Because of this the executable
 * will be smaller and load slightly faster and less relocations will be needed.
 * This also fixes the crash problem with 0xfffe and 0xffff opcodes.
 * Warning: if you enable this, you MUST call CycloneInit() before calling
 * CycloneRun(), or else it will crash.
 */
#define COMPRESS_JUMPTABLE          1

/*
 * Address mask for memory hadlers. The bits set will be masked out of address
 * parameter, which is passed to r/w memory handlers.
 * Using 0xff000000 means that only 24 least significant bits should be used.
 * Set to 0 if you want to mask unused address bits in the memory handlers yourself.
 */
#define MEMHANDLERS_ADDR_MASK       0

/*
 * Cyclone keeps the 4 least significant bits of SR, PC+membase and it's cycle
 * counter in ARM registers instead of the context for performance reasons. If you for
 * any reason need to access them in your memory handlers, enable the options below,
 * otherwise disable them to improve performance.
 *
 * MEMHANDLERS_NEED_PC updates .pc context field with PC value effective at the time
 * when memhandler was called (opcode address + 2-10 bytes).
 * MEMHANDLERS_NEED_PREV_PC updates .prev_pc context field to currently executed
 * opcode address + 2.
 * Note that .pc and .prev_pc values are always real pointers to memory, so you must
 * subtract .membase to get M68k PC value.
 *
 * Warning: updating PC in memhandlers is dangerous, as Cyclone may internally
 * increment the PC before fetching the next instruction and continue executing
 * at wrong location. It's better to wait until Cyclone CycloneRun() finishes.
 *
 * Warning: if you enable MEMHANDLERS_CHANGE_CYCLES, you must also enable
 * MEMHANDLERS_NEED_CYCLES, or else Cyclone will keep reloading the same cycle
 * count and this will screw timing (if not cause a deadlock).
 */
#define MEMHANDLERS_NEED_PC         0
#define MEMHANDLERS_NEED_PREV_PC    0
#define MEMHANDLERS_NEED_FLAGS      0
#define MEMHANDLERS_NEED_CYCLES     0
#define MEMHANDLERS_CHANGE_PC       0
#define MEMHANDLERS_CHANGE_FLAGS    0
#define MEMHANDLERS_CHANGE_CYCLES   0

/*
 * If the following macro is defined, Cyclone no longer calls read*, write*,
 * fetch* and checkpc from it's context, it calls these functions directly
 * instead, prefixed with prefix selected below. For example, if
 * MEMHANDLERS_DIRECT_PREFIX is set to cyclone_, it will call cyclone_read8
 * on byte reads.
 * This is to avoid indirect jumps, which are slower. It also saves one ARM
 * instruction.
 */
/* MEMHANDLERS_DIRECT_PREFIX "cyclone_" */

/*
 * If enabled, Cyclone will call .IrqCallback routine from it's context whenever it
 * acknowledges an IRQ. IRQ level (.irq) is not cleared automatically, do this in your
 * handler if needed.
 * This function must either return vector number to use for interrupt exception,
 * CYCLONE_INT_ACK_AUTOVECTOR to use autovector (this is the most common case), or
 * CYCLONE_INT_ACK_SPURIOUS (least common case).
 * If disabled, it simply uses appropriate autovector, clears the IRQ level and
 * continues execution.
 */
#define USE_INT_ACK_CALLBACK        0

/*
 * Enable this if you need old PC, flags or cycles;
 * or you change cycles in your IrqCallback function.
 */
#define INT_ACK_NEEDS_STUFF         0
#define INT_ACK_CHANGES_CYCLES      0

/*
 * If enabled, .ResetCallback is called from the context, whenever RESET opcode is
 * encountered. All context members are valid and can be changed.
 * If disabled, RESET opcode acts as an NOP.
 */
#define USE_RESET_CALLBACK          0

/*
 * If enabled, UnrecognizedCallback is called if an invalid opcode is
 * encountered. All context members are valid and can be changed. The handler
 * should return zero if you want Cyclone to gererate "Illegal Instruction"
 * exception after this, or nonzero if not. In the later case you should change
 * the PC by yourself, or else Cyclone will keep executing that opcode all over
 * again.
 * If disabled, "Illegal Instruction" exception is generated and execution is
 * continued.
 */
#define USE_UNRECOGNIZED_CALLBACK   0

/*
 * This option will also call UnrecognizedCallback for a-line and f-line
 * (0xa*** and 0xf***) opcodes the same way as described above, only appropriate
 * exceptions will be generated.
 */
#define USE_AFLINE_CALLBACK         0

/*
 * This makes Cyclone to call checkpc from it's context whenever it changes the PC
 * by a large value. It takes and should return the PC value in PC+membase form.
 * The flags and cycle counter are not valid in this function.
 */
#define USE_CHECKPC_CALLBACK        1

/*
 * This determines if checkpc() should be called after jumps when 8 and 16 bit
 * displacement values were used.
 */
#define USE_CHECKPC_OFFSETBITS_16   1
#define USE_CHECKPC_OFFSETBITS_8    0

/*
 * Call checkpc() after DBcc jumps (which use 16bit displacement). Cyclone prior to
 * 0.0087 never did that.
 */
#define USE_CHECKPC_DBRA            0

/*
 * When this option is enabled Cyclone will do two word writes instead of one
 * long write when handling MOVE.L or MOVEM.L with pre-decrementing destination,
 * as described in Bart Trzynadlowski's doc (http://www.trzy.org/files/68knotes.txt).
 * Enable this if you are emulating a 16 bit system.
 */
#define SPLIT_MOVEL_PD              1

/*
 * Enable emulation of trace mode. Shouldn't cause any performance decrease, so it
 * should be safe to keep this ON.
 */
#define EMULATE_TRACE               1

/*
 * If enabled, address error exception will be generated if 68k code jumps to an
 * odd address. Causes very small performance hit (2 ARM instructions for every
 * emulated jump/return/exception in normal case).
 * Note: checkpc() must not clear least significant bit of rebased address
 * for this to work, as checks are performed after calling checkpc().
 */
#define EMULATE_ADDRESS_ERRORS_JUMP 1

/*
 * If enabled, address error exception will be generated if 68k code tries to
 * access a word or longword at an odd address. The performance cost is also 2 ARM
 * instructions per access (for address error checks).
 */
#define EMULATE_ADDRESS_ERRORS_IO   0

/*
 * If an address error happens during another address error processing,
 * the processor halts until it is reset (catastrophic system failure, as the manual
 * states). This option enables halt emulation.
 * Note that this might be not desired if it is known that emulated system should
 * never reach this state.
 */
#define EMULATE_HALT                0

