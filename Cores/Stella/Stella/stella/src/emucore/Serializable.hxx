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

#ifndef SERIALIZABLE_HXX
#define SERIALIZABLE_HXX

#include "Serializer.hxx"

/**
  This class provides an interface for (de)serializing objects.
  It exists strictly to guarantee that all required classes use
  method signatures as defined below.

  @author  Stephen Anthony
*/
class Serializable
{
  public:
    Serializable() = default;
    virtual ~Serializable() = default;

    Serializable(const Serializable&) = default;
    Serializable(Serializable&&) = default;
    Serializable& operator=(const Serializable&) = default;
    Serializable& operator=(Serializable&&) = default;

    /**
      Save the current state of the object to the given Serializer.

      @param out  The Serializer object to use
      @return  False on any errors, else true
    */
    virtual bool save(Serializer& out) const = 0;

    /**
      Load the current state of the object from the given Serializer.

      @param in  The Serializer object to use
      @return  False on any errors, else true
    */
    virtual bool load(Serializer& in) = 0;
};

#endif
