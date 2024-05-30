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

#ifndef MESSAGE_MENU_HXX
#define MESSAGE_MENU_HXX

class OSystem;
class MessageDialog;

#include "DialogContainer.hxx"

/**
  The base dialog for all message menus in Stella.

  @author  Thomas Jentzsch
*/
class MessageMenu : public DialogContainer
{
  public:
    /**
      Create a new menu stack
    */
    explicit MessageMenu(OSystem& osystem);
    ~MessageMenu() override;

    static void setMessage(string_view title, string_view text,
                           bool yesNo = false);
    static void setMessage(string_view title, const StringList& text,
                           bool yesNo = false);
    bool confirmed();

  private:
    Dialog* baseDialog() override;
    MessageDialog* myMessageDialog{nullptr};

  private:
    // Following constructors and assignment operators not supported
    MessageMenu() = delete;
    MessageMenu(const MessageMenu&) = delete;
    MessageMenu(MessageMenu&&) = delete;
    MessageMenu& operator=(const MessageMenu&) = delete;
    MessageMenu& operator=(MessageMenu&&) = delete;
};

#endif
