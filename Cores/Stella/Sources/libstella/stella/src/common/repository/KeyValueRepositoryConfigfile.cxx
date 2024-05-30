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

#include "KeyValueRepositoryConfigfile.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
KeyValueRepositoryConfigfile::KeyValueRepositoryConfigfile(const FSNode& file)
  : KeyValueRepositoryFile<KeyValueRepositoryConfigfile>(file)
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
KVRMap KeyValueRepositoryConfigfile::load(istream& in)
{
  KVRMap values;

  string line, key, value;
  string::size_type equalPos = 0, garbage = 0;

  while(getline(in, line))
  {
    // Strip all whitespace and tabs from the line
    while((garbage = line.find('\t')) != string::npos)
      line.erase(garbage, 1);

    // Ignore commented and empty lines
    if(line.empty() || (line[0] == ';'))
      continue;

    // Search for the equal sign and discard the line if its not found
    if((equalPos = line.find('=')) == string::npos)
      continue;

    // Split the line into key/value pairs and trim any whitespace
    key   = BSPF::trim(line.substr(0, equalPos));
    value = BSPF::trim(line.substr(equalPos + 1, line.length() - key.length() - 1));

    // Skip absent key
    if(key.empty())
      continue;

    values[key] = value;
  }

  return values;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool KeyValueRepositoryConfigfile::save(ostream& out, const KVRMap& values)
{
  out << ";  Stella configuration file\n"
      << ";\n"
      << ";  Lines starting with ';' are comments and are ignored.\n"
      << ";  Spaces and tabs are ignored.\n"
      << ";\n"
      << ";  Format MUST be as follows:\n"
      << ";    command = value\n"
      << ";\n"
      << ";  Commands are the same as those specified on the commandline,\n"
      << ";  without the '-' character.\n"
      << ";\n"
      << ";  Values are the same as those allowed on the commandline.\n"
      << ";  Boolean values are specified as 1 (or true) and 0 (or false)\n"
      << ";\n";

  // Write out each of the key and value pairs
  for(const auto& [key, value]: values)
    out << key << " = " << value << '\n';

  return true;
}
