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

#ifndef DEBUGGER_HXX
#define DEBUGGER_HXX

class OSystem;
class Console;
class EventHandler;
class TiaInfoWidget;
class TiaOutputWidget;
class TiaZoomWidget;
class EditTextWidget;
class RomWidget;
class Expression;
class BreakpointMap;
class TrapArray;
class PromptWidget;
class ButtonWidget;

class M6502;
class System;
class CartDebug;
class CpuDebug;
class RiotDebug;
class TIADebug;
class DebuggerParser;
class RewindManager;

#include <map>

#include "Base.hxx"
#include "Rect.hxx"
#include "DialogContainer.hxx"
#include "DebuggerDialog.hxx"
#include "FrameBufferConstants.hxx"
#include "Cart.hxx"
#include "bspf.hxx"

/**
  The base dialog for all debugging widgets in Stella.  Also acts as the parent
  for all debugging operations in Stella (parser, 6502 debugger, etc).

  @author  Stephen Anthony
*/
class Debugger : public DialogContainer
{
  // Make these friend classes, to ease communications with the debugger
  // Although it isn't enforced, these classes should use accessor methods
  // directly, and not touch the instance variables
  friend class DebuggerParser;
  friend class EventHandler;
  friend class M6502;

  public:
    using FunctionMap = std::map<string, unique_ptr<Expression>, std::less<>>;
    using FunctionDefMap = std::map<string, string, std::less<>>;

    /**
      Create a new debugger parent object
    */
    Debugger(OSystem& osystem, Console& console);
    ~Debugger() override;

  public:
    /**
      Initialize the debugger dialog container.
    */
    void initialize();

    /**
      Initialize the video subsystem wrt this class.
    */
    FBInitStatus initializeVideo();

    /**
      Wrapper method for EventHandler::enterDebugMode() for those classes
      that don't have access to EventHandler.

      @param message  Message to display when entering debugger
      @param address  An address associated with the message
    */
    bool start(string_view message = "", int address = -1, bool read = true,
               string_view toolTip = "");
    bool startWithFatalError(string_view message = "");

    /**
      Wrapper method for EventHandler::leaveDebugMode() for those classes
      that don't have access to EventHandler.
    */
    void exit(bool exitrom);

    /**
      Executed when debugger is quit.
    */
    void quit();

    bool addFunction(string_view name, string_view def,
                     Expression* exp, bool builtin = false);
    static bool isBuiltinFunction(string_view name);
    bool delFunction(string_view name);
    const Expression& getFunction(string_view name) const;

    const string& getFunctionDef(string_view name) const;
    FunctionDefMap getFunctionDefMap() const;
    static string builtinHelp();

    /**
      Methods used by the command parser for tab-completion
      In this case, return completions from the function list
    */
    void getCompletions(string_view in, StringList& list) const;

    /**
      The dialog/GUI associated with the debugger
    */
    Dialog& dialog() const { return *myDialog; }

    /**
      The debugger subsystem responsible for all CPU state
    */
    CpuDebug& cpuDebug() const { return *myCpuDebug; }

    /**
      The debugger subsystem responsible for all Cart RAM/ROM state
    */
    CartDebug& cartDebug() const { return *myCartDebug; }

    /**
      The debugger subsystem responsible for all RIOT state
    */
    RiotDebug& riotDebug() const { return *myRiotDebug; }

    /**
      The debugger subsystem responsible for all TIA state
    */
    TIADebug& tiaDebug() const { return *myTiaDebug; }

    const GUI::Font& lfont() const      { return myDialog->lfont();     }
    const GUI::Font& nlfont() const     { return myDialog->nfont();     }
    DebuggerParser& parser() const      { return *myParser;             }
    PromptWidget& prompt() const        { return myDialog->prompt();    }
    RomWidget& rom() const              { return myDialog->rom();       }
    TiaOutputWidget& tiaOutput() const  { return myDialog->tiaOutput(); }

    BreakpointMap& breakPoints() const;

    TrapArray& readTraps() const;
    TrapArray& writeTraps() const;

    /**
      Sets a breakpoint.

      Returns true if successfully set
    */
    bool setBreakPoint(uInt16 addr, uInt8 bank = ANY_BANK,
                       uInt32 flags = 0) const;

    /**
      Clears a breakpoint.

      Returns true if successfully cleared
    */
    bool clearBreakPoint(uInt16 addr, uInt8 bank) const;

    /**
      Toggles a breakpoint

      Returns new state of breakpoint
    */
    bool toggleBreakPoint(uInt16 addr, uInt8 bank) const;

    /**
      Checks for a breakpoint.

      Returns true if existing, else false
    */
    bool checkBreakPoint(uInt16 addr, uInt8 bank) const;

    /**
      Run the debugger command and return the result.
    */
    string run(string_view command);

    string autoExec(StringList* history);

    string showWatches();

    /**
      Convert between string->integer and integer->string, taking into
      account the current base format.
    */
    int stringToValue(string_view stringval);

