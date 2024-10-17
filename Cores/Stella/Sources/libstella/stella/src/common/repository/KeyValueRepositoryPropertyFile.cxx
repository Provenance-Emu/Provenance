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

#include "repository/KeyValueRepositoryPropertyFile.hxx"

namespace {

  string readQuotedString(istream& in)
  {
    // Read characters until we see a quote
    char c{0};
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

  void writeQuotedString(ostream& out, string_view s)
  {
    out.put('"');
    for(auto c: s)
    {
      if(c == '\\')
      {
        out.put('\\');
        out.put('\\');
      }
      else if(c == '\"')
      {
        out.put('\\');
        out.put('"');
      }
      else
        out.put(c);
    }
    out.put('"');
  }
} // namespace

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
KeyValueRepositoryPropertyFile::KeyValueRepositoryPropertyFile(
        const FSNode& node)
  : KeyValueRepositoryFile<KeyValueRepositoryPropertyFile>(node)
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
KVRMap KeyValueRepositoryPropertyFile::load(istream& in)
{
  KVRMap map;

  // Loop reading properties
  string key, value;
  for(;;)
  {
    // Get the key associated with this property
    key = readQuotedString(in);

    // Make sure the stream is still okay
    if(!in) return map;

    // A null key signifies the end of the property list
    if(key.empty())
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
bool KeyValueRepositoryPropertyFile::save(ostream& out,
    const KVRMap& values)
{
  for (const auto& [key, value]: values) {
    writeQuotedString(out, key);
    out.put(' ');
    writeQuotedString(out, value.toString());
    out.put('\n');
  }
  out.put('"');  out.put('"');
  out.put('\n'); out.put('\n');

  return true;
}
