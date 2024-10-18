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

#ifndef MOUSE_CONTROL_HXX
#define MOUSE_CONTROL_HXX

class Console;
class Controller;
class Properties;

#include "bspf.hxx"

/**
  The mouse can control various virtual 'controllers' in many different
  ways.  In 'auto' mode, the entire mouse (both axes and buttons) are used
  as one controller.  In per-ROM axis mode, each axis/button may control
  separate controllers.  As well, we'd like to switch dynamically between
  each of these modes at runtime.

  This class encapsulates all required info to implement this functionality.

  @author  Stephen Anthony
*/
class MouseControl
{
  public:
    /**
      Enumeration of mouse axis control types
    */
    enum class Type
    {
      LeftPaddleA = 0, LeftPaddleB, RightPaddleA, RightPaddleB,
      LeftDriving, RightDriving, LeftMindLink, RightMindLink,
      NoControl
    };

  public:
    /**
      Create a new MouseControl object

      @param console The console in use by the system
      @param mode    Contains information about how to use the mouse axes/buttons
    */
    MouseControl(Console& console, string_view mode);

    /**
      Cycle through each available mouse control mode

      @return  A message explaining the current mouse mode
    */
    const string& change(int direction = +1);

    /**
      Get whether any current controller supports mouse control
    */
    bool hasMouseControl() const { return myHasMouseControl; }

  private:
    void addLeftControllerModes(bool noswap);
    void addRightControllerModes(bool noswap);
    void addPaddleModes(int lport, int rport, int lname, int rname);
    static bool controllerSupportsMouse(Controller& controller);

  private:
    const Properties& myProps;
    Controller& myLeftController;
    Controller& myRightController;

    struct MouseMode {
      Controller::Type xtype{Controller::Type::Joystick}, ytype{Controller::Type::Joystick};
      int xid{-1}, yid{-1};
      string message;

      explicit MouseMode(string_view msg = "") : message{msg} { }
      MouseMode(Controller::Type xt, int xi,
                Controller::Type yt, int yi,
                string_view msg)
        : xtype{xt}, ytype{yt}, xid{xi}, yid{yi}, message{msg}  { }

      friend ostream& operator<<(ostream& os, const MouseMode& mm)
      {
        os << "xtype=" << static_cast<int>(mm.xtype) << ", xid=" << mm.xid
           << ", ytype=" << static_cast<int>(mm.ytype) << ", yid=" << mm.yid
           << ", msg=" << mm.message;
        return os;
      }
    };

    int myCurrentModeNum{0};
    vector<MouseMode> myModeList;
    bool myHasMouseControl{false};

  private:
    // Following constructors and assignment operators not supported
    MouseControl() = delete;
    MouseControl(const MouseControl&) = delete;
    MouseControl(MouseControl&&) = delete;
    MouseControl& operator=(const MouseControl&) = delete;
    MouseControl& operator=(MouseControl&&) = delete;
};

#endif
