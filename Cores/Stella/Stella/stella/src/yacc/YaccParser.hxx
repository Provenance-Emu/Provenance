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

#ifndef PARSER_HXX
#define PARSER_HXX

#include "Expression.hxx"
#include "CartDebug.hxx"
#include "CpuDebug.hxx"
#include "RiotDebug.hxx"
#include "TIADebug.hxx"

#include "bspf.hxx"

// FIXME - Convert this to a proper C++ class using Bison and Flex C++ mode
namespace YaccParser
{
  Expression* getResult();
  const string& errorMessage();

  void setInput(const string& in);
  int parse(const string& in);
  int const_to_int(char* ch);

  CartMethod getCartSpecial(char* ch);
  CpuMethod getCpuSpecial(char* ch);
  RiotMethod getRiotSpecial(char* ch);
  TiaMethod getTiaSpecial(char* ch);
}

#endif
