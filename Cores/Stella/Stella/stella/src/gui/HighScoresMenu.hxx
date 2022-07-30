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

#ifndef HIGHSCORES_MENU_HXX
#define HIGHSCORES_MENU_HXX

class OSystem;
class HighScoresDialog;

#include "DialogContainer.hxx"

/**
  The base menu for the high scores dialog in Stella.

  @author  Thomas Jentzsch
*/
class HighScoresMenu : public DialogContainer
{
  public:
    /**
      Create a new menu stack
    */
    explicit HighScoresMenu(OSystem& osystem);
    ~HighScoresMenu() override;

  private:
    Dialog* baseDialog() override;
    HighScoresDialog* myHighScoresDialog{nullptr};

  private:
    // Following constructors and assignment operators not supported
    HighScoresMenu() = delete;
    HighScoresMenu(const HighScoresMenu&) = delete;
    HighScoresMenu(HighScoresMenu&&) = delete;
    HighScoresMenu& operator=(const HighScoresMenu&) = delete;
    HighScoresMenu& operator=(HighScoresMenu&&) = delete;
};
#endif
