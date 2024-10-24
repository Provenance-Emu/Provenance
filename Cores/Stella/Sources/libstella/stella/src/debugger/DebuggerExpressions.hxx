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

#ifndef DEBUGGER_EXPRESSIONS_HXX
#define DEBUGGER_EXPRESSIONS_HXX

#include <functional>

#include "bspf.hxx"
#include "CartDebug.hxx"
#include "CpuDebug.hxx"
#include "RiotDebug.hxx"
#include "TIADebug.hxx"
#include "Debugger.hxx"
#include "Expression.hxx"

/**
  All expressions currently supported by the debugger.
  @author  B. Watson and Stephen Anthony
*/

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
class BinAndExpression : public Expression
{
  public:
    BinAndExpression(Expression* left, Expression* right) : Expression(left, right) { }
    Int32 evaluate() const override
      { return myLHS->evaluate() & myRHS->evaluate(); }
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
class BinNotExpression : public Expression
{
  public:
    BinNotExpression(Expression* left) : Expression(left) { }
    Int32 evaluate() const override
      { return ~(myLHS->evaluate()); }
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
class BinOrExpression : public Expression
{
  public:
    BinOrExpression(Expression* left, Expression* right) : Expression(left, right) { }
    Int32 evaluate() const override
      { return myLHS->evaluate() | myRHS->evaluate(); }
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
class BinXorExpression : public Expression
{
  public:
    BinXorExpression(Expression* left, Expression* right) : Expression(left, right) { }
    Int32 evaluate() const override
      { return myLHS->evaluate() ^ myRHS->evaluate(); }
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
class ByteDerefExpression : public Expression
{
  public:
    ByteDerefExpression(Expression* left): Expression(left) { }
    Int32 evaluate() const override
      { return Debugger::debugger().peek(myLHS->evaluate()); }
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
class ByteDerefOffsetExpression : public Expression
{
  public:
    ByteDerefOffsetExpression(Expression* left, Expression* right) : Expression(left, right) { }
    Int32 evaluate() const override
      { return Debugger::debugger().peek(myLHS->evaluate() + myRHS->evaluate()); }
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
class ConstExpression : public Expression
{
  public:
    ConstExpression(const int value) : Expression(), myValue{value} { }
    Int32 evaluate() const override
      { return myValue; }

  private:
    int myValue;
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
class CpuMethodExpression : public Expression
{
  public:
    CpuMethodExpression(CpuMethod method) : Expression(), myMethod{std::mem_fn(method)} { }
    Int32 evaluate() const override
      { return myMethod(Debugger::debugger().cpuDebug()); }

  private:
    std::function<int(const CpuDebug&)> myMethod;
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
class DivExpression : public Expression
{
  public:
    DivExpression(Expression* left, Expression* right) : Expression(left, right) { }
    Int32 evaluate() const override
      { const int denom = myRHS->evaluate();
        return denom == 0 ? 0 : myLHS->evaluate() / denom; }
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
class EqualsExpression : public Expression
{
  public:
    EqualsExpression(Expression* left, Expression* right) : Expression(left, right) { }
    Int32 evaluate() const override
      { return myLHS->evaluate() == myRHS->evaluate(); }
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
class EquateExpression : public Expression
{
  public:
    EquateExpression(string_view label) : Expression(), myLabel{label} { }
    Int32 evaluate() const override
      { return Debugger::debugger().cartDebug().getAddress(myLabel); }

  private:
    string myLabel;
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
class FunctionExpression : public Expression
{
  public:
    FunctionExpression(string_view label) : Expression(), myLabel{label} { }
    Int32 evaluate() const override
      { return Debugger::debugger().getFunction(myLabel).evaluate(); }

