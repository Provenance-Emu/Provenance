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

#include "Settings.hxx"
#include "Logger.hxx"

#include "ControllerDetector.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Controller::Type ControllerDetector::detectType(
    const ByteBuffer& image, size_t size,
    const Controller::Type type, const Controller::Jack port,
    const Settings& settings, bool isQuadTari)
{
  if(type == Controller::Type::Unknown || settings.getBool("rominfo"))
  {
    const Controller::Type detectedType
      = autodetectPort(image, size, port, settings, isQuadTari);

    if(type != Controller::Type::Unknown && type != detectedType)
    {
      cerr << "Controller auto-detection not consistent: "
        << Controller::getName(type) << ", " << Controller::getName(detectedType) << '\n';
    }
    Logger::debug("'" + Controller::getName(detectedType) + "' detected for " +
      (port == Controller::Jack::Left ? "left" : "right") + " port");
    return detectedType;
  }

  return type;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string ControllerDetector::detectName(const ByteBuffer& image, size_t size,
    const Controller::Type type, const Controller::Jack port,
    const Settings& settings, bool isQuadTari)
{
  return Controller::getName(detectType(image, size, type, port, settings, isQuadTari));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Controller::Type ControllerDetector::autodetectPort(
    const ByteBuffer& image, size_t size,
    Controller::Jack port, const Settings& settings, bool isQuadTari)
{
  // default type joystick
  Controller::Type type = Controller::Type::Joystick;

  if(isProbablySaveKey(image, size, port))
    type = Controller::Type::SaveKey;
  else if(!isQuadTari && isProbablyQuadTari(image, size, port))
    type = Controller::Type::QuadTari;
  else if(usesJoystickButton(image, size, port))
  {
    if(isProbablyTrakBall(image, size))
      type = Controller::Type::TrakBall;
    else if(isProbablyAtariMouse(image, size))
      type = Controller::Type::AtariMouse;
    else if(isProbablyAmigaMouse(image, size))
      type = Controller::Type::AmigaMouse;
    else if(usesKeyboard(image, size, port)) // must be detected before Genesis!
      type = usesJoystickDirections(image, size)
        ? Controller::Type::Joy2BPlus
        : Controller::Type::Keyboard;
    else if(usesGenesisButton(image, size, port))
      type = Controller::Type::Genesis;
    else if(isProbablyLightGun(image, size, port))
      type = Controller::Type::Lightgun;
    // add check for games which support joystick and paddles, prefer paddles here
    else if(usesPaddle(image, size, port, settings))
      type = Controller::Type::Paddles;
  }
  else
  {
    if(usesPaddle(image, size, port, settings))
      type = Controller::Type::Paddles;
    else if(isProbablyKidVid(image, size, port))
      type = Controller::Type::KidVid;
    else if (isQuadTari) // currently most likely assumption
      type = Controller::Type::Paddles;
  }
  // TODO: BOOSTERGRIP, DRIVING, COMPUMATE, MINDLINK, ATARIVOX
  // not detectable: PADDLES_IAXIS, PADDLES_IAXDR
  return type;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool ControllerDetector::searchForBytes(const ByteBuffer& image, size_t imagesize,
                                        const uInt8* signature, uInt32 sigsize)
{
  if (imagesize >= sigsize)
    for(uInt32 i = 0; i < imagesize - sigsize; ++i)
    {
      uInt32 matches = 0;
      for(uInt32 j = 0; j < sigsize; ++j)
      {
        if(image[i + j] == signature[j])
          ++matches;
        else
          break;
      }
      if(matches == sigsize)
      {
        return true;
      }
    }

  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool ControllerDetector::usesJoystickButton(const ByteBuffer& image, size_t size,
                                            Controller::Jack port)
{
  if(port == Controller::Jack::Left)
  {
    // check for INPT4 access
    static constexpr int NUM_SIGS_0 = 25;
    static constexpr int SIG_SIZE_0 = 3;
    static constexpr uInt8 signature_0[NUM_SIGS_0][SIG_SIZE_0] = {
      { 0x24, 0x0c, 0x10 }, // bit INPT4; bpl (joystick games only)
      { 0x24, 0x0c, 0x30 }, // bit INPT4; bmi (joystick games only)
      { 0xa5, 0x0c, 0x10 }, // lda INPT4; bpl (joystick games only)
      { 0xa5, 0x0c, 0x30 }, // lda INPT4; bmi (joystick games only)
      { 0xb5, 0x0c, 0x10 }, // lda INPT4,x; bpl (joystick games only)
      { 0xb5, 0x0c, 0x30 }, // lda INPT4,x; bmi (joystick games only)
      { 0x24, 0x3c, 0x10 }, // bit INPT4|$30; bpl (joystick games + Compumate)
      { 0x24, 0x3c, 0x30 }, // bit INPT4|$30; bmi (joystick, keyboard and mindlink games)
      { 0xa5, 0x3c, 0x10 }, // lda INPT4|$30; bpl (joystick and keyboard games)
      { 0xa5, 0x3c, 0x30 }, // lda INPT4|$30; bmi (joystick, keyboard and mindlink games)
      { 0xb5, 0x3c, 0x10 }, // lda INPT4|$30,x; bpl (joystick, keyboard and driving games)
      { 0xb5, 0x3c, 0x30 }, // lda INPT4|$30,x; bmi (joystick and keyboard games)
      { 0xb4, 0x0c, 0x30 }, // ldy INPT4|$30,x; bmi (joystick games only)
      { 0xa5, 0x3c, 0x2a }, // ldy INPT4|$30; rol (joystick games only)
      { 0xa6, 0x3c, 0x8e }, // ldx INPT4|$30; stx (joystick games only)
      { 0xa6, 0x0c, 0x8e }, // ldx INPT4; stx (joystick games only)
      { 0xa4, 0x3c, 0x8c }, // ldy INPT4; sty (joystick games only, Scramble)
      { 0xa5, 0x0c, 0x8d }, // lda INPT4; sta (joystick games only, Super Cobra Arcade)
      { 0xa4, 0x0c, 0x30 }, // ldy INPT4|; bmi (only Game of Concentration)
      { 0xa4, 0x3c, 0x30 }, // ldy INPT4|$30; bmi (only Game of Concentration)
      { 0xa5, 0x0c, 0x25 }, // lda INPT4; and (joystick games only)
      { 0xa6, 0x3c, 0x30 }, // ldx INPT4|$30; bmi (joystick games only)
      { 0xa6, 0x0c, 0x30 }, // ldx INPT4; bmi
      { 0xa5, 0x0c, 0x0a }, // lda INPT4; asl (joystick games only)
      { 0xb5, 0x0c, 0x4a }  // lda INPT4,x; lsr (joystick games only)
    };
    static constexpr int NUM_SIGS_1 = 11;
    static constexpr int SIG_SIZE_1 = 4;
    static constexpr uInt8 signature_1[NUM_SIGS_1][SIG_SIZE_1] = {
      { 0xb9, 0x0c, 0x00, 0x10 }, // lda INPT4,y; bpl (joystick games only)
      { 0xb9, 0x0c, 0x00, 0x30 }, // lda INPT4,y; bmi (joystick games only)
      { 0xb9, 0x3c, 0x00, 0x10 }, // lda INPT4,y; bpl (joystick games only)
      { 0xb9, 0x3c, 0x00, 0x30 }, // lda INPT4,y; bmi (joystick games only)
      { 0xa5, 0x0c, 0x0a, 0xb0 }, // lda INPT4; asl; bcs (joystick games only)
      { 0xb5, 0x0c, 0x29, 0x80 }, // lda INPT4,x; and #$80 (joystick games only)
      { 0xb5, 0x3c, 0x29, 0x80 }, // lda INPT4|$30,x; and #$80 (joystick games only)
      { 0xa5, 0x0c, 0x29, 0x80 }, // lda INPT4; and #$80 (joystick games only)
      { 0xa5, 0x3c, 0x29, 0x80 }, // lda INPT4|$30; and #$80 (joystick games only)
      { 0xa5, 0x0c, 0x49, 0x80 }, // lda INPT4; eor #$80 (Lady Bug Arcade only)
      { 0xb9, 0x0c, 0x00, 0x4a }  // lda INPT4,y; lsr (Wizard of Wor Arcade only)
    };
    static constexpr int NUM_SIGS_2 = 10;
    static constexpr int SIG_SIZE_2 = 5;
    static constexpr uInt8 signature_2[NUM_SIGS_2][SIG_SIZE_2] = {
      { 0xa5, 0x0c, 0x25, 0x0d, 0x10 }, // lda INPT4; and INPT5; bpl (joystick games only)
      { 0xa5, 0x0c, 0x25, 0x0d, 0x30 }, // lda INPT4; and INPT5; bmi (joystick games only)
      { 0xa5, 0x3c, 0x25, 0x3d, 0x10 }, // lda INPT4|$30; and INPT5|$30; bpl (joystick games only)
      { 0xa5, 0x3c, 0x25, 0x3d, 0x30 }, // lda INPT4|$30; and INPT5|$30; bmi (joystick games only)
      { 0xb5, 0x38, 0x29, 0x80, 0xd0 }, // lda INPT0|$30,y; and #$80; bne (Basic Programming)
      { 0xa9, 0x80, 0x24, 0x0c, 0xd0 }, // lda #$80; bit INPT4; bne (bBasic)
      { 0xa5, 0x0c, 0x29, 0x80, 0xd0 }, // lda INPT4; and #$80; bne (joystick games only)
      { 0xa5, 0x3c, 0x29, 0x80, 0xd0 }, // lda INPT4|$30; and #$80; bne (joystick games only)
      { 0xad, 0x0c, 0x00, 0x29, 0x80 }, // lda.w INPT4; and #$80 (joystick games only)
      { 0xb9, 0x0c, 0x00, 0x29, 0x80 }  // lda.w INPT4,y; and #$80 (joystick games only)
    };

    for(const auto* const sig: signature_0)
      if(searchForBytes(image, size, sig, SIG_SIZE_0))
        return true;

    for(const auto* const sig: signature_1)
      if(searchForBytes(image, size, sig, SIG_SIZE_1))
        return true;

    for(const auto* const sig: signature_2)
      if(searchForBytes(image, size, sig, SIG_SIZE_2))
        return true;
  }
  else if(port == Controller::Jack::Right)
  {
    // check for INPT5 and indexed INPT4 access
    static constexpr int NUM_SIGS_0 = 16;
    static constexpr int SIG_SIZE_0 = 3;
    static constexpr uInt8 signature_0[NUM_SIGS_0][SIG_SIZE_0] = {
      { 0x24, 0x0d, 0x10 }, // bit INPT5; bpl (joystick games only)
      { 0x24, 0x0d, 0x30 }, // bit INPT5; bmi (joystick games only)
      { 0xa5, 0x0d, 0x10 }, // lda INPT5; bpl (joystick games only)
      { 0xa5, 0x0d, 0x30 }, // lda INPT5; bmi (joystick games only)
      { 0xb5, 0x0c, 0x10 }, // lda INPT4,x; bpl (joystick games only)
      { 0xb5, 0x0c, 0x30 }, // lda INPT4,x; bmi (joystick games only)
      { 0x24, 0x3d, 0x10 }, // bit INPT5|$30; bpl (joystick games, Compumate)
      { 0x24, 0x3d, 0x30 }, // bit INPT5|$30; bmi (joystick and keyboard games)
      { 0xa5, 0x3d, 0x10 }, // lda INPT5|$30; bpl (joystick games only)
      { 0xa5, 0x3d, 0x30 }, // lda INPT5|$30; bmi (joystick and keyboard games)
      { 0xb5, 0x3c, 0x10 }, // lda INPT4|$30,x; bpl (joystick, keyboard and driving games)
      { 0xb5, 0x3c, 0x30 }, // lda INPT4|$30,x; bmi (joystick and keyboard games)
      { 0xa4, 0x3d, 0x30 }, // ldy INPT5; bmi (only Game of Concentration)
      { 0xa5, 0x0d, 0x25 }, // lda INPT5; and (joystick games only)
      { 0xa6, 0x3d, 0x30 }, // ldx INPT5|$30; bmi (joystick games only)
      { 0xa6, 0x0d, 0x30 }  // ldx INPT5; bmi
    };
    static constexpr int NUM_SIGS_1 = 7;
    static constexpr int SIG_SIZE_1 = 4;
    static constexpr uInt8 signature_1[NUM_SIGS_1][SIG_SIZE_1] = {
      { 0xb9, 0x0c, 0x00, 0x10 }, // lda INPT4,y; bpl (joystick games only)
      { 0xb9, 0x0c, 0x00, 0x30 }, // lda INPT4,y; bmi (joystick games only)
      { 0xb9, 0x3c, 0x00, 0x10 }, // lda INPT4,y; bpl (joystick games only)
      { 0xb9, 0x3c, 0x00, 0x30 }, // lda INPT4,y; bmi (joystick games only)
      { 0xb5, 0x0c, 0x29, 0x80 }, // lda INPT4,x; and #$80 (joystick games only)
      { 0xb5, 0x3c, 0x29, 0x80 }, // lda INPT4|$30,x; and #$80 (joystick games only)
      { 0xa5, 0x3d, 0x29, 0x80 }  // lda INPT5|$30; and #$80 (joystick games only)
    };
    static constexpr int NUM_SIGS_2 = 3;
    static constexpr int SIG_SIZE_2 = 5;
    static constexpr uInt8 signature_2[NUM_SIGS_2][SIG_SIZE_2] = {
      { 0xb5, 0x38, 0x29, 0x80, 0xd0 }, // lda INPT0|$30,y; and #$80; bne (Basic Programming)
      { 0xa9, 0x80, 0x24, 0x0d, 0xd0 }, // lda #$80; bit INPT5; bne (bBasic)
      { 0xad, 0x0d, 0x00, 0x29, 0x80 }  // lda.w INPT5|$30; and #$80 (joystick games only)
    };

    for(const auto* const sig: signature_0)
      if(searchForBytes(image, size, sig, SIG_SIZE_0))
        return true;

    for(const auto* const sig: signature_1)
      if(searchForBytes(image, size, sig, SIG_SIZE_1))
        return true;

    for(const auto* const sig: signature_2)
      if(searchForBytes(image, size, sig, SIG_SIZE_2))
        return true;
  }
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Returns true if the port's joystick direction access code is found.
bool ControllerDetector::usesJoystickDirections(const ByteBuffer& image, size_t size)
{
  // check for SWCHA access (both ports)
  static constexpr int NUM_SIGS = 8;
  static constexpr int SIG_SIZE = 3;
  static constexpr uInt8 signature[NUM_SIGS][SIG_SIZE] = {
    { 0xad, 0x80, 0x02 }, // lda SWCHA (also found in MagiCard, so this needs properties now!)
    { 0xae, 0x80, 0x02 }, // ldx SWCHA
    { 0xac, 0x80, 0x02 }, // ldy SWCHA
    { 0x2c, 0x80, 0x02 }, // bit SWCHA
    { 0x0d, 0x80, 0x02 }, // ora SWCHA (Official Frogger)
    { 0x2d, 0x80, 0x02 }, // and SWCHA (Crypts of Chaos, some paddle games)
    { 0x4d, 0x80, 0x02 }, // eor SWCHA (Chopper Command)
    { 0xad, 0x88, 0x02 }, // lda SWCHA|8 (Jawbreaker)
  };

  for(const auto* const sig: signature)
    if(searchForBytes(image, size, sig, SIG_SIZE))
      return true;

  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool ControllerDetector::usesKeyboard(const ByteBuffer& image, size_t size,
                                      Controller::Jack port)
{
  if(port == Controller::Jack::Left)
  {
    // check for INPT0 *AND* INPT1 access
    static constexpr int NUM_SIGS_0_0 = 7;
    static constexpr int SIG_SIZE_0_0 = 3;
    static constexpr uInt8 signature_0_0[NUM_SIGS_0_0][SIG_SIZE_0_0] = {
      { 0x24, 0x38, 0x30 }, // bit INPT0|$30; bmi
      { 0xa5, 0x38, 0x10 }, // lda INPT0|$30; bpl
      { 0xa4, 0x38, 0x30 }, // ldy INPT0|$30; bmi
      { 0xb5, 0x38, 0x30 }, // lda INPT0|$30,x; bmi
      { 0x24, 0x08, 0x30 }, // bit INPT0; bmi
      { 0x24, 0x08, 0x10 }, // bit INPT0; bpl (Tap-A-Mole, also e.g. Chopper Command, Secret Quest, River Raid II)
      { 0xa6, 0x08, 0x30 }  // ldx INPT0; bmi
    };
    static constexpr int NUM_SIGS_0_2 = 1;
    static constexpr int SIG_SIZE_0_2 = 5;
    static constexpr uInt8 signature_0_2[NUM_SIGS_0_2][SIG_SIZE_0_2] = {
      { 0xb5, 0x38, 0x29, 0x80, 0xd0 }  // lda INPT0,x; and #80; bne
    };

    static constexpr int NUM_SIGS_1_0 = 8;
    static constexpr int SIG_SIZE_1_0 = 3;
    static constexpr uInt8 signature_1_0[NUM_SIGS_1_0][SIG_SIZE_1_0] = {
      { 0x24, 0x39, 0x10 }, // bit INPT1|$30; bpl
      { 0x24, 0x39, 0x30 }, // bit INPT1|$30; bmi
      { 0xa5, 0x39, 0x10 }, // lda INPT1|$30; bpl
      { 0xa4, 0x39, 0x30 }, // ldy INPT1|$30; bmi
      { 0xb5, 0x38, 0x30 }, // lda INPT0|$30,x; bmi
      { 0x24, 0x09, 0x30 }, // bit INPT1; bmi
      { 0x24, 0x09, 0x10 }, // bit INPT1; bpl (Tap-A-Mole and some Genesis games)
      { 0xa6, 0x09, 0x30 }  // ldx INPT1; bmi
    };
    static constexpr int NUM_SIGS_1_2 = 1;
    static constexpr int SIG_SIZE_1_2 = 5;
    static constexpr uInt8 signature_1_2[NUM_SIGS_1_2][SIG_SIZE_1_2] = {
      { 0xb5, 0x38, 0x29, 0x80, 0xd0 }  // lda INPT0,x; and #80; bne
    };

    bool found = false;

    for(const auto* const sig: signature_0_0)
      if(searchForBytes(image, size, sig, SIG_SIZE_0_0))
      {
        found = true;
        break;
      }
    if(!found)
      for(const auto* const sig: signature_0_2)
        if(searchForBytes(image, size, sig, SIG_SIZE_0_2))
        {
          found = true;
          break;
        }
    if(found)
    {
      for(const auto* const sig: signature_1_0)
        if(searchForBytes(image, size, sig, SIG_SIZE_1_0))
        {
          return true;
        }

      for(const auto* const sig: signature_1_2)
        if(searchForBytes(image, size, sig, SIG_SIZE_1_2))
        {
          return true;
        }
    }
  }
  else if(port == Controller::Jack::Right)
  {
    // check for INPT2 *AND* INPT3 access
    static constexpr int NUM_SIGS_0_0 = 6;
    static constexpr int SIG_SIZE_0_0 = 3;
    static constexpr uInt8 signature_0_0[NUM_SIGS_0_0][SIG_SIZE_0_0] = {
      { 0x24, 0x3a, 0x30 }, // bit INPT2|$30; bmi
      { 0xa5, 0x3a, 0x10 }, // lda INPT2|$30; bpl
      { 0xa4, 0x3a, 0x30 }, // ldy INPT2|$30; bmi
      { 0x24, 0x0a, 0x30 }, // bit INPT2; bmi
      { 0x24, 0x0a, 0x10 }, // bit INPT2; bpl
      { 0xa6, 0x0a, 0x30 }  // ldx INPT2; bmi
    };
    static constexpr int NUM_SIGS_0_2 = 1;
    static constexpr int SIG_SIZE_0_2 = 5;
    static constexpr uInt8 signature_0_2[NUM_SIGS_0_2][SIG_SIZE_0_2] = {
      { 0xb5, 0x38, 0x29, 0x80, 0xd0 }  // lda INPT2,x; and #80; bne
    };

    static constexpr int NUM_SIGS_1_0 = 6;
    static constexpr int SIG_SIZE_1_0 = 3;
    static constexpr uInt8 signature_1_0[NUM_SIGS_1_0][SIG_SIZE_1_0] = {
      { 0x24, 0x3b, 0x30 }, // bit INPT3|$30; bmi
      { 0xa5, 0x3b, 0x10 }, // lda INPT3|$30; bpl
      { 0xa4, 0x3b, 0x30 }, // ldy INPT3|$30; bmi
      { 0x24, 0x0b, 0x30 }, // bit INPT3; bmi
      { 0x24, 0x0b, 0x10 }, // bit INPT3; bpl
      { 0xa6, 0x0b, 0x30 }  // ldx INPT3; bmi
    };
    static constexpr int NUM_SIGS_1_2 = 1;
    static constexpr int SIG_SIZE_1_2 = 5;
    static constexpr uInt8 signature_1_2[NUM_SIGS_1_2][SIG_SIZE_1_2] = {
      { 0xb5, 0x38, 0x29, 0x80, 0xd0 }  // lda INPT2,x; and #80; bne
    };

    bool found = false;

    for(const auto* const sig: signature_0_0)
      if(searchForBytes(image, size, sig, SIG_SIZE_0_0))
      {
        found = true;
        break;
      }

    if(!found)
      for(const auto* const sig: signature_0_2)
        if(searchForBytes(image, size, sig, SIG_SIZE_0_2))
        {
          found = true;
          break;
        }

    if(found)
    {
      for(const auto* const sig: signature_1_0)
        if(searchForBytes(image, size, sig, SIG_SIZE_1_0))
        {
          return true;
        }

      for(const auto* const sig: signature_1_2)
        if(searchForBytes(image, size, sig, SIG_SIZE_1_2))
        {
          return true;
        }
    }
  }

  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool ControllerDetector::usesGenesisButton(const ByteBuffer& image, size_t size,
                                           Controller::Jack port)
{
  if(port == Controller::Jack::Left)
  {
    // check for INPT1 access
    static constexpr int NUM_SIGS_0 = 19;
    static constexpr int SIG_SIZE_0 = 3;
    static constexpr uInt8 signature_0[NUM_SIGS_0][SIG_SIZE_0] = {
      { 0x24, 0x09, 0x10 }, // bit INPT1; bpl (Genesis only)
      { 0x24, 0x09, 0x30 }, // bit INPT1; bmi (paddle ROMS too)
      { 0xa5, 0x09, 0x10 }, // lda INPT1; bpl (paddle ROMS too)
      { 0xa5, 0x09, 0x30 }, // lda INPT1; bmi (paddle ROMS too)
      { 0xa4, 0x09, 0x30 }, // ldy INPT1; bmi (Genesis only)
      { 0xa6, 0x09, 0x30 }, // ldx INPT1; bmi (Genesis only)
      { 0x24, 0x39, 0x10 }, // bit INPT1|$30; bpl (keyboard and paddle ROMS too)
      { 0x24, 0x39, 0x30 }, // bit INPT1|$30; bmi (keyboard and paddle ROMS too)
      { 0xa5, 0x39, 0x10 }, // lda INPT1|$30; bpl (keyboard ROMS too)
      { 0xa5, 0x39, 0x30 }, // lda INPT1|$30; bmi (keyboard and paddle ROMS too)
      { 0xa4, 0x39, 0x30 }, // ldy INPT1|$30; bmi (keyboard ROMS too)
      { 0xa5, 0x39, 0x6a }, // lda INPT1|$30; ror (Genesis only)
      { 0xa6, 0x39, 0x8e }, // ldx INPT1|$30; stx (Genesis only)
      { 0xa6, 0x09, 0x8e }, // ldx INPT1; stx (Genesis only)
      { 0xa4, 0x39, 0x8c }, // ldy INPT1|$30; sty (Genesis only, Scramble)
      { 0xa5, 0x09, 0x8d }, // lda INPT1; sta (Genesis only, Super Cobra Arcade)
      { 0xa5, 0x09, 0x29 }, // lda INPT1; and (Genesis only)
      { 0x25, 0x39, 0x30 }, // and INPT1|$30; bmi (Genesis only)
      { 0x25, 0x09, 0x10 }  // and INPT1; bpl (Genesis only)
    };
    for(const auto* const sig: signature_0)
      if(searchForBytes(image, size, sig, SIG_SIZE_0))
        return true;
  }
  else if(port == Controller::Jack::Right)
  {
    // check for INPT3 access
    static constexpr int NUM_SIGS_0 = 10;
    static constexpr int SIG_SIZE_0 = 3;
    static constexpr uInt8 signature_0[NUM_SIGS_0][SIG_SIZE_0] = {
      { 0x24, 0x0b, 0x10 }, // bit INPT3; bpl
      { 0x24, 0x0b, 0x30 }, // bit INPT3; bmi
      { 0xa5, 0x0b, 0x10 }, // lda INPT3; bpl
      { 0xa5, 0x0b, 0x30 }, // lda INPT3; bmi
      { 0x24, 0x3b, 0x10 }, // bit INPT3|$30; bpl
      { 0x24, 0x3b, 0x30 }, // bit INPT3|$30; bmi
      { 0xa5, 0x3b, 0x10 }, // lda INPT3|$30; bpl
      { 0xa5, 0x3b, 0x30 }, // lda INPT3|$30; bmi
      { 0xa6, 0x3b, 0x8e }, // ldx INPT3|$30; stx
      { 0x25, 0x0b, 0x10 }  // and INPT3; bpl (Genesis only)
    };
    for(const auto* const sig: signature_0)
      if(searchForBytes(image, size, sig, SIG_SIZE_0))
        return true;
  }
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool ControllerDetector::usesPaddle(const ByteBuffer& image, size_t size,
                                    Controller::Jack port, const Settings& settings)
{
  if(port == Controller::Jack::Left)
  {
    // check for INPT0 access
    static constexpr int NUM_SIGS_0 = 12;
    static constexpr int SIG_SIZE_0 = 3;
    static constexpr uInt8 signature_0[NUM_SIGS_0][SIG_SIZE_0] = {
      //{ 0x24, 0x08, 0x10 }, // bit INPT0; bpl (many joystick games too!)
      //{ 0x24, 0x08, 0x30 }, // bit INPT0; bmi (joystick games: Spike's Peak, Sweat, Turbo!)
      { 0xa5, 0x08, 0x10 }, // lda INPT0; bpl (no joystick games)
      { 0xa5, 0x08, 0x30 }, // lda INPT0; bmi (no joystick games)
      //{ 0xb5, 0x08, 0x10 }, // lda INPT0,x; bpl (Duck Attack (graphics)!, Toyshop Trouble (Easter Egg))
      { 0xb5, 0x08, 0x30 }, // lda INPT0,x; bmi (no joystick games)
      { 0x24, 0x38, 0x10 }, // bit INPT0|$30; bpl (no joystick games)
      { 0x24, 0x38, 0x30 }, // bit INPT0|$30; bmi (no joystick games)
      { 0xa5, 0x38, 0x10 }, // lda INPT0|$30; bpl (no joystick games)
      { 0xa5, 0x38, 0x30 }, // lda INPT0|$30; bmi (no joystick games)
      { 0xb5, 0x38, 0x10 }, // lda INPT0|$30,x; bpl (Circus Atari, old code!)
      { 0xb5, 0x38, 0x30 }, // lda INPT0|$30,x; bmi (no joystick games)
      { 0x68, 0x48, 0x10 }, // pla; pha; bpl (i.a. Bachelor Party)
      { 0xa5, 0x08, 0x4c }, // lda INPT0; jmp (only Backgammon)
      { 0xa4, 0x38, 0x30 }  // ldy INPT0; bmi (no joystick games)
    };
    static constexpr int NUM_SIGS_1 = 4;
    static constexpr int SIG_SIZE_1 = 4;
    static constexpr uInt8 signature_1[NUM_SIGS_1][SIG_SIZE_1] = {
      { 0xb9, 0x08, 0x00, 0x30 }, // lda INPT0,y; bmi (i.a. Encounter at L-5)
      { 0xb9, 0x38, 0x00, 0x30 }, // lda INPT0|$30,y; bmi (i.a. SW-Jedi Arena, Video Olympics)
      { 0xb9, 0x08, 0x00, 0x10 }, // lda INPT0,y; bpl (Drone Wars)
      { 0x24, 0x08, 0x30, 0x02 }  // bit INPT0; bmi +2 (Picnic)
    };
    static constexpr int NUM_SIGS_2 = 4;
    static constexpr int SIG_SIZE_2 = 5;
    static constexpr uInt8 signature_2[NUM_SIGS_2][SIG_SIZE_2] = {
      { 0xb5, 0x38, 0x29, 0x80, 0xd0 }, // lda INPT0|$30,x; and #$80; bne (Basic Programming)
      { 0x24, 0x38, 0x85, 0x08, 0x10 }, // bit INPT0|$30; sta COLUPF, bpl (Fireball)
      { 0xb5, 0x38, 0x49, 0xff, 0x0a }, // lda INPT0|$30,x; eor #$ff; asl (Blackjack)
      { 0xb1, 0xf2, 0x30, 0x02, 0xe6 }  // lda ($f2),y; bmi...; inc (Warplock)
    };

    for(const auto* const sig: signature_0)
      if(searchForBytes(image, size, sig, SIG_SIZE_0))
        return true;

    for(const auto* const sig: signature_1)
      if(searchForBytes(image, size, sig, SIG_SIZE_1))
        return true;

    for(const auto* const sig: signature_2)
      if(searchForBytes(image, size, sig, SIG_SIZE_2))
        return true;
  }
  else if(port == Controller::Jack::Right)
  {
    // check for INPT2 and indexed INPT0 access
    static constexpr int NUM_SIGS_0 = 17;
    static constexpr int SIG_SIZE_0 = 3;
    static constexpr uInt8 signature_0[NUM_SIGS_0][SIG_SIZE_0] = {
      { 0x24, 0x0a, 0x10 }, // bit INPT2; bpl (no joystick games)
      { 0x24, 0x0a, 0x30 }, // bit INPT2; bmi (no joystick games)
      { 0xa5, 0x0a, 0x10 }, // lda INPT2; bpl (no joystick games)
      { 0xa5, 0x0a, 0x30 }, // lda INPT2; bmi
      //{ 0xb5, 0x0a, 0x10 }, // lda INPT2,x; bpl (no paddle games, but Maze Craze)
      { 0xb5, 0x0a, 0x30 }, // lda INPT2,x; bmi
      { 0xb5, 0x08, 0x10 }, // lda INPT0,x; bpl (no joystick games)
      { 0xb5, 0x08, 0x30 }, // lda INPT0,x; bmi (no joystick games)
      { 0x24, 0x3a, 0x10 }, // bit INPT2|$30; bpl
      { 0x24, 0x3a, 0x30 }, // bit INPT2|$30; bmi
      { 0xa5, 0x3a, 0x10 }, // lda INPT2|$30; bpl
      { 0xa5, 0x3a, 0x30 }, // lda INPT2|$30; bmi
      { 0xb5, 0x3a, 0x10 }, // lda INPT2|$30,x; bpl
      { 0xb5, 0x3a, 0x30 }, // lda INPT2|$30,x; bmi
      { 0xb5, 0x38, 0x10 }, // lda INPT0|$30,x; bpl  (Circus Atari, old code!)
      { 0xb5, 0x38, 0x30 }, // lda INPT0|$30,x; bmi (no joystick games, except G.I. Joe)
      { 0xa4, 0x3a, 0x30 }, // ldy INPT2|$30; bmi (no joystick games)
      { 0xa5, 0x3b, 0x30 }  // lda INPT3|$30; bmi (only Tac Scan, ports and paddles swapped)
    };
    static constexpr int NUM_SIGS_1 = 1;
    static constexpr int SIG_SIZE_1 = 4;
    static constexpr uInt8 signature_1[NUM_SIGS_1][SIG_SIZE_1] = {
      { 0xb9, 0x38, 0x00, 0x30 }, // lda INPT0|$30,y; bmi (Video Olympics)
    };
    static constexpr int NUM_SIGS_2 = 3;
    static constexpr int SIG_SIZE_2 = 5;
    static constexpr uInt8 signature_2[NUM_SIGS_2][SIG_SIZE_2] = {
      { 0xb5, 0x38, 0x29, 0x80, 0xd0 }, // lda INPT0|$30,x; and #$80; bne (Basic Programming)
      { 0x24, 0x38, 0x85, 0x08, 0x10 }, // bit INPT2|$30; sta COLUPF, bpl (Fireball, patched at runtime!)
      { 0xb5, 0x38, 0x49, 0xff, 0x0a }  // lda INPT0|$30,x; eor #$ff; asl (Blackjack)
    };

    for(const auto* const sig: signature_0)
      if(searchForBytes(image, size, sig, SIG_SIZE_0))
        return true;

    for(const auto* const sig: signature_1)
      if(searchForBytes(image, size, sig, SIG_SIZE_1))
        return true;

    for(const auto* const sig: signature_2)
      if(searchForBytes(image, size, sig, SIG_SIZE_2))
        return true;
  }

  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool ControllerDetector::isProbablyTrakBall(const ByteBuffer& image, size_t size)
{
  // check for TrakBall tables
  static constexpr int NUM_SIGS = 3;
  static constexpr int SIG_SIZE = 6;
  static constexpr uInt8 signature[NUM_SIGS][SIG_SIZE] = {
    { 0b1010, 0b1000, 0b1000, 0b1010, 0b0010, 0b0000/*, 0b0000, 0b0010*/ }, // NextTrackTbl (T. Jentzsch)
    { 0x00, 0x07, 0x87, 0x07, 0x88, 0x01/*, 0xff, 0x01*/ }, // .MovementTab_1 (Omegamatrix, SMX7)
    { 0x00, 0x01, 0x81, 0x01, 0x82, 0x03 }  // .MovementTab_1 (Omegamatrix)
  }; // all pattern checked, only TrakBall matches

  for(const auto* const sig: signature)
    if(searchForBytes(image, size, sig, SIG_SIZE))
      return true;

  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool ControllerDetector::isProbablyAtariMouse(const ByteBuffer& image, size_t size)
{
  // check for Atari Mouse tables
  static constexpr int NUM_SIGS = 3;
  static constexpr int SIG_SIZE = 6;
  static constexpr uInt8 signature[NUM_SIGS][SIG_SIZE] = {
    { 0b0101, 0b0111, 0b0100, 0b0110, 0b1101, 0b1111/*, 0b1100, 0b1110*/ }, // NextTrackTbl (T. Jentzsch)
    { 0x00, 0x87, 0x07, 0x00, 0x08, 0x81/*, 0x7f, 0x08*/ }, // .MovementTab_1 (Omegamatrix, SMX7)
    { 0x00, 0x81, 0x01, 0x00, 0x02, 0x83 }  // .MovementTab_1 (Omegamatrix)
  }; // all pattern checked, only Atari Mouse matches

  for(const auto* const sig: signature)
    if(searchForBytes(image, size, sig, SIG_SIZE))
      return true;

  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool ControllerDetector::isProbablyAmigaMouse(const ByteBuffer& image, size_t size)
{
  // check for Amiga Mouse tables
  static constexpr int NUM_SIGS = 4;
  static constexpr int SIG_SIZE = 6;
  static constexpr uInt8 signature[NUM_SIGS][SIG_SIZE] = {
    { 0b1100, 0b1000, 0b0100, 0b0000, 0b1101, 0b1001/*, 0b0101, 0b0001*/ }, // NextTrackTbl (T. Jentzsch)
    { 0x00, 0x88, 0x07, 0x01, 0x08, 0x00/*, 0x7f, 0x07*/ }, // .MovementTab_1 (Omegamatrix, SMX7)
    { 0x00, 0x82, 0x01, 0x03, 0x02, 0x00 }, // .MovementTab_1 (Omegamatrix)
    { 0b100, 0b000, 0b000, 0b000, 0b101, 0b001} // NextTrackTbl (T. Jentzsch, MCTB)
  }; // all pattern checked, only Amiga Mouse matches

  for(const auto* const sig: signature)
    if(searchForBytes(image, size, sig, SIG_SIZE))
      return true;

  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool ControllerDetector::isProbablySaveKey(const ByteBuffer& image, size_t size,
                                           Controller::Jack port)
{
  // check for known SaveKey code, only supports right port
  if(port == Controller::Jack::Right)
  {
    static constexpr int NUM_SIGS = 4;
    static constexpr int SIG_SIZE = 9;
    static constexpr uInt8 signature[NUM_SIGS][SIG_SIZE] = {
      { // from I2C_START (i2c.inc)
        0xa9, 0x08,       // lda #I2C_SCL_MASK
        0x8d, 0x80, 0x02, // sta SWCHA
        0xa9, 0x0c,       // lda #I2C_SCL_MASK|I2C_SDA_MASK
        0x8d, 0x81        // sta SWACNT
      },
      { // from I2C_START (i2c_v2.1..3.inc)
        0xa9, 0x18,       // #(I2C_SCL_MASK|I2C_SDA_MASK)*2
        0x8d, 0x80, 0x02, // sta SWCHA
        0x4a,             // lsr
        0x8d, 0x81, 0x02  // sta SWACNT
      },
      { // from I2C_START (Strat-O-Gems)
        0xa2, 0x08,       // ldx #I2C_SCL_MASK
        0x8e, 0x80, 0x02, // stx SWCHA
        0xa2, 0x0c,       // ldx #I2C_SCL_MASK|I2C_SDA_MASK
        0x8e, 0x81        // stx SWACNT
      },
      { // from I2C_START (AStar, Fall Down, Go Fish!)
        0xa9, 0x08,       // lda #I2C_SCL_MASK
        0x8d, 0x80, 0x02, // sta SWCHA
        0xea,             // nop
        0xa9, 0x0c,       // lda #I2C_SCL_MASK|I2C_SDA_MASK
        0x8d              // sta SWACNT
      }
    };

    for(const auto* const sig: signature)
      if(searchForBytes(image, size, sig, SIG_SIZE))
        return true;
  }

  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool ControllerDetector::isProbablyLightGun(const ByteBuffer& image, size_t size,
                                            Controller::Jack port)
{
  if (port == Controller::Jack::Left)
  {
    // check for INPT4 after NOPs access
    static constexpr int NUM_SIGS = 2;
    static constexpr int SIG_SIZE = 6;
    static constexpr uInt8 signature[NUM_SIGS][SIG_SIZE] = {
      { 0xea, 0xea, 0xea, 0x24, 0x0c, 0x10 },
      { 0xea, 0xea, 0xea, 0x24, 0x3c, 0x10 }
    }; // all pattern checked, only 'Sentinel' and 'Shooting Arcade' match

    for(const auto* const sig: signature)
      if (searchForBytes(image, size, sig, SIG_SIZE))
        return true;

    return false;
  }
  else if(port == Controller::Jack::Right)
  {
    // check for INPT5 after NOPs access
    static constexpr int NUM_SIGS = 2;
    static constexpr int SIG_SIZE = 6;
    static constexpr uInt8 signature[NUM_SIGS][SIG_SIZE] = {
      { 0xea, 0xea, 0xea, 0x24, 0x0d, 0x10 },
      { 0xea, 0xea, 0xea, 0x24, 0x3d, 0x10 }
    }; // all pattern checked, only 'Bobby is Hungry' matches

    for(const auto* const sig: signature)
      if (searchForBytes(image, size, sig, SIG_SIZE))
        return true;
  }
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool ControllerDetector::isProbablyQuadTari(const ByteBuffer& image, size_t size,
                                            Controller::Jack port)
{
  {
    static constexpr int NUM_SIGS = 3;
    static constexpr int SIG_SIZE = 8;
    static constexpr uInt8 signatureBoth[NUM_SIGS][SIG_SIZE] = {
      { 0x1B, 0x1F, 0x0B, 0x0E, 0x1E, 0x0B, 0x1C, 0x13 }, // Champ Games
      { 0x1c, 0x20, 0x0C, 0x0F, 0x1F, 0x0C, 0x1D, 0x14 }, // RobotWar-2684
      { 'Q', 'U', 'A', 'D', 'T', 'A', 'R', 'I' }
    }; // "QUADTARI"

    for(const auto* const sig: signatureBoth)
      if(searchForBytes(image, size, sig, SIG_SIZE))
        return true;
  }

  if(port == Controller::Jack::Left)
  {
    static constexpr int SIG_SIZE = 5;
    static constexpr uInt8 signature[SIG_SIZE] = { 'Q', 'U', 'A', 'D', 'L' };

    return searchForBytes(image, size, signature, SIG_SIZE);
  }
  else if(port == Controller::Jack::Right)
  {
    static constexpr int SIG_SIZE = 5;
    static constexpr uInt8 signature[SIG_SIZE] = { 'Q', 'U', 'A', 'D', 'R' };

    return searchForBytes(image, size, signature, SIG_SIZE);
  }
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool ControllerDetector::isProbablyKidVid(const ByteBuffer& image, size_t size,
                                            Controller::Jack port)
{
  if(port == Controller::Jack::Right)
  {
    static constexpr int SIG_SIZE = 5;
    static constexpr uInt8 signature[SIG_SIZE] = {0xA9, 0x03, 0x8D, 0x81, 0x02};

    return searchForBytes(image, size, signature, SIG_SIZE);
  }
  return false;
}
