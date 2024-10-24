//============================================================================
//
// MM     MM  6666  555555  0000   2222
// MMMM MMMM 66  66 55     00  00 22  22
// MM MMM MM 66     55     00  00     22
// MM  M  MM 66666  55555  00  00  22222  --  "A 6502 Microprocessor Emulator"
// MM     MM 66  66     55 00  00 22
// MM     MM 66  66 55  55 00  00 22
// MM     MM  6666   5555   0000  222222
//
// Copyright (c) 1995-2024 by Bradford W. Mott, Stephen Anthony
// and the Stella Team
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

#ifndef M6502_HXX
#define M6502_HXX

#include <functional>

class Settings;
class System;
class DispatchResult;

#ifdef DEBUGGER_SUPPORT
  class Debugger;
  class CpuDebug;

  #include "Expression.hxx"
  #include "TrapArray.hxx"
  #include "BreakpointMap.hxx"
  #include "TimerMap.hxx"
#endif

#include "bspf.hxx"
#include "Device.hxx"
#include "Serializable.hxx"

/**
  The 6502 is an 8-bit microprocessor that has a 64K addressing space.
  This class provides a high compatibility 6502 microprocessor emulator.

  The memory accesses and cycle counts it generates are valid at the
  sub-instruction level and "false" reads are generated (such as the ones
  produced by the Indirect,X addressing when it crosses a page boundary).
  This provides provides better compatibility for hardware that has side
  effects and for games which are very time sensitive.

  @author  Bradford W. Mott
*/
class M6502 : public Serializable
{
  // The 6502 and Cart debugger classes are friends who need special access
  friend class CartDebug;
  friend class CpuDebug;

  public:

    using onHaltCallback = std::function<void()>;

  public:
    /**
      Create a new 6502 microprocessor.
    */
    explicit M6502(const Settings& settings);
    ~M6502() override = default;

  public:
    /**
      Install the processor in the specified system.  Invoked by the
      system when the processor is attached to it.

      @param system The system the processor should install itself in
    */
    void install(System& system);

    /**
      Reset the processor to its power-on state.  This method should not
      be invoked until the entire 6502 system is constructed and installed
      since it involves reading the reset vector from memory.
    */
    void reset();

    /**
      Request a maskable interrupt
    */
    void irq() { myExecutionStatus |= MaskableInterruptBit; }

    /**
      Request a non-maskable interrupt
    */
    void nmi() { myExecutionStatus |= NonmaskableInterruptBit; }

    /**
      Set the callback for handling a halt condition
    */
    void setOnHaltCallback(const onHaltCallback& callback) {
      myOnHaltCallback = callback;
    }

    /**
      RDY pulled low --- halt on next read.
    */
    void requestHalt();

    /**
      Pull RDY high again before the callback was triggered.
    */
    void clearHaltRequest() { myHaltRequested = false; }

    /**
      Execute instructions until the specified number of instructions
      is executed, someone stops execution, or an error occurs.  Answers
      true iff execution stops normally.

      @param cycles  Indicates the number of cycles to execute. Not that the
                     actual granularity of the CPU is instructions, so this
                     is only accurate up to a couple of cycles
      @param result  A DispatchResult object that will transport the result
    */
    void execute(uInt64 cycles, DispatchResult& result);

    bool execute(uInt64 cycles);

    /**
      Tell the processor to stop executing instructions.  Invoking this
      method while the processor is executing instructions will stop
      execution as soon as possible.
    */
    void stop() { myExecutionStatus |= StopExecutionBit; }

    /**
      Answer true iff a fatal error has occured from which the processor
      cannot recover (i.e. illegal instruction, etc.)

      @return true iff a fatal error has occured
    */
    bool fatalError() const { return myExecutionStatus & FatalErrorBit; }

    /**
      Get the 16-bit value of the Program Counter register.

      @return The program counter register
    */
    // uInt16 getPC() const { return PC; }

