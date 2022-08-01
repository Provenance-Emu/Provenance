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

#ifndef EVENT_HXX
#define EVENT_HXX

#include <mutex>
#include <set>

#include "bspf.hxx"

/**
  @author  Stephen Anthony, Christian Speckner, Thomas Jentzsch
*/
class Event
{
  public:
    /**
      Enumeration of all possible events in Stella, including both
      console and controller event types as well as events that aren't
      technically part of the emulation core.
    */
    enum Type
    {
      NoType = 0,
      ConsoleColor, ConsoleBlackWhite, ConsoleColorToggle, Console7800Pause,
      ConsoleLeftDiffA, ConsoleLeftDiffB, ConsoleLeftDiffToggle,
      ConsoleRightDiffA, ConsoleRightDiffB, ConsoleRightDiffToggle,
      ConsoleSelect, ConsoleReset,

      LeftJoystickUp, LeftJoystickDown, LeftJoystickLeft, LeftJoystickRight,
      LeftJoystickFire, LeftJoystickFire5, LeftJoystickFire9,
      RightJoystickUp, RightJoystickDown, RightJoystickLeft, RightJoystickRight,
      RightJoystickFire, RightJoystickFire5, RightJoystickFire9,

      LeftPaddleADecrease, LeftPaddleAIncrease, LeftPaddleAAnalog, LeftPaddleAFire,
      LeftPaddleBDecrease, LeftPaddleBIncrease, LeftPaddleBAnalog, LeftPaddleBFire,
      RightPaddleADecrease, RightPaddleAIncrease, RightPaddleAAnalog, RightPaddleAFire,
      RightPaddleBDecrease, RightPaddleBIncrease, RightPaddleBAnalog, RightPaddleBFire,

      LeftKeyboard1, LeftKeyboard2, LeftKeyboard3,
      LeftKeyboard4, LeftKeyboard5, LeftKeyboard6,
      LeftKeyboard7, LeftKeyboard8, LeftKeyboard9,
      LeftKeyboardStar, LeftKeyboard0, LeftKeyboardPound,

      RightKeyboard1, RightKeyboard2, RightKeyboard3,
      RightKeyboard4, RightKeyboard5, RightKeyboard6,
      RightKeyboard7, RightKeyboard8, RightKeyboard9,
      RightKeyboardStar, RightKeyboard0, RightKeyboardPound,

      LeftDrivingCCW, LeftDrivingCW, LeftDrivingFire, LeftDrivingAnalog,
      RightDrivingCCW, RightDrivingCW, RightDrivingFire, RightDrivingAnalog,

      CompuMateFunc, CompuMateShift,
      CompuMate0, CompuMate1, CompuMate2, CompuMate3, CompuMate4,
      CompuMate5, CompuMate6, CompuMate7, CompuMate8, CompuMate9,
      CompuMateA, CompuMateB, CompuMateC, CompuMateD, CompuMateE,
      CompuMateF, CompuMateG, CompuMateH, CompuMateI, CompuMateJ,
      CompuMateK, CompuMateL, CompuMateM, CompuMateN, CompuMateO,
      CompuMateP, CompuMateQ, CompuMateR, CompuMateS, CompuMateT,
      CompuMateU, CompuMateV, CompuMateW, CompuMateX, CompuMateY,
      CompuMateZ,
      CompuMateComma, CompuMatePeriod, CompuMateEnter, CompuMateSpace,
      CompuMateQuestion, CompuMateLeftBracket, CompuMateRightBracket, CompuMateMinus,
      CompuMateQuote, CompuMateBackspace, CompuMateEquals, CompuMatePlus,
      CompuMateSlash,

      Combo1, Combo2, Combo3, Combo4, Combo5, Combo6, Combo7, Combo8,
      Combo9, Combo10, Combo11, Combo12, Combo13, Combo14, Combo15, Combo16,

      UIUp, UIDown, UILeft, UIRight, UIHome, UIEnd, UIPgUp, UIPgDown,
      UISelect, UINavPrev, UINavNext, UIOK, UICancel, UIPrevDir,
      UITabPrev, UITabNext,

      NextMouseControl, ToggleGrabMouse,
      MouseAxisXMove, MouseAxisYMove, MouseAxisXValue, MouseAxisYValue,
      MouseButtonLeftValue, MouseButtonRightValue,

      Quit, ReloadConsole, Fry,
      TogglePauseMode, StartPauseMode,
      OptionsMenuMode, CmdMenuMode, DebuggerMode, PlusRomsSetupMode, ExitMode,
      TakeSnapshot, ToggleContSnapshots, ToggleContSnapshotsFrame,
      ToggleTurbo,

      NextState, PreviousState, LoadState, SaveState,
      SaveAllStates, LoadAllStates,
      ToggleAutoSlot, ToggleTimeMachine, TimeMachineMode,
      Rewind1Menu, Rewind10Menu, RewindAllMenu,
      Unwind1Menu, Unwind10Menu, UnwindAllMenu,
      RewindPause, UnwindPause,

