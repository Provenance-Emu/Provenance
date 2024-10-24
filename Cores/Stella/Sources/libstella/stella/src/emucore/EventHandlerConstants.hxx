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

#ifndef EVENTHANDLER_CONSTANTS_HXX
#define EVENTHANDLER_CONSTANTS_HXX

// Enumeration representing the different states of operation
enum class EventHandlerState {
  EMULATION,
  TIMEMACHINE,
  PLAYBACK,
  PAUSE,
  LAUNCHER,
  OPTIONSMENU,
  CMDMENU,
  HIGHSCORESMENU,
  MESSAGEMENU,
  PLUSROMSMENU,
  DEBUGGER,
  NONE
};

enum class MouseButton {
  LEFT,
  RIGHT,
  MIDDLE,
  WHEELDOWN,
  WHEELUP,
  NONE
};

static constexpr int JOY_CTRL_NONE = -1;

enum class JoyAxis {
  X = 0,    // make sure these are set correctly,
  Y = 1,    // since they'll be used as array indices
  Z = 2,
  A3 = 3,
  NONE = JOY_CTRL_NONE
};

enum class JoyDir {
  NEG = -1,
  POS = 1,
  NONE = 0,
  ANALOG = 2
};

enum class JoyHatDir {
  UP     = 0,  // make sure these are set correctly,
  DOWN   = 1,  // since they'll be used as array indices
  LEFT   = 2,
  RIGHT  = 3,
  CENTER = 4
};

enum JoyHatMask {
  EVENT_HATUP_M     = 1<<0,
  EVENT_HATDOWN_M   = 1<<1,
  EVENT_HATLEFT_M   = 1<<2,
  EVENT_HATRIGHT_M  = 1<<3,
  EVENT_HATCENTER_M = 1<<4
};

enum class EventMode {
  kEmulationMode, // active mapping used for emulation
  kMenuMode,      // mapping used for dialogs
  kJoystickMode,  // 5 extra modes for mapping controller keys separately for emulation mode
  kPaddlesMode,
  kKeyboardMode,
  kDrivingMode,
  kCompuMateMode, // cannot be remapped
  kCommonMode,    // mapping common between controllers
  kEditMode,      // mapping used in editable widgets
  kPromptMode,    // extra mappings used in debugger's prompt widget
  kNumModes
};

namespace GUI
{
#ifdef RETRON77
  static const string SELECT = "Mode";
  static const string LEFT_DIFFICULTY = "P1 skill";
  static const string RIGHT_DIFFICULTY = "P2 skill";
  static const string LEFT_DIFF = "P1 Skill";
  static const string RIGHT_DIFF = "P2 Skill";
#else
  static const string SELECT = "Select";
  static const string LEFT_DIFFICULTY = "Left difficulty";
  static const string RIGHT_DIFFICULTY = "Right difficulty";
  static const string LEFT_DIFF = "Left Diff";
  static const string RIGHT_DIFF = "Right Diff";
#endif
}

#endif // EVENTHANDLER_CONSTANTS_HXX
