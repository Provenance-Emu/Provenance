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

#ifndef KEY_VALUE_REPOSITORY_HXX
#define KEY_VALUE_REPOSITORY_HXX

#include <map>

#include "Variant.hxx"
#include "bspf.hxx"

class KeyValueRepositoryAtomic;

class KeyValueRepository
{
  public:
    KeyValueRepository() = default;
    virtual ~KeyValueRepository() = default;

    virtual std::map<string, Variant> load() = 0;

    virtual bool save(const std::map<string, Variant>& values) = 0;

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

    virtual bool has(const string& key) = 0;

    virtual bool get(const string& key, Variant& value) = 0;

    virtual bool save(const string& key, const Variant& value) = 0;

    virtual void remove(const string& key) = 0;

    KeyValueRepositoryAtomic* atomic() override { return this; }
};

#endif // KEY_VALUE_REPOSITORY_HXX
