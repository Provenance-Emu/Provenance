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

#ifndef TOOL_TIP_HXX
#define TOOL_TIP_HXX

/**
 * Class for providing tooltip functionality
 *
 * @author Thomas Jentzsch
 */

class OSystem;
class Dialog;
class Widget;
class FBSurface;

#include "Rect.hxx"

class ToolTip
{
  public:
    static constexpr uInt32 MAX_COLUMNS = 60;

  private:
    static constexpr uInt32 MAX_ROWS = 5;

  public:
    // Maximum tooltip length
    static constexpr uInt32 MAX_LEN = MAX_COLUMNS * MAX_ROWS;

    ToolTip(Dialog& dialog, const GUI::Font& font);
    ~ToolTip();

    void setFont(const GUI::Font& font);

    /**
      Request a tooltip display.
    */
    void request();

    /**
      Hide a displayed tooltip and reset the timer.
    */
    void hide();

    /**
      Hide a displayed tooltip and reset the timer slowly.
      This allows faster tip display of the next tip.
    */
    void release(bool emptyTip);

    /**
      Update focused widget and current mouse position.
    */
    void update(const Widget* widget, const Common::Point& pos);

    /*
      Render the tooltip
    */
    void render();

  private:
    /**
      Allocate surface if required and return it
    */
    const shared_ptr<FBSurface>& surface();

    void show(string_view tip);

  private:
    static constexpr uInt32 DELAY_TIME = 45;   // display delay [frames]
    // Tips are slower released than requested, so that repeated tips are shown
    //  faster. This constant defines how much faster.
    static constexpr uInt32 RELEASE_SPEED = 2;

    Dialog& myDialog;
    const GUI::Font* myFont{nullptr};
    const Widget* myTipWidget{nullptr};
    const Widget* myFocusWidget{nullptr};

    uInt32 myTimer{0};
    Common::Point myMousePos;
    Common::Point myTipPos;
    uInt32 myWidth{0};
    uInt32 myHeight{0};
    uInt32 myTextXOfs{0};
    uInt32 myTextYOfs{0};
    bool myTipShown{false};
    uInt32 myScale{1};
    shared_ptr<FBSurface> mySurface;

  private:
    // Following constructors and assignment operators not supported
    ToolTip(const ToolTip&) = delete;
    ToolTip(ToolTip&&) = delete;
    ToolTip& operator=(const ToolTip&) = delete;
    ToolTip& operator=(ToolTip&&) = delete;
};

#endif
