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

#ifndef KEY_VALUE_REPOSITORY_HXX
#define KEY_VALUE_REPOSITORY_HXX

#include <map>

#include "Variant.hxx"
#include "bspf.hxx"

using KVRMap = std::map<string, Variant, std::less<>>;

class KeyValueRepositoryAtomic;

class KeyValueRepository
{
  public:
    KeyValueRepository() = default;
    virtual ~KeyValueRepository() = default;

    virtual KVRMap load() = 0;

    virtual bool save(const KVRMap& values) = 0;

    virtual KeyValueRepositoryAtomic* atomic() { return nullptr; }

  private:
    // Following constructors and assignment operators not supported
    KeyValueRepository(const KeyValueRepository&) = delete;
    KeyValueRepository(KeyValueRepository&&) = delete;
    KeyValueRepository& operator=(const KeyValueRepository&) = delete;
    KeyValueRepository& operator=(KeyValueRepository&&) = delete;
};

class KeyValueRepositoryAtomic : public KeyValueRepository {
  public:
    using KeyValueRepository::save;

    virtual bool has(string_view key) = 0;

    virtual bool get(string_view key, Variant& value) = 0;

    virtual bool save(string_view key, const Variant& value) = 0;

    virtual void remove(string_view key) = 0;

    KeyValueRepositoryAtomic* atomic() override { return this; }
};

#endif // KEY_VALUE_REPOSITORY_HXX
