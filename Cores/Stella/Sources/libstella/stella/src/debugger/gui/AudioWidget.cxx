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

#include "DataGridWidget.hxx"
#include "GuiObject.hxx"
#include "Font.hxx"
#include "OSystem.hxx"
#include "Debugger.hxx"
#include "TIADebug.hxx"
#include "Widget.hxx"
#include "Base.hxx"

#include "AudioWidget.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
AudioWidget::AudioWidget(GuiObject* boss, const GUI::Font& lfont,
                         const GUI::Font& nfont,
                         int x, int y, int w, int h)
  : Widget(boss, lfont, x, y, w, h),
    CommandSender(boss)
{
  const int fontWidth  = lfont.getMaxCharWidth(),
            fontHeight = lfont.getFontHeight(),
            lineHeight = lfont.getLineHeight();
  int xpos = 10, ypos = 25, lwidth = lfont.getStringWidth("AUDW ");

  // AudF registers
  new StaticTextWidget(boss, lfont, xpos, ypos+2,
                       lwidth, fontHeight,
                       "AUDF", TextAlign::Left);
  xpos += lwidth;
  myAudF = new DataGridWidget(boss, nfont, xpos, ypos,
                              2, 1, 2, 5, Common::Base::Fmt::_16);
  myAudF->setTarget(this);
  myAudF->setID(kAUDFID);
  addFocusWidget(myAudF);
  myAud0F = new StaticTextWidget(boss, lfont,
    myAudF->getRight() + fontWidth, ypos + (lineHeight + 5)/ 2 + 2, "         ");
  new StaticTextWidget(boss, lfont,
    myAud0F->getRight(), ypos + (lineHeight + 5)/ 2 + 2, "/");
  myAud1F = new StaticTextWidget(boss, lfont,
    myAud0F->getRight() + fontWidth, ypos + (lineHeight + 5)/ 2 + 2, "         ");

  for(int col = 0; col < 2; ++col)
  {
    new StaticTextWidget(boss, lfont, xpos + col * myAudF->colWidth() +
                         static_cast<int>(myAudF->colWidth() / 2.75),
                         ypos - lineHeight, fontWidth, fontHeight,
                         Common::Base::toString(col, Common::Base::Fmt::_16_1),
                         TextAlign::Left);
  }
  // AudC registers
  xpos = 10;  ypos += lineHeight + 5;
  new StaticTextWidget(boss, lfont, xpos, ypos+2, lwidth, fontHeight,
                       "AUDC", TextAlign::Left);
  xpos += lwidth;
  myAudC = new DataGridWidget(boss, nfont, xpos + static_cast<int>(myAudF->colWidth() / 2.75), ypos,
                              2, 1, 1, 4, Common::Base::Fmt::_16_1);
  myAudC->setTarget(this);
  myAudC->setID(kAUDCID);
  addFocusWidget(myAudC);

  // AudV registers
  xpos = 10;  ypos += lineHeight + 5;
  new StaticTextWidget(boss, lfont, xpos, ypos+2, lwidth, fontHeight,
                       "AUDV", TextAlign::Left);
  xpos += lwidth;
  myAudV = new DataGridWidget(boss, nfont, xpos + static_cast<int>(myAudF->colWidth() / 2.75), ypos,
                              2, 1, 1, 4, Common::Base::Fmt::_16_1);
  myAudV->setTarget(this);
  myAudV->setID(kAUDVID);
  addFocusWidget(myAudV);

  myAudEffV = new StaticTextWidget(boss, lfont,
                                   myAudV->getRight() + fontWidth * 2, myAudV->getTop() + 2,
                                   "100% (eff. volume)");

  setHelpAnchor("AudioTab", true);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AudioWidget::loadConfig()
{
  IntArray alist;
  IntArray vlist;
  BoolArray changed;

  const Debugger& dbg = instance().debugger();
  TIADebug& tia = dbg.tiaDebug();
  const auto& state    = static_cast<const TiaState&>(tia.getState());
  const auto& oldstate = static_cast<const TiaState&>(tia.getOldState());

  // AUDF0/1
  alist.clear();  vlist.clear();  changed.clear();
  for(uInt32 i = 0; i < 2; ++i)
  {
    alist.push_back(i);
    vlist.push_back(state.aud[i]);
    changed.push_back(state.aud[i] != oldstate.aud[i]);
  }
  myAudF->setList(alist, vlist, changed);

  // AUDC0/1
  alist.clear();  vlist.clear();  changed.clear();
  for(uInt32 i = 2; i < 4; ++i)
  {
    alist.push_back(i-2);
    vlist.push_back(state.aud[i]);
    changed.push_back(state.aud[i] != oldstate.aud[i]);
  }
  myAudC->setList(alist, vlist, changed);

  // AUDV0/1
  alist.clear();  vlist.clear();  changed.clear();
  for(uInt32 i = 4; i < 6; ++i)
  {
    alist.push_back(i-4);
    vlist.push_back(state.aud[i]);
    changed.push_back(state.aud[i] != oldstate.aud[i]);
  }
  myAudV->setList(alist, vlist, changed);

  handleFrequencies();
  handleVolume();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AudioWidget::handleFrequencies()
{
  myAud0F->setLabel(instance().debugger().tiaDebug().audFreq0());
  myAud1F->setLabel(instance().debugger().tiaDebug().audFreq1());
}


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AudioWidget::handleVolume()
{
  stringstream s;

  s << getEffectiveVolume() << "% (eff. volume)";
  myAudEffV->setLabel(s.str());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AudioWidget::handleCommand(CommandSender* sender, int cmd, int data, int id)
{
  if(cmd == DataGridWidget::kItemDataChangedCmd)
  {
    switch(id)
    {
      case kAUDFID:
        changeFrequencyRegs();
        break;

      case kAUDCID:
        changeControlRegs();
        break;

      case kAUDVID:
        changeVolumeRegs();
        break;

      default:
        cerr << "AudioWidget DG changed\n";
        break;
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AudioWidget::changeFrequencyRegs()
{
  const int addr = myAudF->getSelectedAddr();
  const int value = myAudF->getSelectedValue();

  switch(addr)
  {
    case kAud0Addr:
      instance().debugger().tiaDebug().audF0(value);
      break;

    case kAud1Addr:
      instance().debugger().tiaDebug().audF1(value);
      break;

    default:
      break;
  }
  handleFrequencies();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AudioWidget::changeControlRegs()
{
  const int addr = myAudC->getSelectedAddr();
  const int value = myAudC->getSelectedValue();

  switch(addr)
  {
    case kAud0Addr:
      instance().debugger().tiaDebug().audC0(value);
      break;

    case kAud1Addr:
      instance().debugger().tiaDebug().audC1(value);
      break;

    default:
      break;
  }
  handleFrequencies();
  handleVolume();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AudioWidget::changeVolumeRegs()
{
  const int addr = myAudV->getSelectedAddr();
  const int value = myAudV->getSelectedValue();

  switch(addr)
  {
    case kAud0Addr:
      instance().debugger().tiaDebug().audV0(value);
      break;

    case kAud1Addr:
      instance().debugger().tiaDebug().audV1(value);
      break;

    default:
      break;
  }
  handleVolume();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 AudioWidget::getEffectiveVolume()
{
  static constexpr std::array<int, 31> EFF_VOL = {
     0,  6, 13, 18, 24, 29, 33, 38,
    42, 46, 50, 54, 57, 60, 64, 67,
    70, 72, 75, 78, 80, 82, 85, 87,
    89, 91, 93, 95, 97, 98, 100
  };

  return EFF_VOL[(instance().debugger().tiaDebug().audC0() ? instance().debugger().tiaDebug().audV0() : 0) +
    (instance().debugger().tiaDebug().audC1() ? instance().debugger().tiaDebug().audV1() : 0)];
}
