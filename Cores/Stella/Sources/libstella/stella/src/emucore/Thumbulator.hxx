//============================================================================
//
//   SSSS    tt          lll  lll
//  SS  SS   tt           ll   ll
//  SS     tttttt  eeee   ll   ll   aaaa
//   SSSS    tt   ee  ee  ll   ll      aa
//      SS   tt   eeeeee  ll   ll   aaaaa  --  "An Atari 2600 VCS Emulator"
//  SS  SS   tt   ee      ll   ll  aa  aa
//   SSSS     ttt  eeeee llll llll  aaaaa
//
// Copyright (c) 1995-2024 by Bradford W. Mott, Stephen Anthony
// and the Stella Team
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

//============================================================================
// This class provides Thumb emulation code ("Thumbulator")
//    by David Welch (dwelch@dwelch.com)
// Modified by Fred Quimby
// Code is public domain and used with the author's consent
//============================================================================

#ifndef THUMBULATOR_HXX
#define THUMBULATOR_HXX

class Cartridge;

#include "bspf.hxx"
#include "Console.hxx"

#ifdef RETRON77
  #define UNSAFE_OPTIMIZATIONS
#endif

#ifdef DEBUGGER_SUPPORT
  #define THUMB_CYCLE_COUNT
  //#define COUNT_OPS
  //#define THUMB_STATS
#endif

#ifdef THUMB_CYCLE_COUNT
  //#define EMULATE_PIPELINE  // enable coarse ARM pipeline emulation (TODO)
  #define TIMER_0           // enable timer 0 support (e.g. for measuring cycle count)
#endif

class Thumbulator
{
  public:
    // control cartridge specific features of the Thumbulator class,
    // such as the start location for calling custom code
    enum class ConfigureFor {
      BUS,      // cartridges of type BUS
      CDF,      // cartridges of type CDF
      CDF1,     // cartridges of type CDF version 1
      CDFJ,     // cartridges of type CDFJ
      CDFJplus, // cartridges of type CDFJ+
      DPCplus   // cartridges of type DPC+
    };
    enum class ChipType {
      AUTO = -1,
      LPC2101,    // Harmony (includes LPC2103)
      LPC2104_OC, // Dev cart overclocked (includes LPC2105)
      LPC2104,    // Dev cart (includes LPC2105)
      LPC213x,    // future use (includes LPC2132)
      numTypes
    };
    enum class MamModeType {
      mode0, mode1, mode2, modeX
    };
    struct ChipPropsType {
      string name;
      double MHz;
      uInt32 flashCycles;
      uInt32 flashBanks;
    };
    struct Stats {
      uInt32 instructions{0};
    #ifdef THUMB_STATS
      uInt32 reads{0}, writes{0};
      uInt32 nCylces{0}, sCylces{0}, iCylces{0};
      uInt32 branches{0}, taken{0};
      uInt32 mamPrefetchHits{0}, mamPrefetchMisses{0};
      uInt32 mamBranchHits{0}, mamBranchMisses{0};
      uInt32 mamDataHits{0}, mamDataMisses{0};
    #endif
    };

    Thumbulator(const uInt16* rom_ptr, uInt16* ram_ptr, uInt32 rom_size,
                const uInt32 c_base, const uInt32 c_start, const uInt32 c_stack,
                bool traponfatal, double cyclefactor,
                Thumbulator::ConfigureFor configurefor,
                Cartridge* cartridge);

    /**
      Run the ARM code, and return when finished.  A runtime_error exception is
      thrown in case of any fatal errors/aborts (if enabled), containing the
      actual error, and the contents of the registers at that point in time.

      @return  The results of any debugging output (if enabled),
               otherwise an empty string
    */
    string run(uInt32& cycles, bool irqDrivenAudio);
    void enableCycleCount(bool enable) { _countCycles = enable; }
    const Stats& stats() const { return _stats; }
    uInt32 cycles() const { return _totalCycles; }
    ChipPropsType setChipType(ChipType type = ChipType::AUTO);
    void setMamMode(MamModeType mode) { mamcr = mode; }
    void lockMamMode(bool lock) { _lockMamcr = lock; }
    MamModeType mamMode() const { return static_cast<MamModeType>(mamcr); }

  #ifdef THUMB_CYCLE_COUNT
    void cycleFactor(double factor) { _armCyclesFactor = factor; }
    double cycleFactor() const { return _armCyclesFactor; }
  #else
    void cycleFactor(double) { }
    double cycleFactor() const { return 1.0; }
  #endif

