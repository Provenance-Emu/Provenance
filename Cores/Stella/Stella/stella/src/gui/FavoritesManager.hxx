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


#ifndef FAVORITES_MANAGER_HXX
#define FAVORITES_MANAGER_HXX

class Settings;

#include "bspf.hxx"
#include <map>
#include <unordered_set>

/**
  Manages user defined favorites, recently played ROMs and most popular ROMs.

  @author  Thomas Jentzsch
*/

class FavoritesManager
{
  public:
    using UserList = std::vector<string>;
    using RecentList = std::vector<string>;
    using PopularType = std::pair<string, uInt32>;
    using PopularList = std::vector<PopularType>;

    explicit FavoritesManager(Settings& settings);

    void load();
    void save();
    void clear();

    // User favorites
    void addUser(const string& path);
    void removeUser(const string& path);    
    void removeAllUser();
    bool toggleUser(const string& path);
    bool existsUser(const string& path) const;
    const UserList& userList() const;

    void update(const string& path);

    // Recently played
    bool removeRecent(const string& path);
    void removeAllRecent();
    const RecentList& recentList() const;

    // Most popular
    bool removePopular(const string& path);
    void removeAllPopular();
    const PopularList& popularList() const;


  private:
    using PopularMap = std::map<string, uInt32>;
    using UserSet = std::unordered_set<string>;

    UserSet myUserSet;
    RecentList myRecentList;
    PopularMap myPopularMap;
    uInt32 myMaxRecent{20};

    Settings& mySettings;

  private:
    void addRecent(const string& path);
    void incPopular(const string& path);
    const PopularList& sortedPopularList(bool sortByName = false) const;

  private:
    // Following constructors and assignment operators not supported
    FavoritesManager() = delete;
    FavoritesManager(const FavoritesManager&) = delete;
    FavoritesManager(FavoritesManager&&) = delete;
    FavoritesManager& operator=(const FavoritesManager&) = delete;
    FavoritesManager& operator=(FavoritesManager&&) = delete;
};

#endif
