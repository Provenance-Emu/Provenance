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

#include "Dialog.hxx"
#include "Font.hxx"
#include "EventHandler.hxx"
#include "FrameBuffer.hxx"
#include "FBSurface.hxx"
#include "OSystem.hxx"
#include "Widget.hxx"
#include "StateManager.hxx"
#include "RewindManager.hxx"
#include "TimeLineWidget.hxx"
#include "TIASurface.hxx"

#include "Console.hxx"
#include "TIA.hxx"
#include "System.hxx"

#include "TimeMachineDialog.hxx"
#include "Base.hxx"

static constexpr int BUTTON_W = 14, BUTTON_H = 14;

static constexpr std::array<uInt32, BUTTON_H> RECORD = {
  0b00000111100000,
  0b00011111111000,
  0b00111111111100,
  0b01111111111110,
  0b01111111111110,
  0b11111111111111,
  0b11111111111111,
  0b11111111111111,
  0b11111111111111,
  0b01111111111110,
  0b01111111111110,
  0b00111111111100,
  0b00011111111000,
  0b00000111100000
};
static constexpr std::array<uInt32, BUTTON_H> STOP = {
  0b11111111111111,
  0b11111111111111,
  0b11111111111111,
  0b11111111111111,
  0b11111111111111,
  0b11111111111111,
  0b11111111111111,
  0b11111111111111,
  0b11111111111111,
  0b11111111111111,
  0b11111111111111,
  0b11111111111111,
  0b11111111111111,
  0b11111111111111
};
static constexpr std::array<uInt32, BUTTON_H> EXIT = {
  0b01100000000110,
  0b11110000001111,
  0b11111000011111,
  0b01111100111110,
  0b00111111111100,
  0b00011111111000,
  0b00001111110000,
  0b00001111110000,
  0b00011111111000,
  0b00111111111100,
  0b01111100111110,
  0b11111000011111,
  0b11110000001111,
  0b01100000000110
};

