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

#ifndef BROWSER_DIALOG_HXX
#define BROWSER_DIALOG_HXX

class GuiObject;
class ButtonWidget;
class EditTextWidget;
class FileListWidget;
class NavigationWidget;
class StaticTextWidget;

#include "Dialog.hxx"
#include "Command.hxx"
#include "FSNode.hxx"
#include "bspf.hxx"

class BrowserDialog : public Dialog
{
  public:
    enum class Mode {
      FileLoad,       // File selector, no input from user
      FileLoadNoDirs, // File selector, no input from user, fixed directory
      FileSave,       // File selector, filename changable by user
      Directories     // Directories only, no input from user
    };

    /** Function which is run when the user clicks OK or Cancel.
        Boolean parameter is passed as 'true' when OK is clicked, else 'false'.
        FSNode parameter is what is currently selected in the browser.
    */
    using Command = std::function<void(bool, const FSNode&)>;

  public:
    // NOTE: Do not call this c'tor directly!  Use the static show method below
    //       There is no point in doing so, since the result can't be returned
    BrowserDialog(GuiObject* boss, const GUI::Font& font, int max_w, int max_h);
    ~BrowserDialog() override = default;

    /**
      Place the browser window onscreen, using the given attributes.

      @param parent     The parent object of the browser (cannot be nullptr)
      @param font       The font to use in the browser
      @param title      The title of the browser window
      @param startpath  The initial path to select in the browser
      @param mode       The functionality to use (load/save/display)
      @param command    The command to run when 'OK' or 'Cancel' is clicked
      @param namefilter Filter files/directories in browser display
    */
    static void show(GuiObject* parent, const GUI::Font& font,
                     string_view title,string_view startpath,
                     BrowserDialog::Mode mode,
                     const Command& command,
                     const FSNode::NameFilter& namefilter = {
                      [](const FSNode&) { return true; }});

    /**
      Place the browser window onscreen, using the given attributes.

      @param parent     The parent object of the browser (cannot be nullptr)
      @param title      The title of the browser window
      @param startpath  The initial path to select in the browser
      @param mode       The functionality to use (load/save/display)
      @param command    The command to run when 'OK' or 'Cancel' is clicked
      @param namefilter Filter files/directories in browser display
    */
    static void show(GuiObject* parent,
                     string_view title, string_view startpath,
                     BrowserDialog::Mode mode,
                     const Command& command,
                     const FSNode::NameFilter& namefilter = {
                      [](const FSNode&) { return true; } });

    /**
      Since the show methods allocate a static BrowserDialog, at some
      point we need to manually de-allocate it.  This method must be
      called from one of the lowest-level destructors to do that.
      Currently this is called from the OSystem destructor.
    */
    static void hide();

  private:
    /** Place the browser window onscreen, using the given attributes */
    void show(string_view startpath,
              BrowserDialog::Mode mode,
              const Command& command,
              const FSNode::NameFilter& namefilter);

    /** Get resulting file node (called after receiving kChooseCmd) */
    const FSNode& getResult() const;

    void handleKeyDown(StellaKey key, StellaMod mod, bool repeated) override;
    void handleCommand(CommandSender* sender, int cmd, int data, int id) override;
    void updateUI(bool fileSelected);

  private:
    enum {
      kChooseCmd  = 'CHOS',
      kGoUpCmd    = 'GOUP',
      kBaseDirCmd = 'BADR',
      kHomeDirCmd = 'HODR'
    };

    // Called when the user selects OK (bool is true) or Cancel (bool is false)
    // FSNode will be set to whatever is active (basically, getResult())
    Command _command{[](bool, const FSNode&){}};

    FileListWidget*   _fileList{nullptr};
    NavigationWidget* _navigationBar{nullptr};
    StaticTextWidget* _name{nullptr};
    EditTextWidget*   _selected{nullptr};
    ButtonWidget*     _goUpButton{nullptr};
    ButtonWidget*     _baseDirButton{nullptr};
    ButtonWidget*     _homeDirButton{nullptr};
    CheckboxWidget*   _savePathBox{nullptr};

    BrowserDialog::Mode _mode{Mode::Directories};

    static unique_ptr<BrowserDialog> ourBrowser;

  private:
    // Following constructors and assignment operators not supported
    BrowserDialog() = delete;
    BrowserDialog(const BrowserDialog&) = delete;
    BrowserDialog(BrowserDialog&&) = delete;
    BrowserDialog& operator=(const BrowserDialog&) = delete;
    BrowserDialog& operator=(BrowserDialog&&) = delete;
};

#endif
