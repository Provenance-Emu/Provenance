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

#include "Bankswitch.hxx"
#include "FavoritesManager.hxx"
#include "OSystem.hxx"
#include "ProgressDialog.hxx"
#include "Settings.hxx"

#include "LauncherFileListWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
LauncherFileListWidget::LauncherFileListWidget(GuiObject* boss,
    const GUI::Font& font, int x, int y, int w, int h)
  : FileListWidget(boss, font, x, y, w, h)
{
  // This widget is special, in that it catches signals and redirects them
  setTarget(this);
  myFavorites = make_unique<FavoritesManager>(instance().settings());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool LauncherFileListWidget::isDirectory(const FSNode& node) const
{
  const bool isDir = node.isDirectory();

  // Check for virtual directories
  if(!isDir && !node.exists())
    return node.getName() == user_name
      || node.getName() == recent_name
      || node.getName() == popular_name;

  return isDir;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherFileListWidget::getChildren(const FSNode::CancelCheck& isCancelled)
{
  if(_node.exists() || !_node.hasParent())
  {
    myInVirtualDir = false;
    myVirtualDir = EmptyString;
    FileListWidget::getChildren(isCancelled);
  }
  else if(instance().settings().getBool("favorites"))
  {
    myInVirtualDir = true;
    myVirtualDir = _node.getName();

    FSNode parent(_node.getParent());
    parent.setName("..");
    _fileList.emplace_back(parent);

    if(myVirtualDir == user_name)
    {
      for(const auto& item : myFavorites->userList())
      {
        FSNode node(item);
        string name = node.getName();

        if(name.back() == FSNode::PATH_SEPARATOR)
        {
          name.pop_back();
          node.setName(name);
        }
        if(_filter(node))
          _fileList.emplace_back(node);
      }
    }
    else if(myVirtualDir == popular_name)
    {
      for(const auto& item : myFavorites->popularList())
      {
        const FSNode node(item.first);
        if(_filter(node))
          _fileList.emplace_back(node);
      }
    }
    else if(myVirtualDir == recent_name)
    {
      for(const auto& item : myFavorites->recentList())
      {
        const FSNode node(item);
        if(_filter(node))
          _fileList.emplace_back(node);
      }
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherFileListWidget::addFolder(StringList& list, int& offset,
                                       string_view name, IconType icon)
{
  const string n = string{name};
  _fileList.insert(_fileList.begin() + offset,
    FSNode(_node.getPath() + n));
  list.insert(list.begin() + offset, n);
  _dirList.insert(_dirList.begin() + offset, "");
  _iconTypeList.insert((_iconTypeList.begin() + offset), icon);

  ++offset;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FSNode LauncherFileListWidget::startRomNode() const
{
  return FSNode(instance().settings().getString("startromdir"));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherFileListWidget::extendLists(StringList& list)
{
  FSNode romNode = startRomNode();

  // Only show virtual dirs in "romNode". Except if
  //  "romNode" is virtual or "romNode" is a ZIP
  //  Then show virtual dirs in parent of "romNode".
  if(_node == romNode
      && (myInVirtualDir || BSPF::endsWithIgnoreCase(_node.getPath(), ".zip")))
  {
    romNode = _node.getParent();
    instance().settings().setValue("startromdir", romNode.getPath());
  }
  else if(!romNode.isDirectory() && romNode.getParent() == _node)
    // If launcher started in virtual dir, add virtual folders to parent dir
    romNode = _node;

  if(instance().settings().getBool("favorites") && _node == romNode)
  {
    // Add virtual directories behind ".."
    int offset = _fileList.begin()->getName() == ".." ? 1 : 0;

    if(!myFavorites->userList().empty())
      addFolder(list, offset, user_name, IconType::userdir);
    if(!myFavorites->popularList().empty())
      addFolder(list, offset, popular_name, IconType::popdir);
    if(!myFavorites->recentList().empty())
      addFolder(list, offset, recent_name, IconType::recentdir);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherFileListWidget::loadFavorites()
{
  if(instance().settings().getBool("favorites"))
  {
    myFavorites->load();

    for (const auto& path : myFavorites->userList())
      userFavor(path);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherFileListWidget::saveFavorites(bool force)
{
  if (force || instance().settings().getBool("favorites"))
    myFavorites->save();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherFileListWidget::clearFavorites()
{
    myFavorites->clear();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherFileListWidget::updateFavorites()
{
  if (instance().settings().getBool("favorites"))
    myFavorites->update(selected().getPath());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool LauncherFileListWidget::isUserFavorite(string_view path) const
{
  return myFavorites->existsUser(path);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherFileListWidget::toggleUserFavorite()
{
  if(instance().settings().getBool("favorites")
    && (selected().isDirectory() || Bankswitch::isValidRomName(selected())))
  {
    myFavorites->toggleUser(selected().getPath());
    userFavor(selected().getPath());
    // Redraw file list
    if(myVirtualDir == user_name)
      reload();
    else
      setDirty();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherFileListWidget::removeFavorite()
{
  if (instance().settings().getBool("favorites"))
  {
    if (inRecentDir())
      myFavorites->removeRecent(selected().getPath());
    else if (inPopularDir())
      myFavorites->removePopular(selected().getPath());
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherFileListWidget::userFavor(string_view path)
{
  size_t pos = 0;

  for(const auto& file : _fileList)
  {
    if(file.getPath() == path)
      break;
    pos++;
  }
  if(pos < _iconTypeList.size())
    _iconTypeList[pos] = getIconType(path);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherFileListWidget::removeAllUserFavorites()
{
  myFavorites->removeAllUser();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherFileListWidget::removeAllPopular()
{
  myFavorites->removeAllPopular();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherFileListWidget::removeAllRecent()
{
  myFavorites->removeAllRecent();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FileListWidget::IconType LauncherFileListWidget::getIconType(string_view path) const
{
  if(!isUserFavorite(path))
    return FileListWidget::getIconType(path);

  const FSNode node(path);
  if(node.isDirectory())
    return BSPF::endsWithIgnoreCase(node.getName(), ".zip")
      ? IconType::favzip : IconType::favdir;
  else
    return IconType::favrom;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const FileListWidget::Icon* LauncherFileListWidget::getIcon(int i) const
{
  static const Icon favrom_small = {
    0b00000000'00001000,
    0b00001111'00011100,
    0b00001010'01111111,
    0b00001010'00111110,
    0b00001010'10011100,
    0b00001010'10110110,
    0b00001010'10100010,
    0b00011010'10000000,
    0b00110010'10011000,
    0b00100110'11001000,
    0b11101110'11101110,
    0b10001010'10100010,
    0b10011010'10110010,
    0b11110011'10011110
  };
  static const Icon favdir_small = {
    0b00000000'00001000,
    0b11111000'00011100,
    0b11111100'01111111,
    0b11111111'00111110,
    0b10000000'00011100,
    0b10000000'00110110,
    0b10000000'00100010,
    0b10000000'00000000,
    0b10000000'00000010,
    0b10000000'00000010,
    0b10000000'00000010,
    0b10000000'00000010,
    0b10000000'00000010,
    0b11111111'11111110
  };
  static const Icon favzip_small = {
    0b00000000'00001000,
    0b11111000'00011100,
    0b11111100'01111111,
    0b11111111'00111110,
    0b10000000'00011100,
    0b10001111'10110110,
    0b10000000'00100010,
    0b10000001'10000000,
    0b10000011'10000010,
    0b10000111'00000010,
    0b10001110'00000010,
    0b10001111'11100010,
    0b10000000'00000010,
    0b11111111'11111110
  };
  static const Icon user_small = {
    0b00000000'00000000,
    0b11111000'00000000,
    0b11111100'00000000,
    0b11111001'00111110,
    0b10000011'10000010,
    0b10000011'10000010,
    0b10000111'11000010,
    0b10111111'11111010,
    0b10011111'11110010,
    0b10001111'11100010,
    0b10000111'11000010,
    0b10001111'11100010,
    0b10011110'11110010,
    0b11011000'00110110
  };
  static const Icon recent_small = {
    0b00000000'00000000,
    0b11111000'00000000,
    0b11111100'00000000,
    0b11111111'11111110,
    0b10000011'10000010,
    0b10001110'11100010,
    0b10001110'11100010,
    0b10011110'11110010,
    0b10011110'01110010,
    0b10011111'00110010,
    0b10001111'11100010,
    0b10001111'11100010,
    0b10000011'10000010,
    0b11111111'11111110
  };
  static const Icon popular_small = {
    0b00000000'00000000,
    0b11111000'00000000,
    0b11111100'00000000,
    0b11111111'11111110,
    0b10000000'00000010,
    0b10001100'01100010,
    0b10011110'11110010,
    0b10011111'11110010,
    0b10011111'11110010,
    0b10001111'11100010,
    0b10000111'11000010,
    0b10000011'10000010,
    0b10000001'00000010,
    0b11111111'11111110
  };

  static const Icon favrom_large = {
    0b00000000000'00000100000,
    0b00000011111'11101110000,
    0b00000011111'11001110000,
    0b00000011010'00011111000,
    0b00000011010'11111111111,
    0b00000011010'01111111110,
    0b00000011010'00111111100,
    0b00000011010'00011111000,
    0b00000011010'00111111100,
    0b00000111010'01111011110,
    0b00000110010'01100000110,
    0b00000110010'00001000000,
    0b00001110010'10011100000,
    0b00001100010'10001100000,
    0b00011100110'11001110000,
    0b00011000110'11000110000,
    0b11111001110'11100111110,
    0b11110011110'11110011110,
    0b11000011110'11110000110,
    0b11000111110'11111000110,
    0b11111110111'11011111110,
    0b11111100111'11001111110
  };
  static const Icon favdir_large = {
    0b00000000000'00000100000,
    0b11111110000'00001110000,
    0b11111111000'00001110000,
    0b11111111100'00011111000,
    0b11111111110'11111111111,
    0b11111111110'01111111110,
    0b11000000000'00111111100,
    0b11000000000'00011111000,
    0b11000000000'00111111100,
    0b11000000000'01111011110,
    0b11000000000'01100000110,
    0b11000000000'00000000000,
    0b11000000000'00000000110,
    0b11000000000'00000000110,
    0b11000000000'00000000110,
    0b11000000000'00000000110,
    0b11000000000'00000000110,
    0b11000000000'00000000110,
    0b11000000000'00000000110,
    0b11000000000'00000000110,
    0b11111111111'11111111110,
    0b11111111111'11111111110
  };
  static const Icon favzip_large = {
    0b00000000000'00000100000,
    0b11111110000'00001110000,
    0b11111111000'00001110000,
    0b11111111100'00011111000,
    0b11111111110'11111111111,
    0b11111111110'01111111110,
    0b11000000000'00111111100,
    0b11000111111'10011111000,
    0b11000111111'00111111100,
    0b11000111111'01111011110,
    0b11000000000'01100000110,
    0b11000000001'00000000000,
    0b11000000011'11000000110,
    0b11000000111'10000000110,
    0b11000001111'00000000110,
    0b11000011110'00000000110,
    0b11000111111'11111000110,
    0b11000111111'11111000110,
    0b11000111111'11111000110,
    0b11000000000'00000000110,
    0b11111111111'11111111110,
    0b11111111111'11111111110
  };
  static const Icon user_large = {
    0b00000000000'00000000000,
    0b11111110000'00000000000,
    0b11111111000'00000000000,
    0b11111111100'00000000000,
    0b11111111111'11111111110,
    0b11111111111'11111111110,
    0b11000000001'00000000110,
    0b11000000011'10000000110,
    0b11000000011'10000000110,
    0b11000000111'11000000110,
    0b11000111111'11111000110,
    0b11001111111'11111100110,
    0b11000111111'11111000110,
    0b11000011111'11110000110,
    0b11000001111'11100000110,
    0b11000011111'11110000110,
    0b11000111110'11111000110,
    0b11000111100'01111000110,
    0b11000011000'00110000110,
    0b11000000000'00000000110,
    0b11111111111'11111111110,
    0b11111111111'11111111110
  };
  static const Icon recent_large = {
    0b00000000000'00000000000,
    0b11111110000'00000000000,
    0b11111111000'00000000000,
    0b11111111100'00000000000,
    0b11111111111'11111111110,
    0b11111111111'11111111110,
    0b11000000000'00000000110,
    0b11000000111'11000000110,
    0b11000011110'11110000110,
    0b11000111110'11111000110,
    0b11000111110'11111000110,
    0b11001111110'11111100110,
    0b11001111110'11111100110,
    0b11001111110'01111100110,
    0b11001111111'00111100110,
    0b11000111111'10011000110,
    0b11000111111'11111000110,
    0b11000011111'11110000110,
    0b11000000111'11000000110,
    0b11000000000'00000000110,
    0b11111111111'11111111110,
    0b11111111111'11111111110
  };
  static const Icon popular_large = {
    0b00000000000'00000000000,
    0b11111110000'00000000000,
    0b11111111000'00000000000,
    0b11111111100'00000000000,
    0b11111111111'11111111110,
    0b11111111111'11111111110,
    0b11000000000'00000000110,
    0b11000000000'00000000110,
    0b11000011100'01110000110,
    0b11000111110'11111000110,
    0b11001111111'11111100110,
    0b11001111111'11111100110,
    0b11001111111'11111100110,
    0b11000111111'11111000110,
    0b11000011111'11110000110,
    0b11000001111'11100000110,
    0b11000000111'11000000110,
    0b11000000011'10000000110,
    0b11000000001'00000000110,
    0b11000000000'00000000110,
    0b11111111111'11111111110,
    0b11111111111'11111111110
  };
  static constexpr auto NLT = static_cast<int>(IconType::numLauncherTypes);
  static const Icon* const small_icons[NLT] = {
    &favrom_small, &favdir_small, &favzip_small,
    &user_small, &recent_small, &popular_small
  };
  static const Icon* const large_icons[NLT] = {
    &favrom_large, &favdir_large, &favzip_large,
    &user_large, &recent_large, &popular_large
  };

  if(static_cast<int>(_iconTypeList[i]) < static_cast<int>(IconType::numTypes))
    return FileListWidget::getIcon(i);

  const bool smallIcon = iconWidth() < 24;
  const int iconType =
    static_cast<int>(_iconTypeList[i]) - static_cast<int>(IconType::numTypes);

  assert(iconType < NLT);

  return smallIcon ? small_icons[iconType] : large_icons[iconType];
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const string LauncherFileListWidget::user_name = "Favorites";
const string LauncherFileListWidget::recent_name = "Recently Played";
const string LauncherFileListWidget::popular_name = "Most Popular";
