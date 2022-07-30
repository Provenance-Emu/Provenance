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

#ifndef COMPUMATE_HXX
#define COMPUMATE_HXX

class Console;
class Event;
class System;

#include "bspf.hxx"
#include "Control.hxx"

/**
  Handler for SpectraVideo CompuMate bankswitched games.

  The specifics of the CompuMate format can be found in both the Cart side
  (CartCM) and the Controller side (CMControl).  The CompuMate device is
  unique for the 2600 in that it requires close co-operation between the
  cartridge and the left and right controllers.

  This class acts as a 'parent' for cartridge and both the left and right
  CMControl's, taking care of their creation and communication between them.
  It also allows to enable/disable the users actual keyboard when required.

  @author  Stephen Anthony
*/
class CompuMate
{
  public:
    /**
      Create a new CompuMate handler for both left and right ports.
      Note that this class creates CMControl controllers for both ports,
      but does not take responsibility for their deletion.

      @param console  The console that owns the controller
      @param event    The event object to use for events
      @param system   The system using this controller
    */
    CompuMate(const Console& console, const Event& event, const System& system);

    /**
      Return the left and right CompuMate controllers
    */
    unique_ptr<Controller>& leftController()  { return myLeftController;  }
    unique_ptr<Controller>& rightController() { return myRightController; }


    /** Needed for communication with CartCM class */
    uInt8& column() { return myColumn; }

  private:
    /**
      Called by the controller(s) when all pins have been written
      This method keeps track of consecutive calls, and only updates once
    */
    void update();

    // The actual CompuMate controller
    // More information about these scheme can be found in CartCM.hxx
    class CMControl : public Controller
    {
      public:
        /**
          Create a new CMControl controller plugged into the specified jack

          @param handler  Class which coordinates between left & right controllers
          @param jack     The jack the controller is plugged into
          @param event    The event object to use for events
          @param system   The system using this controller
        */
        CMControl(class CompuMate& handler, Controller::Jack jack, const Event& event,
                  const System& system)
          : Controller(jack, event, system, Controller::Type::CompuMate),
            myHandler{handler} { }
        ~CMControl() override = default;

      public:
        /**
          Called after *all* digital pins have been written on Port A.
          Only update on the left controller; the right controller will
          happen at the same cycle and is redundant.
        */
        void controlWrite(uInt8) override {
          if(myJack == Controller::Jack::Left) myHandler.update();
        }

        /**
          Update the entire digital and analog pin state according to the
          events currently set.
        */
        void update() override { }

        /**
          Returns the name of this controller.
        */
        string name() const override { return "CompuMate"; }

      private:
        class CompuMate& myHandler;

        // Following constructors and assignment operators not supported
        CMControl() = delete;
        CMControl(const CMControl&) = delete;
        CMControl(CMControl&&) = delete;
        CMControl& operator=(const CMControl&) = delete;
        CMControl& operator=(CMControl&&) = delete;
    };

  private:
    // Console and Event objects
    const Console& myConsole;
    const Event& myEvent;

    // Left and right controllers
    unique_ptr<Controller> myLeftController, myRightController;

    // Column currently active
    uInt8 myColumn{0};

  private:
    // Following constructors and assignment operators not supported
    CompuMate() = delete;
    CompuMate(const CompuMate&) = delete;
    CompuMate(CompuMate&&) = delete;
    CompuMate& operator=(const CompuMate&) = delete;
    CompuMate& operator=(CompuMate&&) = delete;
};

#endif
