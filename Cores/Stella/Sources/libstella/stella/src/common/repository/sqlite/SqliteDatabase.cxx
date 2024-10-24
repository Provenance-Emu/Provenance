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

#include "FSNode.hxx"
#include "SqliteDatabase.hxx"
#include "Logger.hxx"
#include "SqliteError.hxx"
#include "SqliteStatement.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SqliteDatabase::SqliteDatabase(const string& databaseDirectory,
                               const string& databaseName)
  : myDatabaseFile{FSNode(databaseDirectory).getPath() + databaseName + ".sqlite3"}
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SqliteDatabase::~SqliteDatabase()
{
  if (myHandle) sqlite3_close_v2(myHandle);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void SqliteDatabase::initialize()
{
  if (myHandle) return;

  bool dbInitialized = false;

  for (int tries = 1; tries < 3 && !dbInitialized; tries++) {
    dbInitialized = (sqlite3_open(myDatabaseFile.c_str(), &myHandle) == SQLITE_OK);

    if (dbInitialized)
      dbInitialized = sqlite3_exec(myHandle, "PRAGMA schema_version", nullptr, nullptr, nullptr) == SQLITE_OK;

    if (!dbInitialized && tries == 1) {
      Logger::info("sqlite DB " + myDatabaseFile + " seems to be corrupt, removing and retrying...");

      std::ignore = remove(myDatabaseFile.c_str());
      if (myHandle) sqlite3_close_v2(myHandle);
    }
  }

  if (!dbInitialized) {
    if (myHandle) {
      const string emsg = sqlite3_errmsg(myHandle);

      sqlite3_close_v2(myHandle);
      myHandle = nullptr;

      throw SqliteError(emsg);
    }

    throw SqliteError("unable to initialize sqlite DB for unknown reason");
  }

  exec("PRAGMA journal_mode=WAL");
  exec("PRAGMA synchronous=1");

  switch (sqlite3_wal_checkpoint_v2(myHandle, nullptr, SQLITE_CHECKPOINT_TRUNCATE, nullptr, nullptr)) {
    case SQLITE_OK:
    case SQLITE_BUSY:
      break;

    case SQLITE_MISUSE:
      Logger::error("failed to checkpoint WAL on " + myDatabaseFile + " - WAL probably unavailable");
      break;

    default:
      Logger::error("failed to checkpoint WAL on " + myDatabaseFile + " : " + sqlite3_errmsg(myHandle));
      break;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void SqliteDatabase::exec(string_view sql)
{
  if (sqlite3_exec(myHandle, string{sql}.c_str(), nullptr, nullptr, nullptr) != SQLITE_OK)
    throw SqliteError(myHandle);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Int32 SqliteDatabase::getUserVersion() const
{
  SqliteStatement stmt(*this, "PRAGMA user_version");

  if (!stmt.step())
    throw SqliteError("failed to get user_version");

  return stmt.columnInt(0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void SqliteDatabase::setUserVersion(Int32 version) const
{
  SqliteStatement(*this, "PRAGMA user_version = %i", static_cast<int>(version))
    .step();
}
