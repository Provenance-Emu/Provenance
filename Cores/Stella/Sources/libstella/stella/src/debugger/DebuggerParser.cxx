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

#include "bspf.hxx"

#include "Dialog.hxx"
#include "Debugger.hxx"
#include "CartDebug.hxx"
#include "CpuDebug.hxx"
#include "RiotDebug.hxx"
#include "ControlLowLevel.hxx"
#include "TIADebug.hxx"
#include "TiaOutputWidget.hxx"
#include "YaccParser.hxx"
#include "Expression.hxx"
#include "FSNode.hxx"
#include "OSystem.hxx"
#include "System.hxx"
#include "M6502.hxx"
#include "Settings.hxx"
#include "PromptWidget.hxx"
#include "RomWidget.hxx"
#include "ProgressDialog.hxx"
#include "BrowserDialog.hxx"
#include "FrameBuffer.hxx"
#include "TimerManager.hxx"
#include "Vec.hxx"

#include "Base.hxx"
using Common::Base;
using std::hex;
using std::dec;
using std::setfill;
using std::setw;
using std::right;

#ifdef CHEATCODE_SUPPORT
  #include "Cheat.hxx"
  #include "CheatManager.hxx"
#endif

#include "DebuggerParser.hxx"

// TODO - use C++ streams instead of nasty C-strings and pointers

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
DebuggerParser::DebuggerParser(Debugger& d, Settings& s)
  : debugger{d},
    settings{s}
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// main entry point: PromptWidget calls this method.
string DebuggerParser::run(string_view command)
{
#if 0
  // this was our parser test code. Left for reference.
  static Expression *lastExpression;

  // special case: parser testing
  if(strncmp(command.c_str(), "expr ", 5) == 0) {
    delete lastExpression;
    commandResult = "parser test: status==";
    int status = YaccParser::parse(command.c_str() + 5);
    commandResult += debugger.valueToString(status);
    commandResult += ", result==";
    if(status == 0) {
      lastExpression = YaccParser::getResult();
      commandResult += debugger.valueToString(lastExpression->evaluate());
    } else {
      //  delete lastExpression; // NO! lastExpression isn't valid (not 0 either)
                                // It's the result of casting the last token
                                // to Expression* (because of yacc's union).
                                // As such, we can't and don't need to delete it
                                // (However, it means yacc leaks memory on error)
      commandResult += "ERROR - ";
      commandResult += YaccParser::errorMessage();
    }
    return commandResult;
  }

  if(command == "expr") {
    if(lastExpression)
      commandResult = "result==" + debugger.valueToString(lastExpression->evaluate());
    else
      commandResult = "no valid expr";
    return commandResult;
  }
#endif

  string verb;
  getArgs(command, verb);
  commandResult.str("");

  for(int i = 0; i < static_cast<int>(commands.size()); ++i)
  {
    if(BSPF::equalsIgnoreCase(verb, commands[i].cmdString))
    {
      if(validateArgs(i))
      {
        myCommand = i;
        if(commands[i].refreshRequired)
          debugger.baseDialog()->saveConfig();
        commands[i].executor(this);
      }

      if(commands[i].refreshRequired)
        debugger.baseDialog()->loadConfig();

      return commandResult.str();
    }
  }

  return red("No such command (try \"help\")");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string DebuggerParser::exec(const FSNode& file, StringList* history)
{
  if(file.exists())
  {
    stringstream in;
    try        { file.read(in); }
    catch(...) { return red("script file \'" + file.getShortPath() + "\' not found"); }

    ostringstream buf;
    int count = 0;
    string command;
    while( !in.eof() )
    {
      if(!getline(in, command))
        break;

      ++execDepth;
      run(command);
      --execDepth;
      if (history != nullptr)
        history->push_back(command);
      count++;
    }
    buf << "\nExecuted " << count << " command" << (count != 1 ? "s" : "") << " from \""
        << file.getShortPath() << "\"";

    return buf.str();
  }
  else
    return red("script file \'" + file.getShortPath() + "\' not found");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DebuggerParser::outputCommandError(string_view errorMsg, int command)
{
  const string example = commands[command].extendedDesc.substr(commands[command].extendedDesc.find("Example:"));

  commandResult << red(errorMsg);
  if(!example.empty())
    commandResult << '\n' << example;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Completion-related stuff:
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DebuggerParser::getCompletions(string_view in, StringList& completions)
{
  // cerr << "Attempting to complete \"" << in << "\"\n";
  for(const auto& c: commands)
  {
    if(BSPF::matchesCamelCase(c.cmdString, in))
      completions.push_back(c.cmdString);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Evaluate expression. Expressions always evaluate to a 16-bit value if
// they're valid, or -1 if they're not.
// decipher_arg may be called by the GUI as needed. It is also called
// internally by DebuggerParser::run()
int DebuggerParser::decipher_arg(string_view str)
{
  bool derefByte=false, derefWord=false, lobyte=false, hibyte=false, bin=false, dec=false;
  string arg{str};

  const Base::Fmt defaultBase = Base::format();

  if(defaultBase == Base::Fmt::_2) {
    bin=true; dec=false;
  } else if(defaultBase == Base::Fmt::_10) {
    bin=false; dec=true;
  } else {
    bin=false; dec=false;
  }

  if(arg.substr(0, 1) == "*") {
    derefByte = true;
    arg.erase(0, 1);
  } else if(arg.substr(0, 1) == "@") {
    derefWord = true;
    arg.erase(0, 1);
  }

  if(arg.substr(0, 1) == "<") {
    lobyte = true;
    arg.erase(0, 1);
  } else if(arg.substr(0, 1) == ">") {
    hibyte = true;
    arg.erase(0, 1);
  }

  if(arg.substr(0, 1) == "\\") {
    dec = false;
    bin = true;
    arg.erase(0, 1);
  } else if(arg.substr(0, 1) == "#") {
    dec = true;
    bin = false;
    arg.erase(0, 1);
  } else if(arg.substr(0, 1) == "$") {
    dec = false;
    bin = false;
    arg.erase(0, 1);
  }

  // Special cases (registers):
  const auto& state = static_cast<const CpuState&>(debugger.cpuDebug().getState());
  int result = 0;
  if(arg == "a" && str != "$a") result = state.A;
  else if(arg == "x") result = state.X;
  else if(arg == "y") result = state.Y;
  else if(arg == "p") result = state.PS;
  else if(arg == "s") result = state.SP;
  else if(arg == "pc" || arg == ".") result = state.PC;
  else { // Not a special, must be a regular arg: check for label first
    const char* a = arg.c_str();
    result = debugger.cartDebug().getAddress(arg);

    if(result < 0) { // if not label, must be a number
      if(bin) { // treat as binary
        result = 0;
        while(*a != '\0') {
          result <<= 1;
          switch(*a++) {
            case '1':
              result++;
              break;

            case '0':
              break;

            default:
              return -1;
          }
        }
      } else if(dec) {
        result = 0;
        while(*a != '\0') {
          const int digit = (*a++) - '0';
          if(digit < 0 || digit > 9)
            return -1;

          result = (result * 10) + digit;
        }
      } else { // must be hex.
        result = 0;
        while(*a != '\0') {
          int hex = -1;
          const char d = *a++;
          if(d >= '0' && d <= '9')  hex = d - '0';
          else if(d >= 'a' && d <= 'f') hex = d - 'a' + 10;
          else if(d >= 'A' && d <= 'F') hex = d - 'A' + 10;
          if(hex < 0)
            return -1;

          result = (result << 4) + hex;
        }
      }
    }
  }

  if(lobyte) result &= 0xff;
  else if(hibyte) result = (result >> 8) & 0xff;

  // dereference if we're supposed to:
  if(derefByte) result = debugger.peek(result);
  if(derefWord) result = debugger.dpeek(result);

  return result;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string DebuggerParser::showWatches()
{
  ostringstream buf;
  for(uInt32 i = 0; i < myWatches.size(); ++i)
  {
    if(!myWatches[i].empty())
    {
      // Clear the args, since we're going to pass them to eval()
      argStrings.clear();
      args.clear();

      argCount = 1;
      argStrings.push_back(myWatches[i]);
      args.push_back(decipher_arg(argStrings[0]));
      if(args[0] < 0)
        buf << "BAD WATCH " << (i+1) << ": " << argStrings[0] << '\n';
      else
        buf << " watch #" << (i+1) << " (" << argStrings[0] << ") -> " << eval() << '\n';
    }
  }
  return buf.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Private methods below
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool DebuggerParser::getArgs(string_view command, string& verb)
{
  ParseState state = ParseState::IN_COMMAND;
  size_t i = 0;
  const size_t length = command.length();
  string curArg;
  verb = "";

  argStrings.clear();
  args.clear();

  // cerr << "Parsing \"" << command << "\"" << ", length = " << command.length() << '\n';

  // First, pick apart string into space-separated tokens.
  // The first token is the command verb, the rest go in an array
  do
  {
    const char c = command[i++];
    switch(state)
    {
      case ParseState::IN_COMMAND:
        if(c == ' ')
          state = ParseState::IN_SPACE;
        else
          verb += c;
        break;
      case ParseState::IN_SPACE:
        if(c == '{')
          state = ParseState::IN_BRACE;
        else if(c != ' ') {
          state = ParseState::IN_ARG;
          curArg += c;
        }
        break;
      case ParseState::IN_BRACE:
        if(c == '}') {
          state = ParseState::IN_SPACE;
          argStrings.push_back(curArg);
          //  cerr << "{" << curArg << "}\n";
          curArg = "";
        } else {
          curArg += c;
        }
        break;
      case ParseState::IN_ARG:
        if(c == ' ') {
          state = ParseState::IN_SPACE;
          argStrings.push_back(curArg);
          curArg = "";
        } else {
          curArg += c;
        }
        break;
    }  // switch(state)
  }
  while(i < length);

  // Take care of the last argument, if there is one
  if(!curArg.empty())
    argStrings.push_back(curArg);

  argCount = static_cast<uInt32>(argStrings.size());

  for(uInt32 arg = 0; arg < argCount; ++arg)
  {
    if(!YaccParser::parse(argStrings[arg]))
    {
      unique_ptr<Expression> expr(YaccParser::getResult());
      args.push_back(expr->evaluate());
    }
    else
      args.push_back(-1);
  }

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool DebuggerParser::validateArgs(int cmd)
{
  // cerr << "entering validateArgs(" << cmd << ")\n";
  const bool required = commands[cmd].parmsRequired;
  Parameters* p = commands[cmd].parms.data();

  if(argCount == 0)
  {
    if(required)
    {
      void(commandResult.str());
      outputCommandError("missing required argument(s)", cmd);
      return false; // needed args. didn't get 'em.
    }
    else
      return true;  // no args needed, no args got
  }

  // Figure out how many arguments are required by the command
  uInt32 count = 0, argRequiredCount = 0;
  while(*p != Parameters::ARG_END_ARGS && *p != Parameters::ARG_MULTI_BYTE)
  {
    ++count;
    ++p;
  }

  // Evil hack: some commands intentionally take multiple arguments
  // In this case, the required number of arguments is unbounded
  argRequiredCount = (*p == Parameters::ARG_END_ARGS) ? count : argCount;

  p = commands[cmd].parms.data();
  uInt32 curCount = 0;

  do {
    if(curCount >= argCount)
      break;

    const uInt32 curArgInt  = args[curCount];
    const string& curArgStr = argStrings[curCount];

    switch(*p)
    {
      case Parameters::ARG_DWORD:
      #if 0   // TODO - do we need error checking at all here?
        if(curArgInt > 0xffffffff)
        {
          commandResult.str(red("invalid word argument (must be 0-$ffffffff)"));
          return false;
        }
      #endif
        break;

      case Parameters::ARG_WORD:
        if(curArgInt > 0xffff)
        {
          commandResult.str(red("invalid word argument (must be 0-$ffff)"));
          return false;
        }
        break;

      case Parameters::ARG_BYTE:
        if(curArgInt > 0xff)
        {
          commandResult.str(red("invalid byte argument (must be 0-$ff)"));
          return false;
        }
        break;

      case Parameters::ARG_BOOL:
        if(curArgInt != 0 && curArgInt != 1)
        {
          commandResult.str(red("invalid boolean argument (must be 0 or 1)"));
          return false;
        }
        break;

      case Parameters::ARG_BASE_SPCL:
        if(curArgInt != 2 && curArgInt != 10 && curArgInt != 16
           && curArgStr != "hex" && curArgStr != "dec" && curArgStr != "bin")
        {
          commandResult.str(red(
            R"(invalid base (must be #2, #10, #16, "bin", "dec", or "hex"))"
          ));
          return false;
        }
        break;

      case Parameters::ARG_LABEL:
      case Parameters::ARG_FILE:
        break; // TODO: validate these (for now any string's allowed)

      case Parameters::ARG_MULTI_BYTE:
      case Parameters::ARG_MULTI_WORD:
        break; // FIXME: validate these (for now, any number's allowed)

      case Parameters::ARG_END_ARGS:
        break;
    }
    ++curCount;
    ++p;

  } while(*p != Parameters::ARG_END_ARGS && curCount < argRequiredCount);

/*
cerr << "curCount         = " << curCount << '\n'
     << "argRequiredCount = " << argRequiredCount << '\n'
     << "*p               = " << *p << "\n\n";
*/

  if(curCount < argRequiredCount)
  {
    void(commandResult.str());
    outputCommandError("missing required argument(s)", cmd);
    return false;
  }
  else if(argCount > curCount)
  {
    void(commandResult.str());
    outputCommandError("too many arguments", cmd);
    return false;
  }

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string DebuggerParser::eval()
{
  ostringstream buf;
  for(uInt32 i = 0; i < argCount; ++i)
  {
    if(args[i] < 0x10000)
    {
      string rlabel = debugger.cartDebug().getLabel(args[i], true);
      string wlabel = debugger.cartDebug().getLabel(args[i], false);
      const bool validR = !rlabel.empty() && rlabel[0] != '$',
                 validW = !wlabel.empty() && wlabel[0] != '$';
      if(validR && validW)
      {
        if(rlabel == wlabel)
          buf << rlabel << "(R/W): ";
        else
          buf << rlabel << "(R) / " << wlabel << "(W): ";
      }
      else if(validR)
        buf << rlabel << "(R): ";
      else if(validW)
        buf << wlabel << "(W): ";
    }

    buf << "$" << Base::toString(args[i], Base::Fmt::_16);

    if(args[i] < 0x10000)
      buf << " %" << Base::toString(args[i], Base::Fmt::_2);

    buf << " #" << static_cast<int>(args[i]);
    if(i != argCount - 1)
      buf << '\n';
  }

  return buf.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const string& DebuggerParser::cartName() const
{
  return debugger.myOSystem.console().properties().get(PropType::Cart_Name);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DebuggerParser::printTimer(uInt32 idx, bool showHeader)
{
  if(idx >= debugger.m6502().numTimers())
  {
    commandResult << red("invalid timer");
    return;
  }

  const TimerMap::Timer& timer = debugger.m6502().getTimer(idx);
  const bool banked = debugger.cartDebug().romBankCount() > 1;
  ostringstream buf;

  if(!debugger.cartDebug().getLabel(buf, timer.from.addr, true))
    buf << "    $" << setw(4) << Base::HEX4 << timer.from.addr;
  string labelFrom = buf.str();
  labelFrom = labelFrom.substr(0, (banked ? 12 : 15) - (timer.mirrors ? 1 : 0));
  labelFrom += (timer.mirrors ? "+" : "");
  labelFrom = (labelFrom + "              ").substr(0, banked ? 12 : 15);

  buf.str("");
  if(!debugger.cartDebug().getLabel(buf, timer.to.addr, true))
    buf << "    $" << setw(4) << Base::HEX4 << timer.to.addr;
  string labelTo = buf.str();
  labelTo   = labelTo.substr(0, (banked ? 12 : 15) - (timer.mirrors ? 1 : 0));
  labelTo += (timer.mirrors ? "+" : "");
  labelTo   = (labelTo   + "              ").substr(0, banked ? 12 : 15);

  if(showHeader)
  {
    if(banked)
      commandResult << " #|    From    /Bk|     To     /Bk| Execs| Avg. | Min. | Max. |";
    else
      commandResult << " #|     From      |      To       | Execs| Avg. | Min. | Max. |";
  }
  commandResult << '\n' << Base::toString(idx) << "|" << labelFrom;
  if(banked)
  {
    commandResult << "/" << setw(2) << setfill(' ');
    if(timer.anyBank)
      commandResult << "*";
    else
      commandResult << dec << static_cast<uInt16>(timer.from.bank);
  }
  commandResult << "|";
  if(timer.isPartial)
    commandResult << (banked ? "       -       " : "      -        ")
      << "|     -|     -|     -|     -|";
  else
  {
    commandResult << labelTo;
    if(banked)
    {
      commandResult << "/" << setw(2) << setfill(' ');
      if(timer.anyBank)
        commandResult << "*";
      else
        commandResult << dec << static_cast<uInt16>(timer.to.bank);
    }
    commandResult << "|"
      << setw(6) << setfill(' ') << dec << timer.execs << "|";
    if(!timer.execs)
      commandResult << "     -|     -|     -|";
    else
      commandResult
      << setw(6) << dec << timer.averageCycles() << "|"
      << setw(6) << dec << timer.minCycles << "|"
      << setw(6) << dec << timer.maxCycles << "|";
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DebuggerParser::listTimers()
{
  commandResult << "timers:\n";

  for(uInt32 i = 0; i < debugger.m6502().numTimers(); ++i)
    printTimer(i, i == 0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DebuggerParser::listTraps(bool listCond)
{
  StringList names = debugger.m6502().getCondTrapNames();

  commandResult << (listCond ? "trapifs:" : "traps:") << '\n';
  for(uInt32 i = 0; i < names.size(); ++i)
  {
    const bool hasCond = !names[i].empty();
    if(hasCond == listCond)
    {
      commandResult << Base::toString(i) << ": ";
      if(myTraps[i]->read && myTraps[i]->write)
        commandResult << "read|write";
      else if(myTraps[i]->read)
        commandResult << "read      ";
      else if(myTraps[i]->write)
        commandResult << "     write";
      else
        commandResult << "none";

      if(hasCond)
        commandResult << " " << names[i];
      commandResult << " " << debugger.cartDebug().getLabel(myTraps[i]->begin, true, 4);
      if(myTraps[i]->begin != myTraps[i]->end)
        commandResult << " " << debugger.cartDebug().getLabel(myTraps[i]->end, true, 4);
      commandResult << trapStatus(*myTraps[i]);
      commandResult << " + mirrors";
      if(i != (names.size() - 1)) commandResult << '\n';
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string DebuggerParser::trapStatus(const Trap& trap)
{
  stringstream result;
  const string lblb = debugger.cartDebug().getLabel(trap.begin, !trap.write);
  const string lble = debugger.cartDebug().getLabel(trap.end, !trap.write);

  if(!lblb.empty()) {
    result << " (";
    result << lblb;
  }

  if(trap.begin != trap.end)
  {
    if(!lble.empty())
    {
      if(!lblb.empty())
        result << " ";
      else
        result << " (";
      result << lble;
    }
  }
  if(!lblb.empty() || !lble.empty())
    result << ")";

  return result.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string DebuggerParser::saveScriptFile(string file)
{
  stringstream out;
  const Debugger::FunctionDefMap funcs = debugger.getFunctionDefMap();
  for(const auto& [name, cmd]: funcs)
    if (!Debugger::isBuiltinFunction(name))
      out << "function " << name << " {" << cmd << "}\n";

  for(const auto& w: myWatches)
    out << "watch " << w << '\n';

  for(const auto& bp: debugger.breakPoints().getBreakpoints())
    out << "break " << Base::toString(bp.addr) << " " << Base::toString(bp.bank) << '\n';

  StringList conds = debugger.m6502().getCondBreakNames();
  for(const auto& cond : conds)
    out << "breakIf {" << cond << "}\n";

  conds = debugger.m6502().getCondSaveStateNames();
  for(const auto& cond : conds)
    out << "saveStateIf {" << cond << "}\n";

  StringList names = debugger.m6502().getCondTrapNames();
  for(uInt32 i = 0; i < myTraps.size(); ++i)
  {
    const bool read = myTraps[i]->read,
               write = myTraps[i]->write,
               hasCond = !names[i].empty();

    if(read && write)
      out << "trap";
    else if(read)
      out << "trapRead";
    else if(write)
      out << "trapWrite";
    if(hasCond)
      out << "if {" << names[i] << "}";
    out << " " << Base::toString(myTraps[i]->begin);
    if(myTraps[i]->begin != myTraps[i]->end)
      out << " " << Base::toString(myTraps[i]->end);
    out << '\n';
  }

  // Append 'script' extension when necessary
  if(file.find_last_of('.') == string::npos)
    file += ".script";

  // Use user dir if no path is provided
  if(file.find_first_of(FSNode::PATH_SEPARATOR) == string::npos)
    file = debugger.myOSystem.userDir().getPath() + file;

  const FSNode node(file);

  if(node.exists() || !out.str().empty())
  {
    try
    {
      node.write(out);
    }
    catch(...)
    {
      return "Unable to save script to " + node.getShortPath();
    }

    return "saved " + node.getShortPath() + " OK";
  }
  else
    return "nothing to save";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DebuggerParser::saveDump(const FSNode& node, const stringstream& out,
                              ostringstream& result)
{
  try
  {
    node.write(out);
    result << " to file " << node.getShortPath();
  }
  catch(...)
  {
    result.str(red("Unable to append dump to file " + node.getShortPath()));
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DebuggerParser::executeDirective(Device::AccessType type)
{
  if(argCount != 2)
  {
    outputCommandError("specify start and end of range only", myCommand);
    return;
  }
  else if(args[1] < args[0])
  {
    commandResult << red("start address must be <= end address");
    return;
  }

  const bool result = debugger.cartDebug().addDirective(type, args[0], args[1]);

  commandResult << (result ? "added " : "removed ");
  CartDebug::AccessTypeAsString(commandResult, type);
  commandResult << " directive on range $"
    << hex << args[0] << " $" << hex << args[1];
  debugger.rom().invalidate();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// executor methods for commands[] array. All are void, no args.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "a"
void DebuggerParser::executeA()
{
  debugger.cpuDebug().setA(static_cast<uInt8>(args[0]));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "aud"
void DebuggerParser::executeAud()
{
  executeDirective(Device::AUD);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "autoSave"
void DebuggerParser::executeAutoSave()
{
  const bool enable = !settings.getBool("dbg.autosave");

  settings.setValue("dbg.autosave", enable);
  commandResult << "autoSave " << (enable ? "enabled" : "disabled");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "base"
void DebuggerParser::executeBase()
{
  if(args[0] == 2 || argStrings[0] == "bin")
    Base::setFormat(Base::Fmt::_2);
  else if(args[0] == 10 || argStrings[0] == "dec")
    Base::setFormat(Base::Fmt::_10);
  else if(args[0] == 16 || argStrings[0] == "hex")
    Base::setFormat(Base::Fmt::_16);

  commandResult << "default number base set to ";
  switch(Base::format()) {
    case Base::Fmt::_2:
      commandResult << "#2/bin";
      break;

    case Base::Fmt::_10:
      commandResult << "#10/dec";
      break;

    case Base::Fmt::_16:
      commandResult << "#16/hex";
      break;

    default:
      commandResult << red("UNKNOWN");
      break;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "bCol"
void DebuggerParser::executeBCol()
{
  executeDirective(Device::BCOL);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "break"
void DebuggerParser::executeBreak()
{
  const uInt32 romBankCount = debugger.cartDebug().romBankCount();
  const uInt16 addr = (argCount == 0) ? debugger.cpuDebug().pc() : args[0];
  uInt8 bank = 0;

  if(argCount < 2)
    bank = debugger.cartDebug().getBank(addr);
  else
  {
    bank = args[1];
    if(bank >= romBankCount && bank != 0xff)
    {
      commandResult << red("invalid bank");
      return;
    }
  }
  if(bank != 0xff)
  {
    const bool set = debugger.toggleBreakPoint(addr, bank);

    if(set)
      commandResult << "set";
    else
      commandResult << "cleared";

    commandResult << " breakpoint at $" << Base::HEX4 << addr << " + mirrors";
    if(romBankCount > 1)
      commandResult << " in bank #" << std::dec << static_cast<int>(bank);
  }
  else
  {
    for(int i = 0; i < debugger.cartDebug().romBankCount(); ++i)
    {
      const bool set = debugger.toggleBreakPoint(addr, i);

      if(i)
        commandResult << '\n';

      if(set)
        commandResult << "set";
      else
        commandResult << "cleared";

      commandResult << " breakpoint at $" << Base::HEX4 << addr << " + mirrors";
      if(romBankCount > 1)
        commandResult << " in bank #" << std::dec << static_cast<int>(bank);
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "breakIf"
void DebuggerParser::executeBreakIf()
{
  const int res = YaccParser::parse(argStrings[0]);
  if(res == 0)
  {
    const string condition = argStrings[0];
    for(uInt32 i = 0; i < debugger.m6502().getCondBreakNames().size(); ++i)
    {
      if(condition == debugger.m6502().getCondBreakNames()[i])
      {
        args[0] = i;
        executeDelBreakIf();
        return;
      }
    }
    const uInt32 ret = debugger.m6502().addCondBreak(
                          YaccParser::getResult(), argStrings[0]);
    commandResult << "added breakIf " << Base::toString(ret);
  }
  else
    commandResult << red("invalid expression");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "breakLabel"
void DebuggerParser::executeBreakLabel()
{
  const uInt16 addr = (argCount == 0) ? debugger.cpuDebug().pc() : args[0];
  const bool set = debugger.toggleBreakPoint(addr, BreakpointMap::ANY_BANK);

  commandResult << (set ? "set" : "cleared");
  commandResult << " breakpoint at $" << Base::HEX4 << addr << " (no mirrors)";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "c"
void DebuggerParser::executeC()
{
  if(argCount == 0)
    debugger.cpuDebug().toggleC();
  else if(argCount == 1)
    debugger.cpuDebug().setC(args[0]);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "cheat"
// (see Stella manual for different cheat types)
void DebuggerParser::executeCheat()
{
#ifdef CHEATCODE_SUPPORT
  if(argCount == 0)
  {
    outputCommandError("missing cheat code", myCommand);
    return;
  }

  for(uInt32 arg = 0; arg < argCount; ++arg)
  {
    const string& cheat = argStrings[arg];
    if(debugger.myOSystem.cheat().add("DBG", cheat))
      commandResult << "cheat code " << cheat << " enabled\n";
    else
      commandResult << red("invalid cheat code ") << cheat << '\n';
  }
#else
  commandResult << red("Cheat support not enabled\n");
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "clearBreaks"
void DebuggerParser::executeClearBreaks()
{
  debugger.clearAllBreakPoints();
  debugger.m6502().clearCondBreaks();
  commandResult << "all breakpoints cleared";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "clearConfig"
void DebuggerParser::executeClearConfig()
{
  if(argCount == 1)
    commandResult << debugger.cartDebug().clearConfig(args[0]);
  else
    commandResult << debugger.cartDebug().clearConfig();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "clearHistory"
void DebuggerParser::executeClearHistory()
{
  debugger.prompt().clearHistory();
  commandResult << "";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "clearBreaks"
void DebuggerParser::executeClearSaveStateIfs()
{
  debugger.m6502().clearCondSaveStates();
  commandResult << "all saveState points cleared";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "clearTimers"
void DebuggerParser::executeClearTimers()
{
  debugger.m6502().clearTimers();
  commandResult << "all timers cleared";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "clearTraps"
void DebuggerParser::executeClearTraps()
{
  debugger.clearAllTraps();
  debugger.m6502().clearCondTraps();
  myTraps.clear();
  commandResult << "all traps cleared";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "clearWatches"
void DebuggerParser::executeClearWatches()
{
  myWatches.clear();
  commandResult << "all watches cleared";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "cls"
void DebuggerParser::executeCls()
{
  debugger.prompt().clearScreen();
  commandResult << "";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "code"
void DebuggerParser::executeCode()
{
  executeDirective(Device::CODE);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "col"
void DebuggerParser::executeCol()
{
  executeDirective(Device::COL);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "colorTest"
void DebuggerParser::executeColorTest()
{
  commandResult << "test color: "
                << static_cast<char>((args[0]>>1) | 0x80)
                << inverse("        ");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "d"
void DebuggerParser::executeD()
{
  if(argCount == 0)
    debugger.cpuDebug().toggleD();
  else if(argCount == 1)
    debugger.cpuDebug().setD(args[0]);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "data"
void DebuggerParser::executeData()
{
  executeDirective(Device::DATA);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "debugColors"
void DebuggerParser::executeDebugColors()
{
  commandResult << debugger.tiaDebug().debugColors();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "define"
void DebuggerParser::executeDefine()
{
  // TODO: check if label already defined?
  debugger.cartDebug().addLabel(argStrings[0], args[1]);
  debugger.rom().invalidate();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "delBreakIf"
void DebuggerParser::executeDelBreakIf()
{
  if (debugger.m6502().delCondBreak(args[0]))
    commandResult << "removed breakIf " << Base::toString(args[0]);
  else
    commandResult << red("no such breakIf");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "delFunction"
void DebuggerParser::executeDelFunction()
{
  if(debugger.delFunction(argStrings[0]))
    commandResult << "removed function " << argStrings[0];
  else
    commandResult << "function " << argStrings[0] << " built-in or not found";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "delSaveStateIf"
void DebuggerParser::executeDelSaveStateIf()
{
  if(debugger.m6502().delCondSaveState(args[0]))
    commandResult << "removed saveStateIf " << Base::toString(args[0]);
  else
    commandResult << red("no such saveStateIf");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "delTimer"
void DebuggerParser::executeDelTimer()
{
  const int index = args[0];
  if(debugger.m6502().delTimer(index))
    commandResult << "removed timer " << Base::toString(index);
  else
    commandResult << red("no such timer");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "delTrap"
void DebuggerParser::executeDelTrap()
{
  const int index = args[0];

  if(debugger.m6502().delCondTrap(index))
  {
    for(uInt32 addr = myTraps[index]->begin; addr <= myTraps[index]->end; ++addr)
      executeTrapRW(addr, myTraps[index]->read, myTraps[index]->write, false);
    // @sa666666: please check this:
    Vec::removeAt(myTraps, index);
    commandResult << "removed trap " << Base::toString(index);
  }
  else
    commandResult << red("no such trap");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "delWatch"
void DebuggerParser::executeDelWatch()
{
  const int which = args[0] - 1;
  if(which >= 0 && which < static_cast<int>(myWatches.size()))
  {
    Vec::removeAt(myWatches, which);
    commandResult << "removed watch";
  }
  else
    commandResult << red("no such watch");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "disAsm"
void DebuggerParser::executeDisAsm()
{
  int start = 0, lines = 20;

  if(argCount == 0) {
    start = debugger.cpuDebug().pc();
  } else if(argCount == 1) {
    start = args[0];
  } else if(argCount == 2) {
    start = args[0];
    lines = args[1];
  } else {
    outputCommandError("wrong number of arguments", myCommand);
    return;
  }

  commandResult << debugger.cartDebug().disassembleLines(start, lines);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "dump"
void DebuggerParser::executeDump()
{
  const auto dump = [&](ostream& os, int start, int end)
  {
    for(int i = start; i <= end; i += 16)
    {
      // Print label every 16 bytes
      os << Base::toString(i) << ": ";

      for(int j = i; j < i+16 && j <= end; ++j)
      {
        os << Base::toString(debugger.peek(j)) << " ";
        if(j == i+7 && j != end) os << "- ";
      }
      os << '\n';
    }
  };

  // Error checking
  if(argCount == 0 || argCount > 4)
  {
    outputCommandError("wrong number of arguments", myCommand);
    return;
  }
  if(argCount > 1 && args[1] < args[0])
  {
    commandResult << red("start address must be <= end address");
    return;
  }

  if(argCount == 1)
    dump(commandResult, args[0], args[0] + 127);
  else if(argCount == 2 || args[2] == 0)
    dump(commandResult, args[0], args[1]);
  else
  {
    if((args[2] & 0x07) == 0)
    {
      commandResult << red("dump flags must be 1..7");
      return;
    }
    if(argCount == 4 && argStrings[3] != "?")
    {
      commandResult << red("browser dialog parameter must be '?'");
      return;
    }

    ostringstream path;
    path << debugger.myOSystem.userDir() << cartName() << "_dbg_";
    if(execDepth > 0)
      path << execPrefix;
    else
      path << std::hex << std::setw(8) << std::setfill('0')
           << static_cast<uInt32>(TimerManager::getTicks() / 1000);
    path << ".dump";

    commandResult << "dumped ";

    stringstream out;
    if((args[2] & 0x01) != 0)
    {
      // dump memory
      dump(out, args[0], args[1]);
      commandResult << "bytes from $" << hex << args[0] << " to $" << hex << args[1];
      if((args[2] & 0x06) != 0)
        commandResult << ", ";
    }
    if((args[2] & 0x02) != 0)
    {
      // dump CPU state
      const CpuDebug& cpu = debugger.cpuDebug();
      out << "   <PC>PC SP  A  X  Y  -  -    N  V  B  D  I  Z  C  -\n";
      out << "XC: "
        << Base::toString(cpu.pc() & 0xff) << " "    // PC lsb
        << Base::toString(cpu.pc() >> 8) << " "    // PC msb
        << Base::toString(cpu.sp()) << " "    // SP
        << Base::toString(cpu.a()) << " "    // A
        << Base::toString(cpu.x()) << " "    // X
        << Base::toString(cpu.y()) << " "    // Y
        << Base::toString(0) << " "    // unused
        << Base::toString(0) << " - "  // unused
        << Base::toString(cpu.n()) << " "    // N (flag)
        << Base::toString(cpu.v()) << " "    // V (flag)
        << Base::toString(cpu.b()) << " "    // B (flag)
        << Base::toString(cpu.d()) << " "    // D (flag)
        << Base::toString(cpu.i()) << " "    // I (flag)
        << Base::toString(cpu.z()) << " "    // Z (flag)
        << Base::toString(cpu.c()) << " "    // C (flag)
        << Base::toString(0) << " "    // unused
        << '\n';
      commandResult << "CPU state";
      if((args[2] & 0x04) != 0)
        commandResult << ", ";
    }
    if((args[2] & 0x04) != 0)
    {
      // dump SWCHx/INPTx state
      out << "   SWA - SWB  - IT  -  -  -   I0 I1 I2 I3 I4 I5 -  -\n";
      out << "XS: "
        << Base::toString(debugger.peek(0x280)) << " "    // SWCHA
        << Base::toString(0) << " "    // unused
        << Base::toString(debugger.peek(0x282)) << " "    // SWCHB
        << Base::toString(0) << " "    // unused
        << Base::toString(debugger.peek(0x284)) << " "    // INTIM
        << Base::toString(0) << " "    // unused
        << Base::toString(0) << " "    // unused
        << Base::toString(0) << " - "  // unused
        << Base::toString(debugger.peek(TIARegister::INPT0)) << " "
        << Base::toString(debugger.peek(TIARegister::INPT1)) << " "
        << Base::toString(debugger.peek(TIARegister::INPT2)) << " "
        << Base::toString(debugger.peek(TIARegister::INPT3)) << " "
        << Base::toString(debugger.peek(TIARegister::INPT4)) << " "
        << Base::toString(debugger.peek(TIARegister::INPT5)) << " "
        << Base::toString(0) << " "    // unused
        << Base::toString(0) << " "    // unused
        << '\n';
      commandResult << "switches and fire buttons";
    }

    if(argCount == 4)
    {
      // FIXME: C++ doesn't currently allow capture of stringstreams
      //        So we pass a copy of its contents, then re-create the
      //        stream inside the lambda
      //        Maybe this will change in a future version
      const string outStr = out.str();
      const string resultStr = commandResult.str();

      DebuggerDialog* dlg = debugger.myDialog;
      BrowserDialog::show(dlg, "Save Dump as", path.str(),
                          BrowserDialog::Mode::FileSave,
                          [dlg, outStr, resultStr]
                          (bool OK, const FSNode& node)
      {
        if(OK)
        {
          const stringstream localOut(outStr);
          ostringstream localResult(resultStr, std::ios_base::app);

          saveDump(node, localOut, localResult);
          dlg->prompt().print(localResult.str() + '\n');
        }
        dlg->prompt().printPrompt();
      });
      // avoid printing a new prompt
      commandResult.str("_NO_PROMPT");
    }
    else
      saveDump(FSNode(path.str()), out, commandResult);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "exec"
void DebuggerParser::executeExec()
{
  // Append 'script' extension when necessary
  string file = argStrings[0];
  if(file.find_last_of('.') == string::npos)
    file += ".script";
  FSNode node(file);
  if (!node.exists())
    node = FSNode(debugger.myOSystem.userDir().getPath() + file);

  if (argCount == 2) {
    execPrefix = argStrings[1];
  }
  else {
    ostringstream prefix;
    prefix << std::hex << std::setw(8) << std::setfill('0')
           << static_cast<uInt32>(TimerManager::getTicks()/1000);
    execPrefix = prefix.str();
  }

  // make sure the commands are added to prompt history
  StringList history;

  commandResult << exec(node, &history);

  for(const auto& item: history)
    debugger.prompt().addToHistory(item.c_str());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "exitRom"
void DebuggerParser::executeExitRom()
{
  debugger.exit(true);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "frame"
void DebuggerParser::executeFrame()
{
  int count = 1;
  if(argCount != 0) count = args[0];
  debugger.nextFrame(count);
  commandResult << "advanced " << dec << count << " frame(s)";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "function"
void DebuggerParser::executeFunction()
{
  if(args[0] >= 0)
  {
    commandResult << red("name already in use");
    return;
  }

  const int res = YaccParser::parse(argStrings[1]);
  if(res == 0)
  {
    debugger.addFunction(argStrings[0], argStrings[1], YaccParser::getResult());
    commandResult << "added function " << argStrings[0] << " -> " << argStrings[1];
  }
  else
    commandResult << red("invalid expression");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "gfx"
void DebuggerParser::executeGfx()
{
  executeDirective(Device::GFX);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "help"
void DebuggerParser::executeHelp()
{
  if(argCount == 0)  // normal help, show all commands
  {
    // Find length of longest command
    size_t clen = 0;
    for(const auto& c: commands)
    {
      const size_t len = c.cmdString.length();
      if(len > clen)  clen = len;
    }

    commandResult << setfill(' ');
    for(const auto& c: commands)
      commandResult << setw(static_cast<int>(clen)) << right << c.cmdString
                    << " - " << c.description << '\n';

    commandResult << Debugger::builtinHelp();
  }
  else  // get help for specific command
  {
    for(const auto& c: commands)
    {
      if(argStrings[0] == c.cmdString)
      {
        commandResult << "  " << red(c.description) << '\n' << c.extendedDesc;
        break;
      }
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "joy0Up"
void DebuggerParser::executeJoy0Up()
{
  ControllerLowLevel lport(debugger.myOSystem.console().leftController());
  if(argCount == 0)
    lport.togglePin(Controller::DigitalPin::One);
  else if(argCount == 1)
    lport.setPin(Controller::DigitalPin::One, args[0] != 0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "joy0Down"
void DebuggerParser::executeJoy0Down()
{
  ControllerLowLevel lport(debugger.myOSystem.console().leftController());
  if(argCount == 0)
    lport.togglePin(Controller::DigitalPin::Two);
  else if(argCount == 1)
    lport.setPin(Controller::DigitalPin::Two, args[0] != 0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "joy0Left"
void DebuggerParser::executeJoy0Left()
{
  ControllerLowLevel lport(debugger.myOSystem.console().leftController());
  if(argCount == 0)
    lport.togglePin(Controller::DigitalPin::Three);
  else if(argCount == 1)
    lport.setPin(Controller::DigitalPin::Three, args[0] != 0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "joy0Right"
void DebuggerParser::executeJoy0Right()
{
  ControllerLowLevel lport(debugger.myOSystem.console().leftController());
  if(argCount == 0)
    lport.togglePin(Controller::DigitalPin::Four);
  else if(argCount == 1)
    lport.setPin(Controller::DigitalPin::Four, args[0] != 0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "joy0Fire"
void DebuggerParser::executeJoy0Fire()
{
  ControllerLowLevel lport(debugger.myOSystem.console().leftController());
  if(argCount == 0)
    lport.togglePin(Controller::DigitalPin::Six);
  else if(argCount == 1)
    lport.setPin(Controller::DigitalPin::Six, args[0] != 0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "joy1Up"
void DebuggerParser::executeJoy1Up()
{
  ControllerLowLevel rport(debugger.myOSystem.console().rightController());
  if(argCount == 0)
    rport.togglePin(Controller::DigitalPin::One);
  else if(argCount == 1)
    rport.setPin(Controller::DigitalPin::One, args[0] != 0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "joy1Down"
void DebuggerParser::executeJoy1Down()
{
  ControllerLowLevel rport(debugger.myOSystem.console().rightController());
  if(argCount == 0)
    rport.togglePin(Controller::DigitalPin::Two);
  else if(argCount == 1)
    rport.setPin(Controller::DigitalPin::Two, args[0] != 0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "joy1Left"
void DebuggerParser::executeJoy1Left()
{
  ControllerLowLevel rport(debugger.myOSystem.console().rightController());
  if(argCount == 0)
    rport.togglePin(Controller::DigitalPin::Three);
  else if(argCount == 1)
    rport.setPin(Controller::DigitalPin::Three, args[0] != 0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "joy1Right"
void DebuggerParser::executeJoy1Right()
{
  ControllerLowLevel rport(debugger.myOSystem.console().rightController());
  if(argCount == 0)
    rport.togglePin(Controller::DigitalPin::Four);
  else if(argCount == 1)
    rport.setPin(Controller::DigitalPin::Four, args[0] != 0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "joy1Fire"
void DebuggerParser::executeJoy1Fire()
{
  ControllerLowLevel rport(debugger.myOSystem.console().rightController());
  if(argCount == 0)
    rport.togglePin(Controller::DigitalPin::Six);
  else if(argCount == 1)
    rport.setPin(Controller::DigitalPin::Six, args[0] != 0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "jump"
void DebuggerParser::executeJump()
{
  int line = -1;
  int address = args[0];

  // The specific address we want may not exist (it may be part of a data section)
  // If so, scroll backward a little until we find it
  while(((line = debugger.cartDebug().addressToLine(address)) == -1) &&
        (address >= 0))
    address--;

  if(line >= 0 && address >= 0)
  {
    debugger.rom().scrollTo(line);
    commandResult << "disassembly scrolled to address $" << Base::HEX4 << address;
  }
  else
    commandResult << "address $" << Base::HEX4 << args[0] << " doesn't exist";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "listBreaks"
void DebuggerParser::executeListBreaks()
{
  stringstream buf;
  int count = 0;
  const uInt32 romBankCount = debugger.cartDebug().romBankCount();

  for(const auto& bp: debugger.breakPoints().getBreakpoints())
  {
    if(romBankCount == 1)
    {
      buf << debugger.cartDebug().getLabel(bp.addr, true, 4) << " ";
      if(!(++count % 8)) buf << '\n';
    }
    else
    {
      if(count % 6)
        buf << ", ";
      buf << debugger.cartDebug().getLabel(bp.addr, true, 4);
      if(bp.bank != 255)
        buf << " #" << static_cast<int>(bp.bank);
      else
        buf << " *";
      if(!(++count % 6)) buf << '\n';
    }
  }
  if(count)
    commandResult << "breaks:\n" << buf.str();

  StringList conds = debugger.m6502().getCondBreakNames();

  if(!conds.empty())
  {
    if(count)
      commandResult << '\n';
    commandResult << "BreakIfs:\n";
    for(uInt32 i = 0; i < conds.size(); ++i)
    {
      commandResult << Base::toString(i) << ": " << conds[i];
      if(i != (conds.size() - 1)) commandResult << '\n';
    }
  }

  if(commandResult.str().empty())
    commandResult << "no breakpoints set";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "listConfig"
void DebuggerParser::executeListConfig()
{
  if(argCount == 1)
    commandResult << debugger.cartDebug().listConfig(args[0]);
  else
    commandResult << debugger.cartDebug().listConfig();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "listFunctions"
void DebuggerParser::executeListFunctions()
{
  const Debugger::FunctionDefMap& functions = debugger.getFunctionDefMap();

  if(!functions.empty())
    for(const auto& [name, cmd]: functions)
      commandResult << name << " -> " << cmd << '\n';
  else
    commandResult << "no user-defined functions";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "listSaveStateIfs"
void DebuggerParser::executeListSaveStateIfs()
{
  StringList conds = debugger.m6502().getCondSaveStateNames();
  if(!conds.empty())
  {
    commandResult << "saveStateIf:\n";
    for(uInt32 i = 0; i < conds.size(); ++i)
    {
      commandResult << Base::toString(i) << ": " << conds[i];
      if(i != (conds.size() - 1)) commandResult << '\n';
    }
  }

  if(commandResult.str().empty())
    commandResult << "no savestateifs defined";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "listTimers"
void DebuggerParser::executeListTimers()
{
  if(debugger.m6502().numTimers())
    listTimers();
  else
    commandResult << "no timers set";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "listTraps"
void DebuggerParser::executeListTraps()
{
  const StringList names = debugger.m6502().getCondTrapNames();

  if(myTraps.size() != names.size())
  {
    commandResult << "Internal error! Different trap sizes.";
    return;
  }

  if(!names.empty())
  {
    bool trapFound = false, trapifFound = false;
    for(const auto& name: names)
      if(name.empty())
        trapFound = true;
      else
        trapifFound = true;

    if(trapFound)
      listTraps(false);
    if(trapifFound)
      listTraps(true);
  }
  else
    commandResult << "no traps set";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "loadAllStates"
void DebuggerParser::executeLoadAllStates()
{
  debugger.loadAllStates();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "loadConfig"
void DebuggerParser::executeLoadConfig()
{
  commandResult << debugger.cartDebug().loadConfigFile();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "loadState"
void DebuggerParser::executeLoadState()
{
  if(args[0] >= 0 && args[0] <= 9)
    debugger.loadState(args[0]);
  else
    commandResult << red("invalid slot (must be 0-9)");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DebuggerParser::executeLogBreaks()
{
  const bool enable = !debugger.mySystem.m6502().getLogBreaks();

  debugger.mySystem.m6502().setLogBreaks(enable);
  settings.setValue("dbg.logbreaks", enable);
  commandResult << "logBreaks " << (enable ? "enabled" : "disabled");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DebuggerParser::executeLogTrace()
{
  const bool enable = !debugger.mySystem.m6502().getLogTrace();

  debugger.mySystem.m6502().setLogTrace(enable);
  settings.setValue("dbg.logtrace", enable);
  commandResult << "logTrace " << (enable ? "enabled" : "disabled");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "n"
void DebuggerParser::executeN()
{
  if(argCount == 0)
    debugger.cpuDebug().toggleN();
  else if(argCount == 1)
    debugger.cpuDebug().setN(args[0]);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "palette"
void DebuggerParser::executePalette()
{
  commandResult << TIADebug::palette();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "pc"
void DebuggerParser::executePc()
{
  ostringstream msg;

  debugger.cpuDebug().setPC(args[0]);
  msg << "Set PC @ " << Base::HEX4 << args[0];
  debugger.addState(msg.str());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "pCol"
void DebuggerParser::executePCol()
{
  executeDirective(Device::PCOL);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "pGfx"
void DebuggerParser::executePGfx()
{
  executeDirective(Device::PGFX);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "print"
void DebuggerParser::executePrint()
{
  commandResult << eval();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "printTimer"
void DebuggerParser::executePrintTimer()
{
  printTimer(args[0]);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "ram"
void DebuggerParser::executeRam()
{
  if(argCount == 0)
    commandResult << debugger.cartDebug().toString();
  else
    commandResult << debugger.setRAM(args);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "reset"
void DebuggerParser::executeReset()
{
  debugger.reset();
  debugger.rom().invalidate();

  ControllerLowLevel lport(debugger.myOSystem.console().leftController());
  ControllerLowLevel rport(debugger.myOSystem.console().rightController());
  lport.resetDigitalPins();
  rport.resetDigitalPins();

  commandResult << "reset system";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "resetTimers"
void DebuggerParser::executeResetTimers()
{
  debugger.m6502().resetTimers();
  commandResult << "all timers reset";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "rewind"
void DebuggerParser::executeRewind()
{
  executeWinds(false);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "riot"
void DebuggerParser::executeRiot()
{
  commandResult << debugger.riotDebug().toString();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "rom"
void DebuggerParser::executeRom()
{
  uInt16 addr = args[0];
  for(uInt32 i = 1; i < argCount; ++i)
  {
    if(!(debugger.patchROM(addr++, args[i])))
    {
      commandResult << red("patching ROM unsupported for this cart type");
      return;
    }
  }

  // Normally the run() method calls loadConfig() on the debugger,
  // which results in all child widgets being redrawn.
  // The RomWidget is a special case, since we don't want to re-disassemble
  // any more than necessary.  So we only do it by calling the following
  // method ...
  debugger.rom().invalidate();

  commandResult << "changed " << (args.size() - 1) << " location(s)";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "row"
void DebuggerParser::executeRow()
{
  executeDirective(Device::ROW);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "run"
void DebuggerParser::executeRun()
{
  debugger.saveOldState();
  debugger.exit(false);
  commandResult << "_EXIT_DEBUGGER";  // See PromptWidget for more info
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "runTo"
void DebuggerParser::executeRunTo()
{
  const CartDebug& cartdbg = debugger.cartDebug();
  const CartDebug::DisassemblyList& list = cartdbg.disassembly().list;

  debugger.saveOldState();

  size_t count = 0;
  const size_t max_iterations = list.size();

  // Create a progress dialog box to show the progress searching through the
  // disassembly, since this may be a time-consuming operation
  ostringstream buf;
  ProgressDialog progress(debugger.baseDialog(), debugger.lfont());

  buf << "runTo searching through " << max_iterations << " disassembled instructions"
    << progress.ELLIPSIS;
  progress.setMessage(buf.str());
  progress.setRange(0, static_cast<int>(max_iterations), 5);
  progress.open();

  bool done = false;
  do {
    debugger.step(false);

    // Update romlist to point to current PC
    const int pcline = cartdbg.addressToLine(debugger.cpuDebug().pc());
    if(pcline >= 0)
    {
      const string& next = list[pcline].disasm;
      done = (BSPF::findIgnoreCase(next, argStrings[0]) != string::npos);
    }
    // Update the progress bar
    progress.incProgress();
  } while(!done && ++count < max_iterations && !progress.isCancelled());

  progress.close();

  if(done)
    commandResult
      << "found " << argStrings[0] << " in " << dec << count
      << " disassembled instructions";
  else
    commandResult
      << argStrings[0] << " not found in " << dec << count
      << " disassembled instructions";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "runToPc"
void DebuggerParser::executeRunToPc()
{
  const CartDebug& cartdbg = debugger.cartDebug();
  const CartDebug::DisassemblyList& list = cartdbg.disassembly().list;

  debugger.saveOldState();

  uInt32 count = 0;
  bool done = false;
  // Create a progress dialog box to show the progress searching through the
  // disassembly, since this may be a time-consuming operation
  ostringstream buf;
  ProgressDialog progress(debugger.baseDialog(), debugger.lfont());

  buf << "        runTo PC running" << progress.ELLIPSIS << "        ";
  progress.setMessage(buf.str());
  progress.setRange(0, 100000, 5);
  progress.open();

  do {
    debugger.step(false);

    // Update romlist to point to current PC
    const int pcline = cartdbg.addressToLine(debugger.cpuDebug().pc());
    done = (pcline >= 0) && (list[pcline].address == args[0]);
    progress.incProgress();
    ++count;
  } while(!done && !progress.isCancelled());
  progress.close();

  if(done)
  {
    ostringstream msg;

    commandResult
      << "Set PC to $" << Base::HEX4 << args[0] << " in "
      << dec << count << " instructions";
    msg << "RunTo PC @ " << Base::HEX4 << args[0];
    debugger.addState(msg.str());
  }
  else
    commandResult
      << "PC $" << Base::HEX4 << args[0] << " not reached or found in "
      << dec << count << " instructions";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "s"
void DebuggerParser::executeS()
{
  debugger.cpuDebug().setSP(static_cast<uInt8>(args[0]));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "save"
void DebuggerParser::executeSave()
{
  DebuggerDialog* dlg = debugger.myDialog;
  const string fileName = dlg->instance().userDir().getPath() + cartName() + ".script";

  if(argCount)
  {
    if(argStrings[0] == "?")
    {
      BrowserDialog::show(dlg, "Save Workbench as", fileName,
                          BrowserDialog::Mode::FileSave,
                          [this, dlg](bool OK, const FSNode& node)
      {
        if(OK)
          dlg->prompt().print(saveScriptFile(node.getPath()) + '\n');
        dlg->prompt().printPrompt();
      });
      // avoid printing a new prompt
      commandResult.str("_NO_PROMPT");
    }
    else
      commandResult << saveScriptFile(argStrings[0]);
  }
  else
    commandResult << saveScriptFile(fileName);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "saveAccess"
void DebuggerParser::executeSaveAccess()
{
  if(argCount && argStrings[0] == "?")
  {
    DebuggerDialog* dlg = debugger.myDialog;

    BrowserDialog::show(dlg, "Save Access Counters as",
                        dlg->instance().userDir().getPath() + cartName() + ".csv",
                        BrowserDialog::Mode::FileSave,
                        [this, dlg](bool OK, const FSNode& node)
    {
      if(OK)
        dlg->prompt().print(debugger.cartDebug().saveAccessFile(node.getPath()) + '\n');
      dlg->prompt().printPrompt();
    });
    // avoid printing a new prompt
    commandResult.str("_NO_PROMPT");
  }
  else
    commandResult << debugger.cartDebug().saveAccessFile();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "saveConfig"
void DebuggerParser::executeSaveConfig()
{
  commandResult << debugger.cartDebug().saveConfigFile();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "saveDis"
void DebuggerParser::executeSaveDisassembly()
{
  if(argCount && argStrings[0] == "?")
  {
    DebuggerDialog* dlg = debugger.myDialog;

    BrowserDialog::show(dlg, "Save Disassembly as",
                        dlg->instance().userDir().getPath() + cartName() + ".asm",
                        BrowserDialog::Mode::FileSave,
                        [this, dlg](bool OK, const FSNode& node)
    {
      if(OK)
        dlg->prompt().print(debugger.cartDebug().saveDisassembly(node.getPath()) + '\n');
      dlg->prompt().printPrompt();
    });
    // avoid printing a new prompt
    commandResult.str("_NO_PROMPT");
  }
  else
    commandResult << debugger.cartDebug().saveDisassembly();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "saveRom"
void DebuggerParser::executeSaveRom()
{
  if(argCount && argStrings[0] == "?")
  {
    DebuggerDialog* dlg = debugger.myDialog;

    BrowserDialog::show(dlg, "Save ROM as",
                        dlg->instance().userDir().getPath() + cartName() + ".a26",
                        BrowserDialog::Mode::FileSave,
                        [this, dlg](bool OK, const FSNode& node)
    {
      if(OK)
        dlg->prompt().print(debugger.cartDebug().saveRom(node.getPath()) + '\n');
      dlg->prompt().printPrompt();
    });
    // avoid printing a new prompt
    commandResult.str("_NO_PROMPT");
  }
  else
    commandResult << debugger.cartDebug().saveRom();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "saveSes"
void DebuggerParser::executeSaveSes()
{
  ostringstream filename;
  auto timeinfo = BSPF::localTime();
  filename << std::put_time(&timeinfo, "session_%F_%H-%M-%S.txt");

  if(argCount && argStrings[0] == "?")
  {
    DebuggerDialog* dlg = debugger.myDialog;

    BrowserDialog::show(dlg, "Save Session as",
                        dlg->instance().userDir().getPath() + filename.str(),
                        BrowserDialog::Mode::FileSave,
                        [this, dlg](bool OK, const FSNode& node)
    {
      if(OK)
        dlg->prompt().print(debugger.prompt().saveBuffer(node) + '\n');
      dlg->prompt().printPrompt();
    });
    // avoid printing a new prompt
    commandResult.str("_NO_PROMPT");
  }
  else
  {
    ostringstream path;

    if(argCount)
      path << argStrings[0];
    else
      path << debugger.myOSystem.userDir() << filename.str();

    commandResult << debugger.prompt().saveBuffer(FSNode(path.str()));
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "saveSnap"
void DebuggerParser::executeSaveSnap()
{
  debugger.tiaOutput().saveSnapshot(execDepth, execPrefix, argCount == 0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "saveAllStates"
void DebuggerParser::executeSaveAllStates()
{
  debugger.saveAllStates();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "saveState"
void DebuggerParser::executeSaveState()
{
  if(args[0] >= 0 && args[0] <= 9)
    debugger.saveState(args[0]);
  else
    commandResult << red("invalid slot (must be 0-9)");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "saveStateIf"
void DebuggerParser::executeSaveStateIf()
{
  const int res = YaccParser::parse(argStrings[0]);
  if(res == 0)
  {
    const string condition = argStrings[0];
    for(uInt32 i = 0; i < debugger.m6502().getCondSaveStateNames().size(); ++i)
    {
      if(condition == debugger.m6502().getCondSaveStateNames()[i])
      {
        args[0] = i;
        executeDelSaveStateIf();
        return;
      }
    }
    const uInt32 ret = debugger.m6502().addCondSaveState(
      YaccParser::getResult(), argStrings[0]);
    commandResult << "added saveStateIf " << Base::toString(ret);
  }
  else
    commandResult << red("invalid expression");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "scanLine"
void DebuggerParser::executeScanLine()
{
  int count = 1;
  if(argCount != 0) count = args[0];
  debugger.nextScanline(count);
  commandResult << "advanced " << dec << count << " scanLine(s)";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "step"
void DebuggerParser::executeStep()
{
  commandResult
    << "executed " << dec << debugger.step() << " cycles";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "stepWhile"
void DebuggerParser::executeStepWhile()
{
  const int res = YaccParser::parse(argStrings[0]);
  if(res != 0) {
    commandResult << red("invalid expression");
    return;
  }
  const Expression* expr = YaccParser::getResult();
  int ncycles = 0;

  // Create a progress dialog box to show the progress searching through the
  // disassembly, since this may be a time-consuming operation
  ostringstream buf;
  ProgressDialog progress(debugger.baseDialog(), debugger.lfont());

  buf << "stepWhile running through disassembled instructions"
    << progress.ELLIPSIS;
  progress.setMessage(buf.str());
  progress.setRange(0, 100000, 5);
  progress.open();

  do {
    ncycles += debugger.step(false);
    progress.incProgress();
  } while (expr->evaluate() && !progress.isCancelled());

  progress.close();
  commandResult << "executed " << ncycles << " cycles";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "swchb"
void DebuggerParser::executeSwchb()
{
  debugger.riotDebug().switches(args[0]);
  commandResult << "SWCHB set to " << std::hex << std::setw(2) << std::setfill('0') << args[0];
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "tia"
void DebuggerParser::executeTia()
{
  commandResult << debugger.tiaDebug().toString();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "timer"
void DebuggerParser::executeTimer()
{
  // Input variants:
  // timer                         current address @ current bank
  // timer +                       current address + mirrors @ current bank
  // timer *                       current address @ any bank
  // timer + *                     current address + mirrors @ any bank
  // timer addr                    addr @ current bank
  // timer addr +                  addr + mirrors @ current bank
  // timer addr *                  addr @ any bank
  // timer addr + *                addr + mirrors @ any bank
  // timer bank                    current address @ bank
  // timer bank +                  current address + mirrors @ bank
  // timer addr bank               addr @ bank
  // timer addr bank +             addr + mirrors @ bank
  // timer addr addr               addr, addr @ current bank
  // timer addr addr +             addr, addr + mirrors @ current bank
  // timer addr addr *             addr, addr @ any bank
  // timer addr addr + *           addr, addr + mirrors @ any bank
  // timer addr addr bank          addr, addr @ bank
  // timer addr addr bank bank     addr, addr @ bank, bank
  // timer addr addr bank bank +   addr, addr + mirrors @ bank, bank
  const uInt32 romBankCount = debugger.cartDebug().romBankCount();
  const bool banked = romBankCount > 1;
  bool mirrors = (argCount >= 1 && argStrings[argCount - 1] == "+")
              || (argCount >= 2 && argStrings[argCount - 2] == "+");
  bool anyBank = banked
    && ((argCount >= 1 && argStrings[argCount - 1] == "*")
     || (argCount >= 2 && argStrings[argCount - 2] == "*"));

  argCount -= ((mirrors ? 1 : 0) + (anyBank ? 1 : 0));
  if(argCount > 4)
  {
    outputCommandError("too many arguments", myCommand);
    return;
  }

  uInt32 numAddrs = 0, numBanks = 0;
  uInt16 addr[2];
  uInt8 bank[2];

  // set defaults:
  addr[0] = debugger.cpuDebug().pc() ;
  bank[0] = debugger.cartDebug().getBank(addr[0]);

  for(uInt32 i = 0; i < argCount; ++i)
  {
    if(static_cast<uInt32>(args[i]) >= std::max(0x80U, romBankCount - 1))
    {
      if(numAddrs == 2)
      {
        outputCommandError("too many address arguments", myCommand);
        return;
      }
      addr[numAddrs++] = args[i];
    }
    else
    {
      if(anyBank || (numBanks == 1 && numAddrs < 2) || numBanks == 2)
      {
        outputCommandError("too many bank arguments", myCommand);
        return;
      }
      if(static_cast<uInt32>(args[i]) >= romBankCount)
      {
        commandResult << red("invalid bank");
        return;
      }
      bank[numBanks++] = args[i];
    }
  }

  uInt32 idx = 0;
  if(numAddrs < 2)
  {
    idx = debugger.m6502().addTimer(addr[0], bank[0], mirrors, anyBank);
  }
  else
  {
    idx = debugger.m6502().addTimer(addr[0], addr[1],
                                    bank[0], numBanks < 2 ? bank[0] : bank[1],
                                    mirrors, anyBank);
  }

  const bool isPartial = debugger.m6502().getTimer(idx).isPartial;
  if(numAddrs < 2 && !isPartial)
  {
    mirrors |= debugger.m6502().getTimer(idx).mirrors;
    anyBank |= debugger.m6502().getTimer(idx).anyBank;
  }
  commandResult << "set timer " << Base::toString(idx)
    << (numAddrs < 2 ? (isPartial ? " start" : " end") : "")
    << " at $" << Base::HEX4 << addr[0];
  if(numAddrs == 2)
    commandResult << ", $" << Base::HEX4 << addr[1];
  if(mirrors)
    commandResult << " + mirrors";
  if(banked)
  {
    if(anyBank)
      commandResult << " in all banks";
    else
    {
      commandResult << " in bank #" << std::dec << static_cast<int>(bank[0]);
      if(numBanks == 2)
        commandResult << ", #" << std::dec << static_cast<int>(bank[1]);
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "trace"
void DebuggerParser::executeTrace()
{
  commandResult << "executed " << dec << debugger.trace() << " cycles";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "trap"
void DebuggerParser::executeTrap()
{
  executeTraps(true, true, "trap");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "trapIf"
void DebuggerParser::executeTrapIf()
{
  executeTraps(true, true, "trapIf", true);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "trapRead"
void DebuggerParser::executeTrapRead()
{
  executeTraps(true, false, "trapRead");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "trapReadIf"
void DebuggerParser::executeTrapReadIf()
{
  executeTraps(true, false, "trapReadIf", true);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "trapWrite"
void DebuggerParser::executeTrapWrite()
{
  executeTraps(false, true, "trapWrite");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "trapWriteIf"
void DebuggerParser::executeTrapWriteIf()
{
  executeTraps(false, true, "trapWriteIf", true);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Wrapper function for trap(if)s
void DebuggerParser::executeTraps(bool read, bool write, string_view command,
                                  bool hasCond)
{
  const uInt32 ofs = hasCond ? 1 : 0,
               begin = args[ofs],
               end = argCount == 2 + ofs ? args[1 + ofs] : begin;

  if(argCount < 1 + ofs)
  {
    outputCommandError("missing required argument(s)", myCommand);
    return;
  }
  if(argCount > 2 + ofs)
  {
    outputCommandError("too many arguments", myCommand);
    return;
  }
  if(begin > 0xFFFF || end > 0xFFFF)
  {
    commandResult << red("invalid word argument(s) (must be 0-$ffff)");
    return;
  }
  if(begin > end)
  {
    commandResult << red("start address must be <= end address");
    return;
  }

  // base addresses of mirrors
  const uInt32 beginRead  = Debugger::getBaseAddress(begin, true);
  const uInt32 endRead    = Debugger::getBaseAddress(end, true);
  const uInt32 beginWrite = Debugger::getBaseAddress(begin, false);
  const uInt32 endWrite   = Debugger::getBaseAddress(end, false);
  stringstream conditionBuf;

  // parenthesize provided and address range condition(s) (begin)
  if(hasCond)
    conditionBuf << "(" << argStrings[0] << ")&&(";

  // add address range condition(s) to provided condition
  if(read)
  {
    if(beginRead != endRead)
      conditionBuf << "__lastBaseRead>=" << Base::toString(beginRead) << "&&__lastBaseRead<=" << Base::toString(endRead);
    else
      conditionBuf << "__lastBaseRead==" << Base::toString(beginRead);
  }
  if(read && write)
    conditionBuf << "||";
  if(write)
  {
    if(beginWrite != endWrite)
      conditionBuf << "__lastBaseWrite>=" << Base::toString(beginWrite) << "&&__lastBaseWrite<=" << Base::toString(endWrite);
    else
      conditionBuf << "__lastBaseWrite==" << Base::toString(beginWrite);
  }
  // parenthesize provided condition (end)
  if(hasCond)
    conditionBuf << ")";

  const string condition = conditionBuf.str();

  const int res = YaccParser::parse(condition);
  if(res == 0)
  {
    // duplicates will remove each other
    bool add = true;
    for(uInt32 i = 0; i < myTraps.size(); ++i)
    {
      if(myTraps[i]->begin == begin && myTraps[i]->end == end &&
         myTraps[i]->read == read && myTraps[i]->write == write &&
         myTraps[i]->condition == condition)
      {
        if(debugger.m6502().delCondTrap(i))
        {
          add = false;
          // @sa666666: please check this:
          Vec::removeAt(myTraps, i);
          commandResult << "removed trap " << Base::toString(i);
          break;
        }
        commandResult << "Internal error! Duplicate trap removal failed!";
        return;
      }
    }
    if(add)
    {
      const uInt32 ret = debugger.m6502().addCondTrap(
        YaccParser::getResult(), hasCond ? argStrings[0] : "");
      commandResult << "added trap " << Base::toString(ret);

      myTraps.emplace_back(make_unique<Trap>(read, write, begin, end, condition));
    }

    for(uInt32 addr = begin; addr <= end; ++addr)
      executeTrapRW(addr, read, write, add);
  }
  else
  {
    commandResult << red("invalid expression");
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// wrapper function for trap(if)/trapRead(if)/trapWrite(if) commands
void DebuggerParser::executeTrapRW(uInt32 addr, bool read, bool write, bool add)
{
  switch(CartDebug::addressType(addr))
  {
    case CartDebug::AddrType::TIA:
    {
      for(uInt32 i = 0; i <= 0xFFFF; ++i)
      {
        if((i & 0x1080) == 0x0000)
        {
          // @sa666666: This seems wrong. E.g. trapRead 40 4f will never trigger
          if(read && (i & 0x000F) == (addr & 0x000F))
            add ? debugger.addReadTrap(i) : debugger.removeReadTrap(i);
          if(write && (i & 0x003F) == (addr & 0x003F))
            add ? debugger.addWriteTrap(i) : debugger.removeWriteTrap(i);
        }
      }
      break;
    }
    case CartDebug::AddrType::IO:
    {
      for(uInt32 i = 0; i <= 0xFFFF; ++i)
      {
        if((i & 0x1280) == 0x0280 && (i & 0x029F) == (addr & 0x029F))
        {
          if(read)
            add ? debugger.addReadTrap(i) : debugger.removeReadTrap(i);
          if(write)
            add ? debugger.addWriteTrap(i) : debugger.removeWriteTrap(i);
        }
      }
      break;
    }
    case CartDebug::AddrType::ZPRAM:
    {
      for(uInt32 i = 0; i <= 0xFFFF; ++i)
      {
        if((i & 0x1280) == 0x0080 && (i & 0x00FF) == (addr & 0x00FF))
        {
          if(read)
            add ? debugger.addReadTrap(i) : debugger.removeReadTrap(i);
          if(write)
            add ? debugger.addWriteTrap(i) : debugger.removeWriteTrap(i);
        }
      }
      break;
    }
    case CartDebug::AddrType::ROM:
    {
      if(addr >= 0x1000 && addr <= 0xFFFF)
      {
        for(uInt32 i = 0x1000; i <= 0xFFFF; ++i)
        {
          if((i % 0x2000 >= 0x1000) && (i & 0x0FFF) == (addr & 0x0FFF))
          {
            if(read)
              add ? debugger.addReadTrap(i) : debugger.removeReadTrap(i);
            if(write)
              add ? debugger.addWriteTrap(i) : debugger.removeWriteTrap(i);
          }
        }
      }
      break;
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "type"
void DebuggerParser::executeType()
{
  uInt32 beg = args[0];
  uInt32 end = argCount >= 2 ? args[1] : beg;
  if(beg > end)  std::swap(beg, end);

  for(uInt32 i = beg; i <= end; ++i)
  {
    commandResult << Base::HEX4 << i << ": ";
    debugger.cartDebug().accessTypeAsString(commandResult, i);
    commandResult << '\n';
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "uHex"
void DebuggerParser::executeUHex()
{
  const bool enable = !Base::hexUppercase();
  Base::setHexUppercase(enable);

  settings.setValue("dbg.uHex", enable);
  debugger.rom().invalidate();

  commandResult << "uppercase HEX " << (enable ? "enabled" : "disabled");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "undef"
void DebuggerParser::executeUndef()
{
  if(debugger.cartDebug().removeLabel(argStrings[0]))
  {
    debugger.rom().invalidate();
    commandResult << argStrings[0] + " now undefined";
  }
  else
    commandResult << red("no such label");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "unwind"
void DebuggerParser::executeUnwind()
{
  executeWinds(true);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "v"
void DebuggerParser::executeV()
{
  if(argCount == 0)
    debugger.cpuDebug().toggleV();
  else if(argCount == 1)
    debugger.cpuDebug().setV(args[0]);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "watch"
void DebuggerParser::executeWatch()
{
  myWatches.push_back(argStrings[0]);
  commandResult << "added watch \"" << argStrings[0] << "\"";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// wrapper function for rewind/unwind commands
void DebuggerParser::executeWinds(bool unwind)
{
  const uInt16 states = (argCount == 0) ? 1 : args[0];
  const string type = unwind ? "unwind" : "rewind";
  string message;

  const uInt16 winds = unwind ? debugger.unwindStates(states, message)
                              : debugger.rewindStates(states, message);
  if(winds > 0)
  {
    debugger.rom().invalidate();
    commandResult << type << " by " << winds << " state" << (winds > 1 ? "s" : "");
    commandResult << " (~" << message << ")";
  }
  else
    commandResult << "no states left to " << type;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "x"
void DebuggerParser::executeX()
{
  debugger.cpuDebug().setX(static_cast<uInt8>(args[0]));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "y"
void DebuggerParser::executeY()
{
  debugger.cpuDebug().setY(static_cast<uInt8>(args[0]));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// "z"
void DebuggerParser::executeZ()
{
  if(argCount == 0)
    debugger.cpuDebug().toggleZ();
  else if(argCount == 1)
    debugger.cpuDebug().setZ(args[0]);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// List of all commands available to the parser
DebuggerParser::CommandArray DebuggerParser::commands = { {
  {
    "a",
    "Set Accumulator to <value>",
    "Valid value is 0 - ff\nExample: a ff, a #10",
    true,
    true,
    { Parameters::ARG_BYTE, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeA)
  },

  {
    "aud",
    "Mark 'AUD' range in disassembly",
    "Start and end of range required\nExample: aud f000 f010",
    true,
    false,
    { Parameters::ARG_WORD, Parameters::ARG_MULTI_BYTE },
    std::mem_fn(&DebuggerParser::executeAud)
  },

  {
    "autoSave",
    "Toggle automatic saving of commands (see 'save')",
    "Example: autoSave (no parameters)",
    false,
    true,
    { Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeAutoSave)
  },

  {
    "base",
    "Set default number base to <base>",
    "Base is #2, #10, #16, bin, dec or hex\nExample: base hex",
    true,
    true,
    { Parameters::ARG_BASE_SPCL, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeBase)
  },

  {
    "bCol",
    "Mark 'bCol' range in disassembly",
    "Start and end of range required\nExample: bCol f000 f010",
    true,
    false,
    { Parameters::ARG_WORD, Parameters::ARG_MULTI_BYTE },
    std::mem_fn(&DebuggerParser::executeBCol)
  },


  {
    "break",
    "Break at <address> and <bank>",
    "Set/clear breakpoint on address (and all mirrors) and bank\nDefault are current PC and bank, valid address is 0 - ffff\n"
    "Example: break, break f000, break 7654 3\n         break ff00 ff (= all banks)",
    false,
    true,
    { Parameters::ARG_WORD, Parameters::ARG_MULTI_BYTE },
    std::mem_fn(&DebuggerParser::executeBreak)
  },

  {
    "breakIf",
    "Set/clear breakpoint on <condition>",
    "Condition can include multiple items, see documentation\nExample: breakIf _scan>100",
    true,
    true,
    { Parameters::ARG_WORD, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeBreakIf)
  },

  {
    "breakLabel",
    "Set/clear breakpoint on <address> (no mirrors, all banks)",
    "Example: breakLabel, breakLabel MainLoop",
    false,
    true,
    { Parameters::ARG_WORD, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeBreakLabel)
  },

  {
    "c",
    "Carry Flag: set (0 or 1), or toggle (no arg)",
    "Example: c, c 0, c 1",
    false,
    true,
    { Parameters::ARG_BOOL, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeC)
  },

  {
    "cheat",
    "Use a cheat code (see manual for cheat types)",
    "Example: cheat 0040, cheat abff00",
    false,
    false,
    { Parameters::ARG_LABEL, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeCheat)
  },

  {
    "clearBreaks",
    "Clear all breakpoints",
    "Example: clearBreaks (no parameters)",
    false,
    true,
    { Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeClearBreaks)
  },

  {
    "clearConfig",
    "Clear Distella config directives [bank xx]",
    "Example: clearConfig 0, clearConfig 1",
    false,
    false,
    { Parameters::ARG_WORD, Parameters::ARG_MULTI_BYTE },
    std::mem_fn(&DebuggerParser::executeClearConfig)
  },

  {
    "clearHistory",
    "Clear the prompt history",
    "Example: clearhisotry (no parameters)",
    false,
    true,
    { Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeClearHistory)
  },

  {
    "clearSaveStateIfs",
    "Clear all saveState points",
    "Example: ClearSaveStateIfss (no parameters)",
    false,
    true,
    { Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeClearSaveStateIfs)
  },

  {
    "clearTimers",
    "Clear all timers",
    "All timers cleared\nExample: clearTimers (no parameters)",
    false,
    false,
    { Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeClearTimers)
  },

  {
    "clearTraps",
    "Clear all traps",
    "All traps cleared, including any mirrored ones\nExample: clearTraps (no parameters)",
    false,
    false,
    { Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeClearTraps)
  },

  {
    "clearWatches",
    "Clear all watches",
    "Example: clearWatches (no parameters)",
    false,
    false,
    { Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeClearWatches)
  },

  {
    "cls",
    "Clear prompt area of text",
    "Completely clears screen, but keeps history of commands",
    false,
    false,
    { Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeCls)
  },

  {
    "code",
    "Mark 'CODE' range in disassembly",
    "Start and end of range required\nExample: code f000 f010",
    true,
    false,
    { Parameters::ARG_WORD, Parameters::ARG_MULTI_BYTE },
    std::mem_fn(&DebuggerParser::executeCode)
  },

  {
    "col",
    "Mark 'COL' range in disassembly",
    "Start and end of range required\nExample: col f000 f010",
    true,
    false,
    { Parameters::ARG_WORD, Parameters::ARG_MULTI_BYTE },
    std::mem_fn(&DebuggerParser::executeCol)
  },

  {
    "colorTest",
    "Show value xx as TIA color",
    "Shows a color swatch for the given value\nExample: colorTest 1f",
    true,
    false,
    { Parameters::ARG_BYTE, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeColorTest)
  },

  {
    "d",
    "Decimal Flag: set (0 or 1), or toggle (no arg)",
    "Example: d, d 0, d 1",
    false,
    true,
    { Parameters::ARG_BOOL, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeD)
  },

  {
    "data",
    "Mark 'DATA' range in disassembly",
    "Start and end of range required\nExample: data f000 f010",
    true,
    false,
    { Parameters::ARG_WORD, Parameters::ARG_MULTI_BYTE },
    std::mem_fn(&DebuggerParser::executeData)
  },

  {
    "debugColors",
    "Show Fixed Debug Colors information",
    "Example: debugColors (no parameters)",
    false,
    false,
    { Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeDebugColors)
  },

  {
    "define",
    "Define label xx for address yy",
    "Example: define LABEL1 f100",
    true,
    true,
    { Parameters::ARG_LABEL, Parameters::ARG_WORD, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeDefine)
  },

  {
    "delBreakIf",
    "Delete conditional breakIf <xx>",
    "Example: delBreakIf 0",
    true,
    false,
    { Parameters::ARG_WORD, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeDelBreakIf)
  },

  {
    "delFunction",
    "Delete function with label xx",
    "Example: delFunction FUNC1",
    true,
    false,
    { Parameters::ARG_LABEL, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeDelFunction)
  },

  {
    "delSaveStateIf",
    "Delete conditional saveState point <xx>",
    "Example: delSaveStateIf 0",
    true,
    false,
    { Parameters::ARG_WORD, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeDelSaveStateIf)
  },

  {
    "delTimer",
    "Delete timer <xx>",
    "Example: delTimer 0",
    true,
    false,
    { Parameters::ARG_WORD, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeDelTimer)
  },

  {
    "delTrap",
    "Delete trap <xx>",
    "Example: delTrap 0",
    true,
    false,
    { Parameters::ARG_WORD, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeDelTrap)
  },

  {
    "delWatch",
    "Delete watch <xx>",
    "Example: delWatch 0",
    true,
    false,
    { Parameters::ARG_WORD, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeDelWatch)
  },

  {
    "disAsm",
    "Disassemble address xx [yy lines] (default=PC)",
    "Disassembles from starting address <xx> (default=PC) for <yy> lines\n"
    "Example: disAsm, disAsm f000 100",
    false,
    false,
    { Parameters::ARG_WORD, Parameters::ARG_MULTI_BYTE },
    std::mem_fn(&DebuggerParser::executeDisAsm)
  },

  {
    "dump",
    "Dump data at address <xx> [to yy] [1: memory; 2: CPU state; 4: input regs] [?]",
    "Example:\n"
    "  dump f000 - dumps 128 bytes from f000\n"
    "  dump f000 f0ff - dumps all bytes from f000 to f0ff\n"
    "  dump f000 f0ff 7 - dumps all bytes from f000 to f0ff,\n"
    "    CPU state and input registers into a file in user dir,\n"
    "  dump f000 f0ff 7 ? - same, but with a browser dialog\n",
    true,
    false,
    { Parameters::ARG_WORD, Parameters::ARG_WORD, Parameters::ARG_BYTE, Parameters::ARG_LABEL },
    std::mem_fn(&DebuggerParser::executeDump)
  },

  {
    "exec",
    "Execute script file <xx> [prefix]",
    "Example: exec script.dat, exec auto.txt",
    true,
    true,
    { Parameters::ARG_FILE, Parameters::ARG_LABEL, Parameters::ARG_MULTI_BYTE },
    std::mem_fn(&DebuggerParser::executeExec)
  },

  {
    "exitRom",
    "Exit emulator, return to ROM launcher",
    "Self-explanatory",
    false,
    false,
    { Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeExitRom)
  },

  {
    "frame",
    "Advance emulation by <xx> frames (default=1)",
    "Example: frame, frame 100",
    false,
    true,
    { Parameters::ARG_WORD, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeFrame)
  },

  {
    "function",
    "Define function name xx for expression yy",
    "Example: function FUNC1 { ... }",
    true,
    false,
    { Parameters::ARG_LABEL, Parameters::ARG_WORD, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeFunction)
  },

  {
    "gfx",
    "Mark 'GFX' range in disassembly",
    "Start and end of range required\nExample: gfx f000 f010",
    true,
    false,
    { Parameters::ARG_WORD, Parameters::ARG_MULTI_BYTE },
    std::mem_fn(&DebuggerParser::executeGfx)
  },

  {
    "help",
    "help <command>",
    "Show all commands, or give function for help on that command\n"
    "Example: help, help code",
    false,
    false,
    { Parameters::ARG_LABEL, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeHelp)
  },

  {
    "joy0Up",
    "Set joystick 0 up direction to value <x> (0 or 1), or toggle (no arg)",
    "Example: joy0Up 0",
    false,
    true,
    { Parameters::ARG_BOOL, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeJoy0Up)
  },

  {
    "joy0Down",
    "Set joystick 0 down direction to value <x> (0 or 1), or toggle (no arg)",
    "Example: joy0Down 0",
    false,
    true,
    { Parameters::ARG_BOOL, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeJoy0Down)
  },

  {
    "joy0Left",
    "Set joystick 0 left direction to value <x> (0 or 1), or toggle (no arg)",
    "Example: joy0Left 0",
    false,
    true,
    { Parameters::ARG_BOOL, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeJoy0Left)
  },

  {
    "joy0Right",
    "Set joystick 0 right direction to value <x> (0 or 1), or toggle (no arg)",
    "Example: joy0Left 0",
    false,
    true,
    { Parameters::ARG_BOOL, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeJoy0Right)
  },

  {
    "joy0Fire",
    "Set joystick 0 fire button to value <x> (0 or 1), or toggle (no arg)",
    "Example: joy0Fire 0",
    false,
    true,
    { Parameters::ARG_BOOL, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeJoy0Fire)
  },

  {
    "joy1Up",
    "Set joystick 1 up direction to value <x> (0 or 1), or toggle (no arg)",
    "Example: joy1Up 0",
    false,
    true,
    { Parameters::ARG_BOOL, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeJoy1Up)
  },

  {
    "joy1Down",
    "Set joystick 1 down direction to value <x> (0 or 1), or toggle (no arg)",
    "Example: joy1Down 0",
    false,
    true,
    { Parameters::ARG_BOOL, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeJoy1Down)
  },

  {
    "joy1Left",
    "Set joystick 1 left direction to value <x> (0 or 1), or toggle (no arg)",
    "Example: joy1Left 0",
    false,
    true,
    { Parameters::ARG_BOOL, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeJoy1Left)
  },

  {
    "joy1Right",
    "Set joystick 1 right direction to value <x> (0 or 1), or toggle (no arg)",
    "Example: joy1Left 0",
    false,
    true,
    { Parameters::ARG_BOOL, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeJoy1Right)
  },

  {
    "joy1Fire",
    "Set joystick 1 fire button to value <x> (0 or 1), or toggle (no arg)",
    "Example: joy1Fire 0",
    false,
    true,
    { Parameters::ARG_BOOL, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeJoy1Fire)
  },

  {
    "jump",
    "Scroll disassembly to address xx",
    "Moves disassembly listing to address <xx>\nExample: jump f400",
    true,
    false,
    { Parameters::ARG_WORD, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeJump)
  },

  {
    "listBreaks",
    "List breakpoints",
    "Example: listBreaks (no parameters)",
    false,
    false,
    { Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeListBreaks)
  },

  {
    "listConfig",
    "List Distella config directives [bank xx]",
    "Example: listConfig 0, listConfig 1",
    false,
    false,
    { Parameters::ARG_WORD, Parameters::ARG_MULTI_BYTE },
    std::mem_fn(&DebuggerParser::executeListConfig)
  },

  {
    "listFunctions",
    "List user-defined functions",
    "Example: listFunctions (no parameters)",
    false,
    false,
    { Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeListFunctions)
  },

  {
    "listSaveStateIfs",
    "List saveState points",
    "Example: listSaveStateIfs (no parameters)",
    false,
    false,
    { Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeListSaveStateIfs)
  },

  {
    "listTimers",
    "List timers",
    "Lists all timers\nExample: listTimers (no parameters)",
    false,
    false,
    { Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeListTimers)
  },

  {
    "listTraps",
    "List traps",
    "Lists all traps (read and/or write)\nExample: listTraps (no parameters)",
    false,
    false,
    { Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeListTraps)
  },

  {
    "loadConfig",
    "Load Distella config file",
    "Example: loadConfig",
    false,
    true,
    { Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeLoadConfig)
  },

  {
    "loadAllStates",
    "Load all emulator states",
    "Example: loadAllStates (no parameters)",
    false,
    true,
    { Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeLoadAllStates)
  },

  {
    "loadState",
    "Load emulator state xx (0-9)",
    "Example: loadState 0, loadState 9",
    true,
    true,
    { Parameters::ARG_BYTE, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeLoadState)
  },

  {
    "logBreaks",
    "Toggle logging of breaks/traps and continue emulation",
    "Example: logBreaks (no parameters)",
    false,
    true,
    { Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeLogBreaks)
  },

  {
    "logTrace",
    "Toggle emulation logging",
    "Example: logBreaks",
    false,
    true,
    { Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeLogTrace)
  },

  {
    "n",
    "Negative Flag: set (0 or 1), or toggle (no arg)",
    "Example: n, n 0, n 1",
    false,
    true,
    { Parameters::ARG_BOOL, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeN)
  },

  {
    "palette",
    "Show current TIA palette",
    "Example: palette (no parameters)",
    false,
    false,
    { Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executePalette)
  },

  {
    "pc",
    "Set Program Counter to address xx",
    "Example: pc f000",
    true,
    true,
    { Parameters::ARG_WORD, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executePc)
  },

  {
    "pCol",
    "Mark 'pCol' range in disassembly",
    "Start and end of range required\nExample: col f000 f010",
    true,
    false,
    { Parameters::ARG_WORD, Parameters::ARG_MULTI_BYTE },
    std::mem_fn(&DebuggerParser::executePCol)
  },

  {
    "pGfx",
    "Mark 'pGfx' range in disassembly",
    "Start and end of range required\nExample: pGfx f000 f010",
    true,
    false,
    { Parameters::ARG_WORD, Parameters::ARG_MULTI_BYTE },
    std::mem_fn(&DebuggerParser::executePGfx)
  },

  {
    "print",
    "Evaluate/print expression xx in hex/dec/binary",
    "Almost anything can be printed (constants, expressions, registers)\n"
    "Example: print pc, print f000",
    true,
    false,
    { Parameters::ARG_DWORD, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executePrint)
  },

  {
    "printTimer",
    "Print statistics for timer <xx>",
    "Example: printTimer 0",
    true,
    false,
    { Parameters::ARG_WORD, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executePrintTimer)
  },

  {
    "ram",
    "Show ZP RAM, or set address xx to yy1 [yy2 ...]",
    "Example: ram, ram 80 00 ...",
    false,
    true,
    { Parameters::ARG_WORD, Parameters::ARG_MULTI_BYTE },
    std::mem_fn(&DebuggerParser::executeRam)
  },

  {
    "reset",
    "Reset system to power-on state",
    "System is completely reset, just as if it was just powered on",
    false,
    true,
    { Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeReset)
  },

  {
    "resetTimers",
    "Reset all timers' statistics" ,
    "All timers resetted\nExample: resetTimers (no parameters)",
    false,
    false,
    { Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeResetTimers)
  },

  {
    "rewind",
    "Rewind state by one or [xx] steps/traces/scanlines/frames...",
    "Example: rewind, rewind 5",
    false,
    true,
    { Parameters::ARG_WORD, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeRewind)
  },

  {
    "riot",
    "Show RIOT timer/input status",
    "Display text-based output of the contents of the RIOT tab",
    false,
    false,
    { Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeRiot)
  },

  {
    "rom",
    "Set ROM address xx to yy1 [yy2 ...]",
    "What happens here depends on the current bankswitching scheme\n"
    "Example: rom f000 00 01 ff ...",
    true,
    true,
    { Parameters::ARG_WORD, Parameters::ARG_MULTI_BYTE },
    std::mem_fn(&DebuggerParser::executeRom)
  },

  {
    "row",
    "Mark 'ROW' range in disassembly",
    "Start and end of range required\nExample: row f000 f010",
    true,
    false,
    { Parameters::ARG_WORD, Parameters::ARG_MULTI_BYTE },
    std::mem_fn(&DebuggerParser::executeRow)
  },

  {
    "run",
    "Exit debugger, return to emulator",
    "Self-explanatory",
    false,
    false,
    { Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeRun)
  },

  {
    "runTo",
    "Run until string xx in disassembly",
    "Advance until the given string is detected in the disassembly\n"
    "Example: runTo lda",
    true,
    true,
    { Parameters::ARG_LABEL, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeRunTo)
  },

  {
    "runToPc",
    "Run until PC is set to value xx",
    "Example: runToPc f200",
    true,
    true,
    { Parameters::ARG_WORD, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeRunToPc)
  },

  {
    "s",
    "Set Stack Pointer to value xx",
    "Accepts 8-bit value, Example: s f0",
    true,
    true,
    { Parameters::ARG_BYTE, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeS)
  },

  {
    "save",
    "Save breaks, watches, traps and functions to file [xx or ?]",
    "Example: save, save commands.script, save ?\n"
    "NOTE: saves to user dir by default",
    false,
    false,
    { Parameters::ARG_FILE, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeSave)
  },

  {
    "saveAccess",
    "Save the access counters to CSV file [?]",
    "Example: saveAccess, saveAccess ?\n"
    "NOTE: saves to user dir by default",
      false,
      false,
    { Parameters::ARG_LABEL, Parameters::ARG_END_ARGS },
      std::mem_fn(&DebuggerParser::executeSaveAccess)
  },

  {
    "saveConfig",
    "Save Distella config file (with default name)",
    "Example: saveConfig",
    false,
    false,
    { Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeSaveConfig)
  },

  {
    "saveDis",
    "Save Distella disassembly to file [?]",
    "Example: saveDis, saveDis ?\n"
    "NOTE: saves to user dir by default",
    false,
    false,
    { Parameters::ARG_LABEL, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeSaveDisassembly)
  },

  {
    "saveRom",
    "Save (possibly patched) ROM to file [?]",
    "Example: saveRom, saveRom ?\n"
    "NOTE: saves to user dir by default",
    false,
    false,
    { Parameters::ARG_LABEL, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeSaveRom)
  },

  {
    "saveSes",
    "Save console session to file [?]",
    "Example: saveSes, saveSes ?\n"
    "NOTE: saves to user dir by default",
    false,
    false,
    { Parameters::ARG_LABEL, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeSaveSes)
  },

  {
    "saveSnap",
    "Save current TIA image to PNG file",
    "Save snapshot to current snapshot save directory\n"
    "Example: saveSnap (no parameters)",
    false,
    false,
    { Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeSaveSnap)
  },

  {
    "saveAllStates",
    "Save all emulator states",
    "Example: saveAllStates (no parameters)",
    false,
    false,
    { Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeSaveAllStates)
  },

  {
    "saveState",
    "Save emulator state xx (valid args 0-9)",
    "Example: saveState 0, saveState 9",
    true,
    false,
    { Parameters::ARG_BYTE, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeSaveState)
  },

  {
    "saveStateIf",
    "Create saveState on <condition>",
    "Condition can include multiple items, see documentation\nExample: saveStateIf pc==f000",
    true,
    false,
    { Parameters::ARG_WORD, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeSaveStateIf)
  },

  {
    "scanLine",
    "Advance emulation by <xx> scanlines (default=1)",
    "Example: scanLine, scanLine 100",
    false,
    true,
    { Parameters::ARG_WORD, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeScanLine)
  },

  {
    "step",
    "Single step CPU [with count xx]",
    "Example: step, step 100",
    false,
    true,
    { Parameters::ARG_WORD, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeStep)
  },

  {
    "stepWhile",
    "Single step CPU while <condition> is true",
    "Example: stepWhile pc!=$f2a9",
    true,
    true,
    { Parameters::ARG_WORD, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeStepWhile)
  },

  {
    "swchb",
    "Set SWCHB to xx",
    "Example: swchb fe",
    true,
    true,
    { Parameters::ARG_WORD, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeSwchb)
  },

  {
    "tia",
    "Show TIA state",
    "Display text-based output of the contents of the TIA tab",
    false,
    false,
    { Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeTia)
  },

  {
    "timer",
    "Set a cycle counting timer from addresses xx to yy [banks aa bb]",
    "Example: timer, timer 1000 + *, timer f000 f800 1 +",
    false,
    true,
    { Parameters::ARG_LABEL, Parameters::ARG_LABEL, Parameters::ARG_LABEL,
      Parameters::ARG_LABEL, Parameters::ARG_LABEL, Parameters::ARG_MULTI_BYTE },
    std::mem_fn(&DebuggerParser::executeTimer)
  },

  {
    "trace",
    "Single step CPU over subroutines [with count xx]",
    "Example: trace, trace 100",
    false,
    true,
    { Parameters::ARG_WORD, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeTrace)
  },

  {
    "trap",
    "Trap read/write access to address(es) xx [yy]",
    "Set/clear a R/W trap on the given address(es) and all mirrors\n"
    "Example: trap f000, trap f000 f100",
    true,
    false,
    { Parameters::ARG_WORD, Parameters::ARG_MULTI_BYTE },
    std::mem_fn(&DebuggerParser::executeTrap)
  },

  {
    "trapIf",
    "On <condition> trap R/W access to address(es) xx [yy]",
    "Set/clear a conditional R/W trap on the given address(es) and all mirrors\nCondition can include multiple items.\n"
    "Example: trapIf _scan>#100 GRP0, trapIf _bank==1 f000 f100",
      true,
      false,
      { Parameters::ARG_WORD, Parameters::ARG_MULTI_BYTE },
      std::mem_fn(&DebuggerParser::executeTrapIf)
  },

  {
    "trapRead",
    "Trap read access to address(es) xx [yy]",
    "Set/clear a read trap on the given address(es) and all mirrors\n"
    "Example: trapRead f000, trapRead f000 f100",
    true,
    false,
    { Parameters::ARG_WORD, Parameters::ARG_MULTI_BYTE },
    std::mem_fn(&DebuggerParser::executeTrapRead)
  },

  {
    "trapReadIf",
    "On <condition> trap read access to address(es) xx [yy]",
    "Set/clear a conditional read trap on the given address(es) and all mirrors\nCondition can include multiple items.\n"
    "Example: trapReadIf _scan>#100 GRP0, trapReadIf _bank==1 f000 f100",
      true,
      false,
      { Parameters::ARG_WORD, Parameters::ARG_MULTI_BYTE },
      std::mem_fn(&DebuggerParser::executeTrapReadIf)
  },

  {
    "trapWrite",
    "Trap write access to address(es) xx [yy]",
    "Set/clear a write trap on the given address(es) and all mirrors\n"
    "Example: trapWrite f000, trapWrite f000 f100",
    true,
    false,
    { Parameters::ARG_WORD, Parameters::ARG_MULTI_BYTE },
    std::mem_fn(&DebuggerParser::executeTrapWrite)
  },

  {
    "trapWriteIf",
    "On <condition> trap write access to address(es) xx [yy]",
    "Set/clear a conditional write trap on the given address(es) and all mirrors\nCondition can include multiple items.\n"
    "Example: trapWriteIf _scan>#100 GRP0, trapWriteIf _bank==1 f000 f100",
      true,
      false,
      { Parameters::ARG_WORD, Parameters::ARG_MULTI_BYTE },
      std::mem_fn(&DebuggerParser::executeTrapWriteIf)
  },

  {
    "type",
    "Show access type for address xx [yy]",
    "Example: type f000, type f000 f010",
    true,
    false,
    { Parameters::ARG_WORD, Parameters::ARG_MULTI_BYTE },
    std::mem_fn(&DebuggerParser::executeType)
  },

  {
    "uHex",
    "Toggle upper/lowercase HEX display",
    "Note: not all hex output can be changed\n"
    "Example: uHex (no parameters)",
    false,
    true,
    { Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeUHex)
  },

  {
    "undef",
    "Undefine label xx (if defined)",
    "Example: undef LABEL1",
    true,
    true,
    { Parameters::ARG_LABEL, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeUndef)
  },

  {
    "unwind",
    "Unwind state by one or [xx] steps/traces/scanlines/frames...",
    "Example: unwind, unwind 5",
    false,
    true,
    { Parameters::ARG_WORD, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeUnwind)
  },

  {
    "v",
    "Overflow Flag: set (0 or 1), or toggle (no arg)",
    "Example: v, v 0, v 1",
    false,
    true,
    { Parameters::ARG_BOOL, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeV)
  },

  {
    "watch",
    "Print contents of address xx before every prompt",
    "Example: watch ram_80",
    true,
    false,
    { Parameters::ARG_WORD, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeWatch)
  },

  {
    "x",
    "Set X Register to value xx",
    "Valid value is 0 - ff\nExample: x ff, x #10",
    true,
    true,
    { Parameters::ARG_BYTE, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeX)
  },

  {
    "y",
    "Set Y Register to value xx",
    "Valid value is 0 - ff\nExample: y ff, y #10",
    true,
    true,
    { Parameters::ARG_BYTE, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeY)
  },

  {
    "z",
    "Zero Flag: set (0 or 1), or toggle (no arg)",
    "Example: z, z 0, z 1",
    false,
    true,
    { Parameters::ARG_BOOL, Parameters::ARG_END_ARGS },
    std::mem_fn(&DebuggerParser::executeZ)
  }
} };
