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

#include "KeyValueRepositoryConfigfile.hxx"
#include "Logger.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
KeyValueRepositoryConfigfile::KeyValueRepositoryConfigfile(const FSNode& file)
  : KeyValueRepositoryFile<KeyValueRepositoryConfigfile>(file)
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
std::map<string, Variant> KeyValueRepositoryConfigfile::load(istream& in)
{
  std::map<string, Variant> values;

  string line, key, value;
  string::size_type equalPos = 0, garbage = 0;

  while(getline(in, line))
  {
    // Strip all whitespace and tabs from the line
    while((garbage = line.find('\t')) != string::npos)
      line.erase(garbage, 1);

    // Ignore commented and empty lines
    if((line.length() == 0) || (line[0] == ';'))
      continue;

    // Search for the equal sign and discard the line if its not found
    if((equalPos = line.find('=')) == string::npos)
      continue;

    // Split the line into key/value pairs and trim any whitespace
    key   = BSPF::trim(line.substr(0, equalPos));
    value = BSPF::trim(line.substr(equalPos + 1, line.length() - key.length() - 1));

    // Skip absent key
    if(key.length() == 0)
      continue;

    values[key] = value;
  }

  return values;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool KeyValueRepositoryConfigfile::save(ostream& out, const std::map<string, Variant>& values)
{
  out << ";  Stella configuration file" << endl
      << ";" << endl
      << ";  Lines starting with ';' are comments and are ignored." << endl
      << ";  Spaces and tabs are ignored." << endl
      << ";" << endl
      << ";  Format MUST be as follows:" << endl
      << ";    command = value" << endl
      << ";" << endl
      << ";  Commands are the same as those specified on the commandline," << endl
      << ";  without the '-' character." << endl
      << ";" << endl
      << ";  Values are the same as those allowed on the commandline." << endl
      << ";  Boolean values are specified as 1 (or true) and 0 (or false)" << endl
      << ";" << endl;

  // Write out each of the key and value pairs
  for(const auto& [key, value]: values)
    out << key << " = " << value << endl;

  return true;
}
