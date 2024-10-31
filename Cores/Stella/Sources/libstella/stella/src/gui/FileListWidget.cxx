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

#include "bspf.hxx"
#include "ScrollBarWidget.hxx"
#include "TimerManager.hxx"
#include "ProgressDialog.hxx"
#include "FBSurface.hxx"
#include "Bankswitch.hxx"

#include "FileListWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FileListWidget::FileListWidget(GuiObject* boss, const GUI::Font& font,
                               int x, int y, int w, int h)
  : StringListWidget(boss, font, x, y, w, h),
    _filter{[](const FSNode&) { return true; }}
{
  // This widget is special, in that it catches signals and redirects them
  setTarget(this);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FileListWidget::setDirectory(const FSNode& node, string_view select)
{
  _node = node;

  // We always want a directory listing
  if(_node.isDirectory())
    _selectedFile = select;
  else
  {
    // Otherwise, keeping going up in the directory name until a valid
    // one is found
    while(!_node.isDirectory() && _node.hasParent())
      _node = _node.getParent();

    _selectedFile = _node.getName();
  }

  // Initialize history
  FSNode tmp = _node;
  string name{select};

  _history.clear();
  while(tmp.hasParent())
  {
    _history.emplace_back(tmp, fixPath(name));

    name = tmp.getName();
    tmp = tmp.getParent();
  }
  // History is in reverse order; we need to fix that
  std::reverse(_history.begin(), _history.end());
  _currentHistory = std::prev(_history.end(), 1);
  _historyHome = static_cast<int>(_currentHistory - _history.begin());

  // Finally, go to this location
  setLocation(_node, _selectedFile);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FileListWidget::setLocation(const FSNode& node, string_view select)
{
  progress().resetProgress();
  progress().open();
  FSNode::CancelCheck isCancelled = [this]() {
    return myProgressDialog->isCancelled();
  };

  _node = node;

  // Read in the data from the file system (start with an empty list)
  _fileList.clear();

  getChildren(isCancelled);

  // Now fill the list widget with the names from the file list,
  // even if cancelled
  StringList list;
  const size_t orgLen = _node.getShortPath().length();

  _dirList.clear();
  _iconTypeList.clear();

  for(const auto& file : _fileList)
  {
    const string& path = file.getShortPath();
    const string& name = file.getName();

    // display only relative path in tooltip
    if(path.length() >= orgLen && !fullPathToolTip())
      _dirList.push_back(path.substr(orgLen));
    else
      _dirList.push_back(path);

    if(file.isDirectory() && !BSPF::endsWithIgnoreCase(name, ".zip"))
    {
      list.push_back(name);
      if(name == "..")
        _iconTypeList.push_back(IconType::updir);
      else
        _iconTypeList.push_back(getIconType(file.getPath()));
    }
    else
    {
      const string& displayName = _showFileExtensions ? name : file.getNameWithExt(EmptyString);

      list.push_back(displayName);
      _iconTypeList.push_back(getIconType(file.getPath()));
    }
  }
  extendLists(list);

  setList(list);
  setSelected(select);
  ListWidget::recalc();

  progress().close();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FileListWidget::isDirectory(const FSNode& node) const
{
  return node.isDirectory();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FileListWidget::getChildren(const FSNode::CancelCheck& isCancelled)
{
  if(_includeSubDirs)
  {
    // Actually this could become HUGE
    _fileList.reserve(0x2000);
    _node.getAllChildren(_fileList, _fsmode, _filter, true, isCancelled);
  }
  else
  {
    _fileList.reserve(0x200);
    _node.getChildren(_fileList, _fsmode, _filter, false, true, isCancelled);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FileListWidget::IconType FileListWidget::getIconType(string_view path) const
{
  const FSNode node(path);

  if(node.isDirectory())
  {
    return BSPF::endsWithIgnoreCase(node.getName(), ".zip")
      ? IconType::zip : IconType::directory;
  }
  else
    return node.isFile() && Bankswitch::isValidRomName(node)
      ? IconType::rom : IconType::unknown;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FileListWidget::selectDirectory()
{
  addHistory(selected());
  setLocation(selected(), _selectedFile);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FileListWidget::selectDirectory(const FSNode& node)
{
  if(node.getPath() != _node.getPath())
    addHistory(node);
  setLocation(node, _selectedFile);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FileListWidget::selectParent()
{
  if(_node.hasParent() && _fsmode != FSNode::ListMode::FilesOnly)
  {
    string name = _node.getName();
    const FSNode parent(_node.getParent());

    _currentHistory->selected = selected().getName();
    addHistory(parent);
    setLocation(parent, fixPath(name));
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FileListWidget::selectHomeDir()
{
  while(hasPrevHistory())
    selectPrevHistory();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FileListWidget::selectPrevHistory()
{
  if(_currentHistory != _history.begin() + _historyHome)
  {
    _currentHistory->selected = selected().getName();
    _currentHistory = std::prev(_currentHistory, 1);
    setLocation(_currentHistory->node, _currentHistory->selected);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FileListWidget::selectNextHistory()
{
  if(_currentHistory != std::prev(_history.end(), 1))
  {
    _currentHistory->selected = selected().getName();
    _currentHistory = std::next(_currentHistory, 1);
    setLocation(_currentHistory->node, _currentHistory->selected);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FileListWidget::hasPrevHistory()
{
  return _currentHistory != _history.begin() + _historyHome;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FileListWidget::hasNextHistory()
{
  return _currentHistory != std::prev(_history.end(), 1);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string& FileListWidget::fixPath(string& path)
{
  if(!path.empty() && path.back() == FSNode::PATH_SEPARATOR)
  {
    path.pop_back();
    if(path.length() == 2 && path.back() == ':')
      path.pop_back();
  }
  return path;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FileListWidget::addHistory(const FSNode& node)
{
  if(!_history.empty())
  {
    while(_currentHistory != std::prev(_history.end(), 1))
      _history.pop_back();

    string select = selected().getName();
    _currentHistory->selected = fixPath(select);
  }

  _history.emplace_back(node, "..");
  _currentHistory = std::prev(_history.end(), 1);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FileListWidget::reload()
{
  if(isDirectory(_node))
  {
    _selectedFile = _showFileExtensions
      ? selected().getName()
      : selected().getNameWithExt(EmptyString);
    setLocation(_node, _selectedFile);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const FSNode& FileListWidget::selected()
{
  if(!_fileList.empty())
  {
    _selected = BSPF::clamp(_selected, 0U, static_cast<uInt32>(_fileList.size()-1));
    return _fileList[_selected];
  }
  else
  {
    // This should never happen, but we'll error-check out-of-bounds
    // array access anyway
    return ourDefaultNode;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
ProgressDialog& FileListWidget::progress()
{
  if(myProgressDialog == nullptr)
    myProgressDialog = make_unique<ProgressDialog>(this, _font, "");

  return *myProgressDialog;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FileListWidget::incProgress()
{
  progress().incProgress();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FileListWidget::handleKeyDown(StellaKey key, StellaMod mod)
{
  // Grab the key before passing it to the actual dialog and check for
  // file list navigation keys
  bool handled = false;

  if(StellaModTest::isAlt(mod))
  {
    handled = true;
    switch(key)
    {
      case KBDK_HOME:
        sendCommand(kHomeDirCmd, 0, 0);
        break;

      case KBDK_LEFT:
        sendCommand(kPrevDirCmd, 0, 0);
        break;

      case KBDK_RIGHT:
        sendCommand(kNextDirCmd, 0, 0);
        break;

      case KBDK_UP:
        sendCommand(kParentDirCmd, 0, 0);
        break;

      case KBDK_DOWN:
        sendCommand(kActivatedCmd, _selected, 0);
        break;

      default:
        handled = false;
        break;
    }
  }
  // Handle shift input for quick directory selection
  _lastKey = key; _lastMod = mod;
  if(_quickSelectTime < TimerManager::getTicks() / 1000)
    _firstMod = mod;
  else if(key == KBDK_SPACE) // allow searching ROMs with a space without selecting/starting
    handled = true;

  return handled;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FileListWidget::handleText(char text)
{
  // Quick selection mode: Go to first list item starting with this key
  // (or a substring accumulated from the last couple key presses).
  // Only works in a useful fashion if the list entries are sorted.
  const uInt64 time = TimerManager::getTicks() / 1000;
  const bool firstShift = StellaModTest::isShift(_firstMod);

  if(StellaModTest::isShift(_lastMod))
  {
    const string_view key = StellaKeyName::forKey(_lastKey);
    text = !key.empty() ? key.front() : '\0';
  }

  if(_quickSelectTime < time)
    _quickSelectStr = text;
  else
    _quickSelectStr += text;
  _quickSelectTime = time + _QUICK_SELECT_DELAY;

  int selectedItem = 0;
  for(const auto& i : _list)
  {
    if(BSPF::startsWithIgnoreCase(i, _quickSelectStr))
      // Select directories when the first character is uppercase
      if(firstShift ==
          (_iconTypeList[selectedItem] == IconType::directory
          || _iconTypeList[selectedItem] == IconType::userdir
          || _iconTypeList[selectedItem] == IconType::recentdir
          || _iconTypeList[selectedItem] == IconType::popdir))
        break;
    selectedItem++;
  }

  if(selectedItem > 0)
    setSelected(selectedItem);

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FileListWidget::handleCommand(CommandSender* sender, int cmd, int data, int id)
{
  switch (cmd)
  {
    case FileListWidget::kHomeDirCmd:
      // Do not let the boss know
      selectHomeDir();
      return;

    case FileListWidget::kPrevDirCmd:
      // Do not let the boss know
      selectPrevHistory();
      return;

    case FileListWidget::kNextDirCmd:
      // Do not let the boss know
      selectNextHistory();
      return;

    case ListWidget::kParentDirCmd:
      selectParent();
      // Do not let the boss know
      return;

    case ListWidget::kSelectionChangedCmd:
      _selected = data;
      cmd = ItemChanged;
      break;

    case ListWidget::kActivatedCmd:
      [[fallthrough]];
    case ListWidget::kDoubleClickedCmd:
      _selected = data;
      if(isDirectory(selected())/* || !selected().exists()*/)
      {
        if(selected().getName() == "..")
          selectParent();
        else
        {
          cmd = ItemChanged;
          selectDirectory();
        }
      }
      else
      {
        _selectedFile = selected().getName();
        cmd = ItemActivated;
      }
      break;

    case ListWidget::kLongButtonPressCmd:
      // do nothing, let boss handle this one
      break;

    default:
      // If we don't know about the command, send it to the parent and exit
      StringListWidget::handleCommand(sender, cmd, data, id);
      return;
  }

  // Send command to boss, then revert to target 'this'
  setTarget(_boss);
  sendCommand(cmd, data, id);
  setTarget(this);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int FileListWidget::drawIcon(int i, int x, int y, ColorId color)
{
  const bool smallIcon = iconWidth() < 24;
  const Icon* icon = getIcon(i);
  const int iconGap = smallIcon ? 2 : 3;
  FBSurface& s = _boss->dialog().surface();

  s.drawBitmap(icon->data(), x + 2 + iconGap,
      y + (_lineHeight - static_cast<int>(icon->size())) / 2 - 1,
      color, iconWidth() - iconGap * 2, static_cast<int>(icon->size()));

  return iconWidth();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const FileListWidget::Icon* FileListWidget::getIcon(int i) const
{
  static const Icon unknown_small = {
    0b00111111'11000000,
    0b00100000'01100000,
    0b00100000'01110000,
    0b00100000'01111000,
    0b00100000'00001000,
    0b00100000'00001000,
    0b00100000'00001000,
    0b00100000'00001000,
    0b00100000'00001000,
    0b00100000'00001000,
    0b00100000'00001000,
    0b00100000'00001000,
    0b00100000'00001000,
    0b00111111'11111000
  };
  static const Icon rom_small = {
    0b00000000000000000,
    0b00001111'11100000,
    0b00001010'10100000,
    0b00001010'10100000,
    0b00001010'10100000,
    0b00001010'10100000,
    0b00001010'10100000,
    0b00011010'10110000,
    0b00110010'10011000,
    0b00100110'11001000,
    0b11101110'11101110,
    0b10001010'10100010,
    0b10011010'10110010,
    0b11110011'10011110
  };
  static const Icon directory_small = {
    0b00000000000000000,
    0b11111000'00000000,
    0b11111100'00000000,
    0b11111111'11111110,
    0b10000000'00000010,
    0b10000000'00000010,
    0b10000000'00000010,
    0b10000000'00000010,
    0b10000000'00000010,
    0b10000000'00000010,
    0b10000000'00000010,
    0b10000000'00000010,
    0b10000000'00000010,
    0b11111111'11111110
  };
  static const Icon zip_small = {
    0b00000000000000000,
    0b11111000'00000000,
    0b11111100'00000000,
    0b11111111'11111110,
    0b10000000'00000010,
    0b10001111'11100010,
    0b10000000'11100010,
    0b10000001'11000010,
    0b10000011'10000010,
    0b10000111'00000010,
    0b10001110'00000010,
    0b10001111'11100010,
    0b10000000'00000010,
    0b11111111'11111110
  };
  static const Icon up_small = {
    0b00000000000000000,
    0b11111000'00000000,
    0b11111100'00000000,
    0b11111111'11111110,
    0b10000001'00000010,
    0b10000011'10000010,
    0b10000111'11000010,
    0b10001111'11100010,
    0b10011111'11110010,
    0b10000011'10000010,
    0b10000011'10000010,
    0b10000011'10000010,
    0b10000011'10000010,
    0b11111111'11111110
  };

  static const Icon unknown_large = {
    0b00000000000'00000000000,
    0b00111111111'11110000000,
    0b00111111111'11111000000,
    0b00110000000'00011100000,
    0b00110000000'00001110000,
    0b00110000000'00000111000,
    0b00110000000'00000011000,
    0b00110000000'00000011000,
    0b00110000000'00000011000,
    0b00110000000'00000011000,
    0b00110000000'00000011000,
    0b00110000000'00000011000,
    0b00110000000'00000011000,
    0b00110000000'00000011000,
    0b00110000000'00000011000,
    0b00110000000'00000011000,
    0b00110000000'00000011000,
    0b00110000000'00000011000,
    0b00110000000'00000011000,
    0b00110000000'00000011000,
    0b00111111111'11111111000,
    0b00111111111'11111111000
  };
  static const Icon rom_large = {
    0b00000000000'00000000000,
    0b00000011111'11110000000,
    0b00000011111'11110000000,
    0b00000011010'10110000000,
    0b00000011010'10110000000,
    0b00000011010'10110000000,
    0b00000011010'10110000000,
    0b00000011010'10110000000,
    0b00000011010'10110000000,
    0b00000111010'10111000000,
    0b00000110010'10011000000,
    0b00000110010'10011000000,
    0b00001110010'10011100000,
    0b00001100010'10001100000,
    0b00011100110'11001110000,
    0b00011000110'11000110000,
    0b11111001110'11100111110,
    0b111100111101'1110011110,
    0b110000111101'1110000110,
    0b110001111101'1111000110,
    0b111111101111'1011111110,
    0b111111001111'1001111110
  };
  static const Icon directory_large = {
    0b00000000000'00000000000,
    0b11111110000'00000000000,
    0b11111111000'00000000000,
    0b11111111100'00000000000,
    0b11111111111'11111111110,
    0b11111111111'11111111110,
    0b11000000000'00000000110,
    0b11000000000'00000000110,
    0b11000000000'00000000110,
    0b11000000000'00000000110,
    0b11000000000'00000000110,
    0b11000000000'00000000110,
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
  static const Icon zip_large = {
    0b00000000000'00000000000,
    0b11111110000'00000000000,
    0b11111111000'00000000000,
    0b11111111100'00000000000,
    0b11111111111'11111111110,
    0b11111111111'11111111110,
    0b11000000000'00000000110,
    0b11000111111'11111000110,
    0b11000111111'11111000110,
    0b11000111111'11111000110,
    0b11000000000'11110000110,
    0b11000000001'11100000110,
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
  static const Icon up_large = {
    0b00000000000'00000000000,
    0b11111110000'00000000000,
    0b11111111000'00000000000,
    0b11111111100'00000000000,
    0b11111111111'11111111110,
    0b11111111111'11111111110,
    0b11000000000'00000000110,
    0b11000000001'10000000110,
    0b11000000011'10000000110,
    0b11000000111'11000000110,
    0b11000001111'11100000110,
    0b11000011111'11110000110,
    0b11000111111'11111000110,
    0b11001111111'11111100110,
    0b11000000011'10000000110,
    0b11000000011'10000000110,
    0b11000000011'10000000110,
    0b11000000011'10000000110,
    0b11000000011'10000000110,
    0b11000000000'00000000110,
    0b11111111111'11111111110,
    0b11111111111'11111111110
  };
  const int idx = static_cast<int>(IconType::numTypes);
  static const Icon* const small_icons[idx] = {
    &unknown_small, &rom_small, &directory_small, &zip_small, &up_small
  };
  static const Icon* const large_icons[idx] = {
    &unknown_large, &rom_large, &directory_large, &zip_large, &up_large,
  };
  const bool smallIcon = iconWidth() < 24;
  const int iconType = static_cast<int>(_iconTypeList[i]);

  assert(iconType < idx);

  return smallIcon ? small_icons[iconType] : large_icons[iconType];
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int FileListWidget::iconWidth() const
{
  const bool smallIcon = _lineHeight < 26;

  return smallIcon ? 16 + 4: 24 + 6;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string FileListWidget::getToolTip(const Common::Point& pos) const
{
  const Common::Rect& rect = getEditRect();
  const int idx = getToolTipIndex(pos);

  if(idx < 0)
    return EmptyString;

  if(_includeSubDirs && static_cast<int>(_dirList.size()) > idx)
    return _toolTipText + _dirList[idx];

  const string value = _list[idx];

  if(static_cast<uInt32>(_font.getStringWidth(value)) > rect.w() - iconWidth())
    return _toolTipText + value;
  else
    return _toolTipText;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt64 FileListWidget::_QUICK_SELECT_DELAY = 300;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FSNode FileListWidget::ourDefaultNode = FSNode("~");
