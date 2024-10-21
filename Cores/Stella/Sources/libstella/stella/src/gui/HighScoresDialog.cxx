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
#include "Console.hxx"
#include "Launcher.hxx"
#include "EventHandler.hxx"
#include "Font.hxx"
#include "PropsSet.hxx"
#include "FBSurface.hxx"
#include "EditTextWidget.hxx"
#include "PopUpWidget.hxx"
#include "MessageBox.hxx"

#include "HighScoresDialog.hxx"

static constexpr int BUTTON_GFX_H = 10;
static constexpr int BUTTON_GFX_H_LARGE = 16;

static constexpr std::array<uInt32, BUTTON_GFX_H> PREV_GFX = {
  0b0000110000,
  0b0000110000,
  0b0001111000,
  0b0001111000,
  0b0011001100,
  0b0011001100,
  0b0110000110,
  0b0110000110,
  0b1100000011,
  0b1100000011,
};

static constexpr std::array<uInt32, BUTTON_GFX_H> NEXT_GFX = {
  0b1100000011,
  0b1100000011,
  0b0110000110,
  0b0110000110,
  0b0011001100,
  0b0011001100,
  0b0001111000,
  0b0001111000,
  0b0000110000,
  0b0000110000,
};

static constexpr std::array<uInt32, BUTTON_GFX_H_LARGE> PREV_GFX_LARGE = {
  0b0000000110000000,
  0b0000000110000000,
  0b0000001111000000,
  0b0000001111000000,
  0b0000011111100000,
  0b0000011111100000,
  0b0000111001110000,
  0b0000111001110000,
  0b0001110000111000,
  0b0001110000111000,
  0b0011100000011100,
  0b0011100000011100,
  0b0111000000001110,
  0b0111000000001110,
  0b1110000000000111,
  0b1110000000000111,
};

