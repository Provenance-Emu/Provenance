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

#include "Console.hxx"
#include "EventHandler.hxx"
#include "M6502.hxx"
#include "OSystem.hxx"
#include "RewindManager.hxx"
#include "Settings.hxx"
#include "StateManager.hxx"
#include "TIA.hxx"

#include "DevSettingsHandler.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
DevSettingsHandler::DevSettingsHandler(OSystem& osystem)
  : myOSystem{osystem}
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DevSettingsHandler::loadSettings(SettingsSet set)
{
  const bool devSettings = set == SettingsSet::developer;
  const string& prefix = devSettings ? "dev." : "plr.";
  const Settings& settings = myOSystem.settings();

  myFrameStats[set] = settings.getBool(prefix + "stats");
  myDetectedInfo[set] = settings.getBool(prefix + "detectedinfo");
  myConsole[set] = settings.getString(prefix + "console") == "7800" ? 1 : 0;
  // Randomization
  myRandomBank[set] = settings.getBool(prefix + "bankrandom");
  myRandomizeTIA[set] = settings.getBool(prefix + "tiarandom");
  myRandomizeRAM[set] = settings.getBool(prefix + "ramrandom");
  myRandomizeCPU[set] = settings.getString(prefix + "cpurandom");
  // Undriven TIA pins
  myUndrivenPins[set] = devSettings ? settings.getBool("dev.tiadriven") : false;
#ifdef DEBUGGER_SUPPORT
  // Read from write ports break
  myRWPortBreak[set] = devSettings ? settings.getBool("dev.rwportbreak") : false;
  // Write to read ports break
  myWRPortBreak[set] = devSettings ? settings.getBool("dev.wrportbreak") : false;
#endif
  // Thumb ARM emulation exception
  myThumbException[set] = devSettings ? settings.getBool("dev.thumb.trapfatal") : false;
  // AtariVox/SaveKey/PlusROM access
  myExternAccess[set] = settings.getBool(prefix + "extaccess");

  // TIA tab
  myTIAType[set] = devSettings ? settings.getString("dev.tia.type") : "standard";
  myPlInvPhase[set] = devSettings ? settings.getBool("dev.tia.plinvphase") : false;
  myMsInvPhase[set] = devSettings ? settings.getBool("dev.tia.msinvphase") : false;
  myBlInvPhase[set] = devSettings ? settings.getBool("dev.tia.blinvphase") : false;
  myPFBits[set] = devSettings ? settings.getBool("dev.tia.delaypfbits") : false;
  myPFColor[set] = devSettings ? settings.getBool("dev.tia.delaypfcolor") : false;
  myPFScore[set] = devSettings ? settings.getBool("dev.tia.pfscoreglitch") : false;
  myBKColor[set] = devSettings ? settings.getBool("dev.tia.delaybkcolor") : false;
  myPlSwap[set] = devSettings ? settings.getBool("dev.tia.delayplswap") : false;
  myBlSwap[set] = devSettings ? settings.getBool("dev.tia.delayblswap") : false;

  // Debug colors
  myDebugColors[set] = settings.getBool(prefix + "debugcolors");
  // PAL color-loss effect
  myColorLoss[set] = settings.getBool(prefix + "colorloss");
  // Jitter
  myTVJitter[set] = settings.getBool(prefix + "tv.jitter");
  myTVJitterSense[set] = settings.getInt(prefix + "tv.jitter_sense");
  myTVJitterRec[set] = settings.getInt(prefix + "tv.jitter_recovery");

  // States
  myTimeMachine[set] = settings.getBool(prefix + "timemachine");
  myStateSize[set] = settings.getInt(prefix + "tm.size");
  myUncompressed[set] = settings.getInt(prefix + "tm.uncompressed");
  myStateInterval[set] = settings.getString(prefix + "tm.interval");
  myStateHorizon[set] = settings.getString(prefix + "tm.horizon");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DevSettingsHandler::saveSettings(SettingsSet set)
{
  const bool devSettings = set == SettingsSet::developer;
  const string& prefix = devSettings ? "dev." : "plr.";
  Settings& settings = myOSystem.settings();

  settings.setValue(prefix + "stats", myFrameStats[set]);
  settings.setValue(prefix + "detectedinfo", myDetectedInfo[set]);
  settings.setValue(prefix + "console", myConsole[set] == 1 ? "7800" : "2600");
  if(myOSystem.hasConsole())
    myOSystem.eventHandler().set7800Mode();

  // Randomization
  settings.setValue(prefix + "bankrandom", myRandomBank[set]);
  settings.setValue(prefix + "tiarandom", myRandomizeTIA[set]);
  settings.setValue(prefix + "ramrandom", myRandomizeRAM[set]);
  settings.setValue(prefix + "cpurandom", myRandomizeCPU[set]);

  if(devSettings)
  {
    // Undriven TIA pins
    settings.setValue("dev.tiadriven", myUndrivenPins[set]);
  #ifdef DEBUGGER_SUPPORT
    // Read from write ports break
    settings.setValue("dev.rwportbreak", myRWPortBreak[set]);
    // Write to read ports break
    settings.setValue("dev.wrportbreak", myWRPortBreak[set]);
  #endif
    // Thumb ARM emulation exception
    settings.setValue("dev.thumb.trapfatal", myThumbException[set]);
  }

  // AtariVox/SaveKey/PlusROM access
  settings.setValue(prefix + "extaccess", myExternAccess[set]);

  // TIA tab
  if(devSettings)
  {
    settings.setValue("dev.tia.type", myTIAType[set]);
    if(BSPF::equalsIgnoreCase("custom", myTIAType[set]))
    {
      settings.setValue("dev.tia.plinvphase", myPlInvPhase[set]);
      settings.setValue("dev.tia.msinvphase", myMsInvPhase[set]);
      settings.setValue("dev.tia.blinvphase", myBlInvPhase[set]);
      settings.setValue("dev.tia.delaypfbits", myPFBits[set]);
      settings.setValue("dev.tia.delaypfcolor", myPFColor[set]);
      settings.setValue("dev.tia.pfscoreglitch", myPFScore[set]);
      settings.setValue("dev.tia.delaybkcolor", myBKColor[set]);
      settings.setValue("dev.tia.delayplswap", myPlSwap[set]);
      settings.setValue("dev.tia.delayblswap", myBlSwap[set]);
    }
  }

  // Debug colors
  settings.setValue(prefix + "debugcolors", myDebugColors[set]);
  // PAL color loss
  settings.setValue(prefix + "colorloss", myColorLoss[set]);
  // Jitter
  settings.setValue(prefix + "tv.jitter", myTVJitter[set]);
  settings.setValue(prefix + "tv.jitter_sense", myTVJitterSense[set]);
  settings.setValue(prefix + "tv.jitter_recovery", myTVJitterRec[set]);

  // States
  settings.setValue(prefix + "timemachine", myTimeMachine[set]);
  settings.setValue(prefix + "tm.size", myStateSize[set]);
  settings.setValue(prefix + "tm.uncompressed", myUncompressed[set]);
  settings.setValue(prefix + "tm.interval", myStateInterval[set]);
  settings.setValue(prefix + "tm.horizon", myStateHorizon[set]);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DevSettingsHandler::applySettings(SettingsSet set)
{
  // *** Emulation tab ***
  myOSystem.frameBuffer().showFrameStats(myFrameStats[set]);

  if(myOSystem.hasConsole())
  {
    myOSystem.console().tia().driveUnusedPinsRandom(myUndrivenPins[set]);
    // Notes:
    // - thumb exceptions not updated, because set in cart constructor
    // - other missing settings are used on-the-fly
  }

#ifdef DEBUGGER_SUPPORT
  // Read from write ports and write to read ports breaks
  if(myOSystem.hasConsole())
  {
    myOSystem.console().system().m6502().setReadFromWritePortBreak(myRWPortBreak[set]);
    myOSystem.console().system().m6502().setWriteToReadPortBreak(myWRPortBreak[set]);
  }
#endif

  // *** TIA tab ***
  if(myOSystem.hasConsole())
  {
    myOSystem.console().tia().setPlInvertedPhaseClock(myPlInvPhase[set]);
    myOSystem.console().tia().setMsInvertedPhaseClock(myMsInvPhase[set]);
    myOSystem.console().tia().setBlInvertedPhaseClock(myBlInvPhase[set]);
    myOSystem.console().tia().setPFBitsDelay(myPFBits[set]);
    myOSystem.console().tia().setPFColorDelay(myPFColor[set]);
    myOSystem.console().tia().setPFScoreGlitch(myPFScore[set]);
    myOSystem.console().tia().setBKColorDelay(myBKColor[set]);
    myOSystem.console().tia().setPlSwapDelay(myPlSwap[set]);
    myOSystem.console().tia().setBlSwapDelay(myBlSwap[set]);
  }

  // *** Video tab ***
  if(myOSystem.hasConsole())
  {
    // TV Jitter
    myOSystem.console().tia().toggleJitter(myTVJitter[set] ? 1 : 0);
    myOSystem.console().tia().setJitterSensitivity(myTVJitterSense[set]);
    myOSystem.console().tia().setJitterRecoveryFactor(myTVJitterRec[set]);
    // PAL color loss
    myOSystem.console().enableColorLoss(myColorLoss[set]);
  }

  // Debug colours
  handleEnableDebugColors(myDebugColors[set]);

  // *** Time Machine tab ***
  // update RewindManager
  myOSystem.state().rewindManager().setup();
  myOSystem.state().setRewindMode(myTimeMachine[set] ?
    StateManager::Mode::TimeMachine : StateManager::Mode::Off);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void DevSettingsHandler::handleEnableDebugColors(bool enable)
{
  if(myOSystem.hasConsole())
  {
    const bool fixed = myOSystem.console().tia().usingFixedColors();
    if(fixed != enable)
      myOSystem.console().tia().toggleFixedColors();
  }
}
