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

#ifndef ABSTRACT_KEY_VALUE_REPOSITORY_SQLITE_HXX
#define ABSTRACT_KEY_VALUE_REPOSITORY_SQLITE_HXX

#include "bspf.hxx"
#include "repository/KeyValueRepository.hxx"
#include "SqliteDatabase.hxx"
#include "SqliteStatement.hxx"

class AbstractKeyValueRepositorySqlite : public KeyValueRepositoryAtomic
{
  public:

    bool has(const string& key) override;

    bool get(const string& key, Variant& value) override;

    std::map<string, Variant> load() override;

    bool save(const std::map<string, Variant>& values) override;

    bool save(const string& key, const Variant& value) override;

    void remove(const string& key) override;

  protected:

    virtual SqliteStatement& stmtInsert(const string& key, const string& value) = 0;
    virtual SqliteStatement& stmtSelect() = 0;
    virtual SqliteStatement& stmtDelete(const string& key) = 0;
    virtual SqliteStatement& stmtCount(const string& key) = 0;
    virtual SqliteStatement& stmtSelectOne(const string& key) = 0;
    virtual SqliteDatabase& database() = 0;
};

#endif // ABSTRACT_KEY_VALUE_REPOSITORY_SQLITE_HXX
