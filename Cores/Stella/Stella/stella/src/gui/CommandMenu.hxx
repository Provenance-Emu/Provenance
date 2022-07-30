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

#ifndef COMMAND_MENU_HXX
#define COMMAND_MENU_HXX

class Properties;
class OSystem;

#include "DialogContainer.hxx"

/**
  The base dialog for common commands in Stella.

  @author  Stephen Anthony
*/
class CommandMenu : public DialogContainer
{
  public:
    /**
      Create a new menu stack
    */
    explicit CommandMenu(OSystem& osystem);
    ~CommandMenu() override;

    /**
      Return (and possibly create) the bottom-most dialog of this container.
    */
    Dialog* baseDialog() override;

  private:
    Dialog* myBaseDialog{nullptr};

  private:
    // Following constructors and assignment operators not supported
    CommandMenu() = delete;
    CommandMenu(const CommandMenu&) = delete;
    CommandMenu(CommandMenu&&) = delete;
    CommandMenu& operator=(const CommandMenu&) = delete;
    CommandMenu& operator=(CommandMenu&&) = delete;
};

#endif
