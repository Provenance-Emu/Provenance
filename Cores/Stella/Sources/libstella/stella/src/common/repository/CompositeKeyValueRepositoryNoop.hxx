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

#ifndef COMPOSITE_KEY_VALUE_REPOSITORY_NOOP_HXX
#define COMPOSITE_KEY_VALUE_REPOSITORY_NOOP_HXX

#include "repository/CompositeKeyValueRepository.hxx"
#include "repository/KeyValueRepositoryNoop.hxx"
#include "bspf.hxx"

class CompositeKeyValueRepositoryNoop : public CompositeKeyValueRepositoryAtomic
{
  public:
    using CompositeKeyValueRepositoryAtomic::has;
    using CompositeKeyValueRepositoryAtomic::remove;
    using CompositeKeyValueRepositoryAtomic::get;

    shared_ptr<KeyValueRepository> get(string_view key) override {
      return make_shared<KeyValueRepositoryNoop>();
    }

    bool has(string_view key) override { return false; }

    void remove(string_view key) override {}
};

#endif // COMPOSITE_KEY_VALUE_REPOSITORY_NOOP_HXX
