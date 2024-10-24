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
#include "Bankswitch.hxx"
#include "BrowserDialog.hxx"
#include "ContextMenu.hxx"
#include "DialogContainer.hxx"
#include "Dialog.hxx"
#include "EditTextWidget.hxx"
#include "FileListWidget.hxx"
#include "LauncherFileListWidget.hxx"
#include "NavigationWidget.hxx"
#include "FSNode.hxx"
#include "OptionsDialog.hxx"
#include "GameInfoDialog.hxx"
#include "HighScoresDialog.hxx"
#include "HighScoresManager.hxx"
#include "GlobalPropsDialog.hxx"
#include "StellaSettingsDialog.hxx"
#include "WhatsNewDialog.hxx"
#include "ProgressDialog.hxx"
#include "MessageBox.hxx"
#include "ToolTip.hxx"
#include "TimerManager.hxx"
#include "OSystem.hxx"
#include "FrameBuffer.hxx"
#include "FBSurface.hxx"
#include "EventHandler.hxx"
#include "StellaKeys.hxx"
#include "Props.hxx"
#include "PropsSet.hxx"
#include "RomImageWidget.hxx"
#include "RomInfoWidget.hxx"
#include "TIAConstants.hxx"
#include "Settings.hxx"
#include "Font.hxx"
#include "StellaFont.hxx"
#include "ConsoleBFont.hxx"
#include "ConsoleMediumBFont.hxx"
#include "StellaMediumFont.hxx"
#include "StellaLargeFont.hxx"
#include "Stella12x24tFont.hxx"
#include "Stella14x28tFont.hxx"
#include "Stella16x32tFont.hxx"
#include "Icons.hxx"
#include "Version.hxx"
#include "MediaFactory.hxx"
#include "LauncherDialog.hxx"
#include "Random.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
LauncherDialog::LauncherDialog(OSystem& osystem, DialogContainer& parent,
                               int x, int y, int w, int h)
  : Dialog(osystem, parent, osystem.frameBuffer().launcherFont(), "",
           x, y, w, h),
    CommandSender(this)
{
  const bool bottomButtons = instance().settings().getBool("launcherbuttons");
  int ypos = Dialog::vBorder();

  myUseMinimalUI = instance().settings().getBool("minimal_ui");

  // if minimalUI, show title within dialog surface instead of showing the filtering control
  if(myUseMinimalUI) {
    addTitleWidget(ypos);
    addPathWidgets(ypos);       //-- path widget line will have file count
  } else {
    addPathWidgets(ypos);
    addFilteringWidgets(ypos);  //-- filtering widget line has file count
  }

  mySelectedItem = addRomWidgets(ypos) - (myUseMinimalUI ? 1 : 2);  // Highlight 'Rom Listing'
  if(!myUseMinimalUI && bottomButtons)
    addButtonWidgets(ypos);
  myNavigationBar->setList(myList);

  tooltip().setFont(_font);

  applyFiltering();
  setHelpAnchor("ROMInfo");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherDialog::addTitleWidget(int &ypos)
{
  const int fontHeight   = Dialog::fontHeight(),
            VGAP         = Dialog::vGap();
  // App information
  ostringstream ver;
  ver << "Stella " << STELLA_VERSION;
#if defined(RETRON77)
  ver << " for RetroN 77";
#endif
  new StaticTextWidget(this, _font, 1, ypos, _w - 2, fontHeight,
                       ver.str(), TextAlign::Center);
  ypos += fontHeight + VGAP;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherDialog::addFilteringWidgets(int& ypos)
{
  const int lineHeight   = Dialog::lineHeight(),
            fontHeight   = Dialog::fontHeight(),
            fontWidth    = Dialog::fontWidth(),
            HBORDER      = Dialog::hBorder(),
            LBL_GAP      = Dialog::fontWidth(),
            buttonHeight = Dialog::buttonHeight(),
            btnGap       = fontWidth / 4,
            btnYOfs      = (buttonHeight - lineHeight) / 2 + 1;
  WidgetArray wid;

  if(_w >= 640)
  {
    const bool smallIcon = lineHeight < 26;

    // Figure out general icon button size
    const GUI::Icon& reloadIcon = smallIcon ? GUI::icon_reload_small : GUI::icon_reload_large;
    const GUI::Icon& randomIcon = smallIcon ? GUI::icon_random_small : GUI::icon_random_large;
    const GUI::Icon& dummyIcon = reloadIcon;  //-- used for sizing all the other icons
    const int iconWidth = dummyIcon.width();
    const int iconGap = ((fontWidth + 1) & ~0b1) + 1; // round up to next even
    const int iconButtonWidth = iconWidth + iconGap;
    const int randomButtonWidth = randomIcon.width() + iconGap;

    int xpos = HBORDER;

    // Setup some constants for Settings button - icon, label, and width
    const GUI::Icon& settingsIcon = smallIcon ? GUI::icon_settings_small : GUI::icon_settings_large;
    const string lblSettings = "Options" + ELLIPSIS;
    const int lwSettings = _font.getStringWidth(lblSettings);
    const int bwSettings = iconButtonWidth + lwSettings + btnGap * 2 + 1;   // Button width for Options button

    // Setup some variables for handling the Filter label + field
    const string& lblFilter = "Filter";
    int lwFilter = _font.getStringWidth(lblFilter);

    string lblFound = "12345 items found";
    int lwFound = _font.getStringWidth(lblFound);
    int fwFilter = EditTextWidget::calcWidth(_font, "123456"); // at least 6 chars

    // Calculate how much space everything will take
    int wTotal = xpos + (iconButtonWidth * 2) + randomButtonWidth + lwFilter + fwFilter + lwFound + bwSettings
      + LBL_GAP * 5 + btnGap * 3 + HBORDER;

    // make sure there is space for at least 6 characters in the filter field
    if(_w < wTotal)
    {
      wTotal -= lwFound;
      lblFound = "12345 items";
      myShortCount = true;
      lwFound = _font.getStringWidth(lblFound);
      wTotal += lwFound;
    }
    if(_w < wTotal)
    {
      wTotal -= lwFilter + LBL_GAP;
      lwFilter = 0;
    }

    fwFilter += _w - wTotal;

    ypos += btnYOfs;
    // Show the reload button
    myReloadButton = new ButtonWidget(this, _font, xpos, ypos - btnYOfs,
                                      iconButtonWidth, buttonHeight, reloadIcon, kReloadCmd);
    myReloadButton->setToolTip("Reload listing (Ctrl+R)");
    wid.push_back(myReloadButton);
    xpos = myReloadButton->getRight() + LBL_GAP * 2;

    // Show the "Filter" label
    if(lwFilter)
    {
      const StaticTextWidget* s = new StaticTextWidget(this, _font, xpos, ypos, lblFilter);
      xpos = s->getRight() + LBL_GAP;
    }

    // Show the filter input field that can narrow the results shown in the listing
    myPattern = new EditTextWidget(this, _font, xpos, ypos - 2, fwFilter, lineHeight, "");
    myPattern->setToolTip("Enter filter text to reduce file list.\n"
      "Use '*' and '?' as wildcards.");
    wid.push_back(myPattern);
    xpos = myPattern->getRight() + btnGap;

    // Show the subdirectories button
    mySubDirsButton = new ButtonWidget(this, _font, xpos, ypos - btnYOfs,
                                       iconButtonWidth, buttonHeight, dummyIcon, kSubDirsCmd);
    mySubDirsButton->setToolTip("Toggle subdirectories (Ctrl+D)");
    wid.push_back(mySubDirsButton);
    xpos = mySubDirsButton->getRight() + btnGap + LBL_GAP;

    // Show the files counter
    myRomCount = new StaticTextWidget(this, _font, xpos, ypos,
                                      lwFound, fontHeight, "", TextAlign::Right);
    xpos = _w - HBORDER - bwSettings - randomButtonWidth - btnGap;

    // Show the random ROM button
    myRandomRomButton = new ButtonWidget(this, _font, xpos, ypos - btnYOfs,
                                         randomButtonWidth, buttonHeight, randomIcon, kLoadRndRomCmd);
#ifndef BSPF_MACOS
    myRandomRomButton->setToolTip("Load random ROM (Alt+R)");
#else
    myRandomRomButton->setToolTip("Load random ROM (Cmd+R)");
#endif
    wid.push_back(myRandomRomButton);

    // Show the Settings / Options button (positioned from the right)
    xpos = _w - HBORDER - bwSettings;
    mySettingsButton = new ButtonWidget(this, _font, xpos, ypos - btnYOfs,
                                        iconWidth, buttonHeight, settingsIcon,
                                        iconGap, lblSettings, kOptionsCmd);
    mySettingsButton-> setToolTip("Open Options dialog (Ctrl+O)");
    wid.push_back(mySettingsButton);

    ypos = mySettingsButton->getBottom() + Dialog::vGap();
  }
  addToFocusList(wid);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherDialog::addPathWidgets(int& ypos)
{
  // Add some buttons and textfield to show current directory
  const int
    lineHeight   = Dialog::lineHeight(),
    fontHeight   = Dialog::fontHeight(),
    fontWidth    = Dialog::fontWidth(),
    HBORDER      = Dialog::hBorder(),
    LBL_GAP      = fontWidth,
    buttonHeight = Dialog::buttonHeight(),
    BTN_GAP      = fontWidth / 4,
    btnYOfs      = (buttonHeight - lineHeight) / 2 + 1;
  const bool smallIcon = lineHeight < 26;
  const string lblFound = "12345 items";
  const int lwFound = _font.getStringWidth(lblFound);

  // Setup some constants for Help button
  const GUI::Icon& helpIcon = smallIcon ? GUI::icon_help_small : GUI::icon_help_large;
  const int iconWidth = helpIcon.width();
  const int iconGap = ((fontWidth + 1) & ~0b1) + 1; // round up to next even
  const int buttonWidth = iconWidth + iconGap;
  const int wNav = _w - HBORDER * 2 - (myUseMinimalUI ? lwFound + LBL_GAP : buttonWidth + BTN_GAP);
  int xpos = HBORDER;
  WidgetArray wid;

  myNavigationBar = new NavigationWidget(this, _font, xpos, ypos - btnYOfs, wNav, buttonHeight);

  if(myUseMinimalUI)
  {
    // Show the files counter
    myShortCount = true;
    xpos = _w - HBORDER - lwFound - LBL_GAP / 2;
    myRomCount = new StaticTextWidget(this, _font, xpos, ypos - 1,
      lwFound, fontHeight, "", TextAlign::Right);

    auto* e = new EditTextWidget(this, _font, myNavigationBar->getRight() - 1,
        ypos - btnYOfs, lwFound + LBL_GAP + 1, lineHeight, "");
    e->setEditable(false);
    e->setEnabled(false);
  } else {
    // Show Help icon at far right
    xpos = _w - HBORDER - (buttonWidth + BTN_GAP - 2);
    myHelpButton = new ButtonWidget(this, _font, xpos, ypos - btnYOfs,
                                    buttonWidth, buttonHeight, helpIcon, kHelpCmd);
    const string key = instance().eventHandler().getMappingDesc(Event::UIHelp, EventMode::kMenuMode);
    myHelpButton->setToolTip("Click for help. (" + key + ")");
    myHelpButton->setEnabled(MediaFactory::supportsURL());
    wid.push_back(myHelpButton);
  }
  ypos += lineHeight + Dialog::vGap() * 2;

  addToFocusList(wid);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int LauncherDialog::addRomWidgets(int ypos)
{
  const bool bottomButtons = instance().settings().getBool("launcherbuttons");
  const int fontWidth    = Dialog::fontWidth(),
            VBORDER      = Dialog::vBorder(),
            HBORDER      = Dialog::hBorder(),
            VGAP         = Dialog::vGap(),
            buttonHeight = myUseMinimalUI
              ? -VGAP * 2
              : bottomButtons ? Dialog::buttonHeight() : -VGAP * 2;
  int xpos = HBORDER;
  WidgetArray wid;

  // Add list with game titles
  // Before we add the list, we need to know the size of the RomInfoWidget
  const int listHeight = _h - ypos - VBORDER - buttonHeight - VGAP * 3;

  const float imgZoom = getRomInfoZoom(listHeight);
  const int imageWidth = imgZoom * TIAConstants::viewableWidth;
  const int listWidth = _w - (imageWidth > 0 ? imageWidth + fontWidth : 0) - HBORDER * 2;

  // remember initial ROM directory for returning there via home button
  instance().settings().setValue("startromdir", getRomDir());
  myList = new LauncherFileListWidget(this, _font, xpos, ypos, listWidth, listHeight);
  myList->setEditable(false);
  myList->setListMode(FSNode::ListMode::All);
  // since we cannot know how many files there are, use are really high value here
  myList->progress().setRange(0, 50000, 5);
  myList->progress().setMessage("        Filtering files" + ELLIPSIS + "        ");
  wid.push_back(myList);

  // Add ROM info area (if enabled)
  if(imageWidth > 0)
  {
    xpos += myList->getWidth() + fontWidth;

    // Initial surface size is the viewable area's width squared
    const Common::Size imgSize(TIAConstants::viewableWidth * imgZoom,
      TIAConstants::viewableWidth * imgZoom);

    // Calculate font area, and in the process the font that can be used
    // Infofont is unknown yet, but used in image label too. Assuming maximum font height.
    int imageHeight = imgSize.h + RomImageWidget::labelHeight(_font);

    const Common::Size fontArea(imageWidth - fontWidth * 2,
      myList->getHeight() - imageHeight - VGAP * 4);
    setRomInfoFont(fontArea);

    // Now we have the correct font height
    imageHeight = imgSize.h + RomImageWidget::labelHeight(*myROMInfoFont);
    myRomImageWidget = new RomImageWidget(this, *myROMInfoFont,
      xpos, ypos, imageWidth, imageHeight);
    if(!myUseMinimalUI)
      wid.push_back(myRomImageWidget);

    const int yofs = imageHeight + myROMInfoFont->getFontHeight() / 2;
    myRomInfoWidget = new RomInfoWidget(this, *myROMInfoFont,
      xpos, ypos + yofs, imageWidth, myList->getHeight() - yofs);
  }
  return addToFocusList(wid);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherDialog::addButtonWidgets(int& ypos)
{
  const bool bottomButtons = instance().settings().getBool("launcherbuttons");
  const int lineHeight = Dialog::lineHeight(),
    BUTTON_GAP = Dialog::buttonGap(),
    VBORDER = Dialog::vBorder(),
    HBORDER = Dialog::hBorder(),
    VGAP = Dialog::vGap(),
    buttonHeight = myUseMinimalUI
      ? lineHeight - VGAP * 4
      : bottomButtons ? Dialog::buttonHeight() : -VGAP * 2,
    buttonWidth = (_w - 2 * HBORDER - BUTTON_GAP * (4 - 1));
  int xpos = HBORDER;
  WidgetArray wid;

  // Add four buttons at the bottom
  ypos = _h - VBORDER - buttonHeight;
#ifndef BSPF_MACOS
  myStartButton = new ButtonWidget(this, _font, xpos, ypos, (buttonWidth + 0) / 4, buttonHeight,
    "Select", kLoadROMCmd);
  wid.push_back(myStartButton);

  xpos += (buttonWidth + 0) / 4 + BUTTON_GAP;
  myGoUpButton = new ButtonWidget(this, _font, xpos, ypos, (buttonWidth + 1) / 4, buttonHeight,
    "Go Up", ListWidget::kParentDirCmd);
  wid.push_back(myGoUpButton);

  xpos += (buttonWidth + 1) / 4 + BUTTON_GAP;
  myOptionsButton = new ButtonWidget(this, _font, xpos, ypos, (buttonWidth + 3) / 4, buttonHeight,
    "Options" + ELLIPSIS, kOptionsCmd);
  wid.push_back(myOptionsButton);

  xpos += (buttonWidth + 2) / 4 + BUTTON_GAP;
  myQuitButton = new ButtonWidget(this, _font, xpos, ypos, (buttonWidth + 4) / 4, buttonHeight,
    "Quit", kQuitCmd);
  wid.push_back(myQuitButton);
#else
  myQuitButton = new ButtonWidget(this, _font, xpos, ypos, (buttonWidth + 0) / 4, buttonHeight,
    "Quit", kQuitCmd);
  wid.push_back(myQuitButton);

  xpos += (buttonWidth + 0) / 4 + BUTTON_GAP;
  myOptionsButton = new ButtonWidget(this, _font, xpos, ypos, (buttonWidth + 1) / 4, buttonHeight,
    "Options" + ELLIPSIS, kOptionsCmd);
  wid.push_back(myOptionsButton);

  xpos += (buttonWidth + 1) / 4 + BUTTON_GAP;
  myGoUpButton = new ButtonWidget(this, _font, xpos, ypos, (buttonWidth + 2) / 4, buttonHeight,
    "Go Up", ListWidget::kParentDirCmd);
  wid.push_back(myGoUpButton);

  xpos += (buttonWidth + 2) / 4 + BUTTON_GAP;
  myStartButton = new ButtonWidget(this, _font, xpos, ypos, (buttonWidth + 3) / 4, buttonHeight,
    "Select", kLoadROMCmd);
  wid.push_back(myStartButton);
#endif
  myStartButton->setToolTip("Start emulation of selected ROM\nor switch to selected directory.");
  addToFocusList(wid);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const string& LauncherDialog::selectedRom() const
{
  return currentNode().getPath();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const string& LauncherDialog::selectedRomMD5()
{
  if(currentNode().isDirectory() || !Bankswitch::isValidRomName(currentNode()))
    return EmptyString;

  // Attempt to conserve memory
  if(myMD5List.size() > 500)
    myMD5List.clear();

  // Lookup MD5, and if not present, cache it
  const auto iter = myMD5List.find(currentNode().getPath());
  if(iter == myMD5List.end())
    myMD5List[currentNode().getPath()] = OSystem::getROMMD5(currentNode());

  return myMD5List[currentNode().getPath()];
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const FSNode& LauncherDialog::currentNode() const
{
  return myList->selected();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const FSNode& LauncherDialog::currentDir() const
{
  return myList->currentDir();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherDialog::reload()
{
  const bool extensions = instance().settings().getBool("launcherextensions");

  myMD5List.clear();
  myList->setShowFileExtensions(extensions);
  myList->reload();
  myPendingReload = false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherDialog::handleQuit()
{
  // saveConfig() will be done in quit()
  close();
  instance().eventHandler().quit();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherDialog::quit()
{
  saveConfig();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherDialog::tick()
{
  if(myPendingReload && myReloadTime < TimerManager::getTicks() / 1000)
    reload();

  if(myPendingRomInfo && myRomInfoTime < TimerManager::getTicks() / 1000)
    loadPendingRomInfo();

  Dialog::tick();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherDialog::loadConfig()
{
  // Should we use a temporary directory specified on the commandline, or the
  // default one specified by the settings?
  Settings& settings = instance().settings();
  const string& romdir = getRomDir();
  const string& version = settings.getString("stella.version");

  // Show "What's New" message when a new version of Stella is run for the first time
  if(version < STELLA_VERSION)
  {
    openWhatsNew();
    settings.setValue("stella.version", STELLA_VERSION);
  }

  toggleSubDirs(false);
  myList->setShowFileExtensions(settings.getBool("launcherextensions"));
  // Favorites
  myList->loadFavorites();

  // Assume that if the list is empty, this is the first time that loadConfig()
  // has been called (and we should reload the list)
  if(myList->getList().empty())
  {
    FSNode node(romdir.empty() ? "~" : romdir);
    if(!myList->isDirectory(node))
      node = FSNode("~");

    myList->setDirectory(node, settings.getString("lastrom"));
    updateUI();
  }
  Dialog::setFocus(getFocusList()[mySelectedItem]);

  if(myRomImageWidget && myRomInfoWidget)
  {
    myRomImageWidget->reloadProperties(currentNode());
    myRomInfoWidget->reloadProperties(currentNode());
  }

  myList->clearFlags(Widget::FLAG_WANTS_RAWDATA); // always reset this
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherDialog::saveConfig()
{
  Settings& settings = instance().settings();

  if(settings.getBool("followlauncher"))
    settings.setValue("romdir", myList->currentDir().getShortPath());

  // Favorites
  myList->saveFavorites();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherDialog::updateUI()
{
  // Only enable the 'up' button if there's a parent directory
  if(myGoUpButton)
    myGoUpButton->setEnabled(myList->currentDir().hasParent());
  // Only enable the navigation buttons if function is available
  myNavigationBar->updateUI();

  // Indicate how many files were found
  ostringstream buf;
  buf << (myList->getList().size() - (currentDir().hasParent() ? 1 : 0))
    << (myShortCount ? " items" : " items found");
  myRomCount->setLabel(buf.str());

  loadRomInfo();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string LauncherDialog::getRomDir()
{
  const Settings& settings = instance().settings();
  const string& tmpromdir = settings.getString("tmpromdir");

  return tmpromdir != EmptyString ? tmpromdir : settings.getString("romdir");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool LauncherDialog::matchWithWildcardsIgnoreCase(
    string_view str, string_view pattern)
{
  string in{str};
  string pat{pattern};

  BSPF::toUpperCase(in);
  BSPF::toUpperCase(pat);

  return BSPF::matchWithWildcards(in, pat);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherDialog::applyFiltering()
{
  myList->setNameFilter(
    [&](const FSNode& node) {
      myList->incProgress();
      if(!node.isDirectory())
      {
        // Only show valid ROMs
        string ext;
        if(!Bankswitch::isValidRomName(node, ext) ||
           BSPF::compareIgnoreCase(ext, "zip") == 0) // exclude ZIPs without any valid ROMs
          return false;

        // Skip over files that don't match the pattern in the 'pattern' textbox
        if(myPattern && !myPattern->getText().empty() &&
           !matchWithWildcardsIgnoreCase(node.getName(), myPattern->getText()))
          return false;
      }
      return true;
    }
  );
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
float LauncherDialog::getRomInfoZoom(int listHeight) const
{
  // The ROM info area is some multiple of the minimum TIA image size
  float zoom = instance().settings().getFloat("romviewer");

  if(zoom > 0.F)
  {
    const GUI::Font& smallFont = instance().frameBuffer().smallFont();
    const int fontWidth = Dialog::fontWidth(),
              HBORDER   = Dialog::hBorder();

    // upper zoom limit - at least 24 launchers chars/line and 7 + 4 ROM info lines
    if((_w - (HBORDER * 2 + fontWidth + 30) - zoom * TIAConstants::viewableWidth)
       / fontWidth < MIN_LAUNCHER_CHARS)
    {
      zoom = static_cast<float>(_w - (HBORDER * 2 + fontWidth + 30) - MIN_LAUNCHER_CHARS * fontWidth)
        / TIAConstants::viewableWidth;
    }
    if((listHeight - 12 - zoom * TIAConstants::viewableHeight) <
       MIN_ROMINFO_ROWS * smallFont.getLineHeight() +
       MIN_ROMINFO_LINES * smallFont.getFontHeight())
    {
      zoom = static_cast<float>(listHeight - 12 -
                   MIN_ROMINFO_ROWS * smallFont.getLineHeight() -
                   MIN_ROMINFO_LINES * smallFont.getFontHeight())
        / TIAConstants::viewableHeight;
    }

    // lower zoom limit - at least 30 ROM info chars/line
    if((zoom * TIAConstants::viewableWidth)
       / smallFont.getMaxCharWidth() < MIN_ROMINFO_CHARS + 6)
    {
      zoom = static_cast<float>(MIN_ROMINFO_CHARS * smallFont.getMaxCharWidth() + 6)
        / TIAConstants::viewableWidth;
    }
  }
  return zoom;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherDialog::setRomInfoFont(const Common::Size& area)
{
  // TODO: Perhaps offer a setting to override the font used?

  const FontDesc FONTS[7] = {
    GUI::stella16x32tDesc, GUI::stella14x28tDesc, GUI::stella12x24tDesc,
    GUI::stellaLargeDesc, GUI::stellaMediumDesc,
    GUI::consoleMediumBDesc, GUI::consoleBDesc
  };

  // Try to pick a font that works best, based on the available area
  for(const auto& font: FONTS)
  {
    // only use fonts <= launcher fonts
    if(Dialog::fontHeight() >= font.height)
    {
      if(area.h >= static_cast<uInt32>(MIN_ROMINFO_ROWS * font.height + 2
         + MIN_ROMINFO_LINES * font.height)
         && area.w >= static_cast<uInt32>(MIN_ROMINFO_CHARS * font.maxwidth))
      {
        myROMInfoFont = make_unique<GUI::Font>(font);
        return;
      }
    }
  }
  myROMInfoFont = make_unique<GUI::Font>(GUI::stellaDesc);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherDialog::loadRomInfo()
{
  if(!myRomImageWidget || !myRomInfoWidget)
    return;

  // Update ROM info UI item, delayed
  myRomInfoTime = TimerManager::getTicks() / 1000 + myRomImageWidget->pendingLoadTime();
  myPendingRomInfo = true;

  const string& md5 = selectedRomMD5();
  if(!md5.empty())
  {
    // The properties for the currently selected ROM
    Properties properties;

    // Make sure to load a per-ROM properties entry, if one exists
    instance().propSet().loadPerROM(currentNode(), md5);

    // And now get the properties for this ROM
    instance().propSet().getMD5(md5, properties);

    myRomImageWidget->setProperties(currentNode(), properties, false);
    myRomInfoWidget->setProperties(currentNode(), properties, false);
  }
  else
  {
    myRomImageWidget->clearProperties();
    myRomInfoWidget->clearProperties();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherDialog::loadPendingRomInfo()
{
  myPendingRomInfo = false;

  if(!myRomImageWidget || !myRomInfoWidget)
    return;

  const string& md5 = selectedRomMD5();
  if(md5 != EmptyString)
  {
    // The properties for the currently selected ROM
    Properties properties;

    // Make sure to load a per-ROM properties entry, if one exists
    instance().propSet().loadPerROM(currentNode(), md5);

    // And now get the properties for this ROM
    instance().propSet().getMD5(md5, properties);
    myRomImageWidget->setProperties(currentNode(), properties);
    myRomInfoWidget->setProperties(currentNode(), properties);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherDialog::handleFavoritesChanged()
{
  if (instance().settings().getBool("favorites"))
  {
    myList->loadFavorites();
  }
  else
  {
    if(myList->inVirtualDir())
      myList->selectParent();
    myList->saveFavorites(true);
    myList->clearFavorites();
  }
  reload();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherDialog::handleContextMenu()
{
  const string& cmd = contextMenu().getSelectedTag().toString();

  if(cmd == "favorite")
    myList->toggleUserFavorite();
  else if(cmd == "remove")
  {
    myList->removeFavorite();
    reload();
  }
  else if(cmd == "removefavorites")
    removeAllFavorites();
  else if(cmd == "removepopular")
    removeAllPopular();
  else if(cmd == "removerecent")
    removeAllRecent();
  else if(cmd == "properties")
    openGameProperties();
  else if(cmd == "override")
    openGlobalProps();
  else if(cmd == "extensions")
    toggleExtensions();
  else if(cmd == "sorting")
    toggleSorting();
  else if(cmd == "subdirs")
    sendCommand(kSubDirsCmd, 0, 0);
  else if(cmd == "homedir")
    sendCommand(FileListWidget::kHomeDirCmd, 0, 0);
  else if(cmd == "highscores")
    openHighScores();
  else if(cmd == "reload")
    reload();
  else if(cmd == "options")
    openSettings();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
ContextMenu& LauncherDialog::contextMenu()
{
  if(myContextMenu == nullptr)
    // Create (empty) context menu for ROM list options
    myContextMenu = make_unique<ContextMenu>(this, _font);

  return *myContextMenu;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherDialog::handleKeyDown(StellaKey key, StellaMod mod, bool repeated)
{
  // Grab the key before passing it to the actual dialog and check for
  // context menu keys
  bool handled = false;

  if(!(myPattern && myPattern->isHighlighted()
      && instance().eventHandler().checkEventForKey(EventMode::kEditMode, key, mod)))
  {
    if(StellaModTest::isControl(mod))
    {
      handled = true;
      switch(key)
      {
        case KBDK_D:
          sendCommand(kSubDirsCmd, 0, 0);
          break;

        case KBDK_E:
          toggleExtensions();
          break;

        case KBDK_F:
          myList->toggleUserFavorite();
          break;

        case KBDK_G:
          openGameProperties();
          break;

        case KBDK_H:
          if(instance().highScores().enabled())
            openHighScores();
          break;

        case KBDK_O:
          openSettings();
          break;

        case KBDK_P:
          openGlobalProps();
          break;

        case KBDK_R:
          reload();
          break;

        case KBDK_S:
          toggleSorting();
          break;

        case KBDK_X:
          myList->removeFavorite();
          reload();
          break;

        default:
          handled = false;
          break;
      }
    }
    else if(StellaModTest::isAlt(mod) && key == KBDK_R)
    {
      loadRandomRom();
      handled = true;
    }
  }
  if(!handled)
#if defined(RETRON77)
    // handle keys used by R77
    switch(key)
    {
      case KBDK_F8: // front  ("Skill P2")
        openGlobalProps();
        break;
      case KBDK_F4: // back ("COLOR", "B/W")
        openSettings();
        break;

      case KBDK_F11: // front ("LOAD")
        // convert unused previous item key into page-up event
        _focusedWidget->handleEvent(Event::UIPgUp);
        break;

      case KBDK_F1: // front ("MODE")
        // convert unused next item key into page-down event
        _focusedWidget->handleEvent(Event::UIPgDown);
        break;

      default:
        Dialog::handleKeyDown(key, mod);
        break;
    }
#else
    // Required because BrowserDialog does not want raw input
    if(repeated || !myList->handleKeyDown(key, mod))
      Dialog::handleKeyDown(key, mod, repeated);
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherDialog::handleJoyDown(int stick, int button, bool longPress)
{
  myEventHandled = false;
  myList->setFlags(Widget::FLAG_WANTS_RAWDATA);   // allow handling long button press
  Dialog::handleJoyDown(stick, button, longPress);
  myList->clearFlags(Widget::FLAG_WANTS_RAWDATA); // revert flag afterwards!
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherDialog::handleJoyUp(int stick, int button)
{
  // open power-up options and settings for 2nd and 4th button if not mapped otherwise
  const Event::Type e = instance().eventHandler().eventForJoyButton(EventMode::kMenuMode, stick, button);

  if(myList->isHighlighted() && button == 1 && (e == Event::UIOK || e == Event::NoType))
    openGlobalProps();
  if(myList->isHighlighted() && button == 3 && (e == Event::UITabPrev || e == Event::NoType))
    openSettings();
  else if(!myEventHandled)
    Dialog::handleJoyUp(stick, button);

  myList->clearFlags(Widget::FLAG_WANTS_RAWDATA); // stop allowing to handle long button press
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Event::Type LauncherDialog::getJoyAxisEvent(int stick, JoyAxis axis, JoyDir adir, int button)
{
  Event::Type event = instance().eventHandler().eventForJoyAxis(EventMode::kMenuMode, stick, axis, adir, button);

  // map axis events for launcher
  if(myUseMinimalUI)
  {
    switch(event)
    {
      case Event::UINavPrev:
        // convert unused previous item event into page-up event
        event = Event::UIPgUp;
        break;

      case Event::UINavNext:
        // convert unused next item event into page-down event
        event = Event::UIPgDown;
        break;

      case Event::UITabPrev:
        myRomImageWidget->changeImage(-1);
        myEventHandled = true;
        break;

      case Event::UITabNext:
        myRomImageWidget->changeImage(1);
        myEventHandled = true;
        break;

      case Event::UIOK:
      case Event::UICancel:
        myRomImageWidget->toggleImageZoom();
        myEventHandled = true;
        break;

      default:
        break;
    }
  }
  else
  {
    switch(event)
    {
      case Event::UITabPrev:
        event = Event::UIPgUp;
        break;

      case Event::UITabNext:
        event = Event::UIPgDown;
        break;

      default:
        break;
    }
  }
  return event;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherDialog::handleMouseUp(int x, int y, MouseButton b, int clickCount)
{
  // Grab right mouse button for context menu, send left to base class
  if(b == MouseButton::RIGHT
    && x + getAbsX() >= myList->getLeft() && x + getAbsX() <= myList->getRight()
    && y + getAbsY() >= myList->getTop() && y + getAbsY() <= myList->getBottom())
  {
    openContextMenu(x, y);
  }
  else
    Dialog::handleMouseUp(x, y, b, clickCount);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherDialog::handleCommand(CommandSender* sender, int cmd,
                                   int data, int id)
{
  switch(cmd)
  {
    case kSubDirsCmd:
      toggleSubDirs();
      break;

    case kLoadROMCmd:
      if(myList->isDirectory(myList->selected()))
      {
        if(myList->selected().getName() == "..")
          myList->selectParent();
        else
          myList->selectDirectory();
        break;
      }
      [[fallthrough]];
    case FileListWidget::ItemActivated:
      loadRom();
      break;

    case kLoadRndRomCmd:
      loadRandomRom();
      break;

    case kOptionsCmd:
      openSettings();
      break;

    case kReloadCmd:
      reload();
      break;

    case FileListWidget::ItemChanged:
      updateUI();
      break;

    case ListWidget::kLongButtonPressCmd:
      if(!currentNode().isDirectory() && Bankswitch::isValidRomName(currentNode()))
        openContextMenu();
      myEventHandled = true;
      break;

    case EditableWidget::kChangedCmd:
    case EditableWidget::kAcceptCmd:
    {
      const bool subDirs = instance().settings().getBool("launchersubdirs");

      myList->setIncludeSubDirs(subDirs);
      if(subDirs && cmd == EditableWidget::kChangedCmd)
      {
        // delay (potentially slow) subdirectories reloads until user stops typing
        myReloadTime = TimerManager::getTicks() / 1000 + myList->getQuickSelectDelay();
        myPendingReload = true;
      }
      else
        reload();
      break;
    }

    case kQuitCmd:
      handleQuit();
      break;

    case kRomDirChosenCmd:
    {
      const string romDir = instance().settings().getString("romdir");

      if(myList->currentDir().getPath() != romDir)
      {
        FSNode node(romDir);

        if(!myList->isDirectory(node))
          node = FSNode("~");

        myList->setDirectory(node);
      }
      if(romDir != instance().settings().getString("startromdir"))
      {
        instance().settings().setValue("startromdir", romDir);
        reload();
      }
      break;
    }

    case kFavChangedCmd:
      handleFavoritesChanged();
      break;

    case kRmAllFav:
      myList->removeAllUserFavorites();
      reload();
      break;

    case kRmAllPop:
      myList->removeAllPopular();
      reload();
      break;

    case kRmAllRec:
      myList->removeAllRecent();
      reload();
      break;

    case kExtChangedCmd:
      reload();
      break;

    case ContextMenu::kItemSelectedCmd:
      handleContextMenu();
      break;

    case RomInfoWidget::kClickedCmd:
    {
      const string& url = myRomInfoWidget->getUrl();

      if(url != EmptyString)
        MediaFactory::openURL(url);
      break;
    }

    default:
      Dialog::handleCommand(sender, cmd, data, 0);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherDialog::loadRom()
{
  // Assumes that the ROM will be loaded successfully, has to be done
  //  before saving the config.
  myList->updateFavorites();
  saveConfig();

  const string& result = instance().createConsole(currentNode(), selectedRomMD5());
  if(result == EmptyString)
  {
    instance().settings().setValue("lastrom", myList->getSelectedString());

    // If romdir has never been set, set it now based on the selected rom
    if(instance().settings().getString("romdir") == EmptyString)
      instance().settings().setValue("romdir", currentNode().getParent().getShortPath());
  }
  else
    instance().frameBuffer().showTextMessage(result, MessagePosition::MiddleCenter, true);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherDialog::openContextMenu(int x, int y)
{
  // Dynamically create context menu for ROM list options

  bool addCancel = false;
  if(x < 0 || y < 0)
  {
    // Long pressed button, determine position from currently selected list item
    x = myList->getLeft() + myList->getWidth() / 2;
    y = myList->getTop() + (myList->getSelected() - myList->currentPos() + 1) * _font.getLineHeight();
    addCancel = true;
  }

  struct ContextItem {
    string label;
    string shortcut;
    string key;
    explicit ContextItem(string_view _label, string_view _shortcut,
                         string_view _key)
      : label{_label}, shortcut{_shortcut}, key{_key} {}
    // No shortcuts displayed in minimal UI
    ContextItem(string_view _label, string_view _key)
      : label{_label}, key{_key} {}
  };
  using ContextList = std::vector<ContextItem>;
  ContextList items;
  const bool useFavorites = instance().settings().getBool("favorites");

  if(useFavorites)
  {
    if(!currentNode().isDirectory())
    {
      if(myList->isUserDir(currentNode().getName()))
        items.emplace_back("Remove all from favorites", "removefavorites");
      if(myList->isPopularDir(currentNode().getName()))
        items.emplace_back("Remove all from most popular", "removepopular");
      if(myList->isRecentDir(currentNode().getName()))
        items.emplace_back("Remove all from recently played", "removerecent");
      if(myList->inRecentDir())
        items.emplace_back("Remove from recently played", "Ctrl+X", "remove");
      if(myList->inPopularDir())
        items.emplace_back("Remove from most popular", "Ctrl+X", "remove");
    }
    if((currentNode().isDirectory() && currentNode().getName() != "..")
      || Bankswitch::isValidRomName(currentNode()))
      items.emplace_back(myList->isUserFavorite(myList->selected().getPath())
        ? "Remove from favorites"
        : "Add to favorites", "Ctrl+F", "favorite");
  }
  if(!currentNode().isDirectory() && Bankswitch::isValidRomName(currentNode()))
  {
    items.emplace_back("Game properties" + ELLIPSIS, "Ctrl+G", "properties");
    items.emplace_back("Power-on options" + ELLIPSIS, "Ctrl+P", "override");
    if(instance().highScores().enabled())
      items.emplace_back("High scores" + ELLIPSIS, "Ctrl+H", "highscores");
  }
  if(myUseMinimalUI)
  {
  #ifndef RETRON77
    items.emplace_back(instance().settings().getBool("launchersubdirs")
      ? "Exclude subdirectories"
      : "Include subdirectories", "subdirs");
  #endif
    items.emplace_back("Go to initial directory", "homedir");
    items.emplace_back("Go to parent directory", "prevdir");
  #ifndef RETRON77
    items.emplace_back("Reload listing", "reload");
    items.emplace_back("Options" + ELLIPSIS, "options");
  #else
    items.emplace_back("Settings" + ELLIPSIS, "options");
  #endif
  }
  else
  {
    items.emplace_back(instance().settings().getBool("launcherextensions")
      ? "Disable file extensions"
      : "Enable file extensions", "Ctrl+E", "extensions");
    if(useFavorites && myList->inVirtualDir())
      items.emplace_back(instance().settings().getBool("altsorting")
        ? "Normal sorting"
        : "Alternative sorting", "Ctrl+S", "sorting");
    //if(!instance().settings().getBool("launcherbuttons"))
    //{
    //  items.emplace_back("Options" + ELLIPSIS, "Ctrl+O", "options");
    //}
  }
  if(addCancel)
    items.emplace_back("Cancel", ""); // closes the context menu and does nothing

  // Format items for menu
  VariantList varItems;
  if(myUseMinimalUI)
    for(auto& item : items)
      VarList::push_back(varItems, " " + item.label + " ", item.key);
  else
  {
    // Align all shortcuts to the right
    size_t maxLen = 0;
    for(auto& item : items)
      maxLen = std::max(maxLen, item.label.length());

    for(auto& item : items)
      VarList::push_back(varItems, " " + item.label.append(maxLen - item.label.length(), ' ')
        + "  " + item.shortcut + " ", item.key);
  }
  contextMenu().addItems(varItems);

  // Add menu at current x,y mouse location
  contextMenu().show(x + getAbsX(), y + getAbsY(), surface().dstRect(), 0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherDialog::loadRandomRom()
{
  const Random rand;
  int tries = 100; // limit to 100 tries, in case the directory contains no ROMs

  do {
    myList->setSelected(rand.next() % myList->getList().size());
  } while(myList->isDirectory(myList->selected()) && --tries);
  if(tries)
    loadRom();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherDialog::openSettings()
{
  saveConfig();

  // Create an options dialog, similar to the in-game one
  if (instance().settings().getBool("basic_settings"))
    myDialog = make_unique<StellaSettingsDialog>(instance(), parent(),
                                                 _w, _h, AppMode::launcher);
  else
    myDialog = make_unique<OptionsDialog>(instance(), parent(), this, _w, _h,
                                          AppMode::launcher);
  myDialog->open();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherDialog::openGameProperties()
{
  if(!currentNode().isDirectory() && Bankswitch::isValidRomName(currentNode()))
  {
    // Create game properties dialog
    myDialog = make_unique<GameInfoDialog>(instance(), parent(),
      myUseMinimalUI ? _font : instance().frameBuffer().font(), this, _w, _h);
    myDialog->open();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherDialog::openGlobalProps()
{
  if(!currentNode().isDirectory() && Bankswitch::isValidRomName(currentNode()))
  {
    // Create global props dialog, which is used to temporarily override
    // ROM properties
    myDialog = make_unique<GlobalPropsDialog>(this, myUseMinimalUI
                                              ? _font
                                              : instance().frameBuffer().font());
    myDialog->open();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherDialog::openHighScores()
{
  // Create an high scores dialog, similar to the in-game one
  myDialog = make_unique<HighScoresDialog>(instance(), parent(), _w, _h,
                                           AppMode::launcher);
  myDialog->open();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherDialog::openWhatsNew()
{
  myDialog = make_unique<WhatsNewDialog>(instance(), parent(), _w, _h);
  myDialog->open();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherDialog::toggleSubDirs(bool toggle)
{
  bool subdirs = instance().settings().getBool("launchersubdirs");

  if(toggle)
  {
    subdirs = !subdirs;
    instance().settings().setValue("launchersubdirs", subdirs);
  }

  if(mySubDirsButton)
  {
    const bool smallIcon = Dialog::lineHeight() < 26;
    const GUI::Icon& subdirsIcon = subdirs
      ? smallIcon ? GUI::icon_subdirs_small_on : GUI::icon_subdirs_large_on
      : smallIcon ? GUI::icon_subdirs_small_off : GUI::icon_subdirs_large_off;

    mySubDirsButton->setIcon(subdirsIcon);
  }
  myList->setIncludeSubDirs(subdirs);
  if(toggle)
    reload();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherDialog::toggleExtensions()
{
  const bool extensions = !instance().settings().getBool("launcherextensions");

  instance().settings().setValue("launcherextensions", extensions);
  myList->setShowFileExtensions(extensions);
  reload();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherDialog::toggleSorting()
{
  if(myList->inVirtualDir())
  {
    // Toggle between normal and alternative sorting of virtual directories
    const bool altSorting = !instance().settings().getBool("altsorting");

    instance().settings().setValue("altsorting", altSorting);
    reload();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherDialog::removeAllFavorites()
{
  StringList msg;

  msg.emplace_back("This will remove ALL ROMs from");
  msg.emplace_back("your 'Favorites' list!");
  msg.emplace_back("");
  msg.emplace_back("Are you sure?");
  myConfirmMsg = make_unique<GUI::MessageBox>
    (this, _font, msg, _w, _h, kRmAllFav,
      "Yes", "No", "Remove all Favorites", false);
  myConfirmMsg->show();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherDialog::removeAll(string_view name)
{
  StringList msg;

  msg.emplace_back("This will remove ALL ROMs from");
  msg.emplace_back("your '" + string{name} + "' list!");
  msg.emplace_back("");
  msg.emplace_back("Are you sure?");
  myConfirmMsg = make_unique<GUI::MessageBox>
    (this, _font, msg, _w, _h, kRmAllPop,
      "Yes", "No", "Remove all " + string{name}, false);
  myConfirmMsg->show();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherDialog::removeAllPopular()
{
  removeAll("Most Popular");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void LauncherDialog::removeAllRecent()
{
  removeAll("Recently Played");
}