    /* Convenience methods to get/set bit(s) in an 8-bit register */
    static uInt8 set_bit(uInt8 input, uInt8 bit, bool on)
    {
      if(on)
        return static_cast<uInt8>(input | (1 << bit));
      else
        return static_cast<uInt8>(input & ~(1 << bit));
    }
    static void set_bits(uInt8 reg, BoolArray& bits)
    {
      bits.clear();
      for(int i = 0; i < 8; ++i)
      {
        if(reg & (1<<(7-i)))
          bits.push_back(true);
        else
          bits.push_back(false);
      }
    }
    static uInt8 get_bits(const BoolArray& bits)
    {
      uInt8 result = 0x0;
      for(int i = 0; i < 8; ++i)
        if(bits[i])
          result |= (1<<(7-i));
      return result;
    }

    /** Invert given input if it differs from its previous value */
    static string invIfChanged(int reg, int oldReg);

    /**
      This is used when we want the debugger from a class that can't
      receive the debugger object in any other way.

      It's basically a hack to prevent the need to pass debugger objects
      everywhere, but I feel it's better to place it here then in
      YaccParser (which technically isn't related to it at all).
    */
    static Debugger& debugger() { return *myStaticDebugger; }

    /** Convenience methods to access peek/poke from System */
    uInt8 peek(uInt16 addr, Device::AccessFlags flags = Device::NONE);
    uInt16 dpeek(uInt16 addr, Device::AccessFlags flags = Device::NONE);
    void poke(uInt16 addr, uInt8 value, Device::AccessFlags flags = Device::NONE);

    /** Convenience method to access the 6502 from System */
    M6502& m6502() const;

    /** These are now exposed so Expressions can use them. */
    int peekAsInt(int addr, Device::AccessFlags flags = Device::NONE);
    int dpeekAsInt(int addr, Device::AccessFlags flags = Device::NONE);
    Device::AccessFlags getAccessFlags(uInt16 addr) const;
    void setAccessFlags(uInt16 addr, Device::AccessFlags flags);

    static uInt32 getBaseAddress(uInt32 addr, bool read);

    bool patchROM(uInt16 addr, uInt8 value);

    /**
      Normally, accessing RAM or ROM during emulation can possibly trigger
      bankswitching or other inadvertent changes.  However, when we're in
      the debugger, we'd like to inspect values without restriction.  The
      read/write state must therefore be locked before accessing values,
      and unlocked for normal emulation to occur.
    */
    void lockSystem();
    void unlockSystem();

    /**
      Answers whether the debugger can be exited.  Currently this only
      happens when no other dialogs are active.
    */
    bool canExit() const;

    /**
      Return (and possibly create) the bottom-most dialog of this container.
    */
    Dialog* baseDialog() override { return myDialog; }

  private:
    /**
      Save state of each debugger subsystem and, by default, mark all
      pages as clean (ie, turn off the dirty flag).
    */
    void saveOldState(bool clearDirtyPages = true);

    /**
      Saves a rewind state with the given message.
    */
    void addState(string_view rewindMsg);

    /**
      Set initial state before entering the debugger.
    */
    void setStartState();

    /**
      Set final state before leaving the debugger.
    */
    void setQuitState();

    int step(bool save = true);
    int trace();
    void nextScanline(int lines);
    void nextFrame(int frames);
    uInt16 rewindStates(const uInt16 numStates, string& message);
    uInt16 unwindStates(const uInt16 numStates, string& message);

    void clearAllBreakPoints() const;

    void addReadTrap(uInt16 t) const;
    void addWriteTrap(uInt16 t) const;
    void addTrap(uInt16 t) const;
    void removeReadTrap(uInt16 t) const;
    void removeWriteTrap(uInt16 t) const;
    void removeTrap(uInt16 t) const;
    bool readTrap(uInt16 t) const;
    bool writeTrap(uInt16 t) const;
    void clearAllTraps() const;
    void log(string_view triggerMsg);

    // Set a bunch of RAM locations at once
    string setRAM(IntArray& args);

    void reset();

    void saveState(int state);
    void saveAllStates();
    void loadState(int state);
    void loadAllStates();

  private:
    Console& myConsole;
    System&  mySystem;

    DebuggerDialog* myDialog{nullptr};
    unique_ptr<DebuggerParser> myParser;
    unique_ptr<CartDebug>      myCartDebug;
    unique_ptr<CpuDebug>       myCpuDebug;
    unique_ptr<RiotDebug>      myRiotDebug;
    unique_ptr<TIADebug>       myTiaDebug;

    static Debugger* myStaticDebugger;

    FunctionMap myFunctions;
    FunctionDefMap myFunctionDefs;

    // Dimensions of the entire debugger window
    Common::Size mySize{DebuggerDialog::kSmallFontMinW,
                        DebuggerDialog::kSmallFontMinH};

    // Various builtin functions and operations
    struct BuiltinFunction {
      string name, defn, help;
    };
    struct PseudoRegister {
      string name, help;
    };
    static std::array<BuiltinFunction, 18> ourBuiltinFunctions;
    static std::array<PseudoRegister, 18> ourPseudoRegisters;

    static constexpr Int8 ANY_BANK = -1;
    bool myFirstLog{true};

  private:
    // rewind/unwind n states
    uInt16 windStates(uInt16 numStates, bool unwind, string& message);
    // update the rewind/unwind button state
    void updateRewindbuttons(const RewindManager& r);

    // Following constructors and assignment operators not supported
    Debugger() = delete;
    Debugger(const Debugger&) = delete;
    Debugger(Debugger&&) = delete;
    Debugger& operator=(const Debugger&) = delete;
    Debugger& operator=(Debugger&&) = delete;
};

#endif