  #ifndef UNSAFE_OPTIMIZATIONS
    /**
      Normally when a fatal error is encountered, the ARM emulation
      immediately throws an exception and exits.  This method allows execution
      to continue, and simply log the error.

      Note that this is meant for developers only, and should normally be
      always enabled.  It can be used to temporarily ignore illegal reads
      and writes, but a ROM which consistently performs these operations
      should be fixed, as it can cause crashes on real hardware.

      @param enable  Enable (the default) or disable exceptions on fatal errors
    */
    void trapFatalErrors(bool enable) { trapOnFatal = enable; }
  #endif

    /**
      Inform the Thumbulator class about the console currently in use,
      which is used to accurately determine how many 6507 cycles have
      passed while ARM code is being executed.
    */
    void setConsoleTiming(ConsoleTiming timing);

  private:

    enum class Op : uInt8 {
      invalid,
      adc,
      add1, add2, add3, add4, add5, add6, add7,
      and_,
      asr1, asr2,
      // b1 variants:
      beq, bne, bcs, bcc, bmi, bpl, bvs, bvc, bhi, bls, bge, blt, bgt, ble,
      b2,
      bic,
      bkpt,
      // blx1 variants:
      bl, blx_thumb, blx_arm,
      blx2,
      bx,
      cmn,
      cmp1, cmp2, cmp3,
      cps,
      cpy,
      eor,
      ldmia,
      ldr1, ldr2, ldr3, ldr4,
      ldrb1, ldrb2,
      ldrh1, ldrh2,
      ldrsb,
      ldrsh,
      lsl1, lsl2,
      lsr1, lsr2,
      mov1, mov2, mov3,
      mul,
      mvn,
      neg,
      orr,
      pop,
      push,
      rev,
      rev16,
      revsh,
      ror,
      sbc,
      setend,
      stmia,
      str1, str2, str3,
      strb1, strb2,
      strh1, strh2,
      sub1, sub2, sub3, sub4,
      swi,
      sxtb,
      sxth,
      tst,
      uxtb,
      uxth,
      numOps
    };
  #ifdef THUMB_CYCLE_COUNT
    enum class CycleType {
      S, N, I // Sequential, Non-sequential, Internal
    };
    enum class AccessType {
      prefetch, branch, data
    };
  #endif
    const std::array<ChipPropsType, uInt32(ChipType::numTypes)> ChipProps =
    {{
      { "LPC2101..3",    70.0, 4, 1 }, // LPC2101_02_03
      { "LPC2104..6 OC", 70.0, 4, 2 }, // LPC2104_05_06 Overclocked
      { "LPC2104..6",    60.0, 3, 2 }, // LPC2104_05_06
      { "LPC213x",       60.0, 3, 1 }, // LPC2132..
    }};

  private:
    string doRun(uInt32& cycles, bool irqDrivenAudio);
#ifndef UNSAFE_OPTIMIZATIONS
    uInt32 read_register(uInt32 reg);
    void write_register(uInt32 reg, uInt32 data, bool isFlowBreak = true);
#endif
    uInt32 fetch16(uInt32 addr);
    uInt32 read16(uInt32 addr);
    uInt32 read32(uInt32 addr);
  #ifndef UNSAFE_OPTIMIZATIONS
    bool isInvalidROM(uInt32 addr) const;
    bool isInvalidRAM(uInt32 addr) const;
    bool isProtectedRAM(uInt32 addr);
  #endif
    void write16(uInt32 addr, uInt32 data);
    void write32(uInt32 addr, uInt32 data);
    void updateTimer(uInt32 cycles);

    Op decodeInstructionWord(uint16_t inst, uInt32 pc);

    void do_cvflag(uInt32 a, uInt32 b, uInt32 c);

  #ifndef UNSAFE_OPTIMIZATIONS
    // Throw a runtime_error exception containing an error referencing the
    // given message and variables
    // Note that the return value is never used in these methods
    int fatalError(string_view opcode, uInt32 v1, string_view msg);
    int fatalError(string_view opcode, uInt32 v1, uInt32 v2, string_view msg);

    void dump_counters() const;
    void dump_regs();
  #endif
    int execute();
    int reset();