  private:
    string myLabel;
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
class GreaterEqualsExpression : public Expression
{
  public:
    GreaterEqualsExpression(Expression* left, Expression* right) : Expression(left, right) { }
    Int32 evaluate() const override
      { return myLHS->evaluate() >= myRHS->evaluate(); }
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
class GreaterExpression : public Expression
{
  public:
    GreaterExpression(Expression* left, Expression* right) : Expression(left, right) { }
    Int32 evaluate() const override
      { return myLHS->evaluate() > myRHS->evaluate(); }
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
class HiByteExpression : public Expression
{
  public:
    HiByteExpression(Expression* left) : Expression(left) { }
    Int32 evaluate() const override
      { return 0xff & (myLHS->evaluate() >> 8); }
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
class LessEqualsExpression : public Expression
{
  public:
    LessEqualsExpression(Expression* left, Expression* right) : Expression(left, right) { }
    Int32 evaluate() const override
      { return myLHS->evaluate() <= myRHS->evaluate(); }
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
class LessExpression : public Expression
{
  public:
    LessExpression(Expression* left, Expression* right) : Expression(left, right) { }
    Int32 evaluate() const override
      { return myLHS->evaluate() < myRHS->evaluate(); }
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
class LoByteExpression : public Expression
{
  public:
    LoByteExpression(Expression* left) : Expression(left) { }
    Int32 evaluate() const override
      { return 0xff & myLHS->evaluate(); }
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
class LogAndExpression : public Expression
{
  public:
    LogAndExpression(Expression* left, Expression* right) : Expression(left, right) { }
    Int32 evaluate() const override
      { return myLHS->evaluate() && myRHS->evaluate(); }
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
class LogNotExpression : public Expression
{
  public:
    LogNotExpression(Expression* left) : Expression(left) { }
    Int32 evaluate() const override
      { return !(myLHS->evaluate()); }
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
class LogOrExpression : public Expression
{
  public:
    LogOrExpression(Expression* left, Expression* right) : Expression(left, right) { }
    Int32 evaluate() const override
      { return myLHS->evaluate() || myRHS->evaluate(); }
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
class MinusExpression : public Expression
{
  public:
    MinusExpression(Expression* left, Expression* right) : Expression(left, right) { }
    Int32 evaluate() const override
      { return myLHS->evaluate() - myRHS->evaluate(); }
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
class ModExpression : public Expression
{
  public:
    ModExpression(Expression* left, Expression* right) : Expression(left, right) { }
    Int32 evaluate() const override
      { const int rhs = myRHS->evaluate();
        return rhs == 0 ? 0 : myLHS->evaluate() % rhs; }
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
class MultExpression : public Expression
{
  public:
    MultExpression(Expression* left, Expression* right) : Expression(left, right) { }
    Int32 evaluate() const override
      { return myLHS->evaluate() * myRHS->evaluate(); }
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
class NotEqualsExpression : public Expression
{
  public:
    NotEqualsExpression(Expression* left, Expression* right) : Expression(left, right) { }
    Int32 evaluate() const override
      { return myLHS->evaluate() != myRHS->evaluate(); }
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
class PlusExpression : public Expression
{
  public:
    PlusExpression(Expression* left, Expression* right) : Expression(left, right) { }
    Int32 evaluate() const override
      { return myLHS->evaluate() + myRHS->evaluate(); }
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
class CartMethodExpression : public Expression
{
  public:
    CartMethodExpression(CartMethod method) : Expression(), myMethod{std::mem_fn(method)} { }
    Int32 evaluate() const override
      { return myMethod(Debugger::debugger().cartDebug()); }

  private:
    std::function<int(CartDebug&)> myMethod;
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
class ShiftLeftExpression : public Expression
{
  public:
    ShiftLeftExpression(Expression* left, Expression* right) : Expression(left, right) { }
    Int32 evaluate() const override
      { return myLHS->evaluate() << myRHS->evaluate(); }
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
class ShiftRightExpression : public Expression
{
  public:
    ShiftRightExpression(Expression* left, Expression* right) : Expression(left, right) { }
    Int32 evaluate() const override
      { return myLHS->evaluate() >> myRHS->evaluate(); }
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
class RiotMethodExpression : public Expression
{
  public:
    RiotMethodExpression(RiotMethod method) : Expression(), myMethod{std::mem_fn(method)} { }
    Int32 evaluate() const override
      { return myMethod(Debugger::debugger().riotDebug()); }

  private:
    std::function<int(const RiotDebug&)> myMethod;
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
class TiaMethodExpression : public Expression
{
  public:
    TiaMethodExpression(TiaMethod method) : Expression(), myMethod{std::mem_fn(method)} { }
    Int32 evaluate() const override
      { return myMethod(Debugger::debugger().tiaDebug()); }

  private:
    std::function<int(const TIADebug&)> myMethod;
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
class UnaryMinusExpression : public Expression
{
  public:
    UnaryMinusExpression(Expression* left) : Expression(left) { }
    Int32 evaluate() const override
      { return -(myLHS->evaluate()); }
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
class WordDerefExpression : public Expression
{
  public:
    WordDerefExpression(Expression* left) : Expression(left) { }
    Int32 evaluate() const override
      { return Debugger::debugger().dpeekAsInt(myLHS->evaluate()); }
};

#endif