static constexpr std::array<uInt32, BUTTON_GFX_H_LARGE> NEXT_GFX_LARGE = {
  0b1110000000000111,
  0b1110000000000111,
  0b0111000000001110,
  0b0111000000001110,
  0b0011100000011100,
  0b0011100000011100,
  0b0001110000111000,
  0b0001110000111000,
  0b0000111001110000,
  0b0000111001110000,
  0b0000011111100000,
  0b0000011111100000,
  0b0000001111000000,
  0b0000001111000000,
  0b0000000110000000,
  0b0000000110000000,
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
HighScoresDialog::HighScoresDialog(OSystem& osystem, DialogContainer& parent,
                                   int max_w, int max_h,
                                   AppMode mode)
  : Dialog(osystem, parent, osystem.frameBuffer().font(), "High Scores"),
    _max_w{max_w},
    _max_h{max_h},
    myMode{mode}
{
  myScores.variation = HSM::DEFAULT_VARIATION;

  const GUI::Font& ifont = instance().frameBuffer().infoFont();
  const int infoLineHeight = ifont.getLineHeight();
  const int lineHeight   = Dialog::lineHeight(),
            fontHeight   = Dialog::fontHeight(),
            fontWidth    = Dialog::fontWidth(),
            buttonHeight = Dialog::buttonHeight(),
            BUTTON_GAP   = Dialog::buttonGap(),
            VBORDER      = Dialog::vBorder(),
            HBORDER      = Dialog::hBorder(),
            VGAP         = Dialog::vGap();
  const int xposRank = HBORDER;
  const int xposScore = xposRank + _font.getStringWidth("Rank");
  const int xposSpecial = xposScore + _font.getStringWidth("   Score  ");
  const int xposName = xposSpecial + _font.getStringWidth("Round  ");
  const int xposDate = xposName + _font.getStringWidth("Name  ");
  const int xposDelete = xposDate + _font.getStringWidth("YY-MM-DD HH:MM  ");
  const int nWidth = _font.getStringWidth("ABC") + fontWidth * 0.75;
  const bool smallFont = _font.getFontHeight() < 24;
  const int buttonSize = smallFont ? BUTTON_GFX_H : BUTTON_GFX_H_LARGE;
  WidgetArray wid;
  const VariantList items;

  const int xpos = HBORDER;
  int ypos = VBORDER + _th;
  ypos += lineHeight + VGAP * 2; // space for game name

  auto* s = new StaticTextWidget(this, _font, xpos, ypos + 1, "Variation ");
  myVariationPopup = new PopUpWidget(this, _font, s->getRight(), ypos,
      _font.getStringWidth("256"), lineHeight, items, "", 0, kVariationChanged);
  wid.push_back(myVariationPopup);
  const int bWidth = fontWidth * 5;
  myPrevVarButton = new ButtonWidget(this, _font,
      xposDelete + fontWidth * 2 - bWidth * 2 - BUTTON_GAP, ypos - 1,
      bWidth, myVariationPopup->getHeight(),
      smallFont ? PREV_GFX.data() : PREV_GFX_LARGE.data(),
      buttonSize, buttonSize, kPrevVariation);
  wid.push_back(myPrevVarButton);
  myNextVarButton = new ButtonWidget(this, _font,
      xposDelete + fontHeight - bWidth, ypos - 1,
      bWidth, myVariationPopup->getHeight(),
      smallFont ? NEXT_GFX.data() : NEXT_GFX_LARGE.data(),
      buttonSize, buttonSize, kNextVariation);
  wid.push_back(myNextVarButton);

  ypos += lineHeight + VGAP * 4;

  new StaticTextWidget(this, _font, xposRank, ypos + 1, "Rank");
  new StaticTextWidget(this, _font, xposScore, ypos + 1, "   Score");
  mySpecialLabelWidget = new StaticTextWidget(this, _font, xposSpecial, ypos + 1, "Round");
  new StaticTextWidget(this, _font, xposName - 2, ypos + 1, "Name");
  new StaticTextWidget(this, _font, xposDate+16, ypos + 1, "Date   Time");

  ypos += lineHeight + VGAP;

  for (uInt32 r = 0; r < NUM_RANKS; ++r)
  {
    myRankWidgets[r] = new StaticTextWidget(this, _font, xposRank + 8, ypos + 1,
                                          (r < 9 ? " " : "") + std::to_string(r + 1));
    myScoreWidgets[r] = new StaticTextWidget(this, _font, xposScore, ypos + 1, "12345678");
    mySpecialWidgets[r] = new StaticTextWidget(this, _font, xposSpecial + 8, ypos + 1, "123");
    myNameWidgets[r] = new StaticTextWidget(this, _font, xposName + 2, ypos + 1, "   ");
    myEditNameWidgets[r] = new EditTextWidget(this, _font, xposName, ypos - 1, nWidth, lineHeight);
    myEditNameWidgets[r]->setFlags(EditTextWidget::FLAG_INVISIBLE);
    myEditNameWidgets[r]->setEnabled(false);
    wid.push_back(myEditNameWidgets[r]);
    myDateWidgets[r] = new StaticTextWidget(this, _font, xposDate, ypos + 1, "YY-MM-DD HH:MM");
    myDeleteButtons[r] = new ButtonWidget(this, _font, xposDelete, ypos + 1, fontWidth * 2, fontHeight, "X",
                                          kDeleteSingle);
    myDeleteButtons[r]->setID(r);
    myDeleteButtons[r]->setToolTip("Click to delete this high score.");
    wid.push_back(myDeleteButtons[r]);

    ypos += lineHeight + VGAP;
  }
  ypos += VGAP;

  _w = std::max(myDeleteButtons[0]->getRight() + HBORDER,
                HBORDER * 2 + ifont.getMaxCharWidth() * (5 + 17 + 2 + 7 + 17));
  myNotesWidget = new StaticTextWidget(this, ifont, xpos, ypos + 1, _w - HBORDER * 2,
                                       infoLineHeight, "Note: ");

  ypos += infoLineHeight + VGAP;

  // Note: Only display the first 16 md5 chars + "..."
  myMD5Widget = new StaticTextWidget(this, ifont, xpos, ypos + 1,
                                     "MD5: 1234567890123456.");

  myCheckSumWidget = new StaticTextWidget(this, ifont,
                                          _w - HBORDER - ifont.getStringWidth("Props: 1234567890123456."),
                                          ypos + 1, "Props: 1234567890123456.");

  _h = myMD5Widget->getBottom() + VBORDER + buttonHeight + VBORDER;

  myGameNameWidget = new StaticTextWidget(this, _font, HBORDER, VBORDER + _th + 1,
                                          _w - HBORDER * 2, lineHeight);

  addDefaultsOKCancelBGroup(wid, _font, "Save", "Cancel", " Reset ");
  _defaultWidget->setToolTip("Click to reset all high scores of this variation.");
  addToFocusList(wid);

  _focusedWidget = _okWidget; // start with focus on 'Save' button

  setHelpAnchor("Highscores");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
HighScoresDialog::~HighScoresDialog()  // NOLINT (we need an empty d'tor)
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void HighScoresDialog::loadConfig()
{
  // Enable blending (only once is necessary)
  if (myMode == AppMode::emulator && !surface().attributes().blending)
  {
    surface().attributes().blending = true;
    surface().attributes().blendalpha = 90;
    surface().applyAttributes();
  }

  VariantList items;

  // fill drown down with all variation numbers of current game
  items.clear();
  for (Int32 i = 1; i <= instance().highScores().numVariations(); ++i)
  {
    ostringstream buf;
    buf << std::setw(3) << std::setfill(' ') << i;
    VarList::push_back(items, buf.str(), i);
  }
  myVariationPopup->addItems(items);

  Int32 variation = 0;
  if(instance().highScores().numVariations() == 1)
    variation = HSM::DEFAULT_VARIATION;
  else
    variation = instance().highScores().variation();
  if(variation != HSM::NO_VALUE)
  {
    myVariationPopup->setSelected(variation);
    myUserDefVar = false;
  }
  else
  {
    // use last selected variation
    myVariationPopup->setSelected(myScores.variation);
    myUserDefVar = true;
  }

  myVariationPopup->setEnabled(instance().highScores().numVariations() > 1);

  if(myInitials.empty())
    // load initials from last session
    myInitials = instance().settings().getString("initials");

  string label = "   " + instance().highScores().specialLabel();
  if (label.length() > 5)
    label = label.substr(label.length() - 5);
  mySpecialLabelWidget->setLabel(label);

  if(!instance().highScores().notes().empty())
    myNotesWidget->setLabel("Note: " + instance().highScores().notes());
  else
    myNotesWidget->setLabel("");

  if (instance().hasConsole())
    myScores.md5 = instance().console().properties().get(PropType::Cart_MD5);
  else
    myScores.md5 = instance().launcher().selectedRomMD5();

  myMD5Widget->setLabel("MD5: " + myScores.md5);
  myCheckSumWidget->setLabel("Props: " + instance().highScores().md5Props());

  // requires the current MD5
  myGameNameWidget->setLabel(cartName());

  myEditRank = myHighScoreRank = -1;
  myNow = now();
  myDirty = myHighScoreSaved = false;
  handleVariation(true);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void HighScoresDialog::saveConfig()
{
  // save initials and remember for the next time
  if (myHighScoreRank != -1)
  {
    myInitials = myEditNameWidgets[myHighScoreRank]->getText();
    myScores.scores[myHighScoreRank].name = myInitials;
    // remember initials for next session
    instance().settings().setValue("initials", myInitials);
  }
  // save selected variation
  instance().highScores().saveHighScores(myScores);
  if(myScores.variation == instance().highScores().variation() || myUserDefVar)
    myHighScoreSaved = true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void HighScoresDialog::handleCommand(CommandSender* sender, int cmd, int data, int id)
{
  switch (cmd)
  {
    case kOKCmd:
      saveConfig();
      [[fallthrough]];
    case kCloseCmd:
      if(myMode != AppMode::emulator)
        close();
      else
        instance().eventHandler().leaveMenuMode();
      break;

    case kVariationChanged:
      handleVariation();
      break;
    case kPrevVariation:
      myVariationPopup->setSelected(myScores.variation - 1);
      handleVariation();
      break;

    case kNextVariation:
      myVariationPopup->setSelected(myScores.variation + 1);
      handleVariation();
      break;

    case kDeleteSingle:
      deleteRank(id);
      updateWidgets();
      break;

    case GuiObject::kDefaultsCmd: // "Reset" button
      for (int r = NUM_RANKS - 1; r >= 0; --r)
        deleteRank(r);
      updateWidgets();
      break;

    case kConfirmSave:
      saveConfig();
      [[fallthrough]];
    case kCancelSave:
      myDirty = false;
      handleVariation();
      break;

    default:
      Dialog::handleCommand(sender, cmd, data, 0);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void HighScoresDialog::handleVariation(bool init)
{
  if (handleDirty())
  {
    myScores.variation = myVariationPopup->getSelectedTag().toInt();

    instance().highScores().loadHighScores(myScores);

    myEditRank = -1;

    if (myScores.variation == instance().highScores().variation() || myUserDefVar)
      handlePlayedVariation();

    updateWidgets(init);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void HighScoresDialog::updateWidgets(bool init)
{
  myPrevVarButton->setEnabled(myScores.variation > 1);
  myNextVarButton->setEnabled(myScores.variation < instance().highScores().numVariations());

  for (uInt32 r = 0; r < NUM_RANKS; ++r)
  {
    ostringstream buf;

    if(myScores.scores[r].score > 0)
    {
      myRankWidgets[r]->clearFlags(Widget::FLAG_INVISIBLE);
      myDeleteButtons[r]->clearFlags(Widget::FLAG_INVISIBLE);
      myDeleteButtons[r]->setEnabled(true);
    }
    else
    {
      myRankWidgets[r]->setFlags(Widget::FLAG_INVISIBLE);
      myDeleteButtons[r]->setFlags(Widget::FLAG_INVISIBLE);
      myDeleteButtons[r]->setEnabled(false);
    }
    myScoreWidgets[r]->setLabel(instance().highScores().formattedScore(myScores.scores[r].score,
                                HSM::MAX_SCORE_DIGITS));

    if (myScores.scores[r].special > 0)
      buf << std::setw(HSM::MAX_SPECIAL_DIGITS) << std::setfill(' ')
      << myScores.scores[r].special;
    mySpecialWidgets[r]->setLabel(buf.str());

    myNameWidgets[r]->setLabel(myScores.scores[r].name);
    myDateWidgets[r]->setLabel(myScores.scores[r].date);

    if (static_cast<Int32>(r) == myEditRank)
    {
      myNameWidgets[r]->setFlags(EditTextWidget::FLAG_INVISIBLE);
      myEditNameWidgets[r]->clearFlags(EditTextWidget::FLAG_INVISIBLE);
      myEditNameWidgets[r]->setEnabled(true);
      myEditNameWidgets[r]->setEditable(true);
      if (init)
        myEditNameWidgets[r]->setText(myInitials);
    }
    else
    {
      myNameWidgets[r]->clearFlags(EditTextWidget::FLAG_INVISIBLE);
      myEditNameWidgets[r]->setFlags(EditTextWidget::FLAG_INVISIBLE);
      myEditNameWidgets[r]->setEnabled(false);
      myEditNameWidgets[r]->setEditable(false);
    }
  }
  _defaultWidget->setEnabled(myScores.scores[0].score > 0);
  setDirty();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void HighScoresDialog::handlePlayedVariation()
{
  const Int32 newScore = instance().highScores().score();

  if (!myHighScoreSaved && newScore > 0)
  {
    const Int32 newSpecial = instance().highScores().special();
    const bool scoreInvert = instance().highScores().scoreInvert();

    for (myHighScoreRank = 0; myHighScoreRank < static_cast<Int32>(NUM_RANKS); ++myHighScoreRank)
    {
      const Int32 highScore = myScores.scores[myHighScoreRank].score;

      if ((!scoreInvert && newScore > highScore) ||
          ((scoreInvert && newScore < highScore) ||
          highScore == 0))
        break;
      if (newScore == highScore && newSpecial > myScores.scores[myHighScoreRank].special)
        break;
    }

    if (myHighScoreRank < static_cast<Int32>(NUM_RANKS))
    {
      myEditRank = myHighScoreRank;
      for (uInt32 r = NUM_RANKS - 1; static_cast<Int32>(r) > myHighScoreRank; --r)
      {
        myScores.scores[r].score = myScores.scores[r - 1].score;
        myScores.scores[r].special = myScores.scores[r - 1].special;
        myScores.scores[r].name = myScores.scores[r - 1].name;
        myScores.scores[r].date = myScores.scores[r - 1].date;
      }
      myScores.scores[myHighScoreRank].score = newScore;
      myScores.scores[myHighScoreRank].special = newSpecial;
      myScores.scores[myHighScoreRank].date = myNow;
      myDirty |= !myUserDefVar; // only ask when the variation was read by defintion
    }
    else
      myHighScoreRank = -1;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void HighScoresDialog::deleteRank(int rank)
{
  for (uInt32 r = rank; r < NUM_RANKS - 1; ++r)
  {
    myScores.scores[r].score = myScores.scores[r + 1].score;
    myScores.scores[r].special = myScores.scores[r + 1].special;
    myScores.scores[r].name = myScores.scores[r + 1].name;
    myScores.scores[r].date = myScores.scores[r + 1].date;
  }
  myScores.scores[NUM_RANKS - 1].score = 0;
  myScores.scores[NUM_RANKS - 1].special = 0;
  myScores.scores[NUM_RANKS - 1].name = "";
  myScores.scores[NUM_RANKS - 1].date = "";

  if (myEditRank == rank)
  {
    myHighScoreRank = myEditRank = -1;
  }
  if (myEditRank > rank)
  {
    myHighScoreRank--;
    myEditRank--;
    myEditNameWidgets[myEditRank]->setText(myEditNameWidgets[myEditRank + 1]->getText());
  }
  myDirty = true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool HighScoresDialog::handleDirty()
{
  if (myDirty)
  {
    if (!myConfirmMsg)
    {
      StringList msg;

      msg.emplace_back("Do you want to save the changes");
      msg.emplace_back("for this variation?");
      msg.emplace_back("");
      myConfirmMsg = make_unique<GUI::MessageBox>
        (this, _font, msg, _max_w, _max_h, kConfirmSave, kCancelSave,
         "Yes", "No", "Save High Scores", false);
    }
    myConfirmMsg->show();
    return false;
  }
  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string HighScoresDialog::cartName() const
{
  if(instance().hasConsole())
    return instance().console().properties().get(PropType::Cart_Name);
  else
  {
    Properties props;

    instance().propSet().getMD5(myScores.md5, props);
    if(props.get(PropType::Cart_Name).empty())
      return instance().launcher().currentDir().getNameWithExt("");
    else
      return props.get(PropType::Cart_Name);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string HighScoresDialog::now()
{
  const std::tm now = BSPF::localTime();
  ostringstream ss;

  ss << std::setfill('0') << std::right
    << std::setw(2) << (now.tm_year - 100) << '-'
    << std::setw(2) << (now.tm_mon + 1) << '-'
    << std::setw(2) << now.tm_mday << " "
    << std::setw(2) << now.tm_hour << ":"
    << std::setw(2) << now.tm_min;

  return ss.str();
}
