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

#ifndef LAUNCHER_FILE_LIST_WIDGET_HXX
#define LAUNCHER_FILE_LIST_WIDGET_HXX

class FavoritesManager;
class FSNode;
class ProgressDialog;
class Settings;

#include "FileListWidget.hxx"

/**
  Specialization of the general FileListWidget which provides support for
  user defined favorites, recently played ROMs and most popular ROMs.

  @author  Thomas Jentzsch
*/

class LauncherFileListWidget : public FileListWidget
{
  public:
    LauncherFileListWidget(GuiObject* boss, const GUI::Font& font,
      int x, int y, int w, int h);
    ~LauncherFileListWidget() override = default;

    void loadFavorites();
    void saveFavorites(bool force = false);
    void clearFavorites();
    void updateFavorites();
    bool isUserFavorite(string_view path) const;
    void toggleUserFavorite();
    void removeFavorite();
    void removeAllUserFavorites();
    void removeAllPopular();
    void removeAllRecent();

    bool isDirectory(const FSNode& node) const override;
    bool inVirtualDir() const { return myInVirtualDir; }
    bool inUserDir() const { return myVirtualDir == user_name; }
    bool inRecentDir() const { return myVirtualDir == recent_name; }
    bool inPopularDir() const { return myVirtualDir == popular_name; }
    bool isUserDir(string_view name) const { return name == user_name; }
    bool isRecentDir(string_view name) const { return name == recent_name; }
    bool isPopularDir(string_view name) const { return name == popular_name; }

  private:
    static const string user_name;
    static const string recent_name;
    static const string popular_name;

    unique_ptr<FavoritesManager> myFavorites;
    bool myInVirtualDir{false};
    string myVirtualDir;

  private:
    FSNode startRomNode() const;
    void getChildren(const FSNode::CancelCheck& isCancelled) override;
    void userFavor(string_view path);
    void addFolder(StringList& list, int& offset, string_view name, IconType icon);
    void extendLists(StringList& list) override;
    IconType getIconType(string_view path) const override;
    const Icon* getIcon(int i) const override;
    bool fullPathToolTip() const override { return myInVirtualDir; }

  private:
    // Following constructors and assignment operators not supported
    LauncherFileListWidget(const LauncherFileListWidget&) = delete;
    LauncherFileListWidget(LauncherFileListWidget&&) = delete;
    LauncherFileListWidget& operator=(const LauncherFileListWidget&) = delete;
    LauncherFileListWidget& operator=(LauncherFileListWidget&&) = delete;
};

#endif
