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

#include "OSystem.hxx"
#include "Settings.hxx"
#include "Console.hxx"
#include "Cart.hxx"
#include "Switches.hxx"
#include "RewindManager.hxx"

#include "StateManager.hxx"

// #define MOVIE_HEADER "03030000movie"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
StateManager::StateManager(OSystem& osystem)
  : myOSystem{osystem}
{
  myRewindManager = make_unique<RewindManager>(myOSystem, *this);
  reset();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
StateManager::~StateManager()  // NOLINT (we need an empty d'tor)
{
}

#if 0
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StateManager::toggleRecordMode()
{
  if(myActiveMode != kMovieRecordMode)  // Turn on movie record mode
  {
    myActiveMode = kOffMode;

    string moviefile = /*myOSystem.baseDir() +*/ "test.inp";
    if(myMovieWriter.isOpen())
      myMovieWriter.close();
    if(!myMovieWriter.open(moviefile))
      return false;

    // Prepend the ROM md5 so this state file only works with that ROM
    myMovieWriter.putString(myOSystem.console().properties().get(Cartridge_MD5));

    if(!myOSystem.console().save(myMovieWriter))
      return false;

    // Save controller types for this ROM
    // We need to check this, since some controllers save more state than
    // normal, and those states files wouldn't be compatible with normal
    // controllers.
    myMovieWriter.putString(
      myOSystem.console().controller(Controller::Jack::Left).name());
    myMovieWriter.putString(
      myOSystem.console().controller(Controller::Jack::Right).name());

    // If we get this far, we're really in movie record mode
    myActiveMode = kMovieRecordMode;
  }
  else  // Turn off movie record mode
  {
    myActiveMode = kOffMode;
    myMovieWriter.close();
    return false;
  }

  return myActiveMode == kMovieRecordMode;
////////////////////////////////////////////////////////
// FIXME - For now, I'm going to use this to activate movie playback
  // Close the writer, since we're about to re-open in read mode
  myMovieWriter.close();

  if(myActiveMode != kMoviePlaybackMode)  // Turn on movie playback mode
  {
    myActiveMode = kOffMode;

    string moviefile = /*myOSystem.baseDir() + */ "test.inp";
    if(myMovieReader.isOpen())
      myMovieReader.close();
    if(!myMovieReader.open(moviefile))
      return false;

    // Check the ROM md5
    if(myMovieReader.getString() !=
       myOSystem.console().properties().get(Cartridge_MD5))
      return false;

    if(!myOSystem.console().load(myMovieReader))
      return false;

    // Check controller types
    const string& left  = myMovieReader.getString();
    const string& right = myMovieReader.getString();

    if(left != myOSystem.console().controller(Controller::Jack::Left).name() ||
       right != myOSystem.console().controller(Controller::Jack::Right).name())
      return false;

    // If we get this far, we're really in movie record mode
    myActiveMode = kMoviePlaybackMode;
  }
  else  // Turn off movie playback mode
  {
    myActiveMode = kOffMode;
    myMovieReader.close();
    return false;
  }
}
#endif

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StateManager::toggleTimeMachine()
{
  const bool devSettings = myOSystem.settings().getBool("dev.settings");

  myActiveMode = myActiveMode == Mode::TimeMachine ? Mode::Off : Mode::TimeMachine;
  if(myActiveMode == Mode::TimeMachine)
    myOSystem.frameBuffer().showTextMessage("Time Machine enabled");
  else
    myOSystem.frameBuffer().showTextMessage("Time Machine disabled");
  myOSystem.settings().setValue(devSettings ? "dev.timemachine" : "plr.timemachine", myActiveMode == Mode::TimeMachine);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool StateManager::addExtraState(string_view message)
{
  if(myActiveMode == Mode::TimeMachine)
  {
    RewindManager& r = myOSystem.state().rewindManager();
    return r.addState(message);
  }
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool StateManager::rewindStates(uInt32 numStates)
{
  RewindManager& r = myOSystem.state().rewindManager();
  return r.rewindStates(numStates);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool StateManager::unwindStates(uInt32 numStates)
{
  RewindManager& r = myOSystem.state().rewindManager();
  return r.unwindStates(numStates);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool StateManager::windStates(uInt32 numStates, bool unwind)
{
  RewindManager& r = myOSystem.state().rewindManager();
  return r.windStates(numStates, unwind);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StateManager::update()
{
  switch(myActiveMode)
  {
    case Mode::TimeMachine:
      myRewindManager->addState("Time Machine", true);
      break;

#if 0
    case Mode::MovieRecord:
      myOSystem.console().controller(Controller::Jack::Left).save(myMovieWriter);
      myOSystem.console().controller(Controller::Jack::Right).save(myMovieWriter);
      myOSystem.console().switches().save(myMovieWriter);
      break;

    case Mode::MoviePlayback:
      myOSystem.console().controller(Controller::Jack::Left).load(myMovieReader);
      myOSystem.console().controller(Controller::Jack::Right).load(myMovieReader);
      myOSystem.console().switches().load(myMovieReader);
      break;
#endif
    default:
      break;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StateManager::loadState(int slot)
{
  if(myOSystem.hasConsole())
  {
    if(slot < 0) slot = myCurrentSlot;

    ostringstream buf;
    buf << myOSystem.stateDir()
        << myOSystem.console().properties().get(PropType::Cart_Name)
        << ".st" << slot;

    // Make sure the file can be opened in read-only mode
    Serializer in(buf.str(), Serializer::Mode::ReadOnly);
    if(!in)
    {
      buf.str("");
      buf << "Can't open/load from state file " << slot;
      myOSystem.frameBuffer().showTextMessage(buf.str());
      return;
    }

    // First test if we have a valid header
    // If so, do a complete state load using the Console
    buf.str("");
    try
    {
      if(in.getString() != STATE_HEADER)
        buf << "Incompatible state " << slot << " file";
      else
      {
        if(myOSystem.console().load(in))
          buf << "State " << slot << " loaded";
        else
          buf << "Invalid data in state " << slot << " file";
      }
    }
    catch(...)
    {
      buf << "Invalid data in state " << slot << " file";
    }

    myOSystem.frameBuffer().showTextMessage(buf.str());
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StateManager::saveState(int slot)
{
  if(myOSystem.hasConsole())
  {
    if(slot < 0) slot = myCurrentSlot;

    ostringstream buf;
    buf << myOSystem.stateDir()
        << myOSystem.console().properties().get(PropType::Cart_Name)
        << ".st" << slot;

    // Make sure the file can be opened for writing
    Serializer out(buf.str(), Serializer::Mode::ReadWriteTrunc);
    if(!out)
    {
      buf.str("");
      buf << "Can't open/save to state file " << slot;
      myOSystem.frameBuffer().showTextMessage(buf.str());
      return;
    }

    try
    {
      // Add header so that if the state format changes in the future,
      // we'll know right away, without having to parse the rest of the file
      out.putString(STATE_HEADER);
    }
    catch(...)
    {
      buf << "Error saving state " << slot;
      myOSystem.frameBuffer().showTextMessage(buf.str());
      return;
    }

    // Do a complete state save using the Console
    buf.str("");
    if(myOSystem.console().save(out))
    {
      buf << "State " << slot << " saved";
      if(myOSystem.settings().getBool("autoslot"))
      {
        myCurrentSlot = (slot + 1) % 10;
        buf << ", switching to slot " << myCurrentSlot;
      }
    }
    else
      buf << "Error saving state " << slot;

    myOSystem.frameBuffer().showTextMessage(buf.str());
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StateManager::changeState(int direction)
{
  myCurrentSlot = BSPF::clampw(myCurrentSlot + direction, 0, 9);

  // Print appropriate message
  ostringstream buf;
  if(direction)
    buf << "Changed to state slot " << myCurrentSlot;
  else
    buf << "State slot " << myCurrentSlot;
  myOSystem.frameBuffer().showTextMessage(buf.str());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StateManager::toggleAutoSlot()
{
  const bool autoSlot = !myOSystem.settings().getBool("autoslot");

  // Print appropriate message
  ostringstream buf;
  buf << "Automatic slot change " << (autoSlot ? "enabled" : "disabled");
  myOSystem.frameBuffer().showTextMessage(buf.str());

  myOSystem.settings().setValue("autoslot", autoSlot);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool StateManager::loadState(Serializer& in)
{
  try
  {
    if(myOSystem.hasConsole())
    {
      // Make sure the file can be opened for reading
      if(in)
      {
        // First test if we have a valid header
        // If so, do a complete state load using the Console
        return in.getString() == STATE_HEADER &&
               myOSystem.console().load(in);
      }
    }
  }
  catch(...)
  {
    cerr << "ERROR: StateManager::loadState(Serializer&)\n";
  }
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool StateManager::saveState(Serializer& out)
{
  try
  {
    if(myOSystem.hasConsole())
    {
      // Make sure the file can be opened for writing
      if(out)
      {
        // Add header so that if the state format changes in the future,
        // we'll know right away, without having to parse the rest of the file
        out.putString(STATE_HEADER);

        // Do a complete state save using the Console
        if(myOSystem.console().save(out))
          return true;
      }
    }
  }
  catch(...)
  {
    cerr << "ERROR: StateManager::saveState(Serializer&)\n";
  }
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void StateManager::reset()
{
  myRewindManager->clear();
  myActiveMode = myOSystem.settings().getBool(
    myOSystem.settings().getBool("dev.settings") ? "dev.timemachine" : "plr.timemachine") ? Mode::TimeMachine : Mode::Off;

#if 0
  myCurrentSlot = 0;

  switch(myActiveMode)
  {
    case kMovieRecordMode:
      myMovieWriter.close();
      break;

    case kMoviePlaybackMode:
      myMovieReader.close();
      break;

    default:
      break;
  }
  myActiveMode = kOffMode;
#endif
}
