/*  src/scsp2.c: New, threadable SCSP implementation for Yabause
    Copyright 2004 Stephane Dallongeville
    Copyright 2004-2007 Theo Berkau
    Copyright 2006 Guillaume Duhamel
    Copyright 2010 Andrew Church

    This file is part of Yabause.

    Yabause is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    Yabause is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Yabause; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
*/

#include "core.h"
#include "debug.h"
#include "error.h"
#include "m68kcore.h"
#include "memory.h"
#include "scsp.h"
#include "threads.h"
#include "yabause.h"

#include <math.h>
#include <stdlib.h>

#undef round  // In case math.h defines it
#define round(x)  ((int) (floor((x) + 0.5)))

#undef ScspInit  // Disable compatibility alias

extern SoundInterface_struct *SNDCoreList[];  // Defined by each port

///////////////////////////////////////////////////////////////////////////

// This SCSP implementation is designed to be runnable as an independent
// thread, encompassing the SCSP emulation itself as well as the MC68EC000
// sound processor and the actual generation of PCM audio data.
//
// When running in multithreaded mode, the actual SCSP and M68K emulation
// is performed via ScspThread().  This function is started as a subthread
// (YAB_THREAD_SCSP), and loops over ScspDoExec() until scsp_thread_running
// goes to zero, which is used as a signal for the thread to stop.
// Synchronization is performed via the scsp_clock_target variable; the SCSP
// thread sleeps until clock_target != clock, then calls ScspDoExec() for
// (clock - clock_target) cycles.  The main thread wakes up the subthread
// both when clock_target is updated and when register writes, discussed
// below, are submitted.
//
// Additionally, any register writes from outside the SCSP/M68K will be
// processed synchronously in multithreaded mode, by passing the write
// through a shared buffer (scsp_write_buffer_* variables).  When the
// thread loop detects scsp_write_buffer_size nonzero, it processes the
// write before its next ScspDoExec() iteration and clears ..._size; the
// main thread then waits for ..._size to return to zero before returning
// from the write operation.  (This will typically be no more expensive
// than a pair of context switches, and it seems that SCSP register writes
// from the SH-2 are uncommon.)
//
// The "PSP_*" macros scattered throughout the file are to support the
// execution of the SCSP thread on the Media Engine CPU (ME) in the PSP.
// The ME lacks cache coherence with the main CPU (SC), so special care
// needs to be taken to avoid bugs arising from inconsistent cache states;
// see the technical notes in README.PSP for details.  These macros are all
// no-ops on other platforms.

//-------------------------------------------------------------------------
// PSP cache management macros

#ifdef PSP

# include "psp/common.h"
# include "psp/me.h"
# include "psp/me-utility.h"
# include "psp/misc.h"  // psp_writeback_cache_for_scsp() declaration

