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

#include "KeyValueRepositorySqlite.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
KeyValueRepositorySqlite::KeyValueRepositorySqlite(
  SqliteDatabase& db, string_view tableName, string_view colKey,
  string_view colValue
)
  : myDb{db},
    myTableName{tableName},
    myColKey{colKey},
    myColValue{colValue}
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SqliteStatement& KeyValueRepositorySqlite::stmtInsert(string_view key,
                                                      string_view value)
{
  return (*myStmtInsert)
    .reset()
    .bind(1, key)
    .bind(2, value);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SqliteStatement& KeyValueRepositorySqlite::stmtSelect()
{
  return (*myStmtSelect)
    .reset();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SqliteStatement& KeyValueRepositorySqlite::stmtDelete(string_view key)
{
  return (*myStmtDelete)
    .reset()
    .bind(1, key);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SqliteStatement& KeyValueRepositorySqlite::stmtCount(string_view key)
{
  return (*myStmtCount)
    .reset()
    .bind(1, key);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SqliteStatement& KeyValueRepositorySqlite::stmtSelectOne(string_view key)
{
  return (*myStmtSelectOne)
    .reset()
    .bind(1, key);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SqliteDatabase& KeyValueRepositorySqlite::database()
{
  return myDb;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void KeyValueRepositorySqlite::initialize()
{
  myDb.exec(
    "CREATE TABLE IF NOT EXISTS `%s` (`%s` TEXT PRIMARY KEY, `%s` TEXT) WITHOUT ROWID",
    myTableName.c_str(),
    myColKey.c_str(),
    myColValue.c_str()
  );

  myStmtInsert = make_unique<SqliteStatement>(myDb,
    "INSERT OR REPLACE INTO `%s` VALUES (?, ?)",
    myTableName.c_str()
  );

  myStmtSelect = make_unique<SqliteStatement>(myDb,
    "SELECT `%s`, `%s` FROM `%s`",
    myColKey.c_str(),
    myColValue.c_str(),
    myTableName.c_str()
  );

  myStmtDelete = make_unique<SqliteStatement>(myDb,
    "DELETE FROM `%s` WHERE `%s` = ?",
    myTableName.c_str(),
    myColKey.c_str()
  );

  myStmtSelectOne = make_unique<SqliteStatement>(myDb,
    "SELECT `%s` FROM `%s` WHERE `%s` = ?",
    myColValue.c_str(),
    myTableName.c_str(),
    myColKey.c_str()
  );

  myStmtCount = make_unique<SqliteStatement>(
    myDb,
    "SELECT COUNT(`%s`) FROM `%s` WHERE `%s` = ?",
    myColKey.c_str(),
    myTableName.c_str(),
    myColKey.c_str()
  );
}