      FormatDecrease, FormatIncrease, PaletteDecrease, PaletteIncrease, ToggleColorLoss,
      PreviousPaletteAttribute, NextPaletteAttribute,
      PaletteAttributeDecrease, PaletteAttributeIncrease,
      ToggleFullScreen, VidmodeDecrease, VidmodeIncrease,
      VCenterDecrease, VCenterIncrease, VSizeAdjustDecrease, VSizeAdjustIncrease,
      OverscanDecrease, OverscanIncrease,

      VidmodeStd, VidmodeRGB, VidmodeSVideo, VidModeComposite, VidModeBad, VidModeCustom,
      PreviousVideoMode, NextVideoMode,
      PreviousAttribute, NextAttribute, DecreaseAttribute, IncreaseAttribute,
      ScanlinesDecrease, ScanlinesIncrease,
      PreviousScanlineMask, NextScanlineMask,
      PhosphorDecrease, PhosphorIncrease, TogglePhosphor, ToggleInter,
      ToggleDeveloperSet, JitterRecDecrease, JitterRecIncrease,
      JitterSenseDecrease, JitterSenseIncrease, ToggleJitter,

      VolumeDecrease, VolumeIncrease, SoundToggle,

      ToggleP0Collision, ToggleP0Bit, ToggleP1Collision, ToggleP1Bit,
      ToggleM0Collision, ToggleM0Bit, ToggleM1Collision, ToggleM1Bit,
      ToggleBLCollision, ToggleBLBit, TogglePFCollision, TogglePFBit,
      ToggleCollisions, ToggleBits, ToggleFixedColors,

      ToggleFrameStats, ToggleSAPortOrder, ExitGame,
      SettingDecrease, SettingIncrease, PreviousSetting, NextSetting,
      ToggleAdaptRefresh, PreviousMultiCartRom,
      // add new (after Version 4) events from here to avoid that user remapped events get overwritten
      PreviousSettingGroup, NextSettingGroup,
      TogglePlayBackMode,
      ToggleAutoFire, DecreaseAutoFire, IncreaseAutoFire,
      DecreaseSpeed, IncreaseSpeed,

      QTJoystickThreeUp, QTJoystickThreeDown, QTJoystickThreeLeft, QTJoystickThreeRight,
      QTJoystickThreeFire,
      QTJoystickFourUp, QTJoystickFourDown, QTJoystickFourLeft, QTJoystickFourRight,
      QTJoystickFourFire,

      ToggleCorrectAspectRatio,

      MoveLeftChar, MoveRightChar, MoveLeftWord, MoveRightWord,
      MoveHome, MoveEnd,
      SelectLeftChar, SelectRightChar, SelectLeftWord, SelectRightWord,
      SelectHome, SelectEnd, SelectAll,
      Delete, DeleteLeftWord, DeleteRightWord, DeleteHome, DeleteEnd, Backspace,
      Cut, Copy, Paste, Undo, Redo,
      AbortEdit, EndEdit,

      HighScoresMenuMode,
      // Input settings
      DecreaseDeadzone, IncreaseDeadzone,
      DecAnalogDeadzone, IncAnalogDeadzone,
      DecAnalogSense, IncAnalogSense,
      DecAnalogLinear, IncAnalogLinear,
      DecDejtterAveraging, IncDejtterAveraging,
      DecDejtterReaction, IncDejtterReaction,
      DecDigitalSense, IncDigitalSense,
      ToggleFourDirections, ToggleKeyCombos,
      PrevMouseAsController, NextMouseAsController,
      DecMousePaddleSense, IncMousePaddleSense,
      DecMouseTrackballSense, IncMouseTrackballSense,
      DecreaseDrivingSense, IncreaseDrivingSense,
      PreviousCursorVisbility, NextCursorVisbility,
      // GameInfoDialog/Controllers
      PreviousLeftPort, NextLeftPort,
      PreviousRightPort, NextRightPort,
      ToggleSwapPorts, ToggleSwapPaddles,
      DecreasePaddleCenterX, IncreasePaddleCenterX,
      DecreasePaddleCenterY, IncreasePaddleCenterY,
      PreviousMouseControl,
      DecreaseMouseAxesRange, IncreaseMouseAxesRange,

      SALeftAxis0Value, SALeftAxis1Value, SARightAxis0Value, SARightAxis1Value,
      QTPaddle3AFire, QTPaddle3BFire, QTPaddle4AFire, QTPaddle4BFire,
      UIHelp,
      LastType
    };

    // Event categorizing groups
    enum Group
    {
      Menu, Emulation,
      Misc, AudioVideo, States, Console, Joystick, Paddles, Driving, Keyboard,
      Devices,
      Debug, Combo,
      LastGroup
    };

    // Event list version, update only if the id of existing(!) event types changed
    static constexpr Int32 VERSION = 6;

    using EventSet = std::set<Event::Type>;

  public:
    /**
      Create a new event object.
    */
    Event() { clear(); }

