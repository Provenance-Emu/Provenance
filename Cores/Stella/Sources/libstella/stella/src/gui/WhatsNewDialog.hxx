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

#ifndef WHATSNEW_DIALOG_HXX
#define WHATSNEW_DIALOG_HXX

#include "Dialog.hxx"

class WhatsNewDialog : public Dialog
{
  public:
    WhatsNewDialog(OSystem& osystem, DialogContainer& parent,
                   int max_w, int max_h);
    ~WhatsNewDialog() override = default;

  private:
    void add(int& ypos, string_view text);

  private:
    // Following constructors and assignment operators not supported
    WhatsNewDialog(const WhatsNewDialog&) = delete;
    WhatsNewDialog(WhatsNewDialog&&) = delete;
    WhatsNewDialog& operator=(const WhatsNewDialog&) = delete;
    WhatsNewDialog& operator=(WhatsNewDialog&&) = delete;
};

#endif