// Data section management (to avoid cache line collisions between CPUs)
# define PSP_SECTION(name) \
   __attribute__((section(".meshared.scsp." #name)))
# define PSP_SECTION_START(name) \
   __attribute__((section(".meshared.scsp." #name), aligned(64))) \
   extern volatile char __scsp_sectstart_##name[64];
# define PSP_SECTION_END(name) \
   __attribute__((section(".meshared.scsp." #name))) \
   extern volatile char __scsp_sectend_##name;

// Cache control
# define PSP_WRITEBACK_CACHE(ptr,len) \
   sceKernelDcacheWritebackRange((ptr), (len))
# define PSP_WRITEBACK_ALL() \
   sceKernelDcacheWritebackAll()
# define PSP_FLUSH_ALL() \
   sceKernelDcacheWritebackInvalidateAll()

// Uncached pointer access
# define PSP_UCPTR(ptr) ((typeof(&*ptr))((uint32_t)(ptr) | 0x40000000))
// Uncached variable access (either read or write)
# define PSP_UC(var) (*((typeof(&var))((uint32_t)(&var) | 0x40000000)))

#else  // !PSP

# define PSP_SECTION(name)              /*nothing*/
# define PSP_SECTION_START(name)        /*nothing*/
# define PSP_SECTION_END(name)          /*nothing*/
# define PSP_WRITEBACK_CACHE(ptr,len)   /*nothing*/
# define PSP_WRITEBACK_ALL()            /*nothing*/
# define PSP_FLUSH_ALL()                /*nothing*/
# define PSP_UCPTR(ptr)                 ptr
# define PSP_UC(var)                    var

#endif

//-------------------------------------------------------------------------
// SCSP constants

// SCSP hardware version (4 bits)
#define SCSP_VERSION            0

// SCSP clock frequency (11.2896 MHz, or exactly 44100*256)
#define SCSP_CLOCK_FREQ         (44100 * 256)

// SCSP output frequency
#define SCSP_OUTPUT_FREQ        (SCSP_CLOCK_FREQ / 256)

// SCSP clock increment per 1/10 scanline
#define SCSP_CLOCK_INC_NTSC     (((u64)SCSP_CLOCK_FREQ<<20) * 1001 / 60000 / 263 / 10)
#define SCSP_CLOCK_INC_PAL      (((u64)SCSP_CLOCK_FREQ<<20) / 50 / 313 / 10)

// Limit on execution time for a single thread loop (in SCSP clock cycles);
// if the thread's delay exceeds this value, we stop in the main loop to
// let the SCSP catch up
#define SCSP_CLOCK_MAX_EXEC     (SCSP_CLOCK_FREQ / 1000)

// Sound RAM size
#define SCSP_RAM_SIZE           0x80000
#define SCSP_RAM_MASK           (SCSP_RAM_SIZE - 1)

// Envelope phases
#define SCSP_ENV_RELEASE        0
#define SCSP_ENV_SUSTAIN        1
#define SCSP_ENV_DECAY          2
#define SCSP_ENV_ATTACK         3

// LFO waveform types (equal to ALFOWS/PLFOWS values)
#define SCSP_LFO_SAWTOOTH       0
#define SCSP_LFO_SQUARE         1
#define SCSP_LFO_TRIANGLE       2
#define SCSP_LFO_NOISE          3

// Bit sizes of fixed-point counters

// Fractional part of frequency counter (determines accuracy of audio
// playback frequency)
#define SCSP_FREQ_LOW_BITS      10
// Integer part of envelope counter (determines resolution of attack/decay
// envelope); also used to define envelope value range
#define SCSP_ENV_HIGH_BITS      10
// Fractional part of envelope counter (determines accuracy of envelope timing)
#define SCSP_ENV_LOW_BITS       10
// Integer part of LFO counter (determines resolution of LFO waveform);
// also used to define LFO value range
#define SCSP_LFO_HIGH_BITS      10
// Fractional part of LFO counter (determines accuracy of LFO frequency)
#define SCSP_LFO_LOW_BITS       10
// Fractional part of TL attenuation lookup table (determines resolution of
// per-voice volume control)
#define SCSP_TL_BITS            10

// Envelope/waveform table data sizes and corresponding masks
#define SCSP_ENV_LEN            (1 << SCSP_ENV_HIGH_BITS)
#define SCSP_ENV_MASK           (SCSP_ENV_LEN - 1)
#define SCSP_LFO_LEN            (1 << SCSP_LFO_HIGH_BITS)
#define SCSP_LFO_MASK           (SCSP_LFO_LEN - 1)

// Envelope attack/decay points (counter values)
#define SCSP_ENV_ATTACK_START   0
#define SCSP_ENV_DECAY_START    (SCSP_ENV_LEN << SCSP_ENV_LOW_BITS)
#define SCSP_ENV_ATTACK_END     (SCSP_ENV_DECAY_START - 1)
#define SCSP_ENV_DECAY_END      (((2 * SCSP_ENV_LEN) << SCSP_ENV_LOW_BITS) - 1)

// Envelope attack/decay base times
#define SCSP_ATTACK_TIME        ((u32) (8 * SCSP_OUTPUT_FREQ))
#define SCSP_DECAY_TIME         ((u32) (12 * SCSP_ATTACK_TIME))

// Interrupt bit numbers
#define SCSP_INTERRUPT_MIDI_IN  3       // Data available in MIDI input buffer
#define SCSP_INTERRUPT_DMA      4       // DMA complete
#define SCSP_INTERRUPT_MANUAL   5       // 1 written to bit 5 of [MS]CIPD
#define SCSP_INTERRUPT_TIMER_A  6       // Timer A reached 0xFF
#define SCSP_INTERRUPT_TIMER_B  7       // Timer B reached 0xFF
#define SCSP_INTERRUPT_TIMER_C  8       // Timer C reached 0xFF
#define SCSP_INTERRUPT_MIDI_OUT 9       // MIDI output buffer became empty
#define SCSP_INTERRUPT_SAMPLE   10      // Raised once per output sample

// Interrupt target flags
#define SCSP_INTTARGET_MAIN     (1 << 0)  // Interrupt to main CPU (SCU)
#define SCSP_INTTARGET_SOUND    (1 << 1)  // Interrupt to sound CPU
#define SCSP_INTTARGET_BOTH     (SCSP_INTTARGET_MAIN | SCSP_INTTARGET_SOUND)

// PCM output buffer size parameters
#define SCSP_SOUND_LEN_NTSC     (SCSP_OUTPUT_FREQ / 60)  // Samples per frame
#define SCSP_SOUND_LEN_PAL      (SCSP_OUTPUT_FREQ / 50)
// Reserve 10x the maximum samples per frame
#define SCSP_SOUND_BUFSIZE      (10 * SCSP_SOUND_LEN_PAL)

// CDDA data buffer size in sectors (must be at least 3)
#define CDDA_NUM_BUFFERS        3

// CDDA playback start delay in samples (see cdda_delay comments)
#define CDDA_DELAY_SAMPLES      100

//-------------------------------------------------------------------------
// Internal state data structures

// Per-slot data structure

typedef struct SlotState_struct
{
   ////////////
   // Register fields

   // ISR $00
                        // [12] Write 1 to execute KEY state change
   u8   key;            // [11] KEY state (on/off)
   u8   sbctl;          // [10:9] Source bit control
   u8   ssctl;          // [8:7] Sound source control
   u8   lpctl;          // [6:5] Loop control
   u8   pcm8b;          // [4] PCM sound format
                        // [3:0] Start address (in bytes), high bits (19:16)

   // ISR $02
   u32  sa;             // [15:0] Start address (in bytes), low bits (15:0)

   // ISR $04
   u16  lsa;            // [15:0] Loop start address (in samples)

   // ISR $06
   u16  lea;            // [15:0] Loop end address (in samples)

   // ISR $08
   u8   sr;             // [15:11] Sustain rate
   u8   dr;             // [10:6] Decay rate
   u8   eghold;         // [5] Envelope hold (attack rate 0) flag
   u8   ar;             // [4:0] Attack rate

   // ISR $0A
   u8   lpslnk;         // [14] Loop start link (start decay on reaching LSA)
   u8   krs;            // [13:10] Key rate scale
   u8   sl;             // [9:5] Sustain level
   u8   rr;             // [4:0] Release rate

   // ISR $0C
   u8   stwinh;         // [9] Stack write inhibit flag
   u8   sdir;           // [8] Sound direct output flag
   u8   tl;             // [7:0] Total level

   // ISR $0E
   u8   mdl;            // [15:12] Modulation level
   u8   mdx;            // [11:6] Modulation source X
   u8   mdy;            // [5:0] Modulation source Y

   // ISR $10
   u8   oct;            // [14:11] Octave (treated as signed -8..7)
   u16  fns;            // [9:0] Frequency number switch

   // ISR $12
   u8   lfore;          // [15] LFO reset flag (1 = reset, 0 = count)
   u8   lfof;           // [14:10] LFO frequency index
   u8   plfows;         // [9:8] Pitch LFO waveform select
   u8   plfos;          // [7:5] Pitch LFO sensitivity
   u8   alfows;         // [4:3] Amplitude LFO waveform select
   u8   alfos;          // [2:0] Amplitude LFO sensitivity

   // ISR $14
   u8   isel;           // [6:3] Input selector
   u8   imxl;           // [2:0] Input mix level

   // ISR $16
   u8   disdl;          // [15:13] Direct data send level
   u8   dipan;          // [12:8] Direct data pan position
   u8   efsdl;          // [7:5] Effect data send level
   u8   efpan;          // [2:0] Effect data pan position

   ////////////
   // Internal state

   // Audio generation routine (selected based on slot parameters)
   void (* FASTCALL audiogen)(struct SlotState_struct *slot, u32 len);

   const void *buf;     // Pointer to sample data in sound RAM

   u32  addr_counter;   // Address (playback) counter
   u32  addr_step;      // Address counter increment
   u8   octave_shift;   // Octave shift amount (0..15)
   u32  lsa_shifted;    // lsa << SCSP_FREQ_LOW_BITS (for addr_counter)
   u32  lea_shifted;    // lea << SCSP_FREQ_LOW_BITS (for addr_counter)
   u32  looplen_shifted;// (lea - lsa + 1) << SCSP_FREQ_LOW_BITS

   u32  env_phase;      // Current envelope phase (attack/decay/...)
   s32  env_counter;    // Envelope counter
   s32  env_step;       // Envelope counter increment for current phase
   s32  env_target;     // Envelope target value for advancing to next phase
   s32  env_step_a;     // Envelope counter increment for attack phase
   s32  env_step_d;     // Envelope counter increment for decay phase
   s32  env_step_s;     // Envelope counter increment for sustain phase
   s32  env_step_r;     // Envelope counter increment for release phase
   s32  last_env;       // Last calculated envelope multiplier
   u8   krs_shift;      // Shift count corresponding to KRS
   s32  sl_target;      // Compare value corresponding to SL
   s32  tl_mult;        // Envelope volume multiplier corresponding to TL

   u32  lfo_counter;    // LFO counter (fixed point index into LFO waveforms)
   s32  lfo_step;       // LFO counter increment, or -1 if in reset mode
   s32  *lfo_fm_wave;   // LFO frequency modulation waveform pointer
   s32  *lfo_am_wave;   // LFO amplitude modulation waveform pointer
   s8   lfo_fm_shift;   // LFO frequency modulation strength, -1 if disabled
   s8   lfo_am_shift;   // LFO amplitude modulation strength, -1 if disabled

   u8   outshift_l;     // Output shift for left channel (down to 16 bits)
   u8   outshift_r;     // Output shift for right channel (down to 16 bits)

   u8   imxl_shift;     // Shift count for IMXL

} SlotState;

//------------------------------------

// Overall SCSP data structure

typedef struct ScspState_struct {

   ////////////
   // Register fields

   // $400
   u8   mem4mb;         // [9] Sound RAM memory size flag (4Mbit vs. 2Mbit)
   u8   dac18b;         // [8] DAC 18-bit output flag (ignored)
   u8   ver;            // [7:4] Hardware version (fixed at 0)
   u8   mvol;           // [3:0] Master volume

   // $402
   u8   rbl;            // [8:7] Ring buffer length (8192<<RBL words)
   u32  rbp;            // [6:0] Ring buffer pointer 19:13 (low bits are zero)

   // $404
   u8   mofull;         // [12] MIDI output FIFO full flag
   u8   moemp;          // [11] MIDI output FIFO empty flag
   u8   miovf;          // [10] MIDI input FIFO overflow flag
   u8   mifull;         // [9] MIDI input FIFO full flag
   u8   miemp;          // [8] MIDI input FIFO empty flag
   u8   mibuf;          // [7:0] MIDI input data buffer

   // $406
   u8   mobuf;          // [7:0] MIDI output data buffer

   // $408
   u8   mslc;           // [15:11] Monitor slot
   u8   ca;             // [10:7] Call address
   u8   sgc;            // [6:5] Envelope phase
   u8   eg;             // [4:0] Envelope volume

   // $40A..$410 unused (possibly used in the model 2 SCSP?)

   // $412              // [15:1] DMA transfer start address 15:1
   u32  dmea;

   // $414
                        // [15:12] DMA transfer start address 19:16
   u16  drga;           // [11:1] DMA register address 11:1

   // $416
   u8   dgate;          // [14] DMA gate (1 = zero-clear target)
   u8   ddir;           // [13] DMA direction (0 = from, 1 = to sound RAM)
   u8   dexe;           // [12] DMA execute (write 1 to start; returns to 0 when done)
   u16  dtlg;           // [11:1] DMA transfer length 11:1

   // $418
   u8   tactl;          // [10:8] Timer A step divisor (step every 1<<tactl output samples)
   u16  tima;           // [7:0] Timer A counter (sends an IRQ at 0xFF), as 8.8 fixed point

   // $41A
   u8   tbctl;          // [10:8] Timer B step divisor
   u16  timb;           // [7:0] Timer B counter, as 8.8 fixed point

   // $41C
   u8   tcctl;          // [10:8] Timer C step divisor
   u16  timc;           // [7:0] Timer C counter, as 8.8 fixed point

   // $41E
   u16  scieb;          // [10:0] Sound CPU interrupt enable

   // $420
   u16  scipd;          // [10:0] Sound CPU interrupt pending

   // $422
   //   scire;          // [10:0] Sound CPU interrupt reset (not readable)

   // $424
   u8   scilv0;         // [7:0] Sound CPU interrupt levels, bit 0

   // $426
   u8   scilv1;         // [7:0] Sound CPU interrupt levels, bit 1

   // $428
   u8   scilv2;         // [7:0] Sound CPU interrupt levels, bit 2

   // $42A
   u16  mcieb;          // [10:0] Main CPU interrupt enable

   // $42C
   u16  mcipd;          // [10:0] Main CPU interrupt pending

   // $42E
   //   mcire;          // [10:0] Main CPU interrupt reset (not readable)

   ////////////
   // Internal state

   s32  stack[32*2];    // 2 generations of sound output data ($600..$67E)

   SlotState slot[32];  // Data for each slot

   u32  sample_timer;   // Sample output timer (in SCSP clocks, 256 = 1 sample)

   u32  sound_ram_mask; // Sound RAM address mask (tracks mem4mb)

   u8   midi_in_buf[4]; // MIDI in buffer
   u8   midi_out_buf[4];// MIDI out buffer
   u8   midi_in_cnt;    // MIDI in data count
   u8   midi_out_cnt;   // MIDI out data count

} ScspState;

//-------------------------------------------------------------------------
// Exported data

u8 *SoundRam;

//-------------------------------------------------------------------------
// Lookup tables

// Attack/decay envelope lookup table
static s32 scsp_env_table[SCSP_ENV_LEN*2];

// LFO waveforms for amplitude modulation
static s32 scsp_lfo_wave_amp[4][SCSP_LFO_LEN];
// LFO waveforms for frequency modulation
static s32 scsp_lfo_wave_freq[4][SCSP_LFO_LEN];
// LFO counter step values for each LFOF index
static s32 scsp_lfo_step[32];

// Envelope increments for each attack/decay rate (AR, DR, etc.)
static s32 scsp_attack_rate[62+16];
static s32 scsp_decay_rate[62+16];

// Table of volume multipliers for TL (total level) register
static s32 scsp_tl_table[256];

//-------------------------------------------------------------------------
// Other local data

//-------- Data written by main thread only --------//

// Cached fraction of a clock cycle (12.20 fixed point)
static u32 scsp_clock_frac;
// scsp_clock_frac increment per ScspExec(1) call
static u32 scsp_clock_inc;

// Selected sound output module
static SoundInterface_struct *SNDCore;

// Main CPU (SCU) interrupt function pointer
static void (*scsp_interrupt_handler)(void);

// Flag: Generate sound with frame-accurate timing?
static u8 scsp_frame_accurate;

//-------- Data used for inter-thread communication --------//

PSP_SECTION_START(sc_write)
PSP_SECTION_START(me_write)

// Core 11.2896MHz clock (continually counts up)
PSP_SECTION(me_write)
   static volatile u32 scsp_clock;
// Target clock value for execution (execute until clock == clock_target)
PSP_SECTION(sc_write)
   static volatile u32 scsp_clock_target;

// Flag: Is a subthread currently running?  (Also used to signal the
// subthread to stop.)
PSP_SECTION(sc_write)
   static volatile u8 scsp_thread_running;

// Flag: Has an interrupt request been generated for the main processor?
// (Set by the subthread, cleared by the main thread.)
PSP_SECTION(both_write)
   static volatile u8 scsp_main_interrupt_pending;

// Buffer for external (SH-2) SCSP writes (only _size is written by both
// CPUs, but we keep all three in the same section for cache safety)
PSP_SECTION(both_write)
   static volatile u8 scsp_write_buffer_size;  // 0 = nothing buffered
PSP_SECTION(both_write)
   static volatile u16 scsp_write_buffer_address;
PSP_SECTION(both_write)
   static volatile u32 scsp_write_buffer_data;

// SCSP register value cache (caching handled separately)
#ifdef PSP
__attribute__((aligned(64)))
#endif
static u16 scsp_regcache[0x1000/2];

// CDDA input buffer and read/write pointers
PSP_SECTION(sc_write)
static union {
   u8 sectors[CDDA_NUM_BUFFERS][2352];
   u8 data[CDDA_NUM_BUFFERS*2352];
} cdda_buf;
PSP_SECTION(sc_write)
   static volatile u32 cdda_next_in;  // Offset of next _sector_ to store
PSP_SECTION(me_write)
   static volatile u32 cdda_next_out; // Offset of next _byte_ to read out

PSP_SECTION_END(sc_write)
PSP_SECTION_END(me_write)

//--- Data written by SCSP thread only (except when thread is stopped) ---//

// Current SCSP state
static ScspState scsp;

// PCM output buffers and related data
static s32 scsp_buffer_L[SCSP_SOUND_BUFSIZE];
static s32 scsp_buffer_R[SCSP_SOUND_BUFSIZE];
static u32 scsp_sound_genpos;     // Offset of next sample to generate
static u32 scsp_sound_left;       // Samples not yet sent to host driver

// Parameters for audio data generation (these are file-scope to reduce
// parameter passing overhead)
static s32 *scsp_bufL;            // Base pointer for left channel
static s32 *scsp_bufR;            // Base pointer for right channel

// CDDA playback delay in samples (used to avoid audio popping when the
// SCSP emulation gets a few samples ahead of the CDDA input)
static u32 cdda_delay;

// M68K-related data
static u8 m68k_running;            // Nonzero if M68K execution is enabled
static s32 FASTCALL (*m68k_execf)(s32 cycles);  // M68K->Exec or M68KExecBP
static s32 m68k_saved_cycles;      // Requested minus actual cycles executed
static M68KBreakpointInfo m68k_breakpoint[M68K_MAX_BREAKPOINTS];
static int m68k_num_breakpoints;
static void (*M68KBreakpointCallback)(u32);
static u8 m68k_in_breakpoint;

//-------------------------------------------------------------------------
// Local function declarations

static void ScspThread(void *arg);
static void ScspDoExec(u32 cycles);
static u32 ScspTimerCyclesLeft(u16 timer, u8 timer_scale);
static void ScspUpdateTimer(u32 samples, u16 *timer_ptr, u8 timer_scale,
                            int interrupt);
static void ScspGenerateAudio(s32 *bufL, s32 *bufR, u32 samples);
static void ScspGenerateAudioForSlot(SlotState *slot, u32 samples);
static void ScspGenerateAudioForCDDA(s32 *bufL, s32 *bufR, u32 samples);

static u8 FASTCALL ScspReadByteDirect(u32 address);
static u16 FASTCALL ScspReadWordDirect(u32 address);
static void FASTCALL ScspWriteByteDirect(u32 address, u8 data);
static void FASTCALL ScspWriteWordDirect(u32 address, u16 data);
static u16 ScspReadMonitor(void);
static void ScspDoKeyOnOff(void);
static void ScspKeyOn(SlotState *slot);
static void ScspKeyOff(SlotState *slot);
static void ScspUpdateSlotAddress(SlotState *slot);
static void ScspUpdateSlotEnv(SlotState *slot);
static void ScspUpdateSlotFunc(SlotState *slot);
static u16 ScspMidiIn(void);
static void ScspMidiOut(u8 data);
static void ScspDoDMA(void);

static void ScspSyncThread(void);
static void ScspRaiseInterrupt(int which, int target);
static void ScspCheckInterrupts(u16 mask, int target);
static void ScspClearInterrupts(u16 mask, int target);
static void ScspRunM68K(u32 cycles);
static s32 FASTCALL M68KExecBP(s32 cycles);

static int scsp_mute_flags = 0;
static int scsp_volume = 100;

///////////////////////////////////////////////////////////////////////////
// Single-slot audio generation routines and corresponding table.  The
// table is indexed by:
//    scsp_audiogen_func_table[F][A][S][L][R]
//                             ^  ^  ^  ^  ^-- Right channel on/off (on = 1)
//                             |  |  |  `-- Left channel on/off (on = 1)
//                             |  |  `-- Sample size 16/8 bit (16 bit = 1)
//                             |  `-- Amplitude modulation on/off (on = 1)
//                             `-- Frequency modulation on/off (on = 1)
///////////////////////////////////////////////////////////////////////////

// For convenience, we use a single, parameterized macro to define every
// function, with 0 or 1 in each of the F/A/S/L/R parameters; the compiler
// will optimize out the disabled branches.

// A couple of handy sub-macros:
#define ADDRESS      (addr_counter >> SCSP_FREQ_LOW_BITS)
#ifdef WORDS_BIGENDIAN
#define ADDRESS_8BIT (ADDRESS)
#else
#define ADDRESS_8BIT (ADDRESS ^ 1)
#endif
#define ENV_POS      (env_counter >> SCSP_ENV_LOW_BITS)
#define LFO_POS      ((slot->lfo_counter >> SCSP_LFO_LOW_BITS) & SCSP_LFO_MASK)

#define DEFINE_AUDIOGEN(tag,F,A,S,L,R)                                      \
static void FASTCALL audiogen_##tag(SlotState *slot, u32 len)               \
{                                                                           \
   /* Load these first to avoid having to reload them every iteration */    \
         u32 addr_counter = slot->addr_counter;                             \
   const u32 addr_step    = slot->addr_step;                                \
         u32 env_counter  = slot->env_counter;                              \
         u32 env_step     = slot->env_step;                                 \
                                                                            \
   u32 pos;                                                                 \
   for (pos = 0; pos < len; pos++)                                          \
   {                                                                        \
      if (L || R)  /* Don't bother with calculations if it's all silent */  \
      {                                                                     \
         /* Compute envelope/TL multiplier for waveform data */             \
         s32 env = scsp_env_table[ENV_POS] * slot->tl_mult >> SCSP_TL_BITS; \
         if (A)                                                             \
            env -= slot->lfo_am_wave[LFO_POS] >> slot->lfo_am_shift;        \
         slot->last_env = env;                                              \
                                                                            \
         /* Apply envelope / channel volume to waveform data and output */  \
         if (LIKELY(env > 0))                                               \
         {                                                                  \
            s32 out;                                                        \
            if (S)                                                          \
               out = (s32) ((const s16 *)slot->buf)[ADDRESS];               \
            else                                                            \
               out = (s32) ((const s8 *)slot->buf)[ADDRESS_8BIT] << 8;      \
            out *= env;                                                     \
            if (L)                                                          \
               scsp_bufL[pos] += out >> slot->outshift_l;                   \
            if (R)                                                          \
               scsp_bufR[pos] += out >> slot->outshift_r;                   \
         }                                                                  \
      }                                                                     \
                                                                            \
      /* Update address counter, exiting if we reach the end of the data */ \
      if (F)                                                                \
      {                                                                     \
         /* FIXME: need to handle the case where LFO data range != 1<<FREQ_LOW_BITS */ \
         addr_counter += slot->lfo_fm_wave[LFO_POS]                         \
                         << slot->lfo_fm_shift                              \
                         >> slot->octave_shift;                             \
      }                                                                     \
      addr_counter += addr_step;                                            \
      if (UNLIKELY(addr_counter > slot->lea_shifted))                       \
      {                                                                     \
         /* FIXME: reverse/alternating loops not implemented */             \
         if (slot->lpctl)                                                   \
         {                                                                  \
            addr_counter = slot->lsa_shifted                                \
                         + ((addr_counter - slot->lsa_shifted)              \
                            % slot->looplen_shifted);                       \
         }                                                                  \
         else                                                               \
         {                                                                  \
            env_counter = SCSP_ENV_DECAY_END;                               \
            goto done;                                                      \
         }                                                                  \
      }                                                                     \
                                                                            \
      /* Update envelope counter, advancing the envelope phase as needed */ \
      env_counter += env_step;                                              \
      if (UNLIKELY(env_counter >= slot->env_target))                        \
      {                                                                     \
         switch (slot->env_phase)                                           \
         {                                                                  \
            case SCSP_ENV_ATTACK:                                           \
               env_counter = SCSP_ENV_DECAY_START;                          \
               env_step = slot->env_step = slot->env_step_d;                \
               slot->env_target = slot->sl_target;                          \
               slot->env_phase = SCSP_ENV_DECAY;                            \
               break;                                                       \
            case SCSP_ENV_DECAY:                                            \
               env_counter = slot->sl_target;                               \
               env_step = slot->env_step = slot->env_step_s;                \
               slot->env_target = SCSP_ENV_DECAY_END;                       \
               slot->env_phase = SCSP_ENV_SUSTAIN;                          \
               break;                                                       \
            default:                                                        \
               env_counter = SCSP_ENV_DECAY_END;                            \
               env_step = slot->env_step = 0;                               \
               slot->env_target = SCSP_ENV_DECAY_END + 1;                   \
               goto done;                                                   \
         }                                                                  \
      }                                                                     \
                                                                            \
      /* Update the LFO counter if either LFO waveform is in use            \
       * (technically, we should update whenever slot->lfore == 0, but      \
       * we skip the update on non-modulated channels to save time) */      \
      if (F || A)                                                           \
         slot->lfo_counter += slot->lfo_step;                               \
   }                                                                        \
                                                                            \
  done:                                                                     \
   slot->addr_counter = addr_counter;                                       \
   slot->env_counter = env_counter;                                         \
}

//-------------------------------------------------------------------------

// Define the actual audio generation functions.  For simplicity, we name
// each function using the state of its parameter flags, with uppercase for
// an enabled flag and lowercase for a disabled flag.  We also use the null
// output function for all cases where L and R are zero, to avoid
// unnecessary code bloat.

DEFINE_AUDIOGEN(null,  0,0,0,0,0)

DEFINE_AUDIOGEN(faslR, 0,0,0,0,1)
DEFINE_AUDIOGEN(fasLr, 0,0,0,1,0)
DEFINE_AUDIOGEN(fasLR, 0,0,0,1,1)
DEFINE_AUDIOGEN(faSlR, 0,0,1,0,1)
DEFINE_AUDIOGEN(faSLr, 0,0,1,1,0)
DEFINE_AUDIOGEN(faSLR, 0,0,1,1,1)

DEFINE_AUDIOGEN(fAslR, 0,1,0,0,1)
DEFINE_AUDIOGEN(fAsLr, 0,1,0,1,0)
DEFINE_AUDIOGEN(fAsLR, 0,1,0,1,1)
DEFINE_AUDIOGEN(fASlR, 0,1,1,0,1)
DEFINE_AUDIOGEN(fASLr, 0,1,1,1,0)
DEFINE_AUDIOGEN(fASLR, 0,1,1,1,1)

DEFINE_AUDIOGEN(FaslR, 1,0,0,0,1)
DEFINE_AUDIOGEN(FasLr, 1,0,0,1,0)
DEFINE_AUDIOGEN(FasLR, 1,0,0,1,1)
DEFINE_AUDIOGEN(FaSlR, 1,0,1,0,1)
DEFINE_AUDIOGEN(FaSLr, 1,0,1,1,0)
DEFINE_AUDIOGEN(FaSLR, 1,0,1,1,1)

DEFINE_AUDIOGEN(FAslR, 1,1,0,0,1)
DEFINE_AUDIOGEN(FAsLr, 1,1,0,1,0)
DEFINE_AUDIOGEN(FAsLR, 1,1,0,1,1)
DEFINE_AUDIOGEN(FASlR, 1,1,1,0,1)
DEFINE_AUDIOGEN(FASLr, 1,1,1,1,0)
DEFINE_AUDIOGEN(FASLR, 1,1,1,1,1)

// We don't need these anymore, so get rid of them
#undef ADDRESS
#undef ADDRESS_8BIT
#undef ENV_POS
#undef LFO_POS
#undef DEFINE_AUDIOGEN

//-------------------------------------------------------------------------

// Define the function lookup table.

static void (* FASTCALL scsp_audiogen_func_table[2][2][2][2][2])(SlotState *slot, u32 len) =
{
   {  // F==0
      {  // A==0
         {{audiogen_null, audiogen_faslR}, {audiogen_fasLr, audiogen_fasLR}},
         {{audiogen_null, audiogen_faSlR}, {audiogen_faSLr, audiogen_faSLR}}
      },
      {  // A==1
         {{audiogen_null, audiogen_fAslR}, {audiogen_fAsLr, audiogen_fAsLR}},
         {{audiogen_null, audiogen_fASlR}, {audiogen_fASLr, audiogen_fASLR}}
      }
   },
   {  // F==1
      {  // A==0
         {{audiogen_null, audiogen_FaslR}, {audiogen_FasLr, audiogen_FasLR}},
         {{audiogen_null, audiogen_FaSlR}, {audiogen_FaSLr, audiogen_FaSLR}}
      },
      {  // A==1
         {{audiogen_null, audiogen_FAslR}, {audiogen_FAsLr, audiogen_FAsLR}},
         {{audiogen_null, audiogen_FASlR}, {audiogen_FASLr, audiogen_FASLR}}
      }
   }
};

///////////////////////////////////////////////////////////////////////////
// Initialization, configuration, and cleanup routines
///////////////////////////////////////////////////////////////////////////

// ScspInit:  Initialize the SCSP emulation.  interrupt_handler should
// specify a function to handle interrupts delivered to the SCU.
// Must be called after M68KInit(); returns 0 on success, -1 on failure.

int ScspInit(int coreid, void (*interrupt_handler)(void))
{
   int i, j;
   double x;

   if ((SoundRam = T2MemoryInit(0x80000)) == NULL)
      return -1;

   // Fill in lookup tables

   for (i = 0; i < SCSP_ENV_LEN; i++)
   {
      // Attack Curve (x^4 ?)
      x = pow(((double) (SCSP_ENV_MASK - i) / SCSP_ENV_LEN), 4);
      x *= (double) SCSP_ENV_LEN;
      scsp_env_table[i] = SCSP_ENV_MASK - (s32) floor(x);

      // Decay curve (x = linear)
      scsp_env_table[i + SCSP_ENV_LEN] = SCSP_ENV_MASK - i;
   }

   for (i = 0, j = 0; i < 32; i++)
   {
      double lfo_frequency, lfo_step;
      // Frequency divider follows the pattern 1,2,3,4, 6,8,10,12, 16,...
      j += 1 << (i >> 2);
      // Base LFO frequency is 44100/256 or ~172.3 Hz
      lfo_frequency = (44100.0 / 256.0) / j;
      // Calculate LFO address step per output sample; we use a literal
      // 44100 above but OUTPUT_FREQ here in case anyone wants to try
      // upsampling the audio output someday
      lfo_step = (lfo_frequency / SCSP_OUTPUT_FREQ) * SCSP_LFO_LEN;
      scsp_lfo_step[31 - i] = round(lfo_step * (1 << SCSP_LFO_LOW_BITS));
   }

   for (i = 0; i < SCSP_LFO_LEN; i++)
   {
      // Amplitude modulation uses unsigned values which are subtracted
      // from the base envelope value
      scsp_lfo_wave_amp[SCSP_LFO_SAWTOOTH][i] = i;
      if (i < SCSP_LFO_LEN / 2)
         scsp_lfo_wave_amp[SCSP_LFO_SQUARE][i] = 0;
      else
         scsp_lfo_wave_amp[SCSP_LFO_SQUARE][i] = SCSP_LFO_MASK;
      if (i < SCSP_LFO_LEN / 2)
         scsp_lfo_wave_amp[SCSP_LFO_TRIANGLE][i] = i*2;
      else
         scsp_lfo_wave_amp[SCSP_LFO_TRIANGLE][i] = SCSP_LFO_MASK - ((i - SCSP_LFO_LEN/2) * 2);
      scsp_lfo_wave_amp[SCSP_LFO_NOISE][i] = rand() & SCSP_LFO_MASK;
      // FIXME: note that the noise generator output should be independent
      // of LFORE/LFOF

      // Frequency modulation uses signed values which are added to the
      // address counter
      if (i < SCSP_LFO_LEN / 2)
         scsp_lfo_wave_freq[SCSP_LFO_SAWTOOTH][i] = i;
      else
         scsp_lfo_wave_freq[SCSP_LFO_SAWTOOTH][i] = i - SCSP_LFO_LEN;
      if (i < SCSP_LFO_LEN / 2)
         scsp_lfo_wave_freq[SCSP_LFO_SQUARE][i] = SCSP_LFO_MASK - SCSP_LFO_LEN/2;
      else
         scsp_lfo_wave_freq[SCSP_LFO_SQUARE][i] = 0 - SCSP_LFO_LEN/2;
      if (i < SCSP_LFO_LEN / 4)
         scsp_lfo_wave_freq[SCSP_LFO_TRIANGLE][i] = i*2;
      else if (i < SCSP_LFO_LEN * 3 / 4)
         scsp_lfo_wave_freq[SCSP_LFO_TRIANGLE][i] = SCSP_LFO_MASK - i*2;
      else
         scsp_lfo_wave_freq[SCSP_LFO_TRIANGLE][i] = i*2 - SCSP_LFO_LEN*2;
      scsp_lfo_wave_freq[SCSP_LFO_NOISE][i] = scsp_lfo_wave_amp[SCSP_LFO_NOISE][i] - SCSP_LFO_LEN/2;
   }

   for (i = 0; i < 4; i++)
   {
      scsp_attack_rate[i] = 0;
      scsp_decay_rate[i] = 0;
   }
   for (i = 0; i < 60; i++)
   {
      x = 1.0 + ((i & 3) * 0.25);  // Bits 0-1: x1.00, x1.25, x1.50, x1.75
      x *= 1 << (i >> 2);          // Bits 2-5: shift bits (x2^0 - x2^15)
      x *= SCSP_ENV_LEN << SCSP_ENV_LOW_BITS; // Adjust for envelope table size

      scsp_attack_rate[i + 4] = round(x / SCSP_ATTACK_TIME);
      if (scsp_attack_rate[i + 4] == 0)
         scsp_attack_rate[i + 4] = 1;
      scsp_decay_rate[i + 4] = round(x / SCSP_DECAY_TIME);
      if (scsp_decay_rate[i + 4] == 0)
         scsp_decay_rate[i + 4] = 1;
   }
   scsp_attack_rate[63] = SCSP_ENV_ATTACK_END;
   scsp_decay_rate[61] = scsp_decay_rate[60];
   scsp_decay_rate[62] = scsp_decay_rate[60];
   scsp_decay_rate[63] = scsp_decay_rate[60];
   for (i = 64; i < 78; i++)
   {
      scsp_attack_rate[i] = scsp_attack_rate[63];
      scsp_decay_rate[i] = scsp_decay_rate[63];
   }

   for (i = 0; i < 256; i++)
      scsp_tl_table[i] = round(pow(2.0, -(i/16.0)) * (1 << SCSP_TL_BITS));

   // Initialize the SCSP state

   scsp_interrupt_handler = interrupt_handler;
   scsp_clock_inc = yabsys.IsPal ? SCSP_CLOCK_INC_PAL : SCSP_CLOCK_INC_NTSC;

   ScspReset();

   // Note that we NEVER reset the clock counter after initialization,
   // because in multithreaded mode, that would cause a race condition in
   // which the SCSP thread runs between the two assignments and detects
   // clock != clock_target, causing it to execute a huge number of cycles.
   // (We do, however, reset the accumulated fraction of a cycle inside
   // ScspReset().)
   scsp_clock = 0;
   scsp_clock_target = 0;

   // Initialize the M68K state

   if (M68K->Init() != 0)
      return -1;

   M68K->SetReadB(M68KReadByte);
   M68K->SetReadW(M68KReadWord);
   M68K->SetWriteB(M68KWriteByte);
   M68K->SetWriteW(M68KWriteWord);

   M68K->SetFetch(0x000000, 0x040000, (pointer)SoundRam);
   M68K->SetFetch(0x040000, 0x080000, (pointer)SoundRam);
   M68K->SetFetch(0x080000, 0x0C0000, (pointer)SoundRam);
   M68K->SetFetch(0x0C0000, 0x100000, (pointer)SoundRam);

   m68k_running = 0;
   m68k_execf = M68K->Exec;
   m68k_saved_cycles = 0;
   for (i = 0; i < MAX_BREAKPOINTS; i++)
      m68k_breakpoint[i].addr = 0xFFFFFFFF;
   m68k_num_breakpoints = 0;
   M68KBreakpointCallback = NULL;
   m68k_in_breakpoint = 0;

   // Set up sound output

   scsp_sound_genpos = 0;
   scsp_sound_left = 0;

   if (ScspChangeSoundCore(coreid) < 0)
      return -1;

   // Start a subthread if requested

   scsp_thread_running = 0;
   if (yabsys.UseThreads)
   {
      scsp_thread_running = 1;  // Set now so the thread doesn't quit instantly
      PSP_FLUSH_ALL();
      if (YabThreadStart(YAB_THREAD_SCSP, ScspThread, NULL) < 0)
      {
         SCSPLOG("Failed to start SCSP thread\n");
         scsp_thread_running = 0;
      }
   }

   // Successfully initialized!

   return 0;
}

//-------------------------------------------------------------------------

// ScspReset:  Reset the SCSP to its power-on state, also stopping the M68K
// processor.

void ScspReset(void)
{
   int slotnum;

   if (scsp_thread_running)
      ScspSyncThread();

   scsp.mem4mb  = 0;
   scsp.dac18b  = 0;
   scsp.ver     = 0;
   scsp.mvol    = 0;

   scsp.rbl     = 0;
   scsp.rbp     = 0;

   scsp.mofull  = 0;
   scsp.moemp   = 1;
   scsp.miovf   = 0;
   scsp.mifull  = 0;
   scsp.miemp   = 1;
   scsp.mibuf   = 0;
   scsp.mobuf   = 0;

   scsp.mslc    = 0;
   scsp.ca      = 0;

   scsp.dmea    = 0;
   scsp.drga    = 0;
   scsp.dgate   = 0;
   scsp.ddir    = 0;
   scsp.dexe    = 0;
   scsp.dtlg    = 0;

   scsp.tactl   = 0;
   scsp.tima    = 0xFF00;
   scsp.tbctl   = 0;
   scsp.timb    = 0xFF00;
   scsp.tcctl   = 0;
   scsp.timc    = 0xFF00;

   scsp.mcieb   = 0;
   scsp.mcipd   = 0;
   scsp.scilv0  = 0;
   scsp.scilv1  = 0;
   scsp.scilv2  = 0;
   scsp.scieb   = 0;
   scsp.scipd   = 0;

   memset(scsp_regcache, 0, sizeof(scsp_regcache));
   scsp_regcache[0x400>>1] = SCSP_VERSION << 4;

   memset(scsp.stack, 0, sizeof(scsp.stack));

   for (slotnum = 0; slotnum < 32; slotnum++)
   {
      memset(&scsp.slot[slotnum], 0, sizeof(scsp.slot[slotnum]));
      scsp.slot[slotnum].env_counter = SCSP_ENV_DECAY_END;  // Slot off
      scsp.slot[slotnum].outshift_l = 31;                   // Output off
      scsp.slot[slotnum].outshift_r = 31;
      scsp.slot[slotnum].audiogen = audiogen_null;
   }

   scsp.sound_ram_mask = 0x3FFFF;
   scsp_clock_frac = 0;
   scsp.sample_timer = 0;

   scsp_main_interrupt_pending = 0;
   scsp_write_buffer_size = 0;

   cdda_next_in = 0;
   cdda_next_out = 0;
   cdda_delay = CDDA_DELAY_SAMPLES;

   m68k_running = 0;

   if (scsp_thread_running)
      PSP_FLUSH_ALL();
}

//-------------------------------------------------------------------------

// ScspChangeSoundCore:  Change the module used for sound output.  Returns
// 0 on success, -1 on error.

int ScspChangeSoundCore(int coreid)
{
   int i;

   // Make sure the old core is freed
   if (SNDCore)
      SNDCore->DeInit();

   // If the default was requested, use the first core in the list
   if (coreid == SNDCORE_DEFAULT)
      SNDCore = SNDCoreList[0];
   else
   {
      // Otherwise, go through core list and find the id
      for (i = 0; SNDCoreList[i] != NULL; i++)
      {
         if (SNDCoreList[i]->id == coreid)
         {
            // Set to current core
            SNDCore = SNDCoreList[i];
            break;
         }
      }
   }

   if (SNDCore == NULL)
   {
      SNDCore = &SNDDummy;
      return -1;
   }

   if (SNDCore->Init() == -1)
   {
      // Since it failed, instead of it being fatal, we'll just use the dummy
      // core instead

      // This might be helpful though.
      YabSetError(YAB_ERR_CANNOTINIT, (void *)SNDCore->Name);

      SNDCore = &SNDDummy;
   }

   if (SNDCore)
   {
      if (scsp_mute_flags) SNDCore->MuteAudio();
      else SNDCore->UnMuteAudio();
      SNDCore->SetVolume(scsp_volume);
   }

   return 0;
}

//-------------------------------------------------------------------------

// ScspChangeVideoFormat:  Update SCSP parameters for a change in video
// format.  type is nonzero for PAL (50Hz), zero for NTSC (59.94Hz) video.
// Always returns 0 for success.

int ScspChangeVideoFormat(int type)
{
   scsp_clock_inc = yabsys.IsPal ? SCSP_CLOCK_INC_PAL : SCSP_CLOCK_INC_NTSC;

   SNDCore->ChangeVideoFormat(type ? 50 : 60);

   return 0;
}


//-------------------------------------------------------------------------

// ScspSetFrameAccurate:  Set whether sound should be generated with
// frame-accurate timing.

void ScspSetFrameAccurate(int on)
{
   scsp_frame_accurate = (on != 0);
}

//-------------------------------------------------------------------------

// ScspMuteAudio, ScspUnMuteAudio:  Mute or unmute the sound output.  Does
// not affect actual SCSP processing.

void ScspMuteAudio(int flags)
{
   scsp_mute_flags |= flags;
   if (SNDCore && scsp_mute_flags)
      SNDCore->MuteAudio();
}

void ScspUnMuteAudio(int flags)
{
   scsp_mute_flags &= ~flags;
   if (SNDCore && (scsp_mute_flags == 0))
      SNDCore->UnMuteAudio();
}

//-------------------------------------------------------------------------

// ScspSetVolume:  Set the sound output volume.  Does not affect actual
// SCSP processing.

void ScspSetVolume(int volume)
{
   scsp_volume = volume;
   if (SNDCore)
      SNDCore->SetVolume(volume);
}

//-------------------------------------------------------------------------

// ScspDeInit:  Free all resources used by the SCSP emulation.

void ScspDeInit(void)
{
   if (scsp_thread_running)
   {
      scsp_thread_running = 0;  // Tell the subthread to stop
      YabThreadWake(YAB_THREAD_SCSP);
      YabThreadWait(YAB_THREAD_SCSP);
   }

   if (SNDCore)
      SNDCore->DeInit();
   SNDCore = NULL;

   if (SoundRam)
      T2MemoryDeInit(SoundRam);
   SoundRam = NULL;
}

///////////////////////////////////////////////////////////////////////////
// Main SCSP processing routine and internal helpers
///////////////////////////////////////////////////////////////////////////

// ScspExec:  Main SCSP processing routine.  Executes (decilines/10.0)
// scanlines worth of SCSP emulation; in multithreaded mode, bumps the
// clock target by the same amount of time.

void ScspExec(int decilines)
{
   u32 new_target;

   scsp_clock_frac += scsp_clock_inc * decilines;
   new_target = scsp_clock_target + (scsp_clock_frac >> 20);
   scsp_clock_target = new_target;
   scsp_clock_frac &= 0xFFFFF;

   if (scsp_thread_running)
   {
#ifdef PSP
      if (!psp_writeback_cache_for_scsp())
          PSP_UC(scsp_clock_target) = new_target; // Push just this one through
#endif
      while (new_target - PSP_UC(scsp_clock) > SCSP_CLOCK_MAX_EXEC)
      {
         YabThreadWake(YAB_THREAD_SCSP);
         YabThreadYield();
      }
      if (PSP_UC(scsp_main_interrupt_pending))
      {
          (*scsp_interrupt_handler)();
          PSP_UC(scsp_main_interrupt_pending) = 0;
      }
   }
   else
      ScspDoExec(new_target - scsp_clock);
}

///////////////////////////////////////////////////////////////////////////

// ScspThread:  Control routine for SCSP thread.  Loops over ScspDoExec()
// and SCSP write buffer processing until told to stop.

static void ScspThread(void *arg)
{
   while (PSP_UC(scsp_thread_running))
   {
      const u8 write_size = PSP_UC(scsp_write_buffer_size);
      u32 clock_cycles;

      if (write_size != 0)
      {
         const u32 address = PSP_UC(scsp_write_buffer_address);
         const u32 data = PSP_UC(scsp_write_buffer_data);
         if (write_size == 1)
            ScspWriteByteDirect(address, data);
         else if (write_size == 2)
            ScspWriteWordDirect(address, data);
         else
         {
            ScspWriteWordDirect(address, data >> 16);
            ScspWriteWordDirect(address+2, data & 0xFFFF);
         }
         PSP_UC(scsp_write_buffer_size) = 0;
      }

      clock_cycles = PSP_UC(scsp_clock_target) - scsp_clock;
      if (clock_cycles > SCSP_CLOCK_MAX_EXEC)
         clock_cycles = SCSP_CLOCK_MAX_EXEC;
      if (clock_cycles > 0)
      {
         ScspDoExec(clock_cycles);
         YabThreadYield();
      }
      else
         YabThreadSleep();
   }
}

///////////////////////////////////////////////////////////////////////////

// ScspDoExec:  Main SCSP processing routine implementation.  Runs M68K
// code, updates timers, and generates samples for the given number of
// SCSP clock cycles.

static void ScspDoExec(u32 cycles)
{
#if 0
   s16 stereodata16[(44100 / 60) * 16]; //11760
#endif
   u32 cycles_left;
   u32 sample_count;
   u32 audio_free;


   // If any of the timer interrupts are enabled, give the M68K a chance
   // to respond to them immediately, so that music doesn't slow down if
   // the SCSP thread gets behind and executes a lot of cycles at once.
   sample_count = 0;
   cycles_left = cycles;
   while (cycles_left > 0)
   {
      u32 this_samples = 0;
      u32 this_cycles = cycles_left;
      if (scsp.scieb & (1 << SCSP_INTERRUPT_TIMER_A))
         this_cycles = MIN(this_cycles, ScspTimerCyclesLeft(scsp.tima, scsp.tactl));
      if (scsp.scieb & (1 << SCSP_INTERRUPT_TIMER_B))
         this_cycles = MIN(this_cycles, ScspTimerCyclesLeft(scsp.timb, scsp.tbctl));
      if (scsp.scieb & (1 << SCSP_INTERRUPT_TIMER_C))
         this_cycles = MIN(this_cycles, ScspTimerCyclesLeft(scsp.timc, scsp.tcctl));

      scsp.sample_timer += this_cycles;
      this_samples = scsp.sample_timer >> 8;
      scsp.sample_timer &= 0xFF;
      cycles_left -= this_cycles;
      sample_count += this_samples;

      ScspRunM68K(this_cycles);

      ScspUpdateTimer(this_samples, &scsp.tima, scsp.tactl,
                      SCSP_INTERRUPT_TIMER_A);
      ScspUpdateTimer(this_samples, &scsp.timb, scsp.tbctl,
                      SCSP_INTERRUPT_TIMER_B);
      ScspUpdateTimer(this_samples, &scsp.timc, scsp.tcctl,
                      SCSP_INTERRUPT_TIMER_C);
   }

   if (scsp_frame_accurate)
   {
      s32 *bufL, *bufR;

      // Update sound buffers
      if (scsp_sound_left + sample_count > SCSP_SOUND_BUFSIZE)
      {
         u32 overrun = (scsp_sound_left + sample_count) - SCSP_SOUND_BUFSIZE;
         SCSPLOG("WARNING: Sound buffer overrun, %u samples\n", (int)overrun);
         scsp_sound_left -= overrun;
      }
      while (sample_count > 0)
      {
         u32 this_count = sample_count;
         if (scsp_sound_genpos >= SCSP_SOUND_BUFSIZE)
            scsp_sound_genpos = 0;
         if (this_count > SCSP_SOUND_BUFSIZE - scsp_sound_genpos)
            this_count = SCSP_SOUND_BUFSIZE - scsp_sound_genpos;
         bufL = &scsp_buffer_L[scsp_sound_genpos];
         bufR = &scsp_buffer_R[scsp_sound_genpos];
         ScspGenerateAudio(bufL, bufR, this_count);
         scsp_sound_genpos += this_count;
         scsp_sound_left += this_count;
         sample_count -= this_count;
      }

      // Send audio to the output device if possible
      while (scsp_sound_left > 0 && (audio_free = SNDCore->GetAudioSpace()) > 0)
      {
         s32 out_start = (s32)scsp_sound_genpos - (s32)scsp_sound_left;
         if (out_start < 0)
            out_start += SCSP_SOUND_BUFSIZE;
         if (audio_free > scsp_sound_left)
            audio_free = scsp_sound_left;
         if (audio_free > SCSP_SOUND_BUFSIZE - out_start)
            audio_free = SCSP_SOUND_BUFSIZE - out_start;
         SNDCore->UpdateAudio((u32 *)&scsp_buffer_L[out_start],
                              (u32 *)&scsp_buffer_R[out_start], audio_free);
         scsp_sound_left -= audio_free;
#if 0
         ScspConvert32uto16s(&scsp_buffer_L[out_start], &scsp_buffer_R[out_start], (s16 *)stereodata16, audio_free);
         DRV_AviSoundUpdate(stereodata16, audio_free);
#endif
      }
   }
   else  // !scsp_frame_accurate
   {
      if ((audio_free = SNDCore->GetAudioSpace()))
      {
         if (audio_free > SCSP_SOUND_BUFSIZE)
            audio_free = SCSP_SOUND_BUFSIZE;
         ScspGenerateAudio(scsp_buffer_L, scsp_buffer_R, audio_free);
         SNDCore->UpdateAudio((u32 *)scsp_buffer_L,
                              (u32 *)scsp_buffer_R, audio_free);
#if 0
         ScspConvert32uto16s((s32 *)scsp_buffer_L, (s32 *)scsp_buffer_R, (s16 *)stereodata16, audio_free);
         DRV_AviSoundUpdate(stereodata16, audio_free);
#endif
      }
   }  // if (scsp_frame_accurate)

   // Update scsp_clock last, so the main thread can use it as a signal
   // that we've finished processing to this point
   scsp_clock += cycles;
}

//-------------------------------------------------------------------------

// ScspTimerCyclesLeft:  Return the approximate number of SCSP clock cycles
// before an SCSP timer (A, B, or C) triggers an interrupt.

static u32 ScspTimerCyclesLeft(u16 timer, u8 timer_scale)
{
   return (0xFF00 - timer) << timer_scale;
}

//----------------------------------//

// ScspUpdateTimer:  Update an SCSP timer (A, B, or C) by the given number
// of output samples, and raise an interrupt if the timer reaches 0xFF.

static void ScspUpdateTimer(u32 samples, u16 *timer_ptr, u8 timer_scale,
                            int interrupt)
{
   u32 timer_new = *timer_ptr + (samples << (8 - timer_scale));
   if (UNLIKELY(timer_new >= 0xFF00))
   {
      ScspRaiseInterrupt(interrupt, SCSP_INTTARGET_BOTH);
      timer_new -= 0xFF00;  // We won't pass 0xFF00 multiple times at once
   }
   *timer_ptr = timer_new;
}

//-------------------------------------------------------------------------

// ScspGenerateAudio:  Generate the given number of audio samples based on
// the current SCSP state, and update the sound slot counters.

static void ScspGenerateAudio(s32 *bufL, s32 *bufR, u32 samples)
{
   int slotnum;

   u32 i;
   for (i = 0; i < samples; i++)
      bufL[i] = bufR[i] = 0;

   scsp_bufL = bufL;
   scsp_bufR = bufR;
   for (slotnum = 0; slotnum < 32; slotnum++)
      ScspGenerateAudioForSlot(&scsp.slot[slotnum], samples);

   if (cdda_next_out != PSP_UC(cdda_next_in) * 2352)
   {
      if (cdda_delay > 0)
      {
         if (samples > cdda_delay)
         {
            samples -= cdda_delay;
            cdda_delay = 0;
         }
         else
         {
            cdda_delay -= samples;
            samples = 0;
         }
      }
      if (cdda_delay == 0)
         ScspGenerateAudioForCDDA(bufL, bufR, samples);
   }
   if (cdda_next_out == PSP_UC(cdda_next_in) * 2352)
      cdda_delay = CDDA_DELAY_SAMPLES;  // No data buffered, so reset delay
}

//----------------------------------//

// ScspGenerateAudioForSlot:  Generate audio samples and update counters for
// a single slot.  scsp_bufL and scsp_bufR are assumed to be set properly.

static void ScspGenerateAudioForSlot(SlotState *slot, u32 samples)
{
   if (slot->env_counter >= SCSP_ENV_DECAY_END)
      return;  // No sound is currently playing

   (*slot->audiogen)(slot, samples);
}

//----------------------------------//

// ScspGenerateAudioForCDDA:  Generate audio samples for buffered CDDA data.

static void ScspGenerateAudioForCDDA(s32 *bufL, s32 *bufR, u32 samples)
{
   // May need to wrap around the buffer, so use nested loops
   while (samples > 0)
   {
      const u32 next_out = cdda_next_out;  // Save volatile value locally
      const s32 temp = (PSP_UC(cdda_next_in) * 2352) - next_out;
      const u32 out_left = (temp < 0) ? sizeof(cdda_buf) - next_out : temp;
      const u32 this_len = (samples > out_left/4) ? out_left/4 : samples;
      const u8 *buf = &cdda_buf.data[next_out];
      const u8 *top = buf + this_len*4;

      if (this_len == 0)
         break;  // We ran out of buffered data

      for (; buf < top; buf += 4, bufL++, bufR++)
      {
         *bufL += (s32)(s16)((buf[1] << 8) | buf[0]);
         *bufR += (s32)(s16)((buf[3] << 8) | buf[2]);
      }

      if (next_out + this_len*4 >= sizeof(cdda_buf))
         cdda_next_out = 0;
      else
         cdda_next_out = next_out + this_len*4;
      samples -= this_len;
   }
}

///////////////////////////////////////////////////////////////////////////
// SCSP register/memory access and I/O interface routines
///////////////////////////////////////////////////////////////////////////

// SoundRam{Read,Write}{Byte,Word,Long}:  Read or write sound RAM.
// Intended for calling from external sources.

u8 FASTCALL SoundRamReadByte(u32 address)
{
   address &= scsp.sound_ram_mask;
   return T2ReadByte(SoundRam, address);
}

u16 FASTCALL SoundRamReadWord(u32 address)
{
   address &= scsp.sound_ram_mask;
   return T2ReadWord(SoundRam, address);
}

u32 FASTCALL SoundRamReadLong(u32 address)
{
   address &= scsp.sound_ram_mask;
   return T2ReadLong(SoundRam, address);
}

//----------------------------------//

void FASTCALL SoundRamWriteByte(u32 address, u8 data)
{
   address &= scsp.sound_ram_mask;
   T2WriteByte(SoundRam, address, data);
   M68K->WriteNotify(address, 1);
}

void FASTCALL SoundRamWriteWord(u32 address, u16 data)
{
   address &= scsp.sound_ram_mask;
   T2WriteWord(SoundRam, address, data);
   M68K->WriteNotify(address, 2);
}

void FASTCALL SoundRamWriteLong(u32 address, u32 data)
{
   address &= scsp.sound_ram_mask;
   T2WriteLong(SoundRam, address, data);
   M68K->WriteNotify(address, 4);
}

//-------------------------------------------------------------------------

// Scsp{Read,Write}{Byte,Word,Long}:  Read or write SCSP registers.
// Intended for calling from external sources.

u8 FASTCALL ScspReadByte(u32 address)
{
   const u16 data = ScspReadWord(address & ~1);
   if (address & 1)
      return data & 0xFF;
   else
      return data >> 8;
}

u16 FASTCALL ScspReadWord(u32 address)
{
#ifdef PSP  // Special handling for PSP cache management
   switch (address)
   {
      case 0x404:  // MIDI in
         return 0xFF;  // Not even supported, so don't bother trying
      case 0x408:  // CA/SGC/EG
         return ScspReadMonitor();
      default:
         return PSP_UC(scsp_regcache[address >> 1]);
   }
#else
   return ScspReadWordDirect(address & 0xFFF);
#endif
}

u32 FASTCALL ScspReadLong(u32 address)
{
   return (u32)ScspReadWord(address) << 16 | ScspReadWord(address+2);
}

//----------------------------------//

void FASTCALL ScspWriteByte(u32 address, u8 data)
{
   if (scsp_thread_running)
   {
      PSP_UC(scsp_write_buffer_address) = address & 0xFFF;
      PSP_UC(scsp_write_buffer_data) = data;
      PSP_UC(scsp_write_buffer_size) = 1;
      while (PSP_UC(scsp_write_buffer_size) != 0)
      {
         YabThreadWake(YAB_THREAD_SCSP);
         YabThreadYield();
      }
      return;
   }

   ScspWriteByteDirect(address & 0xFFF, data);
}

void FASTCALL ScspWriteWord(u32 address, u16 data)
{
   if (scsp_thread_running)
   {
      PSP_UC(scsp_write_buffer_address) = address & 0xFFF;
      PSP_UC(scsp_write_buffer_data) = data;
      PSP_UC(scsp_write_buffer_size) = 2;
      while (PSP_UC(scsp_write_buffer_size) != 0)
      {
         YabThreadWake(YAB_THREAD_SCSP);
         YabThreadYield();
      }
      return;
   }

   ScspWriteWordDirect(address & 0xFFF, data);
}

void FASTCALL ScspWriteLong(u32 address, u32 data)
{
   if (scsp_thread_running)
   {
      PSP_UC(scsp_write_buffer_address) = address & 0xFFF;
      PSP_UC(scsp_write_buffer_data) = data;
      PSP_UC(scsp_write_buffer_size) = 4;
      while (PSP_UC(scsp_write_buffer_size) != 0)
      {
         YabThreadWake(YAB_THREAD_SCSP);
         YabThreadYield();
      }
      return;
   }

   ScspWriteWordDirect(address & 0xFFF, data >> 16);
   ScspWriteWordDirect((address+2) & 0xFFF, data & 0xFFFF);
}

//-------------------------------------------------------------------------

// ScspReceiveCDDA:  Receive and buffer a sector (2352 bytes) of CDDA audio
// data.  Intended to be called by the CD driver when an audio sector has
// been read in for playback.

void ScspReceiveCDDA(const u8 *sector)
{
   const u32 next_in = cdda_next_in;  // Save volatile value locally
   const u32 next_next_in = 
      (next_in + 1) % (sizeof(cdda_buf.sectors) / sizeof(cdda_buf.sectors[0]));

   // Make sure we have room for the new sector first
   const u32 next_out = PSP_UC(cdda_next_out);
   if (next_out > next_in * 2352 && next_out <= (next_in+1) * 2352)
   {
      SCSPLOG("WARNING: CDDA buffer overflow, discarding sector\n");
      return;
   }

   memcpy(cdda_buf.sectors[next_in], sector, 2352);
   PSP_WRITEBACK_CACHE(cdda_buf.sectors[next_in], 2352);
   cdda_next_in = next_next_in;
}

///////////////////////////////////////////////////////////////////////////
// Miscellaneous SCSP interface routines
///////////////////////////////////////////////////////////////////////////

// SoundSaveState:  Save the current SCSP state to the given file.

int SoundSaveState(FILE *fp)
{
   int i;
   u32 temp;
   u8 temp8;
   int offset;
   IOCheck_struct check;

   if (scsp_thread_running)
      ScspSyncThread();

   offset = StateWriteHeader(fp, "SCSP", 2);

   // Save 68k registers first
   ywrite(&check, (void *)&m68k_running, 1, 1, fp);
   for (i = 0; i < 8; i++)
   {
      temp = M68K->GetDReg(i);
      ywrite(&check, (void *)&temp, 4, 1, fp);
   }
   for (i = 0; i < 8; i++)
   {
      temp = M68K->GetAReg(i);
      ywrite(&check, (void *)&temp, 4, 1, fp);
   }
   temp = M68K->GetSR();
   ywrite(&check, (void *)&temp, 4, 1, fp);
   temp = M68K->GetPC();
   ywrite(&check, (void *)&temp, 4, 1, fp);

   // Now for the SCSP registers
   ywrite(&check, (void *)scsp_regcache, 0x1000, 1, fp);

   // Sound RAM is important
   ywrite(&check, (void *)SoundRam, 0x80000, 1, fp);

   // Write slot internal variables
   for (i = 0; i < 32; i++)
   {
      ywrite(&check, (void *)&scsp.slot[i].key, 1, 1, fp);
      ywrite(&check, (void *)&scsp.slot[i].addr_counter, 4, 1, fp);
      ywrite(&check, (void *)&scsp.slot[i].env_counter, 4, 1, fp);
      ywrite(&check, (void *)&scsp.slot[i].env_step, 4, 1, fp);
      ywrite(&check, (void *)&scsp.slot[i].env_target, 4, 1, fp);
      ywrite(&check, (void *)&scsp.slot[i].env_phase, 4, 1, fp);

      // Was enxt in scsp1; we don't use it, so just derive the proper
      // value from env_phase
      if (scsp.slot[i].env_phase == SCSP_ENV_RELEASE)
         temp8 = 1;
      else if (scsp.slot[i].env_phase == SCSP_ENV_SUSTAIN)
         temp8 = 2;
      else if (scsp.slot[i].env_phase == SCSP_ENV_DECAY)
         temp8 = 3;
      else if (scsp.slot[i].env_phase == SCSP_ENV_ATTACK)
         temp8 = 4;
      else  // impossible, but avoid "undefined value" warnings
         temp8 = 0;
      ywrite(&check, (void *)&temp8, 1, 1, fp);

      ywrite(&check, (void *)&scsp.slot[i].lfo_counter, 4, 1, fp);
      ywrite(&check, (void *)&scsp.slot[i].lfo_step, 4, 1, fp);
   }

   // Write main internal variables
   // FIXME/SCSP1: need to write a lot of these from temporary variables
   // to maintain save state compatibility
   temp = scsp.mem4mb;
   ywrite(&check, (void *)&temp, 4, 1, fp);
   temp = scsp.mvol;
   ywrite(&check, (void *)&temp, 4, 1, fp);

   temp = scsp.rbl;
   ywrite(&check, (void *)&temp, 4, 1, fp);
   ywrite(&check, (void *)&scsp.rbp, 4, 1, fp);

   temp = scsp.mslc;
   ywrite(&check, (void *)&temp, 4, 1, fp);

   ywrite(&check, (void *)&scsp.dmea, 4, 1, fp);
   temp = scsp.drga;
   ywrite(&check, (void *)&temp, 4, 1, fp);
   temp = scsp.dgate<<6 | scsp.ddir<<5 | scsp.dexe<<4;
   ywrite(&check, (void *)&temp, 4, 1, fp);
   temp = scsp.dtlg;
   ywrite(&check, (void *)&temp, 4, 1, fp);

   ywrite(&check, (void *)scsp.midi_in_buf, 1, 4, fp);
   ywrite(&check, (void *)scsp.midi_out_buf, 1, 4, fp);
   ywrite(&check, (void *)&scsp.midi_in_cnt, 1, 1, fp);
   ywrite(&check, (void *)&scsp.midi_out_cnt, 1, 1, fp);
   temp8 = scsp.mofull<<4 | scsp.moemp<<3
         | scsp.miovf<<2 | scsp.mifull<<1 | scsp.miemp<<0;
   ywrite(&check, (void *)&temp8, 1, 1, fp);

   temp = scsp.tima;
   ywrite(&check, (void *)&temp, 4, 1, fp);
   temp = scsp.tactl;
   ywrite(&check, (void *)&temp, 4, 1, fp);
   temp = scsp.timb;
   ywrite(&check, (void *)&temp, 4, 1, fp);
   temp = scsp.tbctl;
   ywrite(&check, (void *)&temp, 4, 1, fp);
   temp = scsp.timc;
   ywrite(&check, (void *)&temp, 4, 1, fp);
   temp = scsp.tcctl;
   ywrite(&check, (void *)&temp, 4, 1, fp);

   temp = scsp.scieb;
   ywrite(&check, (void *)&temp, 4, 1, fp);
   temp = scsp.scipd;
   ywrite(&check, (void *)&temp, 4, 1, fp);
   temp = scsp.scilv0;
   ywrite(&check, (void *)&temp, 4, 1, fp);
   temp = scsp.scilv1;
   ywrite(&check, (void *)&temp, 4, 1, fp);
   temp = scsp.scilv2;
   ywrite(&check, (void *)&temp, 4, 1, fp);
   temp = scsp.mcieb;
   ywrite(&check, (void *)&temp, 4, 1, fp);
   temp = scsp.mcipd;
   ywrite(&check, (void *)&temp, 4, 1, fp);

   ywrite(&check, (void *)scsp.stack, 4, 32 * 2, fp);

   return StateFinishHeader(fp, offset);
}

//-------------------------------------------------------------------------

// SoundLoadState:  Load the current SCSP state from the given file.

int SoundLoadState(FILE *fp, int version, int size)
{
   int i, i2;
   u32 temp;
   u8 temp8;
   IOCheck_struct check;

   if (scsp_thread_running)
      ScspSyncThread();

   // Read 68k registers first
   yread(&check, (void *)&m68k_running, 1, 1, fp);
   for (i = 0; i < 8; i++)
   {
      yread(&check, (void *)&temp, 4, 1, fp);
      M68K->SetDReg(i, temp);
   }
   for (i = 0; i < 8; i++)
   {
      yread(&check, (void *)&temp, 4, 1, fp);
      M68K->SetAReg(i, temp);
   }
   yread(&check, (void *)&temp, 4, 1, fp);
   M68K->SetSR(temp);
   yread(&check, (void *)&temp, 4, 1, fp);
   M68K->SetPC(temp);

   // Now for the SCSP registers
   yread(&check, (void *)scsp_regcache, 0x1000, 1, fp);

   // And sound RAM
   yread(&check, (void *)SoundRam, 0x80000, 1, fp);

   // Break out slot registers into their respective fields
   for (i = 0; i < 32; i++)
   {
      for (i2 = 0; i2 < 0x18; i2 += 2)
         ScspWriteWordDirect(i<<5 | i2, scsp_regcache[(i<<5 | i2) >> 1]);
      // These are also called during writes, so they're not technically
      // necessary, but call them again anyway just to ensure everything's
      // up to date
      ScspUpdateSlotAddress(&scsp.slot[i]);
      ScspUpdateSlotFunc(&scsp.slot[i]);
   }

   if (version > 1)
   {
      // Read slot internal variables
      for (i = 0; i < 32; i++)
      {
         yread(&check, (void *)&scsp.slot[i].key, 1, 1, fp);
         yread(&check, (void *)&scsp.slot[i].addr_counter, 4, 1, fp);
         yread(&check, (void *)&scsp.slot[i].env_counter, 4, 1, fp);
         yread(&check, (void *)&scsp.slot[i].env_step, 4, 1, fp);
         yread(&check, (void *)&scsp.slot[i].env_target, 4, 1, fp);
         yread(&check, (void *)&scsp.slot[i].env_phase, 4, 1, fp);

         // Was enxt in scsp1; we don't use it, so just read and ignore
         yread(&check, (void *)&temp8, 1, 1, fp);

         yread(&check, (void *)&scsp.slot[i].lfo_counter, 4, 1, fp);
         yread(&check, (void *)&scsp.slot[i].lfo_step, 4, 1, fp);
      }

      // Read main internal variables
      yread(&check, (void *)&temp, 4, 1, fp);
      scsp.mem4mb = temp;
      // This one isn't saved in the state file (though it's not used anyway)
      scsp.dac18b = (scsp_regcache[0x400>>1] >> 8) & 1;
      yread(&check, (void *)&temp, 4, 1, fp);
      scsp.mvol = temp;

      yread(&check, (void *)&temp, 4, 1, fp);
      scsp.rbl = temp;
      yread(&check, (void *)&scsp.rbp, 4, 1, fp);

      yread(&check, (void *)&temp, 4, 1, fp);
      scsp.mslc = temp;

      yread(&check, (void *)&scsp.dmea, 4, 1, fp);
      yread(&check, (void *)&temp, 4, 1, fp);
      scsp.drga = temp;
      yread(&check, (void *)&temp, 4, 1, fp);
      scsp.dgate = temp>>6 & 1;
      scsp.ddir  = temp>>5 & 1;
      scsp.dexe  = temp>>4 & 1;
      yread(&check, (void *)&temp, 4, 1, fp);
      scsp.dtlg = temp;

      yread(&check, (void *)scsp.midi_in_buf, 1, 4, fp);
      yread(&check, (void *)scsp.midi_out_buf, 1, 4, fp);
      yread(&check, (void *)&scsp.midi_in_cnt, 1, 1, fp);
      yread(&check, (void *)&scsp.midi_out_cnt, 1, 1, fp);
      yread(&check, (void *)&temp8, 1, 1, fp);
      scsp.mofull = temp8>>4 & 1;
      scsp.moemp  = temp8>>3 & 1;
      scsp.miovf  = temp8>>2 & 1;
      scsp.mifull = temp8>>1 & 1;
      scsp.miemp  = temp8>>0 & 1;

      yread(&check, (void *)&temp, 4, 1, fp);
      scsp.tima = temp;
      yread(&check, (void *)&temp, 4, 1, fp);
      scsp.tactl = temp;
      yread(&check, (void *)&temp, 4, 1, fp);
      scsp.timb = temp;
      yread(&check, (void *)&temp, 4, 1, fp);
      scsp.tbctl = temp;
      yread(&check, (void *)&temp, 4, 1, fp);
      scsp.timc = temp;
      yread(&check, (void *)&temp, 4, 1, fp);
      scsp.tcctl = temp;

      yread(&check, (void *)&temp, 4, 1, fp);
      scsp.scieb = temp;
      yread(&check, (void *)&temp, 4, 1, fp);
      scsp.scipd = temp;
      yread(&check, (void *)&temp, 4, 1, fp);
      scsp.scilv0 = temp;
      yread(&check, (void *)&temp, 4, 1, fp);
      scsp.scilv1 = temp;
      yread(&check, (void *)&temp, 4, 1, fp);
      scsp.scilv2 = temp;
      yread(&check, (void *)&temp, 4, 1, fp);
      scsp.mcieb = temp;
      yread(&check, (void *)&temp, 4, 1, fp);
      scsp.mcipd = temp;

      yread(&check, (void *)scsp.stack, 4, 32 * 2, fp);
   }

   if (scsp_thread_running)
      PSP_FLUSH_ALL();

   return size;
}

//-------------------------------------------------------------------------

// ScspSlotDebugStats:  Generate a string describing the given slot's state
// and store it in the passed-in buffer (which is assumed to be large enough
// to hold the result).

// Helper functions (defined below)
static char *AddSoundLFO(char *outstring, const char *string, u16 level, u16 waveform);
static char *AddSoundPan(char *outstring, u16 pan);
static char *AddSoundLevel(char *outstring, u16 level);

void ScspSlotDebugStats(u8 slotnum, char *outstring)
{
   AddString(outstring, "Sound Source = ");
   switch (scsp.slot[slotnum].ssctl)
   {
      case 0:
      {
         AddString(outstring, "External DRAM data\r\n");
         break;
      }
      case 1:
      {
         AddString(outstring, "Internal(Noise)\r\n");
         break;
      }
      case 2:
      {
         AddString(outstring, "Internal(0's)\r\n");
         break;
      }
      default:
      {
         AddString(outstring, "Invalid setting\r\n");
         break;
      }
   }
   AddString(outstring, "Source bit = ");
   switch (scsp.slot[slotnum].sbctl)
   {
      case 0:
      {
         AddString(outstring, "No bit reversal\r\n");
         break;
      }
      case 1:
      {
         AddString(outstring, "Reverse other bits\r\n");
         break;
      }
      case 2:
      {
         AddString(outstring, "Reverse sign bit\r\n");
         break;
      }
      case 3:
      {
         AddString(outstring, "Reverse sign and other bits\r\n");
         break;
      }
   }

   // Loop Control
   AddString(outstring, "Loop Mode = ");
   switch (scsp.slot[slotnum].lpctl)
   {
      case 0:
      {
         AddString(outstring, "Off\r\n");
         break;
      }
      case 1:
      {
         AddString(outstring, "Normal\r\n");
         break;
      }
      case 2:
      {
         AddString(outstring, "Reverse\r\n");
         break;
      }
      case 3:
      {
         AddString(outstring, "Alternating\r\n");
         break;
      }
   }
   // PCM8B
   if (scsp.slot[slotnum].pcm8b)
   {
      AddString(outstring, "8-bit samples\r\n");
   }
   else
   {
      AddString(outstring, "16-bit samples\r\n");
   }

   AddString(outstring, "Start Address = %05lX\r\n", (unsigned long)scsp.slot[slotnum].sa);
   AddString(outstring, "Loop Start Address = %04X\r\n", scsp.slot[slotnum].lsa);
   AddString(outstring, "Loop End Address = %04X\r\n", scsp.slot[slotnum].lea);
   AddString(outstring, "Decay 1 Rate = %d\r\n", scsp.slot[slotnum].dr);
   AddString(outstring, "Decay 2 Rate = %d\r\n", scsp.slot[slotnum].sr);
   if (scsp.slot[slotnum].eghold)
   {
      AddString(outstring, "EG Hold Enabled\r\n");
   }
   AddString(outstring, "Attack Rate = %d\r\n", scsp.slot[slotnum].ar);

   if (scsp.slot[slotnum].lpslnk)
   {
      AddString(outstring, "Loop Start Link Enabled\r\n");
   }

   if (scsp.slot[slotnum].krs != 0)
   {
      AddString(outstring, "Key rate scaling = %d\r\n", scsp.slot[slotnum].krs);
   }

   AddString(outstring, "Decay Level = %d\r\n", scsp.slot[slotnum].sl);
   AddString(outstring, "Release Rate = %d\r\n", scsp.slot[slotnum].rr);

   if (scsp.slot[slotnum].stwinh)
   {
      AddString(outstring, "Stack Write Inhibited\r\n");
   }

   if (scsp.slot[slotnum].sdir)
   {
      AddString(outstring, "Sound Direct Enabled\r\n");
   }

   AddString(outstring, "Total Level = %d\r\n", scsp.slot[slotnum].tl);

   AddString(outstring, "Modulation Level = %d\r\n", scsp.slot[slotnum].mdl);
   AddString(outstring, "Modulation Input X = %d\r\n", scsp.slot[slotnum].mdx);
   AddString(outstring, "Modulation Input Y = %d\r\n", scsp.slot[slotnum].mdy);

   AddString(outstring, "Octave = %d\r\n", scsp.slot[slotnum].oct);
   AddString(outstring, "Frequency Number Switch = %d\r\n", scsp.slot[slotnum].fns);

   AddString(outstring, "LFO Reset = %s\r\n", scsp.slot[slotnum].lfore ? "TRUE" : "FALSE");
   AddString(outstring, "LFO Frequency = %d\r\n", scsp.slot[slotnum].lfof);
   outstring = AddSoundLFO(outstring, "LFO Frequency modulation waveform =",
                           scsp.slot[slotnum].plfos, scsp.slot[slotnum].plfows);
   AddString(outstring, "LFO Frequency modulation level = %d\r\n", scsp.slot[slotnum].plfos);
   outstring = AddSoundLFO(outstring, "LFO Amplitude modulation waveform =",
                           scsp.slot[slotnum].alfos, scsp.slot[slotnum].alfows);
   AddString(outstring, "LFO Amplitude modulation level = %d\r\n", scsp.slot[slotnum].alfos);

   AddString(outstring, "Input mix level = ");
   outstring = AddSoundLevel(outstring, scsp.slot[slotnum].imxl);
   AddString(outstring, "Input Select = %d\r\n", scsp.slot[slotnum].isel);

   AddString(outstring, "Direct data send level = ");
   outstring = AddSoundLevel(outstring, scsp.slot[slotnum].disdl);
   AddString(outstring, "Direct data panpot = ");
   outstring = AddSoundPan(outstring, scsp.slot[slotnum].dipan);

   AddString(outstring, "Effect data send level = ");
   outstring = AddSoundLevel(outstring, scsp.slot[slotnum].efsdl);
   AddString(outstring, "Effect data panpot = ");
   outstring = AddSoundPan(outstring, scsp.slot[slotnum].efpan);
}

//----------------------------------//

static char *AddSoundLFO(char *outstring, const char *string, u16 level, u16 waveform)
{
   if (level > 0)
   {
      switch (waveform)
      {
         case 0:
            AddString(outstring, "%s Sawtooth\r\n", string);
            break;
         case 1:
            AddString(outstring, "%s Square\r\n", string);
            break;
         case 2:
            AddString(outstring, "%s Triangle\r\n", string);
            break;
         case 3:
            AddString(outstring, "%s Noise\r\n", string);
            break;
      }
   }

   return outstring;
}

//----------------------------------//

static char *AddSoundPan(char *outstring, u16 pan)
{
   if (pan == 0x0F)
   {
      AddString(outstring, "Left = -MAX dB, Right = -0 dB\r\n");
   }
   else if (pan == 0x1F)
   {
      AddString(outstring, "Left = -0 dB, Right = -MAX dB\r\n");
   }
   else
   {
      AddString(outstring, "Left = -%d dB, Right = -%d dB\r\n", (pan & 0xF) * 3, (pan >> 4) * 3);
   }

   return outstring;
}

//----------------------------------//

static char *AddSoundLevel(char *outstring, u16 level)
{
   if (level == 0)
   {
      AddString(outstring, "-MAX dB\r\n");
   }
   else
   {
      AddString(outstring, "-%d dB\r\n", (7-level) *  6);
   }

   return outstring;
}

//-------------------------------------------------------------------------

// ScspCommonControlRegisterDebugStats:  Generate a string describing the
// SCSP common state registers and store it in the passed-in buffer (which
// is assumed to be large enough to hold the result).

void ScspCommonControlRegisterDebugStats(char *outstring)
{
   AddString(outstring, "Memory: %s\r\n", scsp.mem4mb ? "4 Mbit" : "2 Mbit");
   AddString(outstring, "Master volume: %d\r\n", scsp.mvol);
   AddString(outstring, "Ring buffer length: %d\r\n", scsp.rbl);
   AddString(outstring, "Ring buffer address: %08lX\r\n", (unsigned long)scsp.rbp);
   AddString(outstring, "\r\n");

   AddString(outstring, "Slot Status Registers\r\n");
   AddString(outstring, "-----------------\r\n");
   AddString(outstring, "Monitor slot: %d\r\n", scsp.mslc);
   AddString(outstring, "Call address: %d\r\n", (ScspReadWordDirect(0x408) >> 7) & 0xF);
   AddString(outstring, "\r\n");

   AddString(outstring, "DMA Registers\r\n");
   AddString(outstring, "-----------------\r\n");
   AddString(outstring, "DMA memory address start: %08lX\r\n", (unsigned long)scsp.dmea);
   AddString(outstring, "DMA register address start: %03X\r\n", scsp.drga);
   AddString(outstring, "DMA Flags: %02X (%cDGATE %cDDIR %cDEXE)\r\n",
             scsp.dgate<<6 | scsp.ddir<<5 | scsp.dexe<<4,
             scsp.dgate ? '+' : '-', scsp.ddir ? '+' : '-',
             scsp.dexe ? '+' : '-');
   AddString(outstring, "\r\n");

   AddString(outstring, "Timer Registers\r\n");
   AddString(outstring, "-----------------\r\n");
   AddString(outstring, "Timer A counter: %02X\r\n", scsp.tima >> 8);
   AddString(outstring, "Timer A increment: Every %d sample(s)\r\n", 1 << scsp.tactl);
   AddString(outstring, "Timer B counter: %02X\r\n", scsp.timb >> 8);
   AddString(outstring, "Timer B increment: Every %d sample(s)\r\n", 1 << scsp.tbctl);
   AddString(outstring, "Timer C counter: %02X\r\n", scsp.timc >> 8);
   AddString(outstring, "Timer C increment: Every %d sample(s)\r\n", 1 << scsp.tcctl);
   AddString(outstring, "\r\n");

   AddString(outstring, "Interrupt Registers\r\n");
   AddString(outstring, "-----------------\r\n");
   AddString(outstring, "Sound cpu interrupt pending: %04X\r\n", scsp.scipd);
   AddString(outstring, "Sound cpu interrupt enable: %04X\r\n", scsp.scieb);
   AddString(outstring, "Sound cpu interrupt level 0: %04X\r\n", scsp.scilv0);
   AddString(outstring, "Sound cpu interrupt level 1: %04X\r\n", scsp.scilv1);
   AddString(outstring, "Sound cpu interrupt level 2: %04X\r\n", scsp.scilv2);
   AddString(outstring, "Main cpu interrupt pending: %04X\r\n", scsp.mcipd);
   AddString(outstring, "Main cpu interrupt enable: %04X\r\n", scsp.mcieb);
   AddString(outstring, "\r\n");
}

//-------------------------------------------------------------------------

// ScspSlotDebugSaveRegisters:  Write the values of a single slot's
// registers to a file.

int ScspSlotDebugSaveRegisters(u8 slotnum, const char *filename)
{
   FILE *fp;
   int i;
   IOCheck_struct check;

   if ((fp = fopen(filename, "wb")) == NULL)
      return -1;

   for (i = (slotnum * 0x20); i < ((slotnum+1) * 0x20); i += 2)
   {
#ifdef WORDS_BIGENDIAN
      ywrite(&check, (void *)&scsp_regcache[i], 1, 2, fp);
#else
      ywrite(&check, (void *)&scsp_regcache[i+1], 1, 1, fp);
      ywrite(&check, (void *)&scsp_regcache[i], 1, 1, fp);
#endif
   }

   fclose(fp);
   return 0;
}

//-------------------------------------------------------------------------

// ScspSlotDebugAudioSaveWav:  Generate audio for a single slot and save it
// to a WAV file.

// Helper function to generate audio (defined below)
static u32 ScspSlotDebugAudio(SlotState *slot, s32 *workbuf, s16 *buf, u32 len);

int ScspSlotDebugAudioSaveWav(u8 slotnum, const char *filename)
{
   typedef struct {
      char id[4];
      u32 size;
   } chunk_struct;

   typedef struct {
      chunk_struct riff;
      char rifftype[4];
   } waveheader_struct;

   typedef struct {
      chunk_struct chunk;
      u16 compress;
      u16 numchan;
      u32 rate;
      u32 bytespersec;
      u16 blockalign;
      u16 bitspersample;
   } fmt_struct;

   s32 workbuf[512*2*2];
   s16 buf[512*2];
   SlotState slot;
   FILE *fp;
   u32 counter = 0;
   waveheader_struct waveheader;
   fmt_struct fmt;
   chunk_struct data;
   long length;
   IOCheck_struct check;

   if (scsp.slot[slotnum].lea == 0)
      return 0;

   if ((fp = fopen(filename, "wb")) == NULL)
      return -1;

   // Do wave header
   memcpy(waveheader.riff.id, "RIFF", 4);
   waveheader.riff.size = 0; // we'll fix this after the file is closed
   memcpy(waveheader.rifftype, "WAVE", 4);
   ywrite(&check, (void *)&waveheader, 1, sizeof(waveheader_struct), fp);

   // fmt chunk
   memcpy(fmt.chunk.id, "fmt ", 4);
   fmt.chunk.size = 16; // we'll fix this at the end
   fmt.compress = 1; // PCM
   fmt.numchan = 2; // Stereo
   fmt.rate = 44100;
   fmt.bitspersample = 16;
   fmt.blockalign = fmt.bitspersample / 8 * fmt.numchan;
   fmt.bytespersec = fmt.rate * fmt.blockalign;
   ywrite(&check, (void *)&fmt, 1, sizeof(fmt_struct), fp);

   // data chunk
   memcpy(data.id, "data", 4);
   data.size = 0; // we'll fix this at the end
   ywrite(&check, (void *)&data, 1, sizeof(chunk_struct), fp);

   memcpy(&slot, &scsp.slot[slotnum], sizeof(slot));

   // Clear out the phase counter, etc.
   slot.addr_counter = 0;
   slot.env_counter = SCSP_ENV_ATTACK_START;
   slot.env_step = slot.env_step_a;
   slot.env_target = SCSP_ENV_ATTACK_END;
   slot.env_phase = SCSP_ENV_ATTACK;

   // Mix the audio, and then write it to the file
   for(;;)
   {
      if (ScspSlotDebugAudio(&slot, workbuf, buf, 512) == 0)
         break;

      counter += 512;
      ywrite(&check, (void *)buf, 2, 512 * 2, fp);
      if (slot.lpctl != 0 && counter >= (44100 * 2 * 5))
         break;
   }

   length = ftell(fp);

   // Let's fix the riff chunk size and the data chunk size
   fseek(fp, sizeof(waveheader_struct)-0x8, SEEK_SET);
   length -= 0x4;
   ywrite(&check, (void *)&length, 1, 4, fp);

   fseek(fp, sizeof(waveheader_struct)+sizeof(fmt_struct)+0x4, SEEK_SET);
   length -= sizeof(waveheader_struct)+sizeof(fmt_struct);
   ywrite(&check, (void *)&length, 1, 4, fp);
   fclose(fp);
   return 0;
}

//----------------------------------//

static u32 ScspSlotDebugAudio(SlotState *slot, s32 *workbuf, s16 *buf, u32 len)
{
   s32 *bufL, *bufR;

   bufL = workbuf;
   bufR = workbuf+len;
   scsp_bufL = bufL;
   scsp_bufR = bufR;

   if (slot->env_counter >= SCSP_ENV_DECAY_END)
      return 0;  // Not playing

   if (slot->ssctl)
      return 0; // not yet supported!

   memset(bufL, 0, sizeof(u32) * len);
   memset(bufR, 0, sizeof(u32) * len);
   ScspGenerateAudioForSlot(slot, len);
   ScspConvert32uto16s(bufL, bufR, buf, len);
   return len;
}

//-------------------------------------------------------------------------

// ScspConvert32uto16s:  Saturate two 32-bit input sample buffers to 16-bit
// and interleave them into a single output buffer.

void ScspConvert32uto16s(s32 *srcL, s32 *srcR, s16 *dest, u32 len)
{
   u32 i;

   for (i = 0; i < len; i++, srcL++, srcR++, dest += 2)
   {
      // Left channel
      if (*srcL > 0x7FFF)
         dest[0] = 0x7FFF;
      else if (*srcL < -0x8000)
         dest[0] = -0x8000;
      else
         dest[0] = *srcL;
      // Right channel
      if (*srcR > 0x7FFF)
         dest[1] = 0x7FFF;
      else if (*srcR < -0x8000)
         dest[1] = -0x8000;
      else
         dest[1] = *srcR;
   }
}

///////////////////////////////////////////////////////////////////////////
// SCSP register read/write routines and internal helpers
///////////////////////////////////////////////////////////////////////////

// Scsp{Read,Write}{Byte,Word}Direct:  Perform an SCSP register read or
// write.  These are internal routines that implement the actual register
// read/write logic.  The address must be in the range [0,0xFFF].

static u8 FASTCALL ScspReadByteDirect(u32 address)
{
   const u16 data = ScspReadWordDirect(address & ~1);
   if (address & 1)
      return data & 0xFF;
   else
      return data >> 8;
}

//----------------------------------//

static u16 ScspReadMonitor(void)
{
   u8 ca, sgc, eg;

   ca = (scsp.slot[scsp.mslc].addr_counter >> (SCSP_FREQ_LOW_BITS + 12)) & 0xF;

   switch (scsp.slot[scsp.mslc].env_phase) {
      case SCSP_ENV_ATTACK:
         sgc = 0;
         break;
      case SCSP_ENV_DECAY:
         sgc = 1;
         break;
      case SCSP_ENV_SUSTAIN:
         sgc = 2;
         break;
      case SCSP_ENV_RELEASE:
         sgc = 3;
         break;
   }

   eg = 0x1f - (scsp.slot[scsp.mslc].last_env >> 27);

   return (ca << 7) | (sgc << 5) | eg;
}

static u16 FASTCALL ScspReadWordDirect(u32 address)
{
   switch (address)
   {
      case 0x404:  // MIDI in
         return ScspMidiIn();
      case 0x408:  // CA/SGC/EG
         return ScspReadMonitor();
      default:
         return PSP_UC(scsp_regcache[address >> 1]);
   }
}

//----------------------------------//

static void FASTCALL ScspWriteByteDirect(u32 address, u8 data)
{
   switch (address >> 8)
   {
      case 0x0:
      case 0x1:
      case 0x2:
      case 0x3:
      write_as_word:
      {
         // These can be treated as word writes, borrowing the missing
         // 8 bits from the register cache
         u16 word_data;
         if (address & 1)
            word_data = (PSP_UC(scsp_regcache[address >> 1]) & 0xFF00) | data;
         else
            word_data = (PSP_UC(scsp_regcache[address >> 1]) & 0x00FF) | (data << 8);
         ScspWriteWordDirect(address & ~1, word_data);
         return;
      }

      case 0x4:
         switch (address & 0xFF)
         {
            // FIXME: if interrupts are only triggered on 0->1 changes in
            // [SM]CIEB, we can skip 0x1E/0x1F/0x26/0x27 (see FIXME in
            // ScspWriteWordDirect())

            case 0x1E:
               data &= 0x07;
               scsp.scieb = (data << 8) | (scsp.scieb & 0x00FF);
               ScspCheckInterrupts(0x700, SCSP_INTTARGET_SOUND);
               break;

            case 0x1F:
               scsp.scieb = (scsp.scieb & 0xFF00) | data;
               ScspCheckInterrupts(0x700, SCSP_INTTARGET_SOUND);
               break;

            case 0x20:
               return;  // Not writable

            case 0x21:
               if (data & (1<<5))
                  ScspRaiseInterrupt(5, SCSP_INTTARGET_SOUND);
               return;  // Not writable

            case 0x2A:
               data &= 0x07;
               scsp.mcieb = (data << 8) | (scsp.mcieb & 0x00FF);
               ScspCheckInterrupts(0x700, SCSP_INTTARGET_MAIN);
               break;

            case 0x2B:
               scsp.mcieb = (scsp.mcieb & 0xFF00) | data;
               ScspCheckInterrupts(0x700, SCSP_INTTARGET_MAIN);
               break;

            case 0x2C:
               return;  // Not writable

            case 0x2D:
               if (data & (1<<5))
                  ScspRaiseInterrupt(5, SCSP_INTTARGET_MAIN);
               return;  // Not writable

            case 0x00:
            case 0x01:
            case 0x02:
            case 0x03:
            case 0x04:
            case 0x05:
            case 0x06:
            case 0x07:
            case 0x08:
            case 0x09:
            case 0x12:
            case 0x13:
            case 0x14:
            case 0x15:
            case 0x16:
            case 0x17:
            case 0x18:
            case 0x19:
            case 0x1A:
            case 0x1B:
            case 0x1C:
            case 0x1D:
            case 0x22:
            case 0x23:
            case 0x24:
            case 0x25:
            case 0x26:
            case 0x27:
            case 0x28:
            case 0x29:
            case 0x2E:
            case 0x2F:
               goto write_as_word;

            default:
               goto unhandled_write;
         }
         break;

      default:
      unhandled_write:
         SCSPLOG("ScspWriteByteDirect(): unhandled write %02X to 0x%03X\n",
                 data, address);
         break;
   }

   if (address & 1)
   {
      PSP_UC(scsp_regcache[address >> 1]) &= 0xFF00;
      PSP_UC(scsp_regcache[address >> 1]) |= data;
   }
   else
   {
      PSP_UC(scsp_regcache[address >> 1]) &= 0x00FF;
      PSP_UC(scsp_regcache[address >> 1]) |= data << 8;
   }
}

//----------------------------------//

static void FASTCALL ScspWriteWordDirect(u32 address, u16 data)
{
   switch (address >> 8)
   {
      case 0x0:
      case 0x1:
      case 0x2:
      case 0x3:
      {
         const int slotnum = (address & 0x3E0) >> 5;
         SlotState *slot = &scsp.slot[slotnum];
         switch (address & 0x1F)
         {
            case 0x00:
               slot->key    = (data >> 11) & 0x1;
               slot->sbctl  = (data >>  9) & 0x3;
               slot->ssctl  = (data >>  7) & 0x3;
               slot->lpctl  = (data >>  5) & 0x3;
               slot->pcm8b  = (data >>  4) & 0x1;
               slot->sa     =((data >>  0) & 0xF) << 16 | (slot->sa & 0xFFFF);

               ScspUpdateSlotFunc(slot);
               if (slot->env_counter < SCSP_ENV_DECAY_END)
                  ScspUpdateSlotAddress(slot);

               if (data & (1<<12))
                  ScspDoKeyOnOff();

               data &= 0x0FFF;  // Don't save KYONEX
               break;

            case 0x02:
               slot->sa     = (slot->sa & 0xF0000) | data;
               if (slot->env_counter < SCSP_ENV_DECAY_END)
                  ScspUpdateSlotAddress(slot);
               break;

            case 0x04:
               slot->lsa    = data;
               if (slot->env_counter < SCSP_ENV_DECAY_END)
                  ScspUpdateSlotAddress(slot);
               break;

            case 0x06:
               slot->lea    = data;
               if (slot->env_counter < SCSP_ENV_DECAY_END)
                  ScspUpdateSlotAddress(slot);
               break;

            case 0x08:
               slot->sr     = (data >> 11) & 0x1F;
               slot->dr     = (data >>  6) & 0x1F;
               slot->eghold = (data >>  5) & 0x1;
               slot->ar     = (data >>  0) & 0x1F;
               ScspUpdateSlotEnv(slot);
               break;

            case 0x0A:
               data &= 0x7FFF;
               slot->lpslnk = (data >> 14) & 0x1;
               slot->krs    = (data >> 10) & 0xF;
               slot->sl     = (data >>  5) & 0x1F;
               slot->rr     = (data >>  0) & 0x1F;

               if (slot->krs == 0xF)
                  slot->krs_shift = 4;
               else
                  slot->krs_shift = slot->krs >> 2;

               ScspUpdateSlotEnv(slot);

               slot->sl_target = (slot->sl << (5 + SCSP_ENV_LOW_BITS))
                                 + SCSP_ENV_DECAY_START;

               break;

            case 0x0C:
               data &= 0x03FF;
               slot->stwinh = (data >>  9) & 0x1;
               slot->sdir   = (data >>  8) & 0x1;
               slot->tl     = (data >>  0) & 0xFF;

               slot->tl_mult = scsp_tl_table[slot->tl];

               break;

            case 0x0E:
               slot->mdl    = (data >> 12) & 0xF;
               slot->mdx    = (data >>  6) & 0x3F;
               slot->mdy    = (data >>  0) & 0x3F;
               break;

            case 0x10:
               data &= 0x7BFF;
               slot->oct    = (data >> 11) & 0xF;
               slot->fns    = (data >>  0) & 0x3FF;

               if (slot->oct & 8)
                  slot->octave_shift = 23 - slot->oct;
               else
                  slot->octave_shift = 7 - slot->oct;
               slot->addr_step = ((0x400 + slot->fns) << 7) >> slot->octave_shift;

               ScspUpdateSlotEnv(slot);

               break;

            case 0x12:
               slot->lfore  = (data >> 15) & 0x1;
               slot->lfof   = (data >> 10) & 0x1F;
               slot->plfows = (data >>  8) & 0x3;
               slot->plfos  = (data >>  5) & 0x7;
               slot->alfows = (data >>  3) & 0x3;
               slot->alfos  = (data >>  0) & 0x7;

               if (slot->lfore)
               {
                  slot->lfo_step = -1;
                  slot->lfo_counter = 0;
                  slot->lfo_fm_shift = -1;
                  slot->lfo_am_shift = -1;
               }
               else
               {
                  slot->lfo_step = scsp_lfo_step[slot->lfof];
                  if (slot->plfos)
                     slot->lfo_fm_shift = slot->plfos - 1;
                  else
                     slot->lfo_fm_shift = -1;
                  if (slot->alfos)
                     slot->lfo_am_shift = 11 - slot->alfos;
                  else
                     slot->lfo_am_shift = -1;
               }
               slot->lfo_fm_wave = scsp_lfo_wave_freq[slot->plfows];
               slot->lfo_am_wave = scsp_lfo_wave_amp[slot->alfows];

               ScspUpdateSlotFunc(slot);

               break;

            case 0x14:
               data &= 0x007F;
               slot->isel   = (data >>  3) & 0xF;
               slot->imxl   = (data >>  0) & 0x7;

               if (slot->imxl)
                  slot->imxl_shift = (7 - slot->imxl) + SCSP_ENV_HIGH_BITS;
               else
                  slot->imxl_shift = 31;

               break;

            case 0x16:
               slot->disdl  = (data >> 13) & 0x7;
               slot->dipan  = (data >>  8) & 0x1F;
               slot->efsdl  = (data >>  5) & 0x7;
               slot->efpan  = (data >>  0) & 0x1F;

               // Compute the output shift counts for the left and right
               // channels.  If the direct sound output is muted, we assume
               // the data is being passed through the DSP (which we don't
               // currently implement) and take the effect output level
               // instead.  Note that we lose 1 bit of resolution from the
               // panning parameter because we adjust the output level by
               // shifting (powers of two), while DIPAN/EFPAN have a
               // resolution of sqrt(2).

               if (slot->disdl)
               {
                  slot->outshift_l = slot->outshift_r = (7 - slot->disdl)
                                                        + SCSP_ENV_HIGH_BITS;
                  if (slot->dipan & 0x10)  // Pan left
                  {
                     if (slot->dipan == 0x1F)
                        slot->outshift_r = 31;
                     else
                        slot->outshift_r += (slot->dipan >> 1) & 7;
                  }
                  else  // Pan right
                  {
                     if (slot->dipan == 0xF)
                        slot->outshift_l = 31;
                     else
                        slot->outshift_l += (slot->dipan >> 1) & 7;
                  }
               }
               else if (slot->efsdl)
               {
                  slot->outshift_l = slot->outshift_r = (7 - slot->efsdl)
                                                        + SCSP_ENV_HIGH_BITS;
                  if (slot->efpan & 0x10)  // Pan left
                  {
                     if (slot->efpan == 0x1F)
                        slot->outshift_r = 31;
                     else
                        slot->outshift_r += (slot->efpan >> 1) & 7;
                  }
                  else  // Pan right
                  {
                     if (slot->efpan == 0xF)
                        slot->outshift_l = 31;
                     else
                        slot->outshift_l += (slot->efpan >> 1) & 7;
                  }
               }
               else
                  slot->outshift_l = slot->outshift_r = 31;  // Muted

               ScspUpdateSlotFunc(slot);

               break;

            default:
               goto unhandled_write;
         }
         break;
      }

      case 0x4:
         switch (address & 0xFF)
         {
            case 0x00:
               data &= 0x030F;  // VER is hardwired
               data |= SCSP_VERSION << 4;
               scsp.mem4mb = (data >>  9) & 0x1;
               scsp.dac18b = (data >>  8) & 0x1;
               scsp.mvol   = (data >>  0) & 0xF;

               if (scsp.mem4mb)
                  M68K->SetFetch(0x000000, 0x080000, (pointer)SoundRam);
               else
               {
                  M68K->SetFetch(0x000000, 0x040000, (pointer)SoundRam);
                  M68K->SetFetch(0x040000, 0x080000, (pointer)SoundRam);
                  M68K->SetFetch(0x080000, 0x0C0000, (pointer)SoundRam);
                  M68K->SetFetch(0x0C0000, 0x100000, (pointer)SoundRam);
               }
               scsp.sound_ram_mask = scsp.mem4mb ? 0x7FFFF : 0x3FFFF;

               break;

            case 0x02:
               data &= 0x01FF;
               scsp.rbl    = (data >>  7) & 0x3;
               scsp.rbp    =((data >>  0) & 0x7F) << 13;
               break;

            case 0x04:
               return;  // Not writable

            case 0x06:
               data &= 0x00FF;
               ScspMidiOut(data);
               break;

            case 0x08:
               data &= 0x7800;  // CA/SGC/EG are not writable
               scsp.mslc   = (data >> 11) & 0x1F;
               break;

            case 0x12:
               data &= 0xFFFE;
               scsp.dmea   = (scsp.dmea & 0xF0000) | data;
               break;

            case 0x14:
               data &= 0xFFFE;
               scsp.dmea   =((data >> 12) & 0xF) << 16 | (scsp.dmea & 0xFFFF);
               scsp.drga   = (data >>  0) & 0xFFF;
               break;

            case 0x16:
               data &= 0x7FFE;
               scsp.dgate  = (data >> 14) & 0x1;
               scsp.ddir   = (data >> 13) & 0x1;
               scsp.dexe  |= (data >> 12) & 0x1;  // Writing 0 not allowed
               scsp.dtlg   = (data >>  0) & 0xFFF;
               if (data & (1<<12))
                  ScspDoDMA();
               break;

            case 0x18:
               data &= 0x07FF;
               scsp.tactl  = (data >>  8) & 0x7;
               scsp.tima   =((data >>  0) & 0xFF) << 8;
               break;

            case 0x1A:
               data &= 0x07FF;
               scsp.tbctl  = (data >>  8) & 0x7;
               scsp.timb   =((data >>  0) & 0xFF) << 8;
               break;

            case 0x1C:
               data &= 0x07FF;
               scsp.tcctl  = (data >>  8) & 0x7;
               scsp.timc   =((data >>  0) & 0xFF) << 8;
               break;

            case 0x1E:
               data &= 0x07FF;
               scsp.scieb = data;
               // FIXME: If a bit is already 1 in both SCIEB and SCIPD,
               // does writing another 1 here (no change) trigger another
               // interrupt or not?
               ScspCheckInterrupts(0x7FF, SCSP_INTTARGET_SOUND);
               break;

            case 0x20:
               if (data & (1<<5))
                  ScspRaiseInterrupt(5, SCSP_INTTARGET_SOUND);
               return;  // Not writable

            case 0x22:
               ScspClearInterrupts(data, SCSP_INTTARGET_SOUND);
               return;  // Not writable

            case 0x24:
               data &= 0x00FF;
               scsp.scilv0 = data;
               break;

            case 0x26:
               data &= 0x00FF;
               scsp.scilv1 = data;
               break;

            case 0x28:
               data &= 0x00FF;
               scsp.scilv2 = data;
               break;

            case 0x2A:
               data &= 0x07FF;
               scsp.mcieb = data;
               // FIXME: as above (SCIEB)
               ScspCheckInterrupts(0x7FF, SCSP_INTTARGET_MAIN);
               break;

            case 0x2C:
               if (data & (1<<5))
                  ScspRaiseInterrupt(5, SCSP_INTTARGET_MAIN);
               return;  // Not writable

            case 0x2E:
               ScspClearInterrupts(data, SCSP_INTTARGET_MAIN);
               return;  // Not writable

            default:
               goto unhandled_write;
         }
         break;

      default:
      unhandled_write:
         SCSPLOG("ScspWriteWordDirect(): unhandled write %04X to 0x%03X\n",
                 data, address);
         break;
   }

   PSP_UC(scsp_regcache[address >> 1]) = data;
}

//-------------------------------------------------------------------------

// ScspDoKeyOnOff:  Apply the key-on/key-off setting for all slots.
// Implements the KYONEX trigger.

static void ScspDoKeyOnOff(void)
{
   int slotnum;
   for (slotnum = 0; slotnum < 32; slotnum++)
   {
      if (scsp.slot[slotnum].key)
         ScspKeyOn(&scsp.slot[slotnum]);
      else
         ScspKeyOff(&scsp.slot[slotnum]);
   }
}

//----------------------------------//

// ScspKeyOn:  Execute a key-on event for a single slot.

static void ScspKeyOn(SlotState *slot)
{
   if (slot->env_phase != SCSP_ENV_RELEASE)
      return;  // Can't key a sound that's already playing

   ScspUpdateSlotAddress(slot);

   slot->addr_counter = 0;
   slot->env_phase = SCSP_ENV_ATTACK;
   slot->env_counter = SCSP_ENV_ATTACK_START;  // FIXME: should this start at the current value if the old sound is still decaying?
   slot->env_step = slot->env_step_a;
   slot->env_target = SCSP_ENV_ATTACK_END;
}

//----------------------------------//

// ScspKeyOff:  Execute a key-off event for a single slot.

static void ScspKeyOff(SlotState *slot)
{
   if (slot->env_phase == SCSP_ENV_RELEASE)
      return;  // Can't release a sound that's already released

   // If we still are in attack phase at release time, convert attack to decay
   if (slot->env_phase == SCSP_ENV_ATTACK)
      slot->env_counter = SCSP_ENV_DECAY_END - slot->env_counter;

   slot->env_phase = SCSP_ENV_RELEASE;
   slot->env_step = slot->env_step_r;
   slot->env_target = SCSP_ENV_DECAY_END;
}

//-------------------------------------------------------------------------

// ScspUpdateSlotAddress:  Update the sample data pointer for the given
// slot, bound slot->lea to the end of sound RAM, and cache the shifted
// values of slot->lsa and slot->lea in slot->{lea,lsa}_shifted.

static void ScspUpdateSlotAddress(SlotState *slot)
{
   u32 max_samples;

   if (slot->pcm8b)
      slot->sa &= ~1;
   slot->sa &= scsp.sound_ram_mask;
   slot->buf = &SoundRam[slot->sa];
   max_samples = scsp.sound_ram_mask - slot->sa;
   if (slot->pcm8b)
      max_samples >>= 1;

   if (slot->lsa > max_samples)
      slot->lsa = max_samples;
   slot->lsa_shifted = slot->lsa << SCSP_FREQ_LOW_BITS;

   if (slot->lea > max_samples)
      slot->lea = max_samples;
   slot->lea_shifted = ((slot->lea + 1) << SCSP_FREQ_LOW_BITS) - 1;

   slot->looplen_shifted = slot->lea_shifted - slot->lsa_shifted + 1;
}

//----------------------------------//

// ScspUpdateSlotEnv:  Update the envelope step values from the SR/DR/AR/RR
// slot registers.  slot->krs_shift and slot->octave_shift are assumed to
// be up to date with respect to the KRS and OCT registers.

static void ScspUpdateSlotEnv(SlotState *slot)
{
   if (slot->sr)
   {
      const s32 *rate_table = &scsp_decay_rate[slot->sr << 1];
      slot->env_step_s = rate_table[(15 - slot->octave_shift)
                                    >> slot->krs_shift];
   }
   else
      slot->env_step_s = 0;

   if (slot->dr)
   {
      const s32 *rate_table = &scsp_decay_rate[slot->dr << 1];
      slot->env_step_d = rate_table[(15 - slot->octave_shift)
                                    >> slot->krs_shift];
   }
   else
      slot->env_step_d = 0;

   if (slot->ar)
   {
      const s32 *rate_table = &scsp_attack_rate[slot->ar << 1];
      slot->env_step_a = rate_table[(15 - slot->octave_shift)
                                    >> slot->krs_shift];
   }
   else
      slot->env_step_a = 0;

   if (slot->rr)
   {
      const s32 *rate_table = &scsp_decay_rate[slot->rr << 1];
      slot->env_step_r = rate_table[(15 - slot->octave_shift)
                                    >> slot->krs_shift];
   }
   else
      slot->env_step_r = 0;
}

//----------------------------------//

// ScspUpdateSlotFunc:  Update the audio generation function for the given
// slot based on the slot's parameters.

static void ScspUpdateSlotFunc(SlotState *slot)
{
   if (slot->ssctl)
      // FIXME: noise (ssctl==1) not implemented
      slot->audiogen = scsp_audiogen_func_table[0][0][0][0][0];
   else
      slot->audiogen = scsp_audiogen_func_table[slot->lfo_fm_shift >= 0]
                                               [slot->lfo_am_shift >= 0]
                                               [slot->pcm8b == 0]
                                               [slot->outshift_l != 31]
                                               [slot->outshift_r != 31];
}

//-------------------------------------------------------------------------

// ScspMidiIn:  Handle a read from the MIDI input register ($404).  Since
// there is no facility for sending MIDI data (the Saturn does not have a
// MIDI I/O port), most of this is essentially a giant no-op, but the logic
// is included for reference.

static u16 ScspMidiIn(void)
{
   scsp.miovf = 0;
   scsp.mifull = 0;
   if (scsp.midi_in_cnt > 0)
   {
      scsp.mibuf = scsp.midi_in_buf[0];
      scsp.midi_in_buf[0] = scsp.midi_in_buf[1];
      scsp.midi_in_buf[1] = scsp.midi_in_buf[2];
      scsp.midi_in_buf[2] = scsp.midi_in_buf[3];
      scsp.midi_in_cnt--;
      scsp.miemp = (scsp.midi_in_cnt == 0);
      if (!scsp.miemp)
         ScspRaiseInterrupt(SCSP_INTERRUPT_MIDI_IN, SCSP_INTTARGET_BOTH);
   }
   else  // scsp.midi_in_cnt == 0
      scsp.mibuf = 0xFF;

   return scsp.mofull << 12
        | scsp.moemp  << 11
        | scsp.miovf  << 10
        | scsp.mifull <<  9
        | scsp.miemp  <<  8
        | scsp.mibuf  <<  0;
}

//----------------------------------//

// ScspMidiOut:  Handle a write to the MIDI output register ($406).

static void ScspMidiOut(u8 data)
{
   scsp.moemp = 0;
   if (scsp.midi_out_cnt < 4)
      scsp.midi_out_buf[scsp.midi_out_cnt++] = data;
   scsp.mofull = (scsp.midi_out_cnt >= 4);
}

//-------------------------------------------------------------------------

// ScspDoDMA:  Handle a DMA request (when 1 is written to DEXE).  DMA is
// processed instantaneously regardless of transfer size.

static void ScspDoDMA(void)
{
   const u32 dmea = scsp.dmea & scsp.sound_ram_mask;

   if (scsp.ddir)  // {RAM,zero} -> registers
   {
      SCSPLOG("DMA %s RAM[$%05X] -> registers[$%03X]\n",
              scsp.dgate ? "clear" : "copy", dmea, scsp.drga);
      if (scsp.dgate)
      {
         u32 i;
         for (i = 0; i < scsp.dtlg; i += 2)
            ScspWriteWordDirect(scsp.drga + i, 0);
      }
      else
      {
         u32 i;
         for (i = 0; i < scsp.dtlg; i += 2)
            ScspWriteWordDirect(scsp.drga + i, T2ReadWord(SoundRam, dmea + i));
      }
   }
   else  // !scsp.ddir, i.e. registers -> RAM
   {
      SCSPLOG("DMA %s registers[$%03X] -> RAM[$%05X]\n",
              scsp.dgate ? "clear" : "copy", scsp.drga, dmea);
      if (scsp.dgate)
         memset(&SoundRam[dmea], 0, scsp.dtlg);
      else
      {
         u32 i;
         for (i = 0; i < scsp.dtlg; i += 2)
            T2WriteWord(SoundRam, dmea + i, ScspReadWordDirect(scsp.drga + i));
      }
      M68K->WriteNotify(dmea, scsp.dtlg);
   }

   scsp.dexe = 0;
   PSP_UC(scsp_regcache[0x416>>1]) &= ~(1<<12);
   ScspRaiseInterrupt(SCSP_INTERRUPT_DMA, SCSP_INTTARGET_BOTH);
}

///////////////////////////////////////////////////////////////////////////
// Other SCSP internal helper routines
///////////////////////////////////////////////////////////////////////////

// ScspSyncThread:  Wait for the SCSP subthread to finish executing all
// pending cycles.  Do not call if the subthread is not running.

static void ScspSyncThread(void)
{
   PSP_FLUSH_ALL();
   while (PSP_UC(scsp_clock) != scsp_clock_target)
   {
      YabThreadWake(YAB_THREAD_SCSP);
      YabThreadYield();
   }
}

//-------------------------------------------------------------------------

// ScspRaiseInterrupt:  Raise an interrupt for the main and/or sound CPU.

static void ScspRaiseInterrupt(int which, int target)
{
   if (target & SCSP_INTTARGET_MAIN)
   {
      scsp.mcipd |= 1 << which;
      PSP_UC(scsp_regcache[0x42C >> 1]) = scsp.mcipd;
      if (scsp.mcieb & (1 << which))
      {
         if (scsp_thread_running)
            PSP_UC(scsp_main_interrupt_pending) = 1;
         else
            (*scsp_interrupt_handler)();
      }
   }

   if (target & SCSP_INTTARGET_SOUND)
   {
      scsp.scipd |= 1 << which;
      PSP_UC(scsp_regcache[0x420 >> 1]) = scsp.scipd;
      if (scsp.scieb & (1 << which))
      {
         const int level_shift = (which > 7) ? 7 : which;
         const int level = ((scsp.scilv0 >> level_shift) & 1) << 0
                         | ((scsp.scilv1 >> level_shift) & 1) << 1
                         | ((scsp.scilv2 >> level_shift) & 1) << 2;
         M68K->SetIRQ(level);
      }
   }
}

//----------------------------------//

// ScspCheckInterrupts:  Check pending interrupts for the main or sound CPU
// against the interrupt enable flags, and raise any interrupts which are
// both enabled and pending.  The mask parameter indicates which interrupts
// should be checked.  Implements writes to SCIEB and MCIEB.

static void ScspCheckInterrupts(u16 mask, int target)
{
   int i;

   for (i = 0; i < 11; i++)
   {
      if ((1<<i) & mask & scsp.mcieb && scsp.mcipd)
         ScspRaiseInterrupt(i, SCSP_INTTARGET_MAIN & target);
      if ((1<<i) & mask & scsp.scieb && scsp.scipd)
         ScspRaiseInterrupt(i, SCSP_INTTARGET_SOUND & target);
   }
}

//----------------------------------//

// ScspClearInterrupts:  Clear all pending interrupts specified by the mask
// parameter for the main or sound CPU.  Implements writes to SCIRE and MCIRE.

static void ScspClearInterrupts(u16 mask, int target)
{
   if (target & SCSP_INTTARGET_MAIN)
   {
      scsp.mcipd &= ~mask;
      PSP_UC(scsp_regcache[0x42C >> 1]) = scsp.mcipd;
   }

   if (target & SCSP_INTTARGET_SOUND)
   {
      scsp.scipd &= ~mask;
      PSP_UC(scsp_regcache[0x420 >> 1]) = scsp.scipd;
   }
}

//-------------------------------------------------------------------------

// ScspRunM68K:  Run the M68K for the given number of cycles.

static void ScspRunM68K(u32 cycles)
{
   if (LIKELY(m68k_running))
   {
      s32 new_cycles = m68k_saved_cycles + cycles;
      if (LIKELY(new_cycles > 0))
         new_cycles -= (*m68k_execf)(new_cycles);
      m68k_saved_cycles = new_cycles;
   }
}

//----------------------------------//

// M68KExecBP:  Wrapper for M68K->Exec() which checks for breakpoints and
// calls the breakpoint callback when one is reached.  This logic is
// extracted from M68KExec() to avoid unnecessary register spillage on the
// fast (no-breakpoint) path.

static s32 FASTCALL M68KExecBP(s32 cycles)
{
   s32 cycles_to_exec = cycles;
   s32 cycles_executed = 0;
   int i;

   while (cycles_executed < cycles_to_exec)
   {
      // Make sure it isn't one of our breakpoints
      for (i = 0; i < m68k_num_breakpoints; i++)
      {
         if ((M68K->GetPC() == m68k_breakpoint[i].addr) && !m68k_in_breakpoint)
         {
            m68k_in_breakpoint = 1;
            if (M68KBreakpointCallback)
               M68KBreakpointCallback(m68k_breakpoint[i].addr);
            m68k_in_breakpoint = 0;
         }
      }

      // Execute instructions individually
      cycles_executed += M68K->Exec(1);
   }

   return cycles_executed;
}

///////////////////////////////////////////////////////////////////////////
// M68K management routines
///////////////////////////////////////////////////////////////////////////

// M68KStart:  Start the M68K processor running.

void M68KStart(void)
{
   if (scsp_thread_running)
      ScspSyncThread();

   M68K->Reset();
   m68k_saved_cycles = 0;

   m68k_running = 1;

   if (scsp_thread_running)
      PSP_FLUSH_ALL();
}

//-------------------------------------------------------------------------

// M68KStop:  Halt the M68K processor.

void M68KStop(void)
{
   if (scsp_thread_running)
      ScspSyncThread();

   m68k_running = 0;

   if (scsp_thread_running)
      PSP_FLUSH_ALL();
}

//-------------------------------------------------------------------------

// M68KStep:  Execute a single M68K instruction.

void M68KStep(void)
{
   M68K->Exec(1);
}

//-------------------------------------------------------------------------

// M68KWriteNotify:  Notify the M68K emulator that a region of sound RAM
// has been written to by an external agent.

void M68KWriteNotify(u32 address, u32 size)
{
   M68K->WriteNotify(address, size);
}

//-------------------------------------------------------------------------

// M68KGetRegisters, M68KSetRegisters:  Get or set the current values of
// the M68K registers.

void M68KGetRegisters(M68KRegs *regs)
{
   int i;

   if (regs != NULL)
   {
      for (i = 0; i < 8; i++)
      {
         regs->D[i] = M68K->GetDReg(i);
         regs->A[i] = M68K->GetAReg(i);
      }
      regs->SR = M68K->GetSR();
      regs->PC = M68K->GetPC();
   }
}

void M68KSetRegisters(const M68KRegs *regs)
{
   int i;

   if (regs != NULL)
   {
      for (i = 0; i < 8; i++)
      {
         M68K->SetDReg(i, regs->D[i]);
         M68K->SetAReg(i, regs->A[i]);
      }
      M68K->SetSR(regs->SR);
      M68K->SetPC(regs->PC);
   }
}

//-------------------------------------------------------------------------

// M68KSetBreakpointCallback:  Set a function to be called whenever an M68K
// breakpoint is reached.

void M68KSetBreakpointCallBack(void (*func)(u32 address))
{
   M68KBreakpointCallback = func;
}

//-------------------------------------------------------------------------

// M68KAddCodeBreakpoint:  Add an M68K breakpoint on the given address.
// Returns 0 on success, -1 if the breakpoint table is full or there is
// already a breakpoint set on the address.

int M68KAddCodeBreakpoint(u32 address)
{
   int i;

   if (m68k_num_breakpoints >= MAX_BREAKPOINTS)
      return -1;

   // Make sure it isn't already on the list
   for (i = 0; i < m68k_num_breakpoints; i++)
   {
      if (m68k_breakpoint[i].addr == address)
         return -1;
   }

   m68k_breakpoint[m68k_num_breakpoints].addr = address;
   m68k_num_breakpoints++;

   // Switch to the slow exec routine so we can catch the breakpoint
   m68k_execf = M68KExecBP;

   return 0;
}

//-------------------------------------------------------------------------

// M68KDelCodeBreakpoint:  Delete an M68K breakpoint on the given address.
// Returns 0 on success, -1 if there was no breakpoint set on the address.

int M68KDelCodeBreakpoint(u32 address)
{
   int i;

   if (m68k_num_breakpoints > 0)
   {
      for (i = 0; i < m68k_num_breakpoints; i++)
      {
         if (m68k_breakpoint[i].addr == address)
         {
            // Swap with the last breakpoint in the table, so there are
            // no holes in the breakpoint list
            m68k_breakpoint[i].addr = m68k_breakpoint[m68k_num_breakpoints-1].addr;
            m68k_breakpoint[m68k_num_breakpoints-1].addr = 0xFFFFFFFF;
            m68k_num_breakpoints--;

            if (m68k_num_breakpoints == 0)
            {
               // Last breakpoint deleted, so go back to the fast exec routine
               m68k_execf = M68K->Exec;
            }

            return 0;
         }
      }
   }

   return -1;
}

//-------------------------------------------------------------------------

// M68KGetBreakpointList:  Return the array of breakpoints currently set.
// The array is M68K_MAX_BREAKPOINTS elements long, and an address of
// 0xFFFFFFFF indicates that no breakpoint is set in that slot.

const M68KBreakpointInfo *M68KGetBreakpointList(void)
{
   return m68k_breakpoint;
}

//-------------------------------------------------------------------------

// M68KClearCodeBreakpoints:  Clear all M68K breakpoints.

void M68KClearCodeBreakpoints(void)
{
   int i;
   for (i = 0; i < MAX_BREAKPOINTS; i++)
      m68k_breakpoint[i].addr = 0xFFFFFFFF;

   m68k_num_breakpoints = 0;
   m68k_execf = M68K->Exec;
}

//-------------------------------------------------------------------------

// M68K{Read,Write}{Byte,Word}:  Memory access routines for the M68K
// emulation.  Exported for use in debugging.

u32 FASTCALL M68KReadByte(u32 address)
{
   if (address < 0x100000)
      return T2ReadByte(SoundRam, address & scsp.sound_ram_mask);
   else
      return ScspReadByteDirect(address & 0xFFF);
}

u32 FASTCALL M68KReadWord(u32 address)
{
   if (address < 0x100000)
      return T2ReadWord(SoundRam, address & scsp.sound_ram_mask);
   else
      return ScspReadWordDirect(address & 0xFFF);
}

void FASTCALL M68KWriteByte(u32 address, u32 data)
{
   if (address < 0x100000)
      T2WriteByte(SoundRam, address & scsp.sound_ram_mask, data);
   else
      ScspWriteByteDirect(address & 0xFFF, data);
}

void FASTCALL M68KWriteWord(u32 address, u32 data)
{
   if (address < 0x100000)
      T2WriteWord(SoundRam, address & scsp.sound_ram_mask, data);
   else
      ScspWriteWordDirect(address & 0xFFF, data);
}

///////////////////////////////////////////////////////////////////////////
