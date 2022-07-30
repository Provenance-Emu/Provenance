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

#include "repository/KeyValueRepositoryJsonFile.hxx"
#include "Logger.hxx"
#include "json_lib.hxx"

using nlohmann::json;

namespace {
  json jsonIfValid(const string& s) {
    json parsed = json::parse(s, nullptr, false);

    return parsed.is_discarded() ? json(s) : parsed;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
KeyValueRepositoryJsonFile::KeyValueRepositoryJsonFile(const FSNode& node)
  : KeyValueRepositoryFile<KeyValueRepositoryJsonFile>(node)
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
std::map<string, Variant> KeyValueRepositoryJsonFile::load(istream& in)
{
  try {
    std::map<string, Variant> map;

    json deserialized = json::parse(in);

    if (!deserialized.is_object()) {
      Logger::error("KeyVallueRepositoryJsonFile: not an object");

      return map;
    }

    for (const auto& [key, value] : deserialized.items())
      map[key] = value.is_string() ? value.get<string>() : value.dump();

    return map;
  }
  catch (const json::exception& err) {
    Logger::error("KeyValueRepositoryJsonFile: error during deserialization: " + string(err.what()));

    return std::map<string, Variant>();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool KeyValueRepositoryJsonFile::save(ostream& out, const std::map<string, Variant>& values)
{
  try {
    json serializedJson = json::object();

    for (const auto& [key, value] : values)
      serializedJson[key] = jsonIfValid(value.toString());

    out << serializedJson.dump(2);

    return true;
  }
  catch (const json::exception& err) {
    Logger::error("KeyValueRepositoryJsonFile: error during serialization: "  + string(err.what()));

    return false;
  }
}
