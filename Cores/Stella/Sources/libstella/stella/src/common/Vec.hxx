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

#ifndef VECTOR_OPS_HXX
#define VECTOR_OPS_HXX

#include "bspf.hxx"

namespace Vec {

template<typename T>
void append(vector<T>& dst, const vector<T>& src)
{
  dst.insert(dst.cend(), src.cbegin(), src.cend());
}

template<typename T>
void insertAt(vector<T>& dst, uInt32 idx, const T& element)
{
  dst.insert(dst.cbegin()+idx, element);
}

template<typename T>
void removeAt(vector<T>& dst, uInt32 idx)
{
  dst.erase(dst.cbegin()+idx);
}

} // namespace Vec

#endif