static constexpr std::array<uInt32, BUTTON_H> REWIND_ALL = {
  0,
  0b11000011000011,
  0b11000111000111,
  0b11001111001111,
  0b11011111011111,
  0b11111111111111,
  0b11111111111111,
  0b11111111111111,
  0b11111111111111,
  0b11011111011111,
  0b11001111001111,
  0b11000111000111,
  0b11000011000011,
  0
};
static constexpr std::array<uInt32, BUTTON_H> REWIND_1 = {
  0,
  0b00000110001110,
  0b00001110001110,
  0b00011110001110,
  0b00111110001110,
  0b01111110001110,
  0b11111110001110,
  0b11111110001110,
  0b01111110001110,
  0b00111110001110,
  0b00011110001110,
  0b00001110001110,
  0b00000110001110,
  0
};
static constexpr std::array<uInt32, BUTTON_H> PLAYBACK = {
  0b11000000000000,
  0b11110000000000,
  0b11111100000000,
  0b11111111000000,
  0b11111111110000,
  0b11111111111100,
  0b11111111111111,
  0b11111111111111,
  0b11111111111100,
  0b11111111110000,
  0b11111111000000,
  0b11111100000000,
  0b11110000000000,
  0b11000000000000
};
static constexpr std::array<uInt32, BUTTON_H> UNWIND_1 = {
  0,
  0b01110001100000,
  0b01110001110000,
  0b01110001111000,
  0b01110001111100,
  0b01110001111110,
  0b01110001111111,
  0b01110001111111,
  0b01110001111110,
  0b01110001111100,
  0b01110001111000,
  0b01110001110000,
  0b01110001100000,
  0
};
static constexpr std::array<uInt32, BUTTON_H> UNWIND_ALL = {
  0,
  0b11000011000011,
  0b11100011100011,
  0b11110011110011,
  0b11111011111011,
  0b11111111111111,
  0b11111111111111,
  0b11111111111111,
  0b11111111111111,
  0b11111011111011,
  0b11110011110011,
  0b11100011100011,
  0b11000011000011,
  0
};
static constexpr std::array<uInt32, BUTTON_H> SAVE_ALL = {
  0b00000111100000,
  0b00000111100000,
  0b00000111100000,
  0b00000111100000,
  0b11111111111111,
  0b01111111111110,
  0b00111111111100,
  0b00011111111000,
  0b00001111110000,
  0b00000111100000,
  0b00000011000000,
  0b00000000000000,
  0b11111111111111,
  0b11111111111111,
};
static constexpr std::array<uInt32, BUTTON_H> LOAD_ALL = {
  0b00000011000000,
  0b00000111100000,
  0b00001111110000,
  0b00011111111000,
  0b00111111111100,
  0b01111111111110,
  0b11111111111111,
  0b00000111100000,
  0b00000111100000,
  0b00000111100000,
  0b00000111100000,
  0b00000000000000,
  0b11111111111111,
  0b11111111111111,
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
TimeMachineDialog::TimeMachineDialog(OSystem& osystem, DialogContainer& parent,
                                     int width)
  : Dialog(osystem, parent)
{
  const GUI::Font& font = instance().frameBuffer().font();
  constexpr int H_BORDER = 6, BUTTON_GAP = 4, V_BORDER = 4;
  constexpr int buttonWidth = BUTTON_W + 10, buttonHeight = BUTTON_H + 10;
  const int rowHeight = font.getLineHeight();

  // Set real dimensions
  _w = width;  // Parent determines our width (based on window size)
  _h = V_BORDER * 2 + rowHeight + std::max(buttonHeight + 2, rowHeight);

  this->clearFlags(Widget::FLAG_CLEARBG); // does only work combined with blending (0..100)!
  this->clearFlags(Widget::FLAG_BORDER);
  this->setFlags(Widget::FLAG_NOBG);

  int xpos = H_BORDER, ypos = V_BORDER;

  // Add index info
  myCurrentIdxWidget = new StaticTextWidget(this, font, xpos, ypos, "1000", TextAlign::Left, kBGColor);
  myCurrentIdxWidget->setTextColor(kColorInfo);
  myCurrentIdxWidget->setFlags(Widget::FLAG_CLEARBG | Widget::FLAG_NOBG);
  myLastIdxWidget = new StaticTextWidget(this, font, _w - H_BORDER - font.getStringWidth("1000"), ypos,
                                         "1000", TextAlign::Right, kBGColor);
  myLastIdxWidget->setFlags(Widget::FLAG_CLEARBG | Widget::FLAG_NOBG);
  myLastIdxWidget->setTextColor(kColorInfo);

  // Add timeline
  const uInt32 tl_h = myCurrentIdxWidget->getHeight() / 2 + 6,
    tl_x = xpos + myCurrentIdxWidget->getWidth() + 8,
    tl_y = ypos + (myCurrentIdxWidget->getHeight() - tl_h) / 2 - 1,
    tl_w = myLastIdxWidget->getAbsX() - tl_x - 8;
  myTimeline = new TimeLineWidget(this, font, tl_x, tl_y, tl_w, tl_h, "", 0, kTimeline);
  myTimeline->setMinValue(0);
  ypos += rowHeight;

  // Add time info
  const int ypos_s = ypos + (buttonHeight - font.getFontHeight() + 1) / 2; // align to button vertical center
  myCurrentTimeWidget = new StaticTextWidget(this, font, xpos, ypos_s, "00:00.00", TextAlign::Left, kBGColor);
  myCurrentTimeWidget->setFlags(Widget::FLAG_CLEARBG | Widget::FLAG_NOBG);
  myCurrentTimeWidget->setTextColor(kColorInfo);
  myLastTimeWidget = new StaticTextWidget(this, font, _w - H_BORDER - font.getStringWidth("00:00.00"), ypos_s,
                                          "00:00.00", TextAlign::Right, kBGColor);
  myLastTimeWidget->setFlags(Widget::FLAG_CLEARBG | Widget::FLAG_NOBG);
  myLastTimeWidget->setTextColor(kColorInfo);
  xpos = myCurrentTimeWidget->getRight() + BUTTON_GAP * 4;

  // Add buttons
  myToggleWidget = new ButtonWidget(this, font, xpos, ypos, buttonWidth, buttonHeight,
                                    STOP.data(), BUTTON_W, BUTTON_H, kToggle);
  myToggleWidget->setToolTip("Toggle Time Machine mode.");
  xpos += buttonWidth + BUTTON_GAP;

  myExitWidget = new ButtonWidget(this, font, xpos, ypos, buttonWidth, buttonHeight,
                                  EXIT.data(), BUTTON_W, BUTTON_H, kExit);
  myExitWidget->setToolTip("Exit Time Machine dialog.");
  xpos += buttonWidth + BUTTON_GAP * 4;

  myRewindAllWidget = new ButtonWidget(this, font, xpos, ypos, buttonWidth, buttonHeight,
                                       REWIND_ALL.data(), BUTTON_W, BUTTON_H, kRewindAll);
  xpos += buttonWidth + BUTTON_GAP;

  myRewind1Widget = new ButtonWidget(this, font, xpos, ypos, buttonWidth, buttonHeight,
                                     REWIND_1.data(), BUTTON_W, BUTTON_H, kRewind1, true);
  xpos += buttonWidth + BUTTON_GAP;

  myPlayBackWidget = new ButtonWidget(this, font, xpos, ypos, buttonWidth, buttonHeight,
                                      PLAYBACK.data(), BUTTON_W, BUTTON_H, kPlayBack);
  myPlayBackWidget->setToolTip("Start playback of Time Machine states.");
  xpos += buttonWidth + BUTTON_GAP;

  myUnwind1Widget = new ButtonWidget(this, font, xpos, ypos, buttonWidth, buttonHeight,
                                     UNWIND_1.data(), BUTTON_W, BUTTON_H, kUnwind1, true);
  xpos += buttonWidth + BUTTON_GAP;

  myUnwindAllWidget = new ButtonWidget(this, font, xpos, ypos, buttonWidth, buttonHeight,
                                       UNWIND_ALL.data(), BUTTON_W, BUTTON_H, kUnwindAll);
  xpos = myUnwindAllWidget->getRight() + BUTTON_GAP * 4;

  mySaveAllWidget = new ButtonWidget(this, font, xpos, ypos, buttonWidth, buttonHeight,
                                     SAVE_ALL.data(), BUTTON_W, BUTTON_H, kSaveAll);
  mySaveAllWidget->setToolTip("Save all Time Machine states.");
  xpos = mySaveAllWidget->getRight() + BUTTON_GAP;

  myLoadAllWidget = new ButtonWidget(this, font, xpos, ypos, buttonWidth, buttonHeight,
                                     LOAD_ALL.data(), BUTTON_W, BUTTON_H, kLoadAll);
  myLoadAllWidget->setToolTip("Load all Time Machine states.");
  xpos = myLoadAllWidget->getRight() + BUTTON_GAP * 4;

  // Add message
  const int mWidth = (myLastTimeWidget->getLeft() - xpos) / font.getMaxCharWidth();
  const string blanks = "                                             ";

  myMessageWidget = new StaticTextWidget(this, font, xpos, ypos_s,
                                         blanks.substr(0, mWidth),
                                         TextAlign::Left, kBGColor);
  myMessageWidget->setFlags(Widget::FLAG_CLEARBG | Widget::FLAG_NOBG);
  myMessageWidget->setTextColor(kColorInfo);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TimeMachineDialog::setPosition()
{
  // Place on the bottom of the screen, centered horizontally
  const Common::Size& screen = instance().frameBuffer().screenSize();
  const Common::Rect& dst = surface().dstRect();
  surface().setDstPos((screen.w - dst.w()) >> 1, screen.h - dst.h() - 10);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TimeMachineDialog::loadConfig()
{
  // Enable blending (only once is necessary)
  if(!surface().attributes().blending)
  {
    surface().attributes().blending = true;
    surface().attributes().blendalpha = 92;
    surface().applyAttributes();
  }

  initBar();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TimeMachineDialog::handleKeyDown(StellaKey key, StellaMod mod, bool repeated)
{
  // The following shortcuts duplicate the shortcuts in EventHandler
  const Event::Type event = instance().eventHandler().eventForKey(EventMode::kEmulationMode, key, mod);

  switch(event)
  {
    case Event::ExitMode:
      handleCommand(nullptr, kExit, 0, 0);
      break;

    case Event::Rewind1Menu:
      handleCommand(nullptr, kRewind1, 0, 0);
      break;

    case Event::Rewind10Menu:
      handleCommand(nullptr, kRewind10, 0, 0);
      break;

    case Event::RewindAllMenu:
      handleCommand(nullptr, kRewindAll, 0, 0);
      break;

    case Event::Unwind1Menu:
      handleCommand(nullptr, kUnwind1, 0, 0);
      break;

    case Event::Unwind10Menu:
      handleCommand(nullptr, kUnwind10, 0, 0);
      break;

    case Event::UnwindAllMenu:
      handleCommand(nullptr, kUnwindAll, 0, 0);
      break;

    case Event::LoadAllStates:
      if(!repeated)
        handleCommand(nullptr, kLoadAll, 0, 0);
      break;

    case Event::SaveAllStates:
      if(!repeated)
        handleCommand(nullptr, kSaveAll, 0, 0);
      break;

    // Hotkey only commands (no button available)
    case Event::SaveState:
    case Event::PreviousState:
    case Event::NextState:
    case Event::LoadState:
    case Event::TakeSnapshot:
      if(!repeated)
        handleCommand(nullptr, event, 0, 0);
      break;

    default:
      Dialog::handleKeyDown(key, mod, repeated);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TimeMachineDialog::handleKeyUp(StellaKey key, StellaMod mod)
{
  // The following shortcuts duplicate the shortcuts in EventHandler
  // Note: mode switches must happen in key UP

  const Event::Type event = instance().eventHandler().eventForKey(EventMode::kEmulationMode, key, mod);

  if(event == Event::TogglePlayBackMode || key == KBDK_SPACE)
    handleCommand(nullptr, kPlayBack, 0, 0);
  else
    Dialog::handleKeyUp(key, mod);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TimeMachineDialog::handleCommand(CommandSender* sender, int cmd,
                                      int data, int id)
{
  switch(cmd)
  {
    case kTimeline:
    {
      const Int32 winds = myTimeline->getValue() -
          instance().state().rewindManager().getCurrentIdx() + 1;
      handleWinds(winds);
      break;
    }

    case kToggle:
      instance().toggleTimeMachine();
      handleToggle();
      break;

    case kExit:
      instance().eventHandler().leaveMenuMode();
      break;

    case kRewind1:
      handleWinds(-1);
      break;

    case kRewind10:
      handleWinds(-10);
      break;

    case kRewindAll:
      handleWinds(-1000);
      break;

    case kPlayBack:
      instance().eventHandler().enterPlayBackMode();
      break;

    case kUnwind1:
      handleWinds(1);
      break;

    case kUnwind10:
      handleWinds(10);
      break;

    case kUnwindAll:
      handleWinds(1000);
      break;

    case kSaveAll:
      instance().eventHandler().handleEvent(Event::SaveAllStates);
      break;

    case kLoadAll:
      instance().eventHandler().handleEvent(Event::LoadAllStates);
      initBar();
      break;

    // Hotkey only commands (no button available)
    case Event::SaveState:
    case Event::PreviousState:
    case Event::NextState:
    case Event::LoadState:
      instance().eventHandler().handleEvent(static_cast<Event::Type>(cmd));
      break;

    case Event::TakeSnapshot:
      instance().eventHandler().handleEvent(Event::TakeSnapshot);
      instance().frameBuffer().setPendingRender();
      break;

    default:
      Dialog::handleCommand(sender, cmd, data, 0);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TimeMachineDialog::initBar()
{
  const RewindManager& r = instance().state().rewindManager();
  const IntArray cycles = r.cyclesList();

  // Set range and intervals for timeline
  const uInt32 maxValue = cycles.size() > 1 ? static_cast<uInt32>(cycles.size() - 1) : 0;
  myTimeline->setMaxValue(maxValue);
  myTimeline->setStepValues(cycles);

  myMessageWidget->setLabel("");
  handleWinds(_enterWinds);
  _enterWinds = 0;

  handleToggle();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string TimeMachineDialog::getTimeString(uInt64 cycles) const
{
  const size_t scanlines =
      std::max<size_t>(instance().console().tia().scanlinesLastFrame(), 240);
  const bool isNTSC = scanlines <= 287;
  constexpr size_t NTSC_FREQ = 1193182; // ~76*262*60
  constexpr size_t PAL_FREQ  = 1182298; // ~76*312*50
  const size_t freq = isNTSC ? NTSC_FREQ : PAL_FREQ; // = cycles/second

  const auto minutes = static_cast<uInt32>(cycles / (freq * 60));
  cycles -= minutes * (freq * 60);
  const auto seconds = static_cast<uInt32>(cycles / freq);
  cycles -= seconds * freq;
  const auto frames  = static_cast<uInt32>(cycles / (scanlines * 76));

  stringstream time;
  time << Common::Base::toString(minutes, Common::Base::Fmt::_10_02) << ":";
  time << Common::Base::toString(seconds, Common::Base::Fmt::_10_02) << ".";
  time << Common::Base::toString(frames, Common::Base::Fmt::_10_02);

  return time.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TimeMachineDialog::handleWinds(Int32 numWinds)
{
  RewindManager& r = instance().state().rewindManager();

  if(numWinds)
  {
    const uInt64 startCycles = r.getCurrentCycles();
    if(numWinds < 0)      r.rewindStates(-numWinds);
    else if(numWinds > 0) r.unwindStates(numWinds);

    const uInt64 elapsed = instance().console().tia().cycles() - startCycles;
    if(elapsed > 0)
    {
      const string message = r.getUnitString(elapsed);

      // TODO: add message text from addState()
      myMessageWidget->setLabel((numWinds < 0 ? "(-" : "(+") + message + ")");
    }
  }

  // Update time
  myCurrentTimeWidget->setLabel(getTimeString(r.getCurrentCycles() - r.getFirstCycles()));
  myLastTimeWidget->setLabel(getTimeString(r.getLastCycles() - r.getFirstCycles()));
  myTimeline->setValue(r.getCurrentIdx()-1);
  // Update index
  myCurrentIdxWidget->setValue(r.getCurrentIdx());
  myLastIdxWidget->setValue(r.getLastIdx());
  // Enable/disable buttons
  myRewindAllWidget->setEnabled(!r.atFirst());
  myRewind1Widget->setEnabled(!r.atFirst());
  myPlayBackWidget->setEnabled(!r.atLast());
  myUnwindAllWidget->setEnabled(!r.atLast());
  myUnwind1Widget->setEnabled(!r.atLast());
  mySaveAllWidget->setEnabled(r.getLastIdx() != 0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void TimeMachineDialog::handleToggle()
{
  myToggleWidget->setBitmap(instance().state().mode() == StateManager::Mode::Off ?
    RECORD.data() : STOP.data(), BUTTON_W, BUTTON_H);
}
