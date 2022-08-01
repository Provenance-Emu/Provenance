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

#ifndef MD5_HXX
#define MD5_HXX

class FSNode;

#include "bspf.hxx"

namespace MD5 {

  /**
    Get the MD5 Message-Digest of the specified message with the
    given length.  The digest consists of 32 hexadecimal digits.

    Note that currently, the length is truncated internally to
    32 bits, until the MD5 routines are rewritten for 64-bit.
    Based on the size of data we currently use, this may never
    actually happen.

    @param buffer  The message to compute the digest of
    @param length  The length of the message

    @return   The message-digest
  */
  string hash(const ByteBuffer& buffer, size_t length);
  string hash(const uInt8* buffer, size_t length);
  /**
    Dito.

    @param buffer  The message to compute the digest of

    @return   The message - digest
  */
  string hash(const string& buffer);

}  // Namespace MD5

#endif
