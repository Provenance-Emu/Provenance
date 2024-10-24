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

#include "CompositeKeyValueRepositorySqlite.hxx"
#include "Logger.hxx"
#include "SqliteError.hxx"
#include "bspf.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CompositeKeyValueRepositorySqlite::CompositeKeyValueRepositorySqlite(
  SqliteDatabase& db,
  string_view tableName,
  string_view colKey1,
  string_view colKey2,
  string_view colValue
)
  : myDb{db}, myTableName{tableName},
    myColKey1{colKey1}, myColKey2{colKey2}, myColValue{colValue}
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
shared_ptr<KeyValueRepository> CompositeKeyValueRepositorySqlite::get(
    string_view key)
{
  return make_shared<ProxyRepository>(*this, key);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CompositeKeyValueRepositorySqlite::has(string_view key)
{
  try {
    (*myStmtCountSet)
      .reset()
      .bind(1, key);

    if (!myStmtCountSet->step())
      throw SqliteError("count failed");

    const Int32 rowCount = myStmtCountSet->columnInt(0);

    myStmtCountSet->reset();

    return rowCount > 0;
  } catch (const SqliteError& err) {
    Logger::error(err.what());

    return false;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CompositeKeyValueRepositorySqlite::remove(string_view key)
{
  try {
    (*myStmtDeleteSet)
      .reset()
      .bind(1, key)
      .step();

    myStmtDelete->reset();
  }
  catch (const SqliteError& err) {
    Logger::error(err.what());
  }
}


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CompositeKeyValueRepositorySqlite::initialize()
{
  myDb.exec(
    "CREATE TABLE IF NOT EXISTS `%s` (`%s` TEXT, `%s` TEXT, `%s` TEXT, PRIMARY KEY (`%s`, `%s`)) WITHOUT ROWID",
    myTableName.c_str(),
    myColKey1.c_str(),
    myColKey2.c_str(),
    myColValue.c_str(),
    myColKey1.c_str(),
    myColKey2.c_str()
  );

  myStmtInsert = make_unique<SqliteStatement>(myDb,
    "INSERT OR REPLACE INTO `%s` VALUES (?, ?, ?)",
    myTableName.c_str()
  );

  myStmtSelect = make_unique<SqliteStatement>(myDb,
    "SELECT `%s`, `%s` FROM `%s` WHERE `%s` = ?",
    myColKey2.c_str(),
    myColValue.c_str(),
    myTableName.c_str(),
    myColKey1.c_str()
  );

  myStmtCountSet = make_unique<SqliteStatement>(myDb,
    "SELECT COUNT(*) FROM `%s` WHERE `%s` = ?",
    myTableName.c_str(),
    myColKey1.c_str()
  );

  myStmtDelete = make_unique<SqliteStatement>(myDb,
    "DELETE FROM `%s` WHERE `%s` = ? AND `%s` = ?",
    myTableName.c_str(),
    myColKey1.c_str(),
    myColKey2.c_str()
  );

  myStmtDeleteSet = make_unique<SqliteStatement>(myDb,
    "DELETE FROM `%s` WHERE `%s` = ?",
    myTableName.c_str(),
    myColKey1.c_str()
  );

  myStmtSelectOne = make_unique<SqliteStatement>(myDb,
    "SELECT `%s` FROM `%s` WHERE `%s` = ? AND `%s` = ?",
    myColValue.c_str(),
    myTableName.c_str(),
    myColKey1.c_str(),
    myColKey2.c_str()
  );

  myStmtCount = make_unique<SqliteStatement>(myDb,
    "SELECT COUNT(*) FROM `%s` WHERE `%s` = ? AND `%s` = ?",
    myTableName.c_str(),
    myColKey1.c_str(),
    myColKey2.c_str()
  );
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CompositeKeyValueRepositorySqlite::ProxyRepository::ProxyRepository(
  const CompositeKeyValueRepositorySqlite& repo,
  string_view key
) : myRepo(repo), myKey(key)
{}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SqliteStatement& CompositeKeyValueRepositorySqlite::ProxyRepository::stmtInsert(
  string_view key, string_view value
) {
  return (*myRepo.myStmtInsert)
    .reset()
    .bind(1, myKey)
    .bind(2, key)
    .bind(3, value);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SqliteStatement& CompositeKeyValueRepositorySqlite::ProxyRepository::stmtSelect()
{
  return (*myRepo.myStmtSelect)
    .reset()
    .bind(1, myKey);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SqliteStatement& CompositeKeyValueRepositorySqlite::ProxyRepository::stmtDelete(string_view key)
{
  myRepo.myStmtDelete->reset();

  return (*myRepo.myStmtDelete)
    .bind(1, myKey)
    .bind(2, key);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SqliteStatement& CompositeKeyValueRepositorySqlite::ProxyRepository::stmtSelectOne(string_view key)
{
  return (*myRepo.myStmtSelectOne)
    .reset()
    .bind(1, myKey)
    .bind(2, key);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SqliteStatement& CompositeKeyValueRepositorySqlite::ProxyRepository::stmtCount(string_view key)
{
  return (*myRepo.myStmtCount)
    .reset()
    .bind(1, myKey)
    .bind(2, key);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SqliteDatabase& CompositeKeyValueRepositorySqlite::ProxyRepository::database()
{
  return myRepo.myDb;
}
