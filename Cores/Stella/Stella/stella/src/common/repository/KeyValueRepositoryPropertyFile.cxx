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

#include "repository/KeyValueRepositoryPropertyFile.hxx"

namespace {

  string readQuotedString(istream& in)
  {
    // Read characters until we see a quote
    char c;
    while(in.get(c))
      if(c == '"')
        break;

    // Read characters until we see the close quote
    string s;
    while(in.get(c))
    {
      if((c == '\\') && (in.peek() == '"'))
        in.get(c);
      else if((c == '\\') && (in.peek() == '\\'))
        in.get(c);
      else if(c == '"')
        break;
      else if(c == '\r')
        continue;

      s += c;
    }

    return s;
  }

  void writeQuotedString(ostream& out, const string& s)
  {
    out.put('"');
    for(uInt32 i = 0; i < s.length(); ++i)
    {
      if(s[i] == '\\')
      {
        out.put('\\');
        out.put('\\');
      }
      else if(s[i] == '\"')
      {
        out.put('\\');
        out.put('"');
      }
      else
        out.put(s[i]);
    }
    out.put('"');
  }

}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
KeyValueRepositoryPropertyFile::KeyValueRepositoryPropertyFile(
        const FSNode& node)
  : KeyValueRepositoryFile<KeyValueRepositoryPropertyFile>(node)
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
std::map<string, Variant> KeyValueRepositoryPropertyFile::load(istream& in)
{
  std::map<string, Variant> map;

  // Loop reading properties
  string key, value;
  for(;;)
  {
    // Get the key associated with this property
    key = readQuotedString(in);

    // Make sure the stream is still okay
    if(!in) return map;

    // A null key signifies the end of the property list
    if(key == "")
      break;

    // Get the value associated with this property
    value = readQuotedString(in);

    // Make sure the stream is still okay
    if(!in)
      return map;

    map[key] = value;
  }

  return map;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool KeyValueRepositoryPropertyFile::save(ostream& out, const std::map<string, Variant>& values)
{
  for (auto& [key, value]: values) {
    writeQuotedString(out, key);
    out.put(' ');
    writeQuotedString(out, value.toString());
    out.put('\n');
  }
  out.put('"');  out.put('"');
  out.put('\n'); out.put('\n');

  return true;
}
