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

#ifndef COMPOSITE_KEY_VALUE_REPOSITORY_HXX
#define COMPOSITE_KEY_VALUE_REPOSITORY_HXX

#include <vector>

#include "KeyValueRepository.hxx"
#include "bspf.hxx"

class CompositeKeyValueRepositoryAtomic;

class CompositeKeyValueRepository
{
  public:
    CompositeKeyValueRepository() = default;

    virtual ~CompositeKeyValueRepository() = default;

    virtual shared_ptr<KeyValueRepository> get(string_view key) = 0;

    virtual bool has(string_view key) = 0;

    virtual void remove(string_view key) = 0;

    virtual CompositeKeyValueRepositoryAtomic* atomic() { return nullptr; }

  private:
    // Following constructors and assignment operators not supported
    CompositeKeyValueRepository(const CompositeKeyValueRepository&) = delete;
    CompositeKeyValueRepository(CompositeKeyValueRepository&&) = delete;
    CompositeKeyValueRepository& operator=(const CompositeKeyValueRepository&) = delete;
    CompositeKeyValueRepository& operator=(CompositeKeyValueRepository&&) = delete;
};

class CompositeKeyValueRepositoryAtomic : public CompositeKeyValueRepository
{
  public:
    using CompositeKeyValueRepository::get;
    using CompositeKeyValueRepository::remove;
    using CompositeKeyValueRepository::has;

    virtual bool get(string_view key1, string_view key2, Variant& value);

    virtual shared_ptr<KeyValueRepositoryAtomic> getAtomic(string_view key);

    virtual bool save(string_view key1, string_view key2, const Variant& value);

    virtual bool has(string_view key1, string_view key2);

    virtual void remove(string_view key1, string_view key2);

    CompositeKeyValueRepositoryAtomic* atomic() override { return this; }
};

#endif // COMPOSITE_KEY_VALUE_REPOSITORY_HXX
