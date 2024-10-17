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

#include "OSystem.hxx"
#include "Cheat.hxx"
#include "Settings.hxx"
#include "CheetahCheat.hxx"
#include "BankRomCheat.hxx"
#include "RamCheat.hxx"
#include "Vec.hxx"

#include "CheatManager.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CheatManager::CheatManager(OSystem& osystem)
  : myOSystem{osystem}
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CheatManager::add(string_view name, string_view code,
                       bool enable, int idx)
{
  const shared_ptr<Cheat> cheat = createCheat(name, code);
  if(!cheat)
    return false;

  // Delete duplicate entries
  for(uInt32 i = 0; i < myCheatList.size(); ++i)
  {
    if(myCheatList[i]->name() == name || myCheatList[i]->code() == code)
    {
      Vec::removeAt(myCheatList, i);
      break;
    }
  }

  // Add the cheat to the main cheat list
  if(idx == -1)
    myCheatList.push_back(cheat);
  else
    Vec::insertAt(myCheatList, idx, cheat);

  // And enable/disable it (the cheat knows how to enable or disable itself)
  if(enable)
    cheat->enable();
  else
    cheat->disable();

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CheatManager::remove(int idx)
{
  if(static_cast<size_t>(idx) < myCheatList.size())
  {
    // This will also remove it from the per-frame list (if applicable)
    myCheatList[idx]->disable();

    // Then remove it from the cheatlist entirely
    Vec::removeAt(myCheatList, idx);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CheatManager::addPerFrame(string_view name, string_view code, bool enable)
{
  // The actual cheat will always be in the main list; we look there first
  shared_ptr<Cheat> cheat;
  for(auto& c: myCheatList)
  {
    if(c->name() == name || c->code() == code)
    {
      cheat = c;
      break;
    }
  }

  // Make sure there are no duplicates
  bool found{false};
  uInt32 i{0};
  for(i = 0; i < myPerFrameList.size(); ++i)
  {
    if(myPerFrameList[i]->code() == cheat->code())
    {
      found = true;
      break;
    }
  }

  if(enable)
  {
    if(!found)
      myPerFrameList.push_back(cheat);
  }
  else
  {
    if(found)
      Vec::removeAt(myPerFrameList, i);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CheatManager::addOneShot(string_view name, string_view code)
{
  // Evaluate this cheat once, and then immediately discard it
  const shared_ptr<Cheat> cheat = createCheat(name, code);
  if(cheat)
    cheat->evaluate();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
shared_ptr<Cheat> CheatManager::createCheat(string_view name, string_view code) const
{
  if(!isValidCode(code))
    return nullptr;

  // Create new cheat based on string length
  switch(code.size())
  {
    case 4:  return make_shared<RamCheat>(myOSystem, name, code);
    case 6:  return make_shared<CheetahCheat>(myOSystem, name, code);
    case 7:  return make_shared<BankRomCheat>(myOSystem, name, code);
    case 8:  return make_shared<BankRomCheat>(myOSystem, name, code);
    default: return nullptr;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CheatManager::parse(string_view cheats)
{
  StringList s;
  string::size_type lastPos = cheats.find_first_not_of(',', 0);
  string::size_type pos     = cheats.find_first_of(',', lastPos);
  string cheat, name, code;

  // Split string by comma, getting each cheat
  while(string::npos != pos || string::npos != lastPos)
  {
    // Get the next cheat
    cheat = cheats.substr(lastPos, pos - lastPos);

    // Split cheat by colon, separating each part
    string::size_type lastColonPos = cheat.find_first_not_of(':', 0);
    string::size_type colonPos     = cheat.find_first_of(':', lastColonPos);
    while(string::npos != colonPos || string::npos != lastColonPos)
    {
      s.push_back(cheat.substr(lastColonPos, colonPos - lastColonPos));
      lastColonPos = cheat.find_first_not_of(':', colonPos);
      colonPos     = cheat.find_first_of(':', lastColonPos);
    }

    // Account for variable number of items specified for cheat
    switch(s.size())
    {
      case 1:
        name = s[0];
        code = name;
        add(name, code, true);
        break;

      case 2:
        name = s[0];
        code = s[1];
        add(name, code, true);
        break;

      case 3:
        name = s[0];
        code = s[1];
        add(name, code, s[2] == "1");
        break;

      default:
        break;
    }
    s.clear();

    lastPos = cheats.find_first_not_of(',', pos);
    pos     = cheats.find_first_of(',', lastPos);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CheatManager::enable(string_view code, bool enable)
{
  for(const auto& cheat: myCheatList)
  {
    if(cheat->code() == code)
    {
      if(enable)
        cheat->enable();
      else
        cheat->disable();
      break;
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CheatManager::loadCheatDatabase()
{
  stringstream in;
  try         { myOSystem.cheatFile().read(in); }
  catch(...)  { return; }

  string line, md5, cheat;

  // Loop reading cheats
  while(getline(in, line))
  {
    if(line.empty())
      continue;

    const string::size_type one = line.find('\"', 0);
    const string::size_type two = line.find('\"', one + 1);
    const string::size_type three = line.find('\"', two + 1);
    const string::size_type four = line.find('\"', three + 1);

    // Invalid line if it doesn't contain 4 quotes
    if((one == string::npos) || (two == string::npos) ||
       (three == string::npos) || (four == string::npos))
      break;

    // Otherwise get the ms5sum and associated cheats
    md5   = line.substr(one + 1, two - one - 1);
    cheat = line.substr(three + 1, four - three - 1);

    myCheatMap.emplace(md5, cheat);
  }

  myListIsDirty = false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CheatManager::saveCheatDatabase()
{
  if(!myListIsDirty)
    return;

  stringstream out;
  for(const auto& [md5, cheat]: myCheatMap)
    out << "\"" << md5 << "\" " << "\"" << cheat << "\"\n";

  try         { myOSystem.cheatFile().write(out); }
  catch(...)  { return; }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CheatManager::loadCheats(string_view md5sum)
{
  myPerFrameList.clear();
  myCheatList.clear();
  myCurrentCheat = "";

  // Set up any cheatcodes that was on the command line
  // (and remove the key from the settings, so they won't get set again)
  const string& cheats = myOSystem.settings().getString("cheat");
  if(!cheats.empty())
    myOSystem.settings().setValue("cheat", "");

  const auto& iter = myCheatMap.find(md5sum);
  if(iter == myCheatMap.end() && cheats.empty())
    return;

  // Remember the cheats for this ROM
  myCurrentCheat = iter->second;

  // Parse the cheat list, constructing cheats and adding them to the manager
  parse(iter->second + cheats);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CheatManager::saveCheats(string_view md5sum)
{
  ostringstream cheats;
  for(uInt32 i = 0; i < myCheatList.size(); ++i)
  {
    cheats << myCheatList[i]->name() << ":"
           << myCheatList[i]->code() << ":"
           << myCheatList[i]->enabled();
    if(i+1 < myCheatList.size())
      cheats << ",";
  }

  const bool changed = cheats.str() != myCurrentCheat;

  // Only update the list if absolutely necessary
  if(changed)
  {
    const auto iter = myCheatMap.find(md5sum);

    // Erase old entry and add a new one only if it's changed
    if(iter != myCheatMap.end())
      myCheatMap.erase(iter);

    // Add new entry only if there are any cheats defined
    if(!cheats.str().empty())
      myCheatMap.emplace(md5sum, cheats.str());
  }

  // Update the dirty flag
  myListIsDirty = myListIsDirty || changed;
  myPerFrameList.clear();
  myCheatList.clear();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CheatManager::isValidCode(string_view code)
{
  for(const auto c: code)
    if(!isxdigit(c))
      return false;

  const size_t length = code.length();
  return (length == 4 || length == 6 || length == 7 || length == 8);
}
