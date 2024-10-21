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

#include "AbstractKeyValueRepositorySqlite.hxx"
#include "Logger.hxx"
#include "SqliteError.hxx"
#include "SqliteTransaction.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
KVRMap AbstractKeyValueRepositorySqlite::load()
{
  KVRMap values;

  try {
    SqliteStatement& stmt{stmtSelect()};

    while (stmt.step())
      values[stmt.columnText(0)] = stmt.columnText(1);

    stmt.reset();
  }
  catch (const SqliteError& err) {
    Logger::error(err.what());
  }

  return values;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool AbstractKeyValueRepositorySqlite::has(string_view key)
{
  try {
    SqliteStatement& stmt{stmtCount(key)};

    if (!stmt.step()) throw SqliteError("count failed");

    const bool result = stmt.columnInt(0) != 0;
    stmt.reset();

    return result;
  }
  catch (const SqliteError& err) {
    Logger::error(err.what());

    return false;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool AbstractKeyValueRepositorySqlite::get(string_view key, Variant& value)
{
  try {
    SqliteStatement& stmt{stmtSelectOne(key)};

    if (!stmt.step()) return false;
    value = stmt.columnText(0);

    stmt.reset();

    return true;
  }
  catch (const SqliteError& err) {
    Logger::error(err.what());

    return false;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool AbstractKeyValueRepositorySqlite::save(const KVRMap& values)
{
  try {
    SqliteTransaction tx{database()};

    for (const auto& pair: values) {
      SqliteStatement& stmt{stmtInsert(pair.first, pair.second.toString())};

      stmt.step();
      stmt.reset();
    }

    tx.commit();

    return true;
  }
  catch (const SqliteError& err) {
    Logger::error(err.what());

    return false;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool AbstractKeyValueRepositorySqlite::save(string_view key, const Variant& value)
{
  try {
    SqliteStatement& stmt{stmtInsert(key, value.toString())};

    stmt.step();
    stmt.reset();

    return true;
  }
  catch (const SqliteError& err) {
    Logger::error(err.what());

    return false;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AbstractKeyValueRepositorySqlite::remove(string_view key)
{
  try {
    SqliteStatement& stmt{stmtDelete(key)};

    stmt.step();
    stmt.reset();
  }
  catch (const SqliteError& err) {
    Logger::error(err.what());
  }
}
