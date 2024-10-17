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

#include "Console.hxx"
#include "Control.hxx"
#include "Paddles.hxx"
#include "Props.hxx"

#include "MouseControl.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
MouseControl::MouseControl(Console& console, string_view mode)
  : myProps{console.properties()},
    myLeftController{console.leftController()},
    myRightController{console.rightController()}
{
  istringstream m_axis(string{mode});  // TODO: fixed in C++20
  string m_mode;
  m_axis >> m_mode;

  if(BSPF::equalsIgnoreCase(m_mode, "none"))
  {
    myModeList.emplace_back("Mouse input is disabled");
    return;
  }
  else if(!BSPF::equalsIgnoreCase(m_mode, "auto") && m_mode.length() == 2 &&
          m_mode[0] >= '0' && m_mode[0] <= '8' &&
          m_mode[1] >= '0' && m_mode[1] <= '8')
  {
    const auto xaxis = static_cast<MouseControl::Type>
        (static_cast<int>(m_mode[0]) - '0');
    const auto yaxis = static_cast<MouseControl::Type>
        (static_cast<int>(m_mode[1]) - '0');
    ostringstream msg;
    Controller::Type xtype = Controller::Type::Joystick, ytype = Controller::Type::Joystick;
    int xid = -1, yid = -1;

    const auto MControlToController = [&msg](MouseControl::Type axis,
                                             Controller::Type& type, int& id) {
      switch(axis)
      {
        case MouseControl::Type::NoControl:
          msg << "not used";
          break;
        case MouseControl::Type::LeftPaddleA:
          type = Controller::Type::Paddles;
          id = 0;
          msg << "Left Paddle A";
          break;
        case MouseControl::Type::LeftPaddleB:
          type = Controller::Type::Paddles;
          id = 1;
          msg << "Left Paddle B";
          break;
        case MouseControl::Type::RightPaddleA:
          type = Controller::Type::Paddles;
          id = 2;
          msg << "Right Paddle A";
          break;
        case MouseControl::Type::RightPaddleB:
          type = Controller::Type::Paddles;
          id = 3;
          msg << "Right Paddle B";
          break;
        case MouseControl::Type::LeftDriving:
          type = Controller::Type::Driving;
          id = 0;
          msg << "Left Driving";
          break;
        case MouseControl::Type::RightDriving:
          type = Controller::Type::Driving;
          id = 1;
          msg << "Right Driving";
          break;
        case MouseControl::Type::LeftMindLink:
          type = Controller::Type::MindLink;
          id = 0;
          msg << "Left MindLink";
          break;
        case MouseControl::Type::RightMindLink:
          type = Controller::Type::MindLink;
          id = 1;
          msg << "Right MindLink";
          break;
      }
    };

    msg << "Mouse X-axis is ";
    MControlToController(xaxis, xtype, xid);
    msg << ", Y-axis is ";
    MControlToController(yaxis, ytype, yid);

    myModeList.emplace_back(xtype, xid, ytype, yid, msg.str());
  }

  // Now consider the possible modes for the mouse based on the left
  // and right controllers
  const bool noswap = BSPF::equalsIgnoreCase(myProps.get(PropType::Console_SwapPorts), "NO");
  if(noswap)
  {
    addLeftControllerModes(noswap);
    addRightControllerModes(noswap);
  }
  else
  {
    addRightControllerModes(noswap);
    addLeftControllerModes(noswap);
  }

  // Set range information (currently only for paddles, but may be used
  // for other controllers in the future)
  int m_range = 100;
  if(!(m_axis >> m_range))
    m_range = 100;
  Paddles::setDigitalPaddleRange(m_range);

  // If the mouse isn't used at all, we still need one item in the list
  if(myModeList.empty())
    myModeList.emplace_back("Mouse not used for current controllers");

#if 0
  for(const auto& m: myModeList)
    cerr << m << '\n';
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const string& MouseControl::change(int direction)
{
  myCurrentModeNum = BSPF::clampw(myCurrentModeNum + direction, 0,
                                  static_cast<int>(myModeList.size() - 1));
  const MouseMode& mode = myModeList[myCurrentModeNum];

  const bool leftControl =
    myLeftController.setMouseControl(mode.xtype, mode.xid, mode.ytype, mode.yid);
  const bool rightControl =
    myRightController.setMouseControl(mode.xtype, mode.xid, mode.ytype, mode.yid);

  myHasMouseControl = leftControl || rightControl;

  return mode.message;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void MouseControl::addLeftControllerModes(bool noswap)
{
  if(controllerSupportsMouse(myLeftController))
  {
    if(myLeftController.type() == Controller::Type::Paddles)
    {
      if(noswap)  addPaddleModes(0, 1, 0, 1);
      else        addPaddleModes(2, 3, 0, 1);
    }
    else
    {
      ostringstream msg;
      msg << "Mouse is left " << myLeftController.name() << " controller";
      const Controller::Type type = myLeftController.type();
      const int id = noswap ? 0 : 1;
      myModeList.emplace_back(type, id, type, id, msg.str());
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void MouseControl::addRightControllerModes(bool noswap)
{
  if(controllerSupportsMouse(myRightController))
  {
    if(myRightController.type() == Controller::Type::Paddles)
    {
      if(noswap)  addPaddleModes(2, 3, 2, 3);
      else        addPaddleModes(0, 1, 2, 3);
    }
    else
    {
      ostringstream msg;
      msg << "Mouse is right " << myRightController.name() << " controller";
      const Controller::Type type = myRightController.type();
      const int id = noswap ? 1 : 0;
      myModeList.emplace_back(type, id, type, id, msg.str());
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void MouseControl::addPaddleModes(int lport, int rport, int lname, int rname)
{
  const Controller::Type type = Controller::Type::Paddles;
  ostringstream msg;
  msg << "Mouse is Paddle " << lname << " controller";
  const MouseMode mode0(type, lport, type, lport, msg.str());

  msg.str("");
  msg << "Mouse is Paddle " << rname << " controller";
  const MouseMode mode1(type, rport, type, rport, msg.str());

  if(BSPF::equalsIgnoreCase(myProps.get(PropType::Controller_SwapPaddles), "NO"))
  {
    myModeList.push_back(mode0);
    myModeList.push_back(mode1);
  }
  else
  {
    myModeList.push_back(mode1);
    myModeList.push_back(mode0);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool MouseControl::controllerSupportsMouse(Controller& controller)
{
  // Test whether the controller uses the mouse at all
  // We can pass in dummy values here, since the controllers will be
  // initialized by a call to next() once the system is up and running
  return controller.setMouseControl(
      Controller::Type::Joystick, -1, Controller::Type::Joystick, -1);
}
