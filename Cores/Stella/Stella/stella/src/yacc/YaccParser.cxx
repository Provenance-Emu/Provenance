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
// Copyright (c) 1995-2022 by Bradford W. Mott, Stephen Anthony
// and the Stella Team
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

#include "Base.hxx"
#include "DebuggerExpressions.hxx"

#include "YaccParser.hxx"

namespace YaccParser {
#include <cstdio>
#include <cctype>

#include "y.tab.h"
static YYSTYPE result;
static string errMsg;

void yyerror(const char* e);

#ifdef __clang__
  #pragma clang diagnostic push
  #pragma clang diagnostic ignored "-Wold-style-cast"
  #pragma clang diagnostic ignored "-Wimplicit-fallthrough"
  #pragma clang diagnostic ignored "-Wmissing-variable-declarations"
  #include "y.tab.c"
  #pragma clang diagnostic pop
#else
  #include "y.tab.c"
#endif

enum class State {
  DEFAULT,
  IDENTIFIER,
  OPERATOR,
  SPACE
};

static State state = State::DEFAULT;
static const char *input, *c;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const string& errorMessage()
{
  return errMsg;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Expression* getResult()
{
  lastExp = nullptr;
  return result.exp;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void setInput(const string& in)
{
  input = c = in.c_str();
  state = State::DEFAULT;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int parse(const string& in)
{
  lastExp = nullptr;
  errMsg = "(no error)";
  setInput(in);
  return yyparse();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// hand-rolled lexer. Hopefully faster than flex...
inline constexpr bool is_base_prefix(char x)
{
  return ( (x=='\\' || x=='$' || x=='#') );
}

inline constexpr bool is_identifier(char x)
{
  return ( (x>='0' && x<='9') ||
           (x>='a' && x<='z') ||
           (x>='A' && x<='Z') ||
            x=='.' || x=='_'  );
}

inline constexpr bool is_operator(char x)
{
  return ( (x=='+' || x=='-' || x=='*' ||
            x=='/' || x=='<' || x=='>' ||
            x=='|' || x=='&' || x=='^' ||
            x=='!' || x=='~' || x=='(' ||
            x==')' || x=='=' || x=='%' ||
            x=='[' || x==']' ) );
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// const_to_int converts a string into a number, in either the
// current base, or (if there's a base override) the selected base.
// Returns -1 on error, since negative numbers are the parser's
// responsibility, not the lexer's
int const_to_int(char* ch)
{
  // what base is the input in?
  Common::Base::Fmt format = Common::Base::format();

  switch(*ch) {
    case '\\':
      format = Common::Base::Fmt::_2;
      ch++;
      break;

    case '#':
      format = Common::Base::Fmt::_10;
      ch++;
      break;

    case '$':
      format = Common::Base::Fmt::_16;
      ch++;
      break;

    default: // not a base_prefix, use default base
      break;
  }

  int ret = 0;
  switch(format) {
    case Common::Base::Fmt::_2:
      while(*ch) {
        if(*ch != '0' && *ch != '1')
          return -1;
        ret *= 2;
        ret += (*ch - '0');
        ch++;
      }
      return ret;

    case Common::Base::Fmt::_10:
      while(*ch) {
        if(!isdigit(*ch))
          return -1;
        ret *= 10;
        ret += (*ch - '0');
        ch++;
      }
      return ret;

    case Common::Base::Fmt::_16:
      while(*ch) { // FIXME: error check!
        if(!isxdigit(*ch))
          return -1;
        int dig = (*ch - '0');
        if(dig > 9) dig = tolower(*ch) - 'a' + 10;
        ret *= 16;
        ret += dig;
        ch++;
      }
      return ret;

    default:
      cerr << "INVALID BASE in lexer!" << endl;
      return 0;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// special methods that get Cart RAM/ROM internal state
CartMethod getCartSpecial(char* ch)
{
  if(BSPF::equalsIgnoreCase(ch, "_bank"))
    return &CartDebug::getPCBank;

  else if(BSPF::equalsIgnoreCase(ch, "__lastBaseRead"))
    return &CartDebug::lastReadBaseAddress;
  else if(BSPF::equalsIgnoreCase(ch, "__lastBaseWrite"))
    return &CartDebug::lastWriteBaseAddress;
  else if(BSPF::equalsIgnoreCase(ch, "__lastRead"))
    return &CartDebug::lastReadAddress;
  else if(BSPF::equalsIgnoreCase(ch, "__lastWrite"))
    return &CartDebug::lastWriteAddress;
  else
    return nullptr;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// special methods that get e.g. CPU registers
CpuMethod getCpuSpecial(char* ch)
{
  if(BSPF::equalsIgnoreCase(ch, "a"))
    return &CpuDebug::a;
  else if(BSPF::equalsIgnoreCase(ch, "x"))
    return &CpuDebug::x;
  else if(BSPF::equalsIgnoreCase(ch, "y"))
    return &CpuDebug::y;
  else if(BSPF::equalsIgnoreCase(ch, "pc"))
    return &CpuDebug::pc;
  else if(BSPF::equalsIgnoreCase(ch, "sp"))
    return &CpuDebug::sp;
  else if(BSPF::equalsIgnoreCase(ch, "c"))
    return &CpuDebug::c;
  else if(BSPF::equalsIgnoreCase(ch, "z"))
    return &CpuDebug::z;
  else if(BSPF::equalsIgnoreCase(ch, "n"))
    return &CpuDebug::n;
  else if(BSPF::equalsIgnoreCase(ch, "v"))
    return &CpuDebug::v;
  else if(BSPF::equalsIgnoreCase(ch, "d"))
    return &CpuDebug::d;
  else if(BSPF::equalsIgnoreCase(ch, "i"))
    return &CpuDebug::i;
  else if(BSPF::equalsIgnoreCase(ch, "b"))
    return &CpuDebug::b;
  else if(BSPF::equalsIgnoreCase(ch, "_iCycles"))
    return &CpuDebug::icycles;
  else
    return nullptr;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// special methods that get RIOT internal state
RiotMethod getRiotSpecial(char* ch)
{
  if(BSPF::equalsIgnoreCase(ch, "_timWrapRead"))
    return &RiotDebug::timWrappedOnRead;
  else if(BSPF::equalsIgnoreCase(ch, "_timWrapWrite"))
    return &RiotDebug::timWrappedOnWrite;
  else if(BSPF::equalsIgnoreCase(ch, "_fTimReadCycles"))
    return &RiotDebug::timReadCycles;
  else if(BSPF::equalsIgnoreCase(ch, "_inTim"))
    return &RiotDebug::intimAsInt;
  else if(BSPF::equalsIgnoreCase(ch, "_timInt"))
    return &RiotDebug::timintAsInt;
  else
    return nullptr;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// special methods that get TIA internal state
TiaMethod getTiaSpecial(char* ch)
{
  if(BSPF::equalsIgnoreCase(ch, "_scan"))
    return &TIADebug::scanlines;
  else if(BSPF::equalsIgnoreCase(ch, "_scanEnd"))
    return &TIADebug::scanlinesLastFrame;
  else if(BSPF::equalsIgnoreCase(ch, "_sCycles"))
    return &TIADebug::cyclesThisLine;
  else if(BSPF::equalsIgnoreCase(ch, "_fCount"))
    return &TIADebug::frameCount;
  else if(BSPF::equalsIgnoreCase(ch, "_fCycles"))
    return &TIADebug::frameCycles;
  else if(BSPF::equalsIgnoreCase(ch, "_fWsyncCycles"))
    return &TIADebug::frameWsyncCycles;
  else if(BSPF::equalsIgnoreCase(ch, "_cyclesLo"))
    return &TIADebug::cyclesLo;
  else if(BSPF::equalsIgnoreCase(ch, "_cyclesHi"))
    return &TIADebug::cyclesHi;
  else if(BSPF::equalsIgnoreCase(ch, "_cClocks"))
    return &TIADebug::clocksThisLine;
  else if(BSPF::equalsIgnoreCase(ch, "_vSync"))
    return &TIADebug::vsyncAsInt;
  else if(BSPF::equalsIgnoreCase(ch, "_vBlank"))
    return &TIADebug::vblankAsInt;
  else
    return nullptr;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int yylex() {
  static char idbuf[255];  // NOLINT  (will be rewritten soon)
  char o, p;
  yylval.val = 0;
  while(*c != '\0') {
    switch(state) {
      case State::SPACE:
        yylval.val = 0;
        if(isspace(*c)) {
          c++;
        } else if(is_identifier(*c) || is_base_prefix(*c)) {
          state = State::IDENTIFIER;
        } else if(is_operator(*c)) {
          state = State::OPERATOR;
        } else {
          state = State::DEFAULT;
        }

        break;

      case State::IDENTIFIER:
        {
          CartMethod cartMeth;
          CpuMethod  cpuMeth;
          RiotMethod riotMeth;
          TiaMethod  tiaMeth;

          char *bufp = idbuf;
          *bufp++ = *c++; // might be a base prefix
          while(is_identifier(*c)) { // may NOT be base prefixes
            *bufp++ = *c++;
          }
          *bufp = '\0';
          state = State::DEFAULT;

          // Note: specials (like "a" for accumulator) have priority over
          // numbers. So "a" always means accumulator, not hex 0xa. User
          // is welcome to use a base prefix ("$a"), or a capital "A",
          // to mean 0xa.

          // Also, labels have priority over specials, so Bad Things will
          // happen if the user defines a label that matches one of
          // the specials. Who would do that, though?

          if(Debugger::debugger().cartDebug().getAddress(idbuf) > -1) {
            yylval.Equate = idbuf;
            return EQUATE;
          } else if( (cpuMeth = getCpuSpecial(idbuf)) ) {
            yylval.cpuMethod = cpuMeth;
            return CPU_METHOD;
          } else if( (cartMeth = getCartSpecial(idbuf)) ) {
            yylval.cartMethod = cartMeth;
            return CART_METHOD;
          } else if( (riotMeth = getRiotSpecial(idbuf)) ) {
            yylval.riotMethod = riotMeth;
            return RIOT_METHOD;
          } else if( (tiaMeth = getTiaSpecial(idbuf)) ) {
            yylval.tiaMethod = tiaMeth;
            return TIA_METHOD;
          } else if( Debugger::debugger().getFunctionDef(idbuf) != EmptyString ) {
            yylval.DefinedFunction = idbuf;
            return FUNCTION;
          } else {
            yylval.val = const_to_int(idbuf);
            if(yylval.val >= 0)
              return NUMBER;
            else
              return ERR;
          }
        }

      case State::OPERATOR:
        o = *c++;
        if(!*c) return o;
        if(isspace(*c)) {
          state = State::SPACE;
          return o;
        } else if(is_identifier(*c) || is_base_prefix(*c)) {
          state = State::IDENTIFIER;
          return o;
        } else {
          state = State::DEFAULT;
          p = *c++;
          if(o == '>' && p == '=')
            return GTE;
          else if(o == '<' && p == '=')
            return LTE;
          else if(o == '!' && p == '=')
            return NE;
          else if(o == '=' && p == '=')
            return EQ;
          else if(o == '|' && p == '|')
            return LOG_OR;
          else if(o == '&' && p == '&')
            return LOG_AND;
          else if(o == '<' && p == '<')
            return SHL;
          else if(o == '>' && p == '>')
            return SHR;
          else {
            c--;
            return o;
          }
        }
        // break;  Never executed

      case State::DEFAULT:
        yylval.val = 0;
        if(isspace(*c)) {
          state = State::SPACE;
        } else if(is_identifier(*c) || is_base_prefix(*c)) {
          state = State::IDENTIFIER;
        } else if(is_operator(*c)) {
          state = State::OPERATOR;
        } else {
          yylval.val = *c++;
          return yylval.val;
        }
        break;
    }
  }

  return 0; // hit NUL, end of input.
}

} // namespace YaccParser
