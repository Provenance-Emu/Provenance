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

#ifndef DEV_SETTINGS_HANDLER_HXX
#define DEV_SETTINGS_HANDLER_HXX

class OSystem;

#include <array>

/**
  This class takes care of developer settings sets.

  @author  Thomas Jentzsch
*/
class DevSettingsHandler
{
  public:
    enum SettingsSet {
      player,
      developer,
      numSets
    };

    explicit DevSettingsHandler(OSystem& osystem);

    void loadSettings(SettingsSet set);
    void saveSettings(SettingsSet set);
    void applySettings(SettingsSet set);

  protected:
    OSystem& myOSystem;
    // Emulator sets
    std::array<bool, numSets>   myFrameStats;
    std::array<bool, numSets>   myDetectedInfo;
    std::array<bool, numSets>   myExternAccess;
    std::array<int, numSets>    myConsole;
    std::array<bool, numSets>   myRandomBank;
    std::array<bool, numSets>   myRandomizeTIA;
    std::array<bool, numSets>   myRandomizeRAM;
    std::array<string, numSets> myRandomizeCPU;
    std::array<bool, numSets>   myColorLoss;
    std::array<bool, numSets>   myTVJitter;
    std::array<int, numSets>    myTVJitterSense;
    std::array<int, numSets>    myTVJitterRec;
    std::array<bool, numSets>   myDebugColors;
    std::array<bool, numSets>   myUndrivenPins;
  #ifdef DEBUGGER_SUPPORT
    std::array<bool, numSets>   myRWPortBreak;
    std::array<bool, numSets>   myWRPortBreak;
  #endif
    std::array<bool, numSets>   myThumbException;
    // TIA sets
    std::array<string, numSets> myTIAType;
    std::array<bool, numSets>   myPlInvPhase;
    std::array<bool, numSets>   myMsInvPhase;
    std::array<bool, numSets>   myBlInvPhase;
    std::array<bool, numSets>   myPFBits;
    std::array<bool, numSets>   myPFColor;
    std::array<bool, numSets>   myPFScore;
    std::array<bool, numSets>   myBKColor;
    std::array<bool, numSets>   myPlSwap;
    std::array<bool, numSets>   myBlSwap;
    // States sets
    std::array<bool, numSets>   myTimeMachine;
    std::array<int, numSets>    myStateSize;
    std::array<int, numSets>    myUncompressed;
    std::array<string, numSets> myStateInterval;
    std::array<string, numSets> myStateHorizon;

  private:
    void handleEnableDebugColors(bool enable);

    // Following constructors and assignment operators not supported
    DevSettingsHandler() = delete;
    DevSettingsHandler(const DevSettingsHandler&) = delete;
    DevSettingsHandler(DevSettingsHandler&&) = delete;
    DevSettingsHandler& operator=(const DevSettingsHandler&) = delete;
    DevSettingsHandler& operator=(DevSettingsHandler&&) = delete;
};

#endif
