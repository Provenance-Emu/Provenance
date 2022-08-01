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

#ifndef EXPRESSION_HXX
#define EXPRESSION_HXX

#include "bspf.hxx"

/**
  This class provides an implementation of an expression node, which
  is a construct that is given two other expressions and evaluates and
  returns the result.  When placed in a tree, a collection of such nodes
  can represent complex expression statements.

  @author  Stephen Anthony
*/
class Expression
{
  public:
    Expression(Expression* lhs = nullptr, Expression* rhs = nullptr)
      : myLHS{lhs}, myRHS{rhs} { }
    virtual ~Expression() = default;

    virtual Int32 evaluate() const { return 0; }

  protected:
    unique_ptr<Expression> myLHS, myRHS;

  private:
    // Following constructors and assignment operators not supported
    Expression(const Expression&) = delete;
    Expression(Expression&&) = delete;
    Expression& operator=(const Expression&) = delete;
    Expression& operator=(Expression&&) = delete;
};

static const Expression EmptyExpression;

#endif
