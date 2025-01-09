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

#ifndef SQLITE_DATABASE_HXX
#define SQLITE_DATABASE_HXX

#include <sqlite3.h>

#include "bspf.hxx"

class SqliteDatabase
{
  public:

    SqliteDatabase(const string& databaseDirectory, const string& databaseName);

    ~SqliteDatabase();

    void initialize();

    const string& fileName() const { return myDatabaseFile; }

    operator sqlite3*() const { return myHandle; }

    void exec(string_view sql);

    template<class T, class ...Ts>
    void exec(string_view sql, T arg1, Ts... args);

    Int32 getUserVersion() const;
    void setUserVersion(Int32 version) const;

  private:

    string myDatabaseFile;

    sqlite3* myHandle{nullptr};

  private:

    SqliteDatabase(const SqliteDatabase&) = delete;
    SqliteDatabase(SqliteDatabase&&) = delete;
    SqliteDatabase& operator=(const SqliteDatabase&) = delete;
    SqliteDatabase& operator=(SqliteDatabase&&) = delete;
};

///////////////////////////////////////////////////////////////////////////////
// IMPLEMENTATION
///////////////////////////////////////////////////////////////////////////////

#if defined(__clang__)
  #pragma clang diagnostic push
  #pragma clang diagnostic ignored "-Wformat-nonliteral"
#endif

template <class T, class ...Ts>
void SqliteDatabase::exec(string_view sql, T arg1, Ts... args)
{
  char buffer[512];

  if (snprintf(buffer, 512, string{sql}.c_str(), arg1, args...) >= 512)
    throw runtime_error("SQL statement too long");

  exec(buffer);
}

#if defined(__clang__)
#pragma clang diagnostic pop
#endif

#endif // SQLITE_DATABASE_HXX
