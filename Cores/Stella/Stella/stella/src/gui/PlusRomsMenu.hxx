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

#ifndef PLUSROMS_MENU_HXX
#define PLUSROMS_MENU_HXX

class OSystem;
class PlusRomsSetupDialog;

#include "DialogContainer.hxx"

/**
  The dialog container for PlusROMs setup.

  @author  Thomas Jentzsch
*/
class PlusRomsMenu : public DialogContainer
{
  public:
    /**
      Create a new menu stack
    */
    explicit PlusRomsMenu(OSystem& osystem);
    ~PlusRomsMenu() override;

  private:
    /**
      Return (and possibly create) the bottom-most dialog of this container.
    */
    Dialog* baseDialog() override;

    PlusRomsSetupDialog& plusRomsSetupDialog();

  private:
    PlusRomsSetupDialog* myPlusRomsSetupDialog{nullptr};

  private:
    // Following constructors and assignment operators not supported
    PlusRomsMenu() = delete;
    PlusRomsMenu(const PlusRomsMenu&) = delete;
    PlusRomsMenu(PlusRomsMenu&&) = delete;
    PlusRomsMenu& operator=(const PlusRomsMenu&) = delete;
    PlusRomsMenu& operator=(PlusRomsMenu&&) = delete;
};

#endif