    /**
      Check the type of the last peek().

      @return true, if the last peek() was a ghost read.
    */
    bool lastWasGhostPeek() const { return myFlags == 0; } // DISASM_NONE

    /**
      Return the last address that was part of a read/peek.

      @return The address of the last read
    */
    uInt16 lastReadAddress() const { return myLastPeekAddress; }

    /**
      Return the last address that was part of a write/poke.

      @return The address of the last write
    */
    uInt16 lastWriteAddress() const { return myLastPokeAddress; }

    /**
      Return the last (non-mirrored) address that was part of a read/peek.

      @return The address of the last read
    */
    uInt16 lastReadBaseAddress() const { return myLastPeekBaseAddress; }

    /**
      Return the last (non-mirrored) address that was part of a write/poke.

      @return The address of the last write
    */
    uInt16 lastWriteBaseAddress() const { return myLastPokeBaseAddress; }

    /**
      Return the source of the address that was used for a write/poke.
      Note that this isn't the same as the address that is poked, but
      is instead the address of the *data* that is poked (if any).

      @return The address of the data used in the last poke, else 0
    */
    uInt16 lastDataAddressForPoke() const { return myDataAddressForPoke; }

    /**
      Return the last data address used as part of a peek operation for
      the S/A/X/Y registers.  Note that if an address wasn't used (as in
      immediate mode), then the address is -1.

      @return The address of the data used in the last peek, else -1
    */
    Int32 lastSrcAddressS() const { return myLastSrcAddressS; }
    Int32 lastSrcAddressA() const { return myLastSrcAddressA; }
    Int32 lastSrcAddressX() const { return myLastSrcAddressX; }
    Int32 lastSrcAddressY() const { return myLastSrcAddressY; }

    /**
      Get the number of memory accesses to distinct memory locations

      @return The number of memory accesses to distinct memory locations
    */
    uInt32 distinctAccesses() const { return myNumberOfDistinctAccesses; }

    /**
      Saves the current state of this device to the given Serializer.

      @param out The serializer device to save to.
      @return The result of the save.  True on success, false on failure.
    */
    bool save(Serializer& out) const override;

    /**
      Loads the current state of this device from the given Serializer.

      @param in The Serializer device to load from.
      @return The result of the load.  True on success, false on failure.
    */
    bool load(Serializer& in) override;

#ifdef DEBUGGER_SUPPORT
  public:
    // Attach the specified debugger.
    void attach(Debugger& debugger);

    TrapArray& readTraps() { return myReadTraps; }
    TrapArray& writeTraps() { return myWriteTraps; }

    BreakpointMap& breakPoints() { return myBreakPoints; }

    // methods for 'breakif' handling
    uInt32 addCondBreak(Expression* e, string_view name, bool oneShot = false);
    bool delCondBreak(uInt32 idx);
    void clearCondBreaks();
    const StringList& getCondBreakNames() const;

    // methods for 'savestateif' handling
    uInt32 addCondSaveState(Expression* e, string_view name);
    bool delCondSaveState(uInt32 idx);
    void clearCondSaveStates();
    const StringList& getCondSaveStateNames() const;

    // methods for 'trapif' handling
    uInt32 addCondTrap(Expression* e, string_view name);
    bool delCondTrap(uInt32 idx);
    void clearCondTraps();
    const StringList& getCondTrapNames() const;

    // methods for 'timer' handling:
    uInt32 addTimer(uInt16 fromAddr, uInt16 toAddr, uInt8 fromBank, uInt8 toBank,
                    bool mirrors, bool anyBank);
    uInt32 addTimer(uInt16 addr, uInt8 bank, bool mirrors, bool anyBank);
    bool delTimer(uInt32 idx);
    void clearTimers();
    void resetTimers();
    uInt32 numTimers() const { return myTimer.size(); }
    const TimerMap::Timer& getTimer(uInt32 idx) const { return myTimer.get(idx); }

