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

#ifndef LAUNCHER_DIALOG_HXX
#define LAUNCHER_DIALOG_HXX

class ButtonWidget;
class CommandSender;
class ContextMenu;
class DialogContainer;
class OSystem;
class Properties;
class EditTextWidget;
class NavigationWidget;
class LauncherFileListWidget;
class RomImageWidget;
class RomInfoWidget;
class StaticTextWidget;

namespace Common {
  struct Size;
}
namespace GUI {
  class MessageBox;
}

#include <unordered_map>
#include <unordered_set>

#include "bspf.hxx"
#include "Dialog.hxx"
#include "FSNode.hxx"
#include "Variant.hxx"

class LauncherDialog : public Dialog, CommandSender
{
  public:
    // These must be accessible from dialogs created by this class
    enum {
      kLoadROMCmd      = 'STRT',  // load currently selected ROM
      kRomDirChosenCmd = 'romc',  // ROM dir chosen
      kFavChangedCmd   = 'favc',  // Favorite tracking changed
      kExtChangedCmd   = 'extc',  // File extension display changed
    };
    using FileList = std::unordered_set<string>;

  public:
    LauncherDialog(OSystem& osystem, DialogContainer& parent,
                   int x, int y, int w, int h);
    ~LauncherDialog() override = default;

    /**
      Get path for the currently selected file.

      @return path if a valid ROM file, else the empty string
    */
    const string& selectedRom() const;

    /**
      Get MD5sum for the currently selected file.
      If the MD5 hasn't already been calculated, it will be
      calculated (and cached) for future use.

      @return md5sum if a valid ROM file, else the empty string
    */
    const string& selectedRomMD5();

    /**
      Get node for the currently selected entry.

      @return FSNode currently selected
    */
    const FSNode& currentNode() const;

    /**
      Get node for the current directory.

      @return FSNode (directory) currently active
    */
    const FSNode& currentDir() const;

    /**
      Reload the current listing
    */
    void reload();

    /**
      Quit the dialog
    */
    void quit();


    void tick() override;

  private:
    static constexpr int MIN_LAUNCHER_CHARS = 24;
    static constexpr int MIN_ROMINFO_CHARS = 30;
    static constexpr int MIN_ROMINFO_ROWS = 7; // full lines
    static constexpr int MIN_ROMINFO_LINES = 4; // extra lines

    void setPosition() override { positionAt(0); }
    void handleKeyDown(StellaKey key, StellaMod mod, bool repeated) override;
    void handleMouseUp(int x, int y, MouseButton b, int clickCount) override;
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;
    void handleJoyDown(int stick, int button, bool longPress) override;
    void handleJoyUp(int stick, int button) override;
    Event::Type getJoyAxisEvent(int stick, JoyAxis axis, JoyDir adir, int button) override;

    void loadConfig() override;
    void saveConfig() override;
    void updateUI();
    void addTitleWidget(int& ypos);
    void addFilteringWidgets(int& ypos);
    void addPathWidgets(int& ypos);
    int addRomWidgets(int ypos);
    void addButtonWidgets(int& ypos);
    string getRomDir();

    /**
      Search if string contains pattern including wildcard '*'
      and '?' as joker, ignoring case.

      @param str      The searched string
      @param pattern  The pattern to search for

      @return True if pattern was found.
    */
    static bool matchWithWildcardsIgnoreCase(string_view str, string_view pattern);

    void applyFiltering();

    float getRomInfoZoom(int listHeight) const;
    void setRomInfoFont(const Common::Size& area);

    void loadRom();
    void loadRomInfo();
    void loadPendingRomInfo();
    void loadRandomRom();
    void openSettings();
    void openGameProperties();
    void openContextMenu(int x = -1, int y = -1);
    void openGlobalProps();
    void openHighScores();
    void openWhatsNew();
    void toggleSubDirs(bool toggle = true);
    void handleContextMenu();
    void handleQuit();
    void toggleExtensions();
    void toggleSorting();
    void handleFavoritesChanged();
    void removeAllFavorites();
    void removeAll(string_view name);
    void removeAllPopular();
    void removeAllRecent();

    ContextMenu& contextMenu();

  private:
    unique_ptr<Dialog> myDialog;
    unique_ptr<ContextMenu> myContextMenu;

    // automatically sized font for ROM info viewer
    unique_ptr<GUI::Font> myROMInfoFont;

    ButtonWidget*     mySettingsButton{nullptr};
    EditTextWidget*   myPattern{nullptr};
    ButtonWidget*     mySubDirsButton{nullptr};
    ButtonWidget*     myRandomRomButton{nullptr};
    StaticTextWidget* myRomCount{nullptr};
    ButtonWidget*     myHelpButton{nullptr};

    NavigationWidget* myNavigationBar{nullptr};
    ButtonWidget*     myReloadButton{nullptr};

    LauncherFileListWidget* myList{nullptr};

    ButtonWidget*     myStartButton{nullptr};
    ButtonWidget*     myGoUpButton{nullptr};
    ButtonWidget*     myOptionsButton{nullptr};
    ButtonWidget*     myQuitButton{nullptr};

    RomImageWidget*   myRomImageWidget{nullptr};
    RomInfoWidget*    myRomInfoWidget{nullptr};

    std::unordered_map<string,string> myMD5List;

    // Show a message about the dangers of using this function
    unique_ptr<GUI::MessageBox> myConfirmMsg;

    int mySelectedItem{0};

    bool myUseMinimalUI{false};
    bool myEventHandled{false};
    bool myShortCount{false};
    bool myPendingReload{false};
    uInt64 myReloadTime{0};
    bool myPendingRomInfo{false};
    uInt64 myRomInfoTime{0};

    enum {
      kSubDirsCmd    = 'lred',
      kLoadRndRomCmd = 'lrnd',  // load random ROM
      kOptionsCmd    = 'OPTI',
      kQuitCmd       = 'QUIT',
      kReloadCmd     = 'relc',
      kRmAllFav      = 'rmaf',
      kRmAllPop      = 'rmap',
      kRmAllRec      = 'rmar'
    };

  private:
    // Following constructors and assignment operators not supported
    LauncherDialog() = delete;
    LauncherDialog(const LauncherDialog&) = delete;
    LauncherDialog(LauncherDialog&&) = delete;
    LauncherDialog& operator=(const LauncherDialog&) = delete;
    LauncherDialog& operator=(LauncherDialog&&) = delete;
};

#endif
