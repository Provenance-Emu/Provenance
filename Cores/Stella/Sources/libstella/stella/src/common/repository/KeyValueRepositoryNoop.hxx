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

#ifndef KEY_VALUE_REPOSITORY_NOOP_HXX
#define KEY_VALUE_REPOSITORY_NOOP_HXX

#include "KeyValueRepository.hxx"

class KeyValueRepositoryNoop : public KeyValueRepositoryAtomic
{
  public:

    KVRMap load() override { return KVRMap{}; }

    bool has(string_view key) override { return false; }

    bool get(string_view key, Variant& value) override { return false; }

    bool save(const KVRMap& values) override { return false; }

    bool save(string_view key, const Variant& value) override { return false; }

    void remove(string_view key) override {}
};

#endif // KEY_VALUE_REPOSITORY_NOOP_HXX