    void setGhostReadsTrap(bool enable) { myGhostReadsTrap = enable; }
    void setReadFromWritePortBreak(bool enable) { myReadFromWritePortBreak = enable; }
    void setWriteToReadPortBreak(bool enable) { myWriteToReadPortBreak = enable; }
    void setLogBreaks(bool enable) { myLogBreaks = enable; }
    bool getLogBreaks() const { return myLogBreaks; }
    void setLogTrace(bool enable) { myLogTrace = enable; }
    bool getLogTrace() const { return myLogTrace; }
#endif  // DEBUGGER_SUPPORT

  private:
    /**
      Get the byte at the specified address and update the cycle count.
      Addresses marked as code are hints to the debugger/disassembler to
      conclusively determine code sections, even if the disassembler cannot
      find them itself.

      @param address  The address from which the value should be loaded
      @param flags    Indicates that this address has the given flags
                      for type of access (CODE, DATA, GFX, etc)

      @return The byte at the specified address
    */
    uInt8 peek(uInt16 address, Device::AccessFlags flags);

    /**
      Change the byte at the specified address to the given value and
      update the cycle count.

      @param address  The address where the value should be stored
      @param value    The value to be stored at the address
    */
    void poke(uInt16 address, uInt8 value, Device::AccessFlags flags = Device::NONE);

    /**
      Get the 8-bit value of the Processor Status register.

      @return The processor status register
    */
    uInt8 PS() const {
      uInt8 ps = 0x20;

      if(N)     ps |= 0x80;
      if(V)     ps |= 0x40;
      if(B)     ps |= 0x10;
      if(D)     ps |= 0x08;
      if(I)     ps |= 0x04;
      if(!notZ) ps |= 0x02;
      if(C)     ps |= 0x01;

      return ps;
    }

    /**
      Change the Processor Status register to correspond to the given value.

      @param ps The value to set the processor status register to
    */
    void PS(uInt8 ps) {
      N = ps & 0x80;
      V = ps & 0x40;
      B = true;        // B = ps & 0x10;  The 6507's B flag always true
      D = ps & 0x08;
      I = ps & 0x04;
      notZ = !(ps & 0x02);
      C = ps & 0x01;
    }

    /**
      Called after an interrupt has be requested using irq() or nmi()
    */
    void interruptHandler();

    /**
      Check whether halt was requested (RDY low) and notify
    */
    void handleHalt();

    /**
      This is the actual dispatch function that does the grunt work. M6502::execute
      wraps it and makes sure that any pending halt is processed before returning.
    */
    void _execute(uInt64 cycles, DispatchResult& result);

#ifdef DEBUGGER_SUPPORT
    /**
      Check whether we are required to update hardware (TIA + RIOT) in lockstep
      with the CPU and update the flag accordingly.
    */
    void updateStepStateByInstruction();
#endif  // DEBUGGER_SUPPORT

  private:
    /**
      Bit fields used to indicate that certain conditions need to be
      handled such as stopping execution, fatal errors, maskable interrupts
      and non-maskable interrupts (in myExecutionStatus)
    */
    static constexpr uInt8
      StopExecutionBit        = 0x01,
      FatalErrorBit           = 0x02,
      MaskableInterruptBit    = 0x04,
      NonmaskableInterruptBit = 0x08
    ;
    uInt8 myExecutionStatus{0};

    /// Pointer to the system the processor is installed in or the null pointer
    System* mySystem{nullptr};

    /// Reference to the settings
    const Settings& mySettings;

    uInt8 A{0};    // Accumulator
    uInt8 X{0};    // X index register
    uInt8 Y{0};    // Y index register
    uInt8 SP{0};   // Stack Pointer
    uInt8 IR{0};   // Instruction register
    uInt16 PC{0};  // Program Counter

    bool N{false};     // N flag for processor status register
    bool V{false};     // V flag for processor status register
    bool B{false};     // B flag for processor status register
    bool D{false};     // D flag for processor status register
    bool I{false};     // I flag for processor status register
    bool notZ{false};  // Z flag complement for processor status register
    bool C{false};     // C flag for processor status register

