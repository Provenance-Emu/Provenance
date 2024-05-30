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
#include "FrameBuffer.hxx"
#include "PaletteHandler.hxx"
#include "QuadTari.hxx"
#include "Sound.hxx"
#include "StateManager.hxx"
#include "TIASurface.hxx"

#include "GlobalKeyHandler.hxx"

using namespace std::placeholders;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
GlobalKeyHandler::GlobalKeyHandler(OSystem& osystem)
  : myOSystem{osystem}
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool GlobalKeyHandler::handleEvent(const Event::Type event, bool pressed, bool repeated)
{
  // The global settings keys change settings or values as long as the setting
  //  message from the previous settings event is still displayed.
  // Therefore, do not change global settings/values or direct values if
  //  a) the setting message is no longer shown
  //  b) other keys have been pressed
  if(!myOSystem.frameBuffer().messageShown())
  {
    mySettingActive = false;
    myDirectSetting = Setting::NONE;
  }

  const bool settingActive = mySettingActive;
  const Setting directSetting = myDirectSetting;

  if(pressed)
  {
    mySettingActive = false;
    myDirectSetting = Setting::NONE;
  }

  bool handled = true;

  switch(event)
  {
    ////////////////////////////////////////////////////////////////////////
    // Allow adjusting several (mostly repeated) settings using the same six hotkeys
    case Event::PreviousSettingGroup:
    case Event::NextSettingGroup:
      if(pressed && !repeated)
      {
        const int direction = (event == Event::PreviousSettingGroup ? -1 : +1);
        const auto group = static_cast<Group>(
            BSPF::clampw(static_cast<int>(getGroup()) + direction,
            0, static_cast<int>(Group::NUM_GROUPS) - 1));
        const std::map<Group, GroupData> GroupMap = {
          {Group::AV,    {Setting::START_AV_ADJ,    "Audio & Video"}},
          {Group::INPUT, {Setting::START_INPUT_ADJ, "Input Devices & Ports"}},
          {Group::DEBUG, {Setting::START_DEBUG_ADJ, "Debug"}},
        };
        const auto result = GroupMap.find(group);

        myOSystem.frameBuffer().showTextMessage(result->second.name + " settings");
        mySetting = result->second.start;
        mySettingActive = false;
      }
      break;

    case Event::PreviousSetting:
    case Event::NextSetting:
      if(pressed && !repeated)
      {
        const int direction = (event == Event::PreviousSetting ? -1 : +1);

        // Get (and display) the previous|next adjustment function,
        //  but do not change its value
        cycleSetting(settingActive ? direction : 0)(0);
        // Fallback message when no message is displayed by method
        //if(!myOSystem.frameBuffer().messageShown())
        //  myOSystem.frameBuffer().showMessage("Message " + std::to_string(int(mySetting)));
        mySettingActive = true;
      }
      break;

    case Event::SettingDecrease:
    case Event::SettingIncrease:
      if(pressed)
      {
        const int direction = (event == Event::SettingDecrease ? -1 : +1);

        // if a "direct only" hotkey was pressed last, use this one
        if(directSetting != Setting::NONE)
        {
          const SettingData& data = getSettingData(directSetting);

          myDirectSetting = directSetting;
          if(!repeated || data.repeated)
            data.function(direction);
        }
        else
        {
          // Get (and display) the current adjustment function,
          //  but only change its value if the function was already active before
          const SettingData& data = getSettingData(mySetting);

          if(!repeated || data.repeated)
          {
            data.function(settingActive ? direction : 0);
            mySettingActive = true;
          }
        }
      }
      break;

    default:
      handled = false;
  }
  return handled;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void GlobalKeyHandler::setSetting(const Setting setting)
{
  if(setting == Setting::ZOOM && myOSystem.frameBuffer().fullScreen())
    mySetting = Setting::FS_ASPECT;
  else
    mySetting = setting;
  mySettingActive = true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void GlobalKeyHandler::setDirectSetting(const Setting setting)
{
  myDirectSetting = setting;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
GlobalKeyHandler::Group GlobalKeyHandler::getGroup() const
{
  if(mySetting >= Setting::START_DEBUG_ADJ && mySetting <= Setting::END_DEBUG_ADJ)
    return Group::DEBUG;

  if(mySetting >= Setting::START_INPUT_ADJ && mySetting <= Setting::END_INPUT_ADJ)
    return Group::INPUT;

  return Group::AV;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool GlobalKeyHandler::isJoystick(const Controller& controller)
{
  return controller.type() == Controller::Type::Joystick
    || controller.type() == Controller::Type::BoosterGrip
    || controller.type() == Controller::Type::Genesis
    || controller.type() == Controller::Type::Joy2BPlus
    || (controller.type() == Controller::Type::QuadTari
      && (isJoystick(static_cast<const QuadTari*>(&controller)->firstController())
      || isJoystick(static_cast<const QuadTari*>(&controller)->secondController())));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool GlobalKeyHandler::isPaddle(const Controller& controller)
{
  return controller.type() == Controller::Type::Paddles
    || controller.type() == Controller::Type::PaddlesIAxDr
    || controller.type() == Controller::Type::PaddlesIAxis
    || (controller.type() == Controller::Type::QuadTari
      && (isPaddle(static_cast<const QuadTari*>(&controller)->firstController())
      || isPaddle(static_cast<const QuadTari*>(&controller)->secondController())));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool GlobalKeyHandler::isTrackball(const Controller& controller)
{
  return controller.type() == Controller::Type::AmigaMouse
    || controller.type() == Controller::Type::AtariMouse
    || controller.type() == Controller::Type::TrakBall;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool GlobalKeyHandler::skipAVSetting() const
{
  const bool isFullScreen = myOSystem.frameBuffer().fullScreen();
  const bool isFsStretch = isFullScreen &&
    myOSystem.settings().getBool("tia.fs_stretch");
  const bool isCustomPalette =
    myOSystem.settings().getString("palette") == PaletteHandler::SETTING_CUSTOM;
  const bool isCustomFilter =
    myOSystem.settings().getInt("tv.filter") == static_cast<int>(NTSCFilter::Preset::CUSTOM);
  const bool hasScanlines =
    myOSystem.settings().getInt("tv.scanlines") > 0;
  const bool isSoftwareRenderer =
    myOSystem.settings().getString("video") == "software";
  const bool allowBezel =
    myOSystem.settings().getBool("bezel.windowed") || isFullScreen;

  return (mySetting == Setting::OVERSCAN && !isFullScreen)
    || (mySetting == Setting::ZOOM && isFullScreen)
#ifdef ADAPTABLE_REFRESH_SUPPORT
    || (mySetting == Setting::ADAPT_REFRESH && !isFullScreen)
#endif
    || (mySetting == Setting::FS_ASPECT && !isFullScreen)
    || (mySetting == Setting::ASPECT_RATIO && isFsStretch)
    || (mySetting >= Setting::PALETTE_PHASE
      && mySetting <= Setting::PALETTE_BLUE_SHIFT
      && !isCustomPalette)
    || (mySetting >= Setting::NTSC_SHARPNESS
      && mySetting <= Setting::NTSC_BLEEDING
      && !isCustomFilter)
    || (mySetting == Setting::SCANLINE_MASK && !hasScanlines)
    || (mySetting == Setting::INTERPOLATION && isSoftwareRenderer)
    || (mySetting == Setting::BEZEL && !allowBezel);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool GlobalKeyHandler::skipInputSetting() const
{
  const bool grabMouseAllowed = myOSystem.frameBuffer().grabMouseAllowed();
  const bool analog = myOSystem.console().leftController().isAnalog()
    || myOSystem.console().rightController().isAnalog();
  const bool joystick = isJoystick(myOSystem.console().leftController())
    || isJoystick(myOSystem.console().rightController());
  const bool paddle = isPaddle(myOSystem.console().leftController())
    || isPaddle(myOSystem.console().rightController());
  const bool trackball = isTrackball(myOSystem.console().leftController())
    || isTrackball(myOSystem.console().rightController());
  const bool driving =
    myOSystem.console().leftController().type() == Controller::Type::Driving
    || myOSystem.console().rightController().type() == Controller::Type::Driving;
  const bool useMouse =
    BSPF::equalsIgnoreCase("always", myOSystem.settings().getString("usemouse"))
    || (BSPF::equalsIgnoreCase("analog", myOSystem.settings().getString("usemouse"))
      && analog);
  const bool stelladapter = joyHandler().hasStelladaptors();

  return (!grabMouseAllowed && mySetting == Setting::GRAB_MOUSE)
    || (!joystick
      && (mySetting == Setting::DIGITAL_DEADZONE
      || mySetting == Setting::FOUR_DIRECTIONS))
    || (!paddle
      && (mySetting == Setting::ANALOG_DEADZONE
      || mySetting == Setting::ANALOG_SENSITIVITY
      || mySetting == Setting::ANALOG_LINEARITY
      || mySetting == Setting::DEJITTER_AVERAGING
      || mySetting == Setting::DEJITTER_REACTION
      || mySetting == Setting::DIGITAL_SENSITIVITY
      || mySetting == Setting::SWAP_PADDLES
      || mySetting == Setting::PADDLE_CENTER_X
      || mySetting == Setting::PADDLE_CENTER_Y))
    || ((!paddle || !useMouse)
      && mySetting == Setting::PADDLE_SENSITIVITY)
    || ((!trackball || !useMouse)
      && mySetting == Setting::TRACKBALL_SENSITIVITY)
    || (!driving
      && mySetting == Setting::DRIVING_SENSITIVITY) // also affects digital device input sensitivity
    || ((!myOSystem.eventHandler().hasMouseControl() || !useMouse)
      && mySetting == Setting::MOUSE_CONTROL)
    || ((!paddle || !useMouse)
      && mySetting == Setting::MOUSE_RANGE)
    || (!stelladapter
      && mySetting == Setting::SA_PORT_ORDER);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool GlobalKeyHandler::skipDebugSetting() const
{
  const bool isPAL = myOSystem.console().timing() == ConsoleTiming::pal;

  return (mySetting == Setting::COLOR_LOSS && !isPAL);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
GlobalKeyHandler::Function GlobalKeyHandler::cycleSetting(int direction)
{
  bool skip = false;

  do
  {
    switch(getGroup())
    {
      case Group::AV:
        mySetting = static_cast<Setting>(
            BSPF::clampw(static_cast<int>(mySetting) + direction,
            static_cast<int>(Setting::START_AV_ADJ), static_cast<int>(Setting::END_AV_ADJ)));
        // skip currently non-relevant adjustments
        skip = skipAVSetting();
        break;

      case Group::INPUT:
        mySetting = static_cast<Setting>(
            BSPF::clampw(static_cast<int>(mySetting) + direction,
            static_cast<int>(Setting::START_INPUT_ADJ), static_cast<int>(Setting::END_INPUT_ADJ)));
        // skip currently non-relevant adjustments
        skip = skipInputSetting();
        break;

      case Group::DEBUG:
        mySetting = static_cast<Setting>(
            BSPF::clampw(static_cast<int>(mySetting) + direction,
            static_cast<int>(Setting::START_DEBUG_ADJ), static_cast<int>(Setting::END_DEBUG_ADJ)));
        // skip currently non-relevant adjustments
        skip = skipDebugSetting();
        break;

      default:
        break;
    }
    // avoid endless loop
    if(skip && !direction)
      direction = 1;
  } while(skip);

  return getSettingData(mySetting).function;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
GlobalKeyHandler::SettingData GlobalKeyHandler::getSettingData(const Setting setting) const
{
  // Notes:
  // - all setting methods MUST always display a message
  // - some settings reset the repeat state, therefore the code cannot detect repeats
  const std::map<Setting, SettingData> SettingMap = {
    // *** Audio & Video group ***
    {Setting::VOLUME,                 {true,  std::bind(&Sound::adjustVolume, &myOSystem.sound(), _1)}},
    {Setting::ZOOM,                   {false, std::bind(&FrameBuffer::switchVideoMode, &myOSystem.frameBuffer(), _1)}}, // always repeating
    {Setting::FULLSCREEN,             {false, std::bind(&FrameBuffer::toggleFullscreen, &myOSystem.frameBuffer(), _1)}}, // always repeating
    {Setting::FS_ASPECT,              {false, std::bind(&FrameBuffer::switchVideoMode, &myOSystem.frameBuffer(), _1)}}, // always repeating
  #ifdef ADAPTABLE_REFRESH_SUPPORT
    {Setting::ADAPT_REFRESH,          {false, std::bind(&FrameBuffer::toggleAdaptRefresh, &myOSystem.frameBuffer(), _1)}}, // always repeating
  #endif
    {Setting::OVERSCAN,               {true,  std::bind(&FrameBuffer::changeOverscan, &myOSystem.frameBuffer(), _1)}},
    {Setting::TVFORMAT,               {false, std::bind(&Console::selectFormat, &myOSystem.console(), _1)}}, // property, not persisted
    {Setting::VCENTER,                {true,  std::bind(&Console::changeVerticalCenter, &myOSystem.console(), _1)}}, // property, not persisted
    {Setting::ASPECT_RATIO,           {false, std::bind(&Console::toggleCorrectAspectRatio, &myOSystem.console(), _1)}}, // always repeating
    {Setting::VSIZE,                  {true,  std::bind(&Console::changeVSizeAdjust, &myOSystem.console(), _1)}},
    // Palette adjustables
    {Setting::PALETTE,                {false, std::bind(&PaletteHandler::cyclePalette,
                                              &myOSystem.frameBuffer().tiaSurface().paletteHandler(), _1)}},
    {Setting::PALETTE_PHASE,          {true,  std::bind(&PaletteHandler::changeAdjustable, &myOSystem.frameBuffer().tiaSurface().paletteHandler(),
                                              PaletteHandler::PHASE_SHIFT, _1)}},
    {Setting::PALETTE_RED_SCALE,      {true,  std::bind(&PaletteHandler::changeAdjustable, &myOSystem.frameBuffer().tiaSurface().paletteHandler(),
                                              PaletteHandler::RED_SCALE, _1)}},
    {Setting::PALETTE_RED_SHIFT,      {true,  std::bind(&PaletteHandler::changeAdjustable, &myOSystem.frameBuffer().tiaSurface().paletteHandler(),
                                              PaletteHandler::RED_SHIFT, _1)}},
    {Setting::PALETTE_GREEN_SCALE,    {true,  std::bind(&PaletteHandler::changeAdjustable, &myOSystem.frameBuffer().tiaSurface().paletteHandler(),
                                              PaletteHandler::GREEN_SCALE, _1)}},
    {Setting::PALETTE_GREEN_SHIFT,    {true,  std::bind(&PaletteHandler::changeAdjustable, &myOSystem.frameBuffer().tiaSurface().paletteHandler(),
                                              PaletteHandler::GREEN_SHIFT, _1)}},
    {Setting::PALETTE_BLUE_SCALE,     {true,  std::bind(&PaletteHandler::changeAdjustable, &myOSystem.frameBuffer().tiaSurface().paletteHandler(),
                                              PaletteHandler::BLUE_SCALE, _1)}},
    {Setting::PALETTE_BLUE_SHIFT,     {true,  std::bind(&PaletteHandler::changeAdjustable, &myOSystem.frameBuffer().tiaSurface().paletteHandler(),
                                              PaletteHandler::BLUE_SHIFT, _1)}},
    {Setting::PALETTE_HUE,            {true,  std::bind(&PaletteHandler::changeAdjustable, &myOSystem.frameBuffer().tiaSurface().paletteHandler(),
                                              PaletteHandler::HUE, _1)}},
    {Setting::PALETTE_SATURATION,     {true,  std::bind(&PaletteHandler::changeAdjustable, &myOSystem.frameBuffer().tiaSurface().paletteHandler(),
                                              PaletteHandler::SATURATION, _1)}},
    {Setting::PALETTE_CONTRAST,       {true,  std::bind(&PaletteHandler::changeAdjustable, &myOSystem.frameBuffer().tiaSurface().paletteHandler(),
                                              PaletteHandler::CONTRAST, _1)}},
    {Setting::PALETTE_BRIGHTNESS,     {true,  std::bind(&PaletteHandler::changeAdjustable, &myOSystem.frameBuffer().tiaSurface().paletteHandler(),
                                              PaletteHandler::BRIGHTNESS, _1)}},
    {Setting::PALETTE_GAMMA,          {true,  std::bind(&PaletteHandler::changeAdjustable, &myOSystem.frameBuffer().tiaSurface().paletteHandler(),
                                              PaletteHandler::GAMMA, _1)}},
    // NTSC filter adjustables
    {Setting::NTSC_PRESET,            {false, std::bind(&TIASurface::changeNTSC, &myOSystem.frameBuffer().tiaSurface(), _1)}},
    {Setting::NTSC_SHARPNESS,         {true,  std::bind(&TIASurface::changeNTSCAdjustable, &myOSystem.frameBuffer().tiaSurface(),
                                              static_cast<int>(NTSCFilter::Adjustables::SHARPNESS), _1)}},
    {Setting::NTSC_RESOLUTION,        {true,  std::bind(&TIASurface::changeNTSCAdjustable, &myOSystem.frameBuffer().tiaSurface(),
                                              static_cast<int>(NTSCFilter::Adjustables::RESOLUTION), _1)}},
    {Setting::NTSC_ARTIFACTS,         {true,  std::bind(&TIASurface::changeNTSCAdjustable, &myOSystem.frameBuffer().tiaSurface(),
                                              static_cast<int>(NTSCFilter::Adjustables::ARTIFACTS), _1)}},
    {Setting::NTSC_FRINGING,          {true,  std::bind(&TIASurface::changeNTSCAdjustable, &myOSystem.frameBuffer().tiaSurface(),
                                              static_cast<int>(NTSCFilter::Adjustables::FRINGING), _1)}},
    {Setting::NTSC_BLEEDING,          {true,  std::bind(&TIASurface::changeNTSCAdjustable, &myOSystem.frameBuffer().tiaSurface(),
                                              static_cast<int>(NTSCFilter::Adjustables::BLEEDING), _1)}},
    // Other TV effects adjustables
    {Setting::PHOSPHOR_MODE,          {true,  std::bind(&Console::cyclePhosphorMode, &myOSystem.console(), _1)}},
    {Setting::PHOSPHOR,               {true,  std::bind(&Console::changePhosphor, &myOSystem.console(), _1)}},
    {Setting::SCANLINES,              {true,  std::bind(&TIASurface::changeScanlineIntensity, &myOSystem.frameBuffer().tiaSurface(), _1)}},
    {Setting::SCANLINE_MASK,          {false, std::bind(&TIASurface::cycleScanlineMask, &myOSystem.frameBuffer().tiaSurface(), _1)}},
    {Setting::INTERPOLATION,          {false, std::bind(&Console::toggleInter, &myOSystem.console(), _1)}},
    {Setting::BEZEL,                  {false, std::bind(&FrameBuffer::toggleBezel, &myOSystem.frameBuffer(), _1)}},
    // *** Input group ***
    {Setting::DIGITAL_DEADZONE,       {true,  std::bind(&PhysicalJoystickHandler::changeDigitalDeadZone, &joyHandler(), _1)}},
    {Setting::ANALOG_DEADZONE,        {true,  std::bind(&PhysicalJoystickHandler::changeAnalogPaddleDeadZone, &joyHandler(), _1)}},
    {Setting::ANALOG_SENSITIVITY,     {true,  std::bind(&PhysicalJoystickHandler::changeAnalogPaddleSensitivity, &joyHandler(), _1)}},
    {Setting::ANALOG_LINEARITY,       {true,  std::bind(&PhysicalJoystickHandler::changeAnalogPaddleLinearity, &joyHandler(), _1)}},
    {Setting::DEJITTER_AVERAGING,     {true,  std::bind(&PhysicalJoystickHandler::changePaddleDejitterAveraging, &joyHandler(), _1)}},
    {Setting::DEJITTER_REACTION,      {true,  std::bind(&PhysicalJoystickHandler::changePaddleDejitterReaction, &joyHandler(), _1)}},
    {Setting::DIGITAL_SENSITIVITY,    {true,  std::bind(&PhysicalJoystickHandler::changeDigitalPaddleSensitivity, &joyHandler(), _1)}},
    {Setting::AUTO_FIRE,              {true,  std::bind(&Console::changeAutoFireRate, &myOSystem.console(), _1)}},
    {Setting::FOUR_DIRECTIONS,        {false, std::bind(&EventHandler::toggleAllow4JoyDirections, &myOSystem.eventHandler(), _1)}},
    {Setting::MOD_KEY_COMBOS,         {false, std::bind(&PhysicalKeyboardHandler::toggleModKeys, &keyHandler(), _1)}},
    {Setting::SA_PORT_ORDER,          {false, std::bind(&EventHandler::toggleSAPortOrder, &myOSystem.eventHandler(), _1)}},
    {Setting::USE_MOUSE,              {false, std::bind(&EventHandler::changeMouseControllerMode, &myOSystem.eventHandler(), _1)}},
    {Setting::PADDLE_SENSITIVITY,     {true,  std::bind(&PhysicalJoystickHandler::changeMousePaddleSensitivity, &joyHandler(), _1)}},
    {Setting::TRACKBALL_SENSITIVITY,  {true,  std::bind(&PhysicalJoystickHandler::changeMouseTrackballSensitivity, &joyHandler(), _1)}},
    {Setting::DRIVING_SENSITIVITY,    {true,  std::bind(&PhysicalJoystickHandler::changeDrivingSensitivity, &joyHandler(), _1)}},
    {Setting::MOUSE_CURSOR,           {false, std::bind(&EventHandler::changeMouseCursor, &myOSystem.eventHandler(), _1)}},
    {Setting::GRAB_MOUSE,             {false, std::bind(&FrameBuffer::toggleGrabMouse, &myOSystem.frameBuffer(), _1)}},
    // Game properties/Controllers
    {Setting::LEFT_PORT,              {false, std::bind(&Console::changeLeftController, &myOSystem.console(), _1)}}, // property, not persisted
    {Setting::RIGHT_PORT,             {false, std::bind(&Console::changeRightController, &myOSystem.console(), _1)}}, // property, not persisted
    {Setting::SWAP_PORTS,             {false, std::bind(&Console::toggleSwapPorts, &myOSystem.console(), _1)}}, // property, not persisted
    {Setting::SWAP_PADDLES,           {false, std::bind(&Console::toggleSwapPaddles, &myOSystem.console(), _1)}}, // property, not persisted
    {Setting::PADDLE_CENTER_X,        {true,  std::bind(&Console::changePaddleCenterX, &myOSystem.console(), _1)}}, // property, not persisted
    {Setting::PADDLE_CENTER_Y,        {true,  std::bind(&Console::changePaddleCenterY, &myOSystem.console(), _1)}}, // property, not persisted
    {Setting::MOUSE_CONTROL,          {false, std::bind(&EventHandler::changeMouseControl, &myOSystem.eventHandler(), _1)}}, // property, not persisted
    {Setting::MOUSE_RANGE,            {true,  std::bind(&Console::changePaddleAxesRange, &myOSystem.console(), _1)}}, // property, not persisted
    // *** Debug group ***
    {Setting::DEVELOPER,              {false, std::bind(&Console::toggleDeveloperSet, &myOSystem.console(), _1)}},
    {Setting::STATS,                  {false, std::bind(&FrameBuffer::toggleFrameStats, &myOSystem.frameBuffer(), _1)}},
    {Setting::P0_ENAM,                {false, std::bind(&Console::toggleP0Bit, &myOSystem.console(), _1)}}, // debug, not persisted
    {Setting::P1_ENAM,                {false, std::bind(&Console::toggleP1Bit, &myOSystem.console(), _1)}}, // debug, not persisted
    {Setting::M0_ENAM,                {false, std::bind(&Console::toggleM0Bit, &myOSystem.console(), _1)}}, // debug, not persisted
    {Setting::M1_ENAM,                {false, std::bind(&Console::toggleM1Bit, &myOSystem.console(), _1)}}, // debug, not persisted
    {Setting::BL_ENAM,                {false, std::bind(&Console::toggleBLBit, &myOSystem.console(), _1)}}, // debug, not persisted
    {Setting::PF_ENAM,                {false, std::bind(&Console::togglePFBit, &myOSystem.console(), _1)}}, // debug, not persisted
    {Setting::ALL_ENAM,               {false, std::bind(&Console::toggleBits, &myOSystem.console(), _1)}}, // debug, not persisted
    {Setting::P0_CX,                  {false, std::bind(&Console::toggleP0Collision, &myOSystem.console(), _1)}}, // debug, not persisted
    {Setting::P1_CX,                  {false, std::bind(&Console::toggleP1Collision, &myOSystem.console(), _1)}}, // debug, not persisted
    {Setting::M0_CX,                  {false, std::bind(&Console::toggleM0Collision, &myOSystem.console(), _1)}}, // debug, not persisted
    {Setting::M1_CX,                  {false, std::bind(&Console::toggleM1Collision, &myOSystem.console(), _1)}}, // debug, not persisted
    {Setting::BL_CX,                  {false, std::bind(&Console::toggleBLCollision, &myOSystem.console(), _1)}}, // debug, not persisted
    {Setting::PF_CX,                  {false, std::bind(&Console::togglePFCollision, &myOSystem.console(), _1)}}, // debug, not persisted
    {Setting::ALL_CX,                 {false, std::bind(&Console::toggleCollisions, &myOSystem.console(), _1)}}, // debug, not persisted
    {Setting::FIXED_COL,              {false, std::bind(&Console::toggleFixedColors, &myOSystem.console(), _1)}}, // debug, not persisted
    {Setting::COLOR_LOSS,             {false, std::bind(&Console::toggleColorLoss, &myOSystem.console(), _1)}},
    {Setting::JITTER_SENSE,           {true,  std::bind(&Console::changeJitterSense, &myOSystem.console(), _1)}},
    {Setting::JITTER_REC,             {true,  std::bind(&Console::changeJitterRecovery, &myOSystem.console(), _1)}},
    // *** Following functions are not used when cycling settings, but for "direct only" hotkeys ***
    {Setting::STATE,                  {true,  std::bind(&StateManager::changeState, &myOSystem.state(), _1)}}, // temporary, not persisted
    {Setting::PALETTE_ATTRIBUTE,      {true,  std::bind(&PaletteHandler::changeCurrentAdjustable, &myOSystem.frameBuffer().tiaSurface().paletteHandler(), _1)}},
    {Setting::NTSC_ATTRIBUTE,         {true,  std::bind(&TIASurface::changeCurrentNTSCAdjustable, &myOSystem.frameBuffer().tiaSurface(), _1)}},
    {Setting::CHANGE_SPEED,           {true,  std::bind(&Console::changeSpeed, &myOSystem.console(), _1)}},
  };
  const auto result = SettingMap.find(setting);

  if(result != SettingMap.end())
    return result->second;
  else
  {
    cerr << "Error: setting " << static_cast<int>(setting)
         << " missing in SettingMap!\n";
    return SettingMap.find(Setting::VOLUME)->second; // default function!
  }
}
