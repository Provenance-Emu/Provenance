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

#include "FSNode.hxx"
#include "json_lib.hxx"
#include "Settings.hxx"

#include "FavoritesManager.hxx"

using json = nlohmann::json;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FavoritesManager::FavoritesManager(Settings& settings)
  : mySettings{settings}
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FavoritesManager::load()
{
  myMaxRecent = mySettings.getInt("maxrecentroms");

  // User Favorites
  myUserSet.clear();
  const string& serializedUser = mySettings.getString("_favoriteroms");
  if(!serializedUser.empty())
  {
    try
    {
      const json& jUser = json::parse(serializedUser);
      for (const auto& u : jUser)
      {
        const string& path = u.get<string>();
        FSNode node(path);
        if (node.exists())
          addUser(path);
      }
    }
    catch (...)
    {
      cerr << "ERROR: FavoritesManager::load() '_favoriteroms' exception\n";
    }
  }

  // Recently Played
  myRecentList.clear();
  if(myMaxRecent > 0)
  {
    const string& serializedRecent = mySettings.getString("_recentroms");
    if(!serializedRecent.empty())
    {
      try
      {
        const json& jRecent = json::parse(serializedRecent);
        for (const auto& r : jRecent)
        {
          const string& path = r.get<string>();
          FSNode node(path);
          if (node.exists())
            addRecent(path);
        }
      }
      catch (...)
      {
        cerr << "ERROR: FavoritesManager::load() '_recentroms' exception\n";
      }
    }
  }

  // Most Popular
  myPopularMap.clear();
  const string& serializedPopular = mySettings.getString("_popularroms");
  if (!serializedPopular.empty())
  {
    try
    {
      const json& jPopular = json::parse(serializedPopular);
      for (const auto& p : jPopular)
      {
        const string& path = p[0].get<string>();
        const uInt32 count = p[1].get<uInt32>();
        FSNode node(path);
        if (node.exists())
          myPopularMap.emplace(path, count);
      }
    }
    catch (...)
    {
      cerr << "ERROR: FavoritesManager::load() '_popularroms' exception\n";
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FavoritesManager::save()
{
  // User Favorites
  json jUser = json::array();
  for(const auto& path : myUserSet)
    jUser.push_back(path);
  mySettings.setValue("_favoriteroms", jUser.dump(2));

  // Recently Played
  json jRecent = json::array();
  for(const auto& path : myRecentList)
    jRecent.push_back(path);
  mySettings.setValue("_recentroms", jRecent.dump(2));

  // Most Popular
  json jPopular = json::array();
  for(const auto& path : myPopularMap)
    jPopular.emplace_back(path);
  mySettings.setValue("_popularroms", jPopular.dump(2));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FavoritesManager::clear()
{
  myUserSet.clear();
  myRecentList.clear();
  myPopularMap.clear();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FavoritesManager::addUser(const string& path)
{
  myUserSet.emplace(path);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FavoritesManager::removeUser(const string& path)
{
  myUserSet.erase(path);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FavoritesManager::removeAllUser()
{
  myUserSet.clear();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FavoritesManager::toggleUser(const string& path)
{
  const bool favorize = !existsUser(path);

  if(favorize)
    addUser(path);
  else
    removeUser(path);

  return favorize;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FavoritesManager::existsUser(const string& path) const
{
  return myUserSet.find(path) != myUserSet.end();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const FavoritesManager::UserList& FavoritesManager::userList() const
{
  // Return newest to oldest
  static UserList sortedList;

  sortedList.clear();
  sortedList.assign(myUserSet.begin(), myUserSet.end());

  if(!mySettings.getBool("altsorting"))
    std::sort(sortedList.begin(), sortedList.end(),
      [](const string& a, const string& b)
    {
      // Sort without path
      FSNode aNode(a);
      FSNode bNode(b);
      const bool realDir = aNode.isDirectory() && !BSPF::endsWithIgnoreCase(aNode.getPath(), ".zip");

      if(realDir != (bNode.isDirectory() && !BSPF::endsWithIgnoreCase(bNode.getPath(), ".zip")))
        return realDir;
      return BSPF::compareIgnoreCase(aNode.getName(), bNode.getName()) < 0;
    });
  return sortedList;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FavoritesManager::update(const string& path)
{
  addRecent(path);
  incPopular(path);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FavoritesManager::addRecent(const string& path)
{
  // Always remove existing before adding at the end again
  removeRecent(path);
  myRecentList.emplace_back(path);

  // Limit size
  while(myRecentList.size() > myMaxRecent)
    myRecentList.erase(myRecentList.begin());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FavoritesManager::removeRecent(const string& path)
{
  auto it = std::find(myRecentList.begin(), myRecentList.end(), path);

  if(it != myRecentList.end())
    myRecentList.erase(it);

  return it != myRecentList.end();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FavoritesManager::removeAllRecent()
{
  myRecentList.clear();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const FavoritesManager::RecentList& FavoritesManager::recentList() const
{
  static RecentList sortedList;
  bool sortByName = mySettings.getBool("altsorting");

  sortedList.clear();
  if(sortByName)
  {
    sortedList.assign(myRecentList.begin(), myRecentList.end());

    std::sort(sortedList.begin(), sortedList.end(),
      [](const string& a, const string& b)
    {
      // Sort alphabetical, without path
      FSNode aNode(a);
      FSNode bNode(b);
      return BSPF::compareIgnoreCase(aNode.getName(), bNode.getName()) < 0;
    });

  }
  else
    // sort newest to oldest
    sortedList.assign(myRecentList.rbegin(), myRecentList.rend());

  return sortedList;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FavoritesManager::removePopular(const string& path)
{
  return myPopularMap.erase(path);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FavoritesManager::removeAllPopular()
{
  myPopularMap.clear();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FavoritesManager::incPopular(const string& path)
{
  static constexpr uInt32 scale = 100;
  static constexpr double factor = 0.7;
  static constexpr uInt32 max_popular = scale;

  const auto increased = myPopularMap.find(path);
  if(increased != myPopularMap.end())
    increased->second += scale;
  else
  {
    // Limit number of entries and age data
    if(myPopularMap.size() >= max_popular)
    {
      PopularList sortedList = sortedPopularList(); // sorted by frequency!
      for(auto item = sortedList.cbegin(); item != sortedList.cend(); ++item)
      {
        const auto entry = myPopularMap.find(item->first);
        if(entry != myPopularMap.end())
        {
          if(entry->second >= scale * (1.0 - factor))
            entry->second *= factor; // age data
          else
            myPopularMap.erase(entry); // remove least popular
        }

      }
    }
    myPopularMap.emplace(path, scale);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const FavoritesManager::PopularList& FavoritesManager::popularList() const
{
  return sortedPopularList(mySettings.getBool("altsorting"));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const FavoritesManager::PopularList& FavoritesManager::sortedPopularList(bool sortByName) const
{
  // Return most to least popular or sorted by name
  static PopularList sortedList;

  sortedList.clear();
  sortedList.assign(myPopularMap.begin(), myPopularMap.end());

  std::sort(sortedList.begin(), sortedList.end(),
    [sortByName](const PopularType& a, const PopularType& b)
  {
    // 1. sort by most popular
    if(!sortByName && a.second != b.second)
      return a.second > b.second;

    // 2. Sort alphabetical, without path
    FSNode aNode(a.first);
    FSNode bNode(b.first);
    return BSPF::compareIgnoreCase(aNode.getName(), bNode.getName()) < 0;
  });
  return sortedList;
}
