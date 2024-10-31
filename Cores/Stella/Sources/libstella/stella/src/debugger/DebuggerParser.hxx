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

#ifndef DEBUGGER_PARSER_HXX
#define DEBUGGER_PARSER_HXX

#include <functional>
#include <set>

class Debugger;
class Settings;
class FSNode;
struct Command;

#include "bspf.hxx"
#include "Device.hxx"

class DebuggerParser
{
  public:
    DebuggerParser(Debugger& debugger, Settings& settings);

    /** Run the given command, and return the result */
    string run(string_view command);

    /** Execute parser commands given in 'file' */
    string exec(const FSNode& file, StringList* history = nullptr);

    /** Given a substring, determine matching substrings from the list
        of available commands.  Used in the debugger prompt for tab-completion */
    static void getCompletions(string_view in, StringList& completions);

    /** Evaluate the given expression using operators, current base, etc */
    int decipher_arg(string_view str);

    /** String representation of all watches currently defined */
    string showWatches();

    static inline string red(string_view msg = "")
    {
      return char(kDbgColorRed & 0xff) + string{msg};
    }
    static inline string inverse(string_view msg = "")
    {
      // ASCII DEL char, decimal 127
      return "\177" + string{msg};
    }

  private:
    bool getArgs(string_view command, string& verb);
    bool validateArgs(int cmd);
    string eval();
    string saveScriptFile(string file);
    static void saveDump(const FSNode& node, const stringstream& out,
                         ostringstream& result);
    const string& cartName() const;

  private:
    // Constants for argument processing
    enum class ParseState {
      IN_COMMAND,
      IN_SPACE,
      IN_BRACE,
      IN_ARG
    };

    enum class Parameters {
      ARG_WORD,        // single 16-bit value
      ARG_DWORD,       // single 32-bit value
      ARG_MULTI_WORD,  // multiple 16-bit values (must occur last)
      ARG_BYTE,        // single 8-bit value
      ARG_MULTI_BYTE,  // multiple 8-bit values (must occur last)
      ARG_BOOL,        // 0 or 1 only
      ARG_LABEL,       // label (need not be defined, treated as string)
      ARG_FILE,        // filename
      ARG_BASE_SPCL,   // base specifier: 2, 10, or 16 (or "bin" "dec" "hex")
      ARG_END_ARGS     // sentinel, occurs at end of list
    };

    // List of commands available
    struct Command {
      string cmdString;
      string description;
      string extendedDesc;
      bool parmsRequired{false};
      bool refreshRequired{false};
      std::array<Parameters, 10> parms;
      std::function<void (DebuggerParser*)> executor;
    };
    using CommandArray = std::array<Command, 111>;
    static CommandArray commands;

    struct Trap
    {
      bool read{false};
      bool write{false};
      uInt32 begin{0};
      uInt32 end{0};
      string condition;

      Trap(bool r, bool w, uInt32 b, uInt32 e, string_view c)
        : read(r), write(w), begin(b), end(e), condition(c) {}
    };

    // Reference to our debugger object
    Debugger& debugger;

    // Reference to settings object (required for saving certain options)
    Settings& settings;

    // The results of the currently running command
    ostringstream commandResult;

    // currently execute command id
    int myCommand{0};
    // Arguments in 'int' and 'string' format for the currently running command
    IntArray args;
    StringList argStrings;
    uInt32 argCount{0};

    uInt32 execDepth{0};
    string execPrefix;

    StringList myWatches;

    // Keep track of traps (read and/or write)
    vector<unique_ptr<Trap>> myTraps;
    void listTraps(bool listCond);
    string trapStatus(const Trap& trap);

    void printTimer(uInt32 idx,bool showHeader = true);
    void listTimers();

    // output the error with the example provided for the command
    void outputCommandError(string_view errorMsg, int command);

    void executeDirective(Device::AccessType type);

    // List of available command methods
    void executeA();
    void executeAud();
    void executeAutoSave();
    void executeBase();
    void executeBCol();
    void executeBreak();
    void executeBreakIf();
    void executeBreakLabel();
    void executeC();
    void executeCheat();
    void executeClearBreaks();
    void executeClearConfig();
    void executeClearHistory();
    void executeClearSaveStateIfs();
    void executeClearTimers();
    void executeClearTraps();
    void executeClearWatches();
    void executeCls();
    void executeCode();
    void executeCol();
    void executeColorTest();
    void executeD();
    void executeData();
    void executeDebugColors();
    void executeDefine();
    void executeDelBreakIf();
    void executeDelFunction();
    void executeDelSaveStateIf();
    void executeDelTimer();
    void executeDelTrap();
    void executeDelWatch();
    void executeDisAsm();
    void executeDump();
    void executeExec();
    void executeExitRom();
    void executeFrame();
    void executeFunction();
    void executeGfx();
    void executeHelp();
    void executeJoy0Up();
    void executeJoy0Down();
    void executeJoy0Left();
    void executeJoy0Right();
    void executeJoy0Fire();
    void executeJoy1Up();
    void executeJoy1Down();
    void executeJoy1Left();
    void executeJoy1Right();
    void executeJoy1Fire();
    void executeJump();
    void executeListBreaks();
    void executeListConfig();
    void executeListFunctions();
    void executeListSaveStateIfs();
    void executeListTimers();
    void executeListTraps();
    void executeLoadAllStates();
    void executeLoadConfig();
    void executeLoadState();
    void executeLogBreaks();
    void executeLogTrace();
    void executeN();
    void executePalette();
    void executePc();
    void executePCol();
    void executePGfx();
    void executePrint();
    void executePrintTimer();
    void executeRam();
    void executeReset();
    void executeResetTimers();
    void executeRewind();
    void executeRiot();
    void executeRom();
    void executeRow();
    void executeRun();
    void executeRunTo();
    void executeRunToPc();
    void executeS();
    void executeSave();
    void executeSaveAccess();
    void executeSaveAllStates();
    void executeSaveConfig();
    void executeSaveDisassembly();
    void executeSaveRom();
    void executeSaveSes();
    void executeSaveSnap();
    void executeSaveState();
    void executeSaveStateIf();
    void executeScanLine();
    void executeStep();
    void executeStepWhile();
    void executeSwchb();
    void executeTia();
    void executeTimer();
    void executeTrace();
    void executeTrap();
    void executeTrapIf();
    void executeTrapRead();
    void executeTrapReadIf();
    void executeTrapWrite();
    void executeTrapWriteIf();
    void executeTraps(bool read, bool write, string_view command, bool cond = false);
    void executeTrapRW(uInt32 addr, bool read, bool write, bool add = true);  // not exposed by debugger
    void executeType();
    void executeUHex();
    void executeUndef();
    void executeUnwind();
    void executeV();
    void executeWatch();
    void executeWinds(bool unwind);
    void executeX();
    void executeY();
    void executeZ();

  private:
    // Following constructors and assignment operators not supported
    DebuggerParser() = delete;
    DebuggerParser(const DebuggerParser&) = delete;
    DebuggerParser(DebuggerParser&&) = delete;
    DebuggerParser& operator=(const DebuggerParser&) = delete;
    DebuggerParser& operator=(DebuggerParser&&) = delete;
};

#endif
