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
// Copyright (c) 1995-2022 by Bradford W. Mott, Stephen Anthony
// and the Stella Team
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

#include "OSystem.hxx"
#include "FrameBuffer.hxx"
#include "Version.hxx"

#include "WhatsNewDialog.hxx"

static constexpr int MAX_CHARS = 64; // maximum number of chars per line

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
WhatsNewDialog::WhatsNewDialog(OSystem& osystem, DialogContainer& parent,
                               int max_w, int max_h)
#if defined(RETRON77)
  : Dialog(osystem, parent, osystem.frameBuffer().font(),
           "What's New in Stella " + string(STELLA_VERSION) + " for RetroN 77?")
#else
  : Dialog(osystem, parent, osystem.frameBuffer().font(),
           "What's New in Stella " + string(STELLA_VERSION) + "?")
#endif
{
  const int fontWidth = Dialog::fontWidth(),
    buttonHeight = Dialog::buttonHeight(),
    VBORDER = Dialog::vBorder(),
    HBORDER = Dialog::hBorder(),
    VGAP = Dialog::vGap();
  int ypos = _th + VBORDER;

  // Set preliminary dimensions
  setSize(MAX_CHARS * fontWidth + HBORDER * 2, max_h,
          max_w, max_h);

  const string& version = instance().settings().getString("stella.version");
#ifdef RETRON77
  add(ypos, "extensively redesigned and enhanced file launcher");
  add(ypos, "improved controller mappings for Paddles");
  add(ypos, "improved controller mappings for Driving controllers");
  add(ypos, "enhanced support for CDFJ+ bankswitching type");
  add(ypos, "added MovieCart support");
  add(ypos, "added keeping multiple dump files when dumping to SD");
  add(ypos, "removed deadzone from USB game controllers");
  add(ypos, "added opt-out for overclocking to the settings file");
#else
  if(version < "6.6")
  {
    add(ypos, "added tooltips to many UI items");
    add(ypos, "added sound to Time Machine playback");
    add(ypos, "moved settings, properties etc. to an SQLite database");
    add(ypos, "added context-sensitive help");
    add(ypos, "added PlusROMs support for saving high scores");
    add(ypos, "added MovieCart support");
    add(ypos, "added weblinks for many games");
  }
  add(ypos, "extensively redesigned and enhanced file launcher");
  add(ypos, "added automatic emulation pause when focus is lost");
  add(ypos, "added option to toggle autofire mode");
  add(ypos, "improved controller mappings for Paddles and Driving controllers");
  add(ypos, "added another oddball TIA glitch option for score mode color");
  add(ypos, "enhanced support for CDFJ+ bankswitching type");
  add(ypos, ELLIPSIS + " (for a complete list see 'docs/Changes.txt')");
#endif

  // Set needed dimensions
  ypos += VGAP * 2 + buttonHeight + VBORDER;
  assert(ypos <= int(FBMinimum::Height)); // minimal launcher height
  setSize(MAX_CHARS * fontWidth + HBORDER * 2, ypos, max_w, max_h);

  WidgetArray wid;
  addOKBGroup(wid, _font);
  addBGroupToFocusList(wid);

  // We don't have a close/cancel button, but we still want the cancel
  // event to be processed
  processCancelWithoutWidget();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void WhatsNewDialog::add(int& ypos, const string& text)
{
  const int lineHeight = Dialog::lineHeight(),
            fontHeight = Dialog::fontHeight(),
            HBORDER    = Dialog::hBorder();
  const string DOT = "\x1f";
  string txt = DOT + " " + text;

  // automatically wrap too long texts
  while(txt.length() > MAX_CHARS)
  {
    int i = MAX_CHARS;

    while(--i && txt[i] != ' ');
    new StaticTextWidget(this, _font, HBORDER, ypos, txt.substr(0, i));
    txt = " " + txt.substr(i);
    ypos += fontHeight;
  }
  new StaticTextWidget(this, _font, HBORDER, ypos, txt);
  ypos += lineHeight;
}
