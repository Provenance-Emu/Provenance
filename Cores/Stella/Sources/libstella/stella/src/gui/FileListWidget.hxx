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

#ifndef FILE_LIST_WIDGET_HXX
#define FILE_LIST_WIDGET_HXX

class CommandSender;
class ProgressDialog;

#include "FSNode.hxx"
#include "Stack.hxx"
#include "StringListWidget.hxx"

/**
  Provides an encapsulation of a file listing, allowing to descend into
  directories, and send signals based on whether an item is selected or
  activated.

  When the signals ItemChanged and ItemActivated are emitted, the caller
  can query the selected() and/or currentDir() methods to determine the
  current state.

  Note that the ItemActivated signal is not sent when activating a
  directory; instead the selection descends into the directory.

  Widgets wishing to enforce their own filename filtering are able
  to use a 'NameFilter' as described below.
*/
class FileListWidget : public StringListWidget
{
  public:
    enum {
      ItemChanged   = 'FLic',  // Entry in the list is changed (single-click, etc)
      ItemActivated = 'FLac',  // Entry in the list is activated (double-click, etc)
      kHomeDirCmd   = 'homc',  // go to Home directory
      kPrevDirCmd   = 'prvc',  // go back in history to previous directory
      kNextDirCmd   = 'nxtc'   // go back in history to next directory
    };
    using IconTypeFilter = std::function<bool(const FSNode& node)>;

  public:
    FileListWidget(GuiObject* boss, const GUI::Font& font,
                   int x, int y, int w, int h);
    ~FileListWidget() override = default;

    bool handleKeyDown(StellaKey key, StellaMod mod) override;

    string getToolTip(const Common::Point& pos) const override;

    /** Determines how to display files/folders; either setDirectory or reload
        must be called after any of these are called. */
    void setListMode(FSNode::ListMode mode) { _fsmode = mode; }
    void setNameFilter(const FSNode::NameFilter& filter) {
      _filter = filter;
    }

    // When enabled, all subdirectories will be searched too.
    void setIncludeSubDirs(bool enable) { _includeSubDirs = enable; }

    // When enabled, file extensions will be displayed too.
    void setShowFileExtensions(bool enable) { _showFileExtensions = enable; }

    /**
      Set initial directory, and optionally select the given item.

        @param node       The directory to display.  If this is a file, its parent
                          will instead be used, and the file will be selected
        @param select     An optional entry to select (if applicable)
    */
    void setDirectory(const FSNode& node, string_view select = EmptyString);

    /** Descend into currently selected directory */
    void selectDirectory();
    /** Go to directory */
    void selectDirectory(const FSNode& node);
    /** Select parent directory (if applicable) */
    void selectParent();
    /** Check if the there is a previous directory in history */
    bool hasPrevHistory();
    /** Check if the there is a next directory in history */
    bool hasNextHistory();

    /** Reload current location (file or directory) */
    void reload();

    /** Gets current node(s) */
    const FSNode& selected();
    const FSNode& currentDir() const { return _node; }

    static void setQuickSelectDelay(uInt64 time) { _QUICK_SELECT_DELAY = time; }
    uInt64 getQuickSelectDelay() const { return _QUICK_SELECT_DELAY; }

    ProgressDialog& progress();
    void incProgress();

  protected:
    struct HistoryType
    {
      FSNode node;
      string selected;

      explicit HistoryType(const FSNode& _hnode, string_view _hselected)
        : node{_hnode}, selected{_hselected} {}
    };
    enum class IconType {
      unknown,
      rom,
      directory,
      zip,
      updir,
      numTypes,
      favrom = numTypes,
      favdir,
      favzip,
      userdir,
      recentdir,
      popdir,
      numLauncherTypes = popdir - numTypes + 1
    };
    using IconTypeList = std::vector<IconType>;
    using Icon = uIntArray;

  protected:
    /** Very similar to setDirectory(), but also updates the history */
    void setLocation(const FSNode& node, string_view select);
    /** Select to home directory */
    void selectHomeDir();
    /** Select previous directory in history (if applicable) */
    void selectPrevHistory();
    /** Select next directory in history (if applicable) */
    void selectNextHistory();
    virtual bool isDirectory(const FSNode& node) const;
    virtual void getChildren(const FSNode::CancelCheck& isCancelled);
    virtual void extendLists(StringList& list) { }
    virtual IconType getIconType(string_view path) const;
    virtual const Icon* getIcon(int i) const;
    int iconWidth() const;
    virtual bool fullPathToolTip() const { return false; }
    static string& fixPath(string& path);
    void addHistory(const FSNode& node);

  protected:
    FSNode _node;
    FSList _fileList;
    FSNode::NameFilter _filter;
    string _selectedFile;
    StringList _dirList;
    std::vector<HistoryType> _history;
    int _historyHome{0}; // offset into initially created history
    std::vector<HistoryType>::iterator _currentHistory{_history.begin()};
    IconTypeList _iconTypeList;

  private:
    bool handleText(char text) override;
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;
    int drawIcon(int i, int x, int y, ColorId color) override;

  private:
    FSNode::ListMode _fsmode{FSNode::ListMode::All};
    bool _includeSubDirs{false};
    bool _showFileExtensions{true};

    uInt32 _selected{0};

    // Allow quick select for "uppercase", non-letter input
    StellaKey _lastKey{StellaKey::KBDK_UNKNOWN};
    StellaMod _lastMod{StellaMod::KBDM_NONE};
    StellaMod _firstMod{StellaMod::KBDM_NONE};
    string _quickSelectStr;
    uInt64 _quickSelectTime{0};
    static uInt64 _QUICK_SELECT_DELAY;

    unique_ptr<ProgressDialog> myProgressDialog;

    static FSNode ourDefaultNode;

  private:
    // Following constructors and assignment operators not supported
    FileListWidget() = delete;
    FileListWidget(const FileListWidget&) = delete;
    FileListWidget(FileListWidget&&) = delete;
    FileListWidget& operator=(const FileListWidget&) = delete;
    FileListWidget& operator=(FileListWidget&&) = delete;
};

#endif
