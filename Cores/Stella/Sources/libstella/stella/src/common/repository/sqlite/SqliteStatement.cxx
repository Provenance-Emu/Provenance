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

#include "SqliteStatement.hxx"
#include "SqliteError.hxx"

#ifdef __clang__
#pragma clang diagnostic ignored "-Wold-style-cast"
#endif

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SqliteStatement::SqliteStatement(sqlite3* handle, string_view sql)
  : myHandle{handle}
{
  initialize(sql);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void SqliteStatement::initialize(string_view sql)
{
  if (sqlite3_prepare_v2(myHandle, string{sql}.c_str(), -1, &myStmt, nullptr) != SQLITE_OK)
    throw SqliteError(myHandle);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SqliteStatement::~SqliteStatement()
{
  if (myStmt) sqlite3_finalize(myStmt);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SqliteStatement& SqliteStatement::bind(int index, string_view value)
{
  if (sqlite3_bind_text(myStmt, index, string{value}.c_str(), -1,
      SQLITE_TRANSIENT) != SQLITE_OK)  // NOLINT (performance-no-int-to-ptr)
    throw SqliteError(myHandle);

  return *this;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SqliteStatement& SqliteStatement::bind(int index, Int32 value)
{
  if (sqlite3_bind_int(myStmt, index, value) != SQLITE_OK)
    throw SqliteError(myHandle);

  return *this;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool SqliteStatement::step()
{
  const int result = sqlite3_step(myStmt);

  if (result == SQLITE_ERROR) throw SqliteError(myHandle);

  return result == SQLITE_ROW;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SqliteStatement& SqliteStatement::reset()
{
  if (sqlite3_reset(myStmt) != SQLITE_OK) throw SqliteError(myHandle);

  return *this;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string SqliteStatement::columnText(int index) const
{
  return reinterpret_cast<const char*>(sqlite3_column_text(myStmt, index));
}


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int SqliteStatement::columnInt(int index) const
{
  return sqlite3_column_int(myStmt, index);
}
