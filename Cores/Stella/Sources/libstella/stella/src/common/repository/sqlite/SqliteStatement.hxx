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

#ifndef SQLITE_STATEMENT_HXX
#define SQLITE_STATEMENT_HXX

#include <sqlite3.h>

#include "bspf.hxx"

class SqliteStatement {
  public:

    SqliteStatement(sqlite3* handle, string_view sql);

    template<class T, class ...Ts>
    SqliteStatement(sqlite3* handle, string_view sql, T arg1, Ts... args);

    ~SqliteStatement();

    operator sqlite3_stmt*() const { return myStmt; }

    SqliteStatement& bind(int index, string_view value);
    SqliteStatement& bind(int index, Int32 value);

    bool step();

    SqliteStatement& reset();

    string columnText(int index) const;

    Int32 columnInt(int index) const;

  private:

    void initialize(string_view sql);

  private:

    sqlite3_stmt* myStmt{nullptr};

    sqlite3* myHandle{nullptr};

  private:

    SqliteStatement() = delete;
    SqliteStatement(const SqliteStatement&) = delete;
    SqliteStatement(SqliteStatement&&) = delete;
    SqliteStatement& operator=(SqliteStatement&&) = delete;
    SqliteStatement& operator=(const SqliteStatement&) = delete;
};

///////////////////////////////////////////////////////////////////////////////
// IMPLEMENTATION
///////////////////////////////////////////////////////////////////////////////

#if defined(__clang__)
  #pragma clang diagnostic push
  #pragma clang diagnostic ignored "-Wformat-nonliteral"
#endif

template<class T, class ...Ts>
SqliteStatement::SqliteStatement(sqlite3* handle, string_view sql, T arg1, Ts... args)
  : myHandle{handle}
{
  char buffer[512];

  if (snprintf(buffer, 512, string{sql}.c_str(), arg1, args...) >= 512)
    throw runtime_error("SQL statement too long");

  initialize(buffer);
}

#if defined(__clang__)
  #pragma clang diagnostic pop
#endif

#endif // SQLITE_STATEMENT_HXX