  #ifdef THUMB_CYCLE_COUNT
    bool isMamBuffered(uInt32 addr, AccessType = AccessType::data);
    void incCycles(AccessType accessType, uInt32 cycles);
    void incSCycles(uInt32 addr, AccessType = AccessType::data);
    void incNCycles(uInt32 addr, AccessType = AccessType::data);
    void incICycles(uInt32 m = 1);
  #endif
    bool searchPattern(uInt32 pattern, uInt32 repeats = 1) const;

  private:
    const uInt16* rom{nullptr};
    uInt32 romSize{0};
    uInt32 cBase{0};
    uInt32 cStart{0};
    uInt32 cStack{0};
    const unique_ptr<Op[]> decodedRom;  // NOLINT
    const unique_ptr<uInt32[]> decodedParam;  // NOLINT
    uInt16* ram{nullptr};
    std::array<uInt32, 16> reg_norm; // normal execution mode, do not have a thread mode
    uInt32 znFlags{0};
    uInt32 cFlag{0};
    uInt32 vFlag{0};
    MamModeType mamcr{MamModeType::mode0};
    bool handler_mode{false};
    uInt32 systick_ctrl{0}, systick_reload{0}, systick_count{0}, systick_calibrate{0};
    ChipType _chipType{ChipType::AUTO};
    ConsoleTiming _consoleTiming{ConsoleTiming::ntsc};
    double _MHz{70.0};
    uInt32 _flashCycles{4};
    uInt32 _flashBanks{1};
    Stats _stats{0};
    bool _irqDrivenAudio{false};
    uInt32 _totalCycles{0};

    // For emulation of LPC2103's timer 1, used for NTSC/PAL/SECAM detection.
    // Register names from documentation:
    // http://www.nxp.com/documents/user_manual/UM10161.pdf
  #ifdef TIMER_0
    uInt32 T0TCR{0};      // Timer 0 Timer Control Register
    uInt32 T0TC{0};       // Timer 0 Timer Counter
    uInt32 tim0Start{0};  // _totalCycles when Timer 0 got started last time
    uInt32 tim0Total{0};  // total cycles of Timer 0
  #endif
    uInt32 T1TCR{0};      // Timer 1 Timer Control Register
    uInt32 T1TC{0};       // Timer 1 Timer Counter
    uInt32 tim1Start{0};  // _totalCycles when Timer 1 got started last time
    uInt32 tim1Total{0};  // total cycles of Timer 1
    double timing_factor{0.0};

  #ifndef UNSAFE_OPTIMIZATIONS
    ostringstream statusMsg;
    bool trapOnFatal{true};
  #endif
    bool _countCycles{false};
    bool _lockMamcr{false};

  #ifdef THUMB_CYCLE_COUNT
    double _armCyclesFactor{1.05};
    uInt32 _pipeIdx{0};
    CycleType _prefetchCycleType[3]{CycleType::S};
    CycleType _lastCycleType[3]{CycleType::S};
#if 0 // unused for now
    AccessType _prefetchAccessType[3]{AccessType::data};
#endif
   #ifdef EMULATE_PIPELINE
    uInt32 _fetchPipeline{0}; // reserve fetch cycles resulting from pipelining (execution stage)
    uInt32 _memory0Pipeline{0}, _memory1Pipeline{0};
   #endif
    uInt32 _prefetchBufferAddr[2]{0};
    uInt32 _branchBufferAddr[2]{0};
    uInt32 _dataBufferAddr{0};
  #endif
  #ifdef COUNT_OPS
    uInt32 opCount[size_t(Op::numOps)]{0};
  #endif

    ConfigureFor configuration;

    Cartridge* myCartridge{nullptr};

    static constexpr uInt32
      ROMADDMASK = 0x7FFFF,
      RAMADDMASK = 0x7FFF,

      ROMSIZE = ROMADDMASK + 1,  // 512KB
      RAMSIZE = RAMADDMASK + 1,  // 32KB

      CPSR_N = 1u << 31,
      CPSR_Z = 1u << 30,
      CPSR_C = 1u << 29,
      CPSR_V = 1u << 28;

  private:
    // Following constructors and assignment operators not supported
    Thumbulator() = delete;
    Thumbulator(const Thumbulator&) = delete;
    Thumbulator(Thumbulator&&) = delete;
    Thumbulator& operator=(const Thumbulator&) = delete;
    Thumbulator& operator=(Thumbulator&&) = delete;
};

#endif  // THUMBULATOR_HXX