    uInt8 icycles{0}; // cycles of last instruction

    /// Indicates the numer of distinct memory accesses
    uInt32 myNumberOfDistinctAccesses{0};

    /// Indicates the last address which was accessed
    uInt16 myLastAddress{0};

    /// Last cycle that triggered a breakpoint
    uInt64 myLastBreakCycle{ULLONG_MAX};

    /// Indicates the last address which was accessed specifically
    /// by a peek or poke command
    uInt16 myLastPeekAddress{0}, myLastPokeAddress{0};
    /// Indicates the last base (= non-mirrored) address which was
    /// accessed specifically by a peek or poke command
    uInt16 myLastPeekBaseAddress{0}, myLastPokeBaseAddress{0};
    // Indicates the type of the last access
    uInt16 myFlags{0};

    /// Indicates the last address used to access data by a peek command
    /// for the CPU registers (S/A/X/Y)
    Int32 myLastSrcAddressS{-1}, myLastSrcAddressA{-1},
          myLastSrcAddressX{-1}, myLastSrcAddressY{-1};

    /// Indicates the data address used by the last command that performed
    /// a poke (currently, the last address used by STx)
    /// If an address wasn't used (ie, as in immediate mode), the address
    /// is set to zero
    uInt16 myDataAddressForPoke{0};

    /// Indicates the number of system cycles per processor cycle
    static constexpr uInt32 SYSTEM_CYCLES_PER_CPU = 1;

    /// Called when the processor enters halt state
    onHaltCallback myOnHaltCallback{nullptr};

    /// Indicates whether RDY was pulled low
    bool myHaltRequested{false};

#ifdef DEBUGGER_SUPPORT
    Int32 evalCondBreaks() {
      for(Int32 i = static_cast<Int32>(myCondBreaks.size()) - 1; i >= 0; --i)
        if(myCondBreaks[i]->evaluate())
          return i;

      return -1; // no break hit
    }

    Int32 evalCondSaveStates()
    {
      for(Int32 i = static_cast<Int32>(myCondSaveStates.size()) - 1; i >= 0; --i)
        if(myCondSaveStates[i]->evaluate())
          return i;

      return -1; // no save state point hit
    }

    Int32 evalCondTraps()
    {
      for(Int32 i = static_cast<Int32>(myTrapConds.size()) - 1; i >= 0; --i)
        if(myTrapConds[i]->evaluate())
          return i;

      return -1; // no trapif hit
    }

    /// Pointer to the debugger for this processor or the null pointer
    Debugger* myDebugger{nullptr};

    // Addresses for which the specified action should occur
    TrapArray myReadTraps, myWriteTraps;

    // Did we just now hit a trap?
    bool myJustHitReadTrapFlag{false};
    bool myJustHitWriteTrapFlag{false};
    struct HitTrapInfo {
      string message;
      int address{0};
    };
    HitTrapInfo myHitTrapInfo;

    BreakpointMap myBreakPoints;
    vector<unique_ptr<Expression>> myCondBreaks;
    StringList myCondBreakNames;
    vector<unique_ptr<Expression>> myCondSaveStates;
    StringList myCondSaveStateNames;
    vector<unique_ptr<Expression>> myTrapConds;
    StringList myTrapCondNames;

    TimerMap myTimer;

#endif  // DEBUGGER_SUPPORT

    bool myGhostReadsTrap{false};          // trap on ghost reads
    bool myReadFromWritePortBreak{false};  // trap on reads from write ports
    bool myWriteToReadPortBreak{false};    // trap on writes to read ports
    bool myStepStateByInstruction{false};
    bool myLogBreaks{false};               // log breaks/taps and continue emulation
    bool myLogTrace{false};                // log emulation

  private:
    // Following constructors and assignment operators not supported
    M6502() = delete;
    M6502(const M6502&) = delete;
    M6502(M6502&&) = delete;
    M6502& operator=(const M6502&) = delete;
    M6502& operator=(M6502&&) = delete;
};

#endif
