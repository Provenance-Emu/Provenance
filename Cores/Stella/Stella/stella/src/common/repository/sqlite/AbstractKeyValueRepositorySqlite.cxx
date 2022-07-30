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

#include "AbstractKeyValueRepositorySqlite.hxx"
#include "Logger.hxx"
#include "SqliteError.hxx"
#include "SqliteTransaction.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
std::map<string, Variant> AbstractKeyValueRepositorySqlite::load()
{
  std::map<string, Variant> values;

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
bool AbstractKeyValueRepositorySqlite::has(const string& key)
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
bool AbstractKeyValueRepositorySqlite::get(const string& key, Variant& value)
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
bool AbstractKeyValueRepositorySqlite::save(const std::map<string, Variant>& values)
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
bool AbstractKeyValueRepositorySqlite::save(const string& key, const Variant& value)
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
void AbstractKeyValueRepositorySqlite::remove(const string& key)
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