  public:
    /**
      Get the value associated with the event of the specified type.
    */
    Int32 get(Type type) const {
      std::lock_guard<std::mutex> lock(myMutex);

      return myValues[type];
    }

    /**
      Set the value associated with the event of the specified type.
    */
    void set(Type type, Int32 value) {
      std::lock_guard<std::mutex> lock(myMutex);

      myValues[type] = value;
    }

    /**
      Clears the event array (resets to initial state).
    */
    void clear()
    {
      std::lock_guard<std::mutex> lock(myMutex);

      myValues.fill(Event::NoType);
    }

    /**
      Tests if a given event represents continuous or analog values.
    */
    static bool isAnalog(Type type)
    {
      switch(type)
      {
        case Event::LeftPaddleAAnalog:
        case Event::LeftPaddleBAnalog:
        case Event::RightPaddleAAnalog:
        case Event::RightPaddleBAnalog:
        case Event::LeftDrivingAnalog:
        case Event::RightDrivingAnalog:
          return true;
        default:
          return false;
      }
    }

  private:
    // Array of values associated with each event type
    std::array<Int32, LastType> myValues;

    mutable std::mutex myMutex;

  private:
    // Following constructors and assignment operators not supported
    Event(const Event&) = delete;
    Event(Event&&) = delete;
    Event& operator=(const Event&) = delete;
    Event& operator=(Event&&) = delete;
};

// Hold controller related events
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
static const Event::EventSet LeftJoystickEvents = {
  Event::LeftJoystickUp, Event::LeftJoystickDown, Event::LeftJoystickLeft, Event::LeftJoystickRight,
  Event::LeftJoystickFire, Event::LeftJoystickFire5, Event::LeftJoystickFire9,
};
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
static const Event::EventSet QTJoystick3Events = {
  Event::QTJoystickThreeUp, Event::QTJoystickThreeDown, Event::QTJoystickThreeLeft, Event::QTJoystickThreeRight,
  Event::QTJoystickThreeFire
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
static const Event::EventSet RightJoystickEvents = {
  Event::RightJoystickUp, Event::RightJoystickDown, Event::RightJoystickLeft, Event::RightJoystickRight,
  Event::RightJoystickFire, Event::RightJoystickFire5, Event::RightJoystickFire9,
};
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
static const Event::EventSet QTJoystick4Events = {
  Event::QTJoystickFourUp, Event::QTJoystickFourDown, Event::QTJoystickFourLeft, Event::QTJoystickFourRight,
  Event::QTJoystickFourFire
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
static const Event::EventSet LeftPaddlesEvents = {
  Event::LeftPaddleADecrease, Event::LeftPaddleAIncrease, Event::LeftPaddleAAnalog, Event::LeftPaddleAFire,
  Event::LeftPaddleBDecrease, Event::LeftPaddleBIncrease, Event::LeftPaddleBAnalog, Event::LeftPaddleBFire,
};
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
static const Event::EventSet QTPaddles3Events = {
  // Only fire buttons supported by QuadTari
  Event::QTPaddle3AFire, Event::QTPaddle3BFire
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
static const Event::EventSet RightPaddlesEvents = {
  Event::RightPaddleADecrease, Event::RightPaddleAIncrease, Event::RightPaddleAAnalog, Event::RightPaddleAFire,
  Event::RightPaddleBDecrease, Event::RightPaddleBIncrease, Event::RightPaddleBAnalog, Event::RightPaddleBFire,
};
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
static const Event::EventSet QTPaddles4Events = {
  // Only fire buttons supported by QuadTari
  Event::QTPaddle4AFire, Event::QTPaddle4BFire
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
static const Event::EventSet LeftKeyboardEvents = {
  Event::LeftKeyboard1, Event::LeftKeyboard2, Event::LeftKeyboard3,
  Event::LeftKeyboard4, Event::LeftKeyboard5, Event::LeftKeyboard6,
  Event::LeftKeyboard7, Event::LeftKeyboard8, Event::LeftKeyboard9,
  Event::LeftKeyboardStar, Event::LeftKeyboard0, Event::LeftKeyboardPound,
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
static const Event::EventSet RightKeyboardEvents = {
  Event::RightKeyboard1, Event::RightKeyboard2, Event::RightKeyboard3,
  Event::RightKeyboard4, Event::RightKeyboard5, Event::RightKeyboard6,
  Event::RightKeyboard7, Event::RightKeyboard8, Event::RightKeyboard9,
  Event::RightKeyboardStar, Event::RightKeyboard0, Event::RightKeyboardPound,
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
static const Event::EventSet LeftDrivingEvents = {
  Event::LeftDrivingAnalog, Event::LeftDrivingCCW,
  Event::LeftDrivingCW, Event::LeftDrivingFire,
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
static const Event::EventSet RightDrivingEvents = {
  Event::RightDrivingAnalog, Event::RightDrivingCCW,
  Event::RightDrivingCW, Event::RightDrivingFire,
};

#endif
