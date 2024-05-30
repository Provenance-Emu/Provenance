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

#ifndef ABSTRACT_KEY_VALUE_REPOSITORY_SQLITE_HXX
#define ABSTRACT_KEY_VALUE_REPOSITORY_SQLITE_HXX

#include "bspf.hxx"
#include "repository/KeyValueRepository.hxx"
#include "SqliteDatabase.hxx"
#include "SqliteStatement.hxx"

class AbstractKeyValueRepositorySqlite : public KeyValueRepositoryAtomic
{
  public:

    bool has(string_view key) override;

    bool get(string_view key, Variant& value) override;

    KVRMap load() override;

    bool save(const KVRMap& values) override;

    bool save(string_view key, const Variant& value) override;

    void remove(string_view key) override;

  protected:

    virtual SqliteStatement& stmtInsert(string_view key, string_view value) = 0;
    virtual SqliteStatement& stmtSelect() = 0;
    virtual SqliteStatement& stmtDelete(string_view key) = 0;
    virtual SqliteStatement& stmtCount(string_view key) = 0;
    virtual SqliteStatement& stmtSelectOne(string_view key) = 0;
    virtual SqliteDatabase& database() = 0;
};

#endif // ABSTRACT_KEY_VALUE_REPOSITORY_SQLITE_HXX
