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

#include "Logger.hxx"
#include "SqliteError.hxx"
#include "repository/KeyValueRepositoryNoop.hxx"
#include "repository/CompositeKeyValueRepositoryNoop.hxx"
#include "repository/CompositeKVRJsonAdapter.hxx"
#include "repository/KeyValueRepositoryConfigfile.hxx"
#include "repository/KeyValueRepositoryPropertyFile.hxx"
#include "KeyValueRepositorySqlite.hxx"
#include "CompositeKeyValueRepositorySqlite.hxx"
#include "SqliteStatement.hxx"
#include "FSNode.hxx"

#ifdef BSPF_MACOS
#include "SettingsRepositoryMACOS.hxx"
#endif

#include "StellaDb.hxx"

namespace {
  constexpr Int32 CURRENT_VERSION = 1;
} // namespace

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
StellaDb::StellaDb(const string& databaseDirectory, const string& databaseName)
  : myDatabaseDirectory{databaseDirectory},
    myDatabaseName{databaseName}
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StellaDb::initialize()
{
  try {
    myDb = make_unique<SqliteDatabase>(myDatabaseDirectory, myDatabaseName);
    myDb->initialize();

    auto settingsRepository = make_unique<KeyValueRepositorySqlite>(*myDb, "settings", "setting", "value");
    settingsRepository->initialize();
    mySettingsRepository = std::move(settingsRepository);

    auto propertyRepositoryHost = make_unique<KeyValueRepositorySqlite>(*myDb, "properties", "md5", "properties");
    propertyRepositoryHost->initialize();
    myPropertyRepositoryHost = std::move(propertyRepositoryHost);

    auto highscoreRepository = make_unique<CompositeKeyValueRepositorySqlite>(*myDb, "highscores", "md5", "variation", "highscore_data");
    highscoreRepository->initialize();
    myHighscoreRepository = std::move(highscoreRepository);

    myPropertyRepository = make_unique<CompositeKVRJsonAdapter>(*myPropertyRepositoryHost);

    if (myDb->getUserVersion() == 0) {
      initializeDb();
    } else {
      migrate();
    }
  }
  catch (const SqliteError& err) {
    Logger::error("sqlite DB " + databaseFileName() + " failed to initialize: " + err.what());

    mySettingsRepository = make_unique<KeyValueRepositoryNoop>();
    myPropertyRepository = make_unique<CompositeKeyValueRepositoryNoop>();
    myHighscoreRepository = make_unique<CompositeKeyValueRepositoryNoop>();

    myDb.reset();
    myPropertyRepositoryHost.reset();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string StellaDb::databaseFileName() const
{
  return myDb ? FSNode(myDb->fileName()).getShortPath() : "[failed]";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool StellaDb::isValid() const
{
  return myDb.operator bool();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StellaDb::initializeDb()
{
  importOldSettings();

  FSNode legacyPropertyFile{myDatabaseDirectory};
  legacyPropertyFile /= "stella.pro";

  if (legacyPropertyFile.exists() && legacyPropertyFile.isFile())
    importOldPropset(legacyPropertyFile);

  myDb->setUserVersion(CURRENT_VERSION);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StellaDb::importOldSettings()
{
  #ifdef BSPF_MACOS
    Logger::info("importing old settings");

    mySettingsRepository->save(SettingsRepositoryMACOS().load());
  #else
    #if defined(BSPF_WINDOWS)
      constexpr char LEGACY_SETTINGS_FILE[] = "stella.ini";
    #else
      constexpr char LEGACY_SETTINGS_FILE[] = "stellarc";
    #endif

    FSNode legacyConfigFile{myDatabaseDirectory};
    legacyConfigFile /= LEGACY_SETTINGS_FILE;

    FSNode legacyConfigDatabase{myDatabaseDirectory};
    legacyConfigDatabase /= "settings.sqlite3";

    if (legacyConfigDatabase.exists() && legacyConfigDatabase.isFile())
      importOldStellaDb(legacyConfigDatabase);
    else if (legacyConfigFile.exists() && legacyConfigFile.isFile())
      importStellarc(legacyConfigFile);
  #endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StellaDb::importStellarc(const FSNode& node)
{
  Logger::info("importing old settings from " + node.getPath());

  mySettingsRepository->save(KeyValueRepositoryConfigfile(node).load());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StellaDb::importOldStellaDb(const FSNode& node)
{
  Logger::info("importing old settings from " + node.getPath());

  try {
    SqliteStatement(
      *myDb,
      "ATTACH DATABASE ? AS `old_db`"
    )
      .bind(1, node.getPath())
      .step();

    myDb->exec("INSERT INTO `settings` SELECT * FROM `old_db`.`settings`");
    myDb->exec("DETACH DATABASE `old_db`");
  }
  catch (const SqliteError& err) {
    Logger::error(err.what());
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StellaDb::importOldPropset(const FSNode& node)
{
  Logger::info("importing old game properties from " + node.getPath());

  stringstream in;

  try {
    node.read(in);
  }
  catch (const runtime_error& err) {
    Logger::error(err.what());

    return;
  }
  catch (...) {
    Logger::error("import failed");

    return;
  }

  while (true) {
    auto props = KeyValueRepositoryPropertyFile::load(in);

    if (props.empty())
      break;
    if ((props.find("Cart.MD5") == props.end()) ||
         props["Cart.MD5"].toString().empty())
      continue;

    myPropertyRepository->get(props["Cart.MD5"].toString())->save(props);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StellaDb::migrate()
{
  const Int32 version = myDb->getUserVersion();
  switch (version) {  // NOLINT (could be written as IF/ELSE)
    case 1:
      return;

    default: {
      stringstream ss;
      ss << "invalid database version " << version;

      throw SqliteError(ss.str());
    }
  }
}
