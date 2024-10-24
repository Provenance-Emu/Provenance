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

#include "Playfield.hxx"
#include "TIA.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Playfield::Playfield(uInt32 collisionMask)
  : myCollisionMaskDisabled{collisionMask}
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Playfield::reset()
{
  myPattern = 0;
  myReflected = false;
  myRefp = false;

  myPf0 = 0;
  myPf1 = 0;
  myPf2 = 0;

  myX = 0;

  myObjectColor = myDebugColor = 0;
  myColorLeft = myColorRight = 0;
  myColorP0 = myColorP1 = 0;
  myColorMode = ColorMode::normal;
  myScoreGlitch = false;
  myScoreHaste = 0;
  myDebugEnabled = false;

  collision = 0;

  updatePattern();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Playfield::pf0(uInt8 value)
{
  if (myPf0 == value >> 4) return;

  myTIA->flushLineCache();

  myPattern = (myPattern & 0x000FFFF0) | (value >> 4);
  myPf0 = value >> 4;

  updatePattern();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Playfield::pf1(uInt8 value)
{
  if (myPf1 == value) return;

  myTIA->flushLineCache();

  myPattern = (myPattern & 0x000FF00F)
    | ((value & 0x80) >> 3)
    | ((value & 0x40) >> 1)
    | ((value & 0x20) << 1)
    | ((value & 0x10) << 3)
    | ((value & 0x08) << 5)
    | ((value & 0x04) << 7)
    | ((value & 0x02) << 9)
    | ((value & 0x01) << 11);

  myPf1 = value;
  updatePattern();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Playfield::pf2(uInt8 value)
{
  if (myPf2 == value) return;

  myTIA->flushLineCache();

  myPattern = (myPattern & 0x00000FFF) | (value << 12);
  myPf2 = value;

  updatePattern();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Playfield::ctrlpf(uInt8 value)
{
  const bool reflected = (value & 0x01) > 0;
  const ColorMode colorMode = (value & 0x06) == 0x02 ? ColorMode::score : ColorMode::normal;

  if (myReflected == reflected && myColorMode == colorMode) return;

  myTIA->flushLineCache();

  myReflected = reflected;
  myColorMode = colorMode;
  myScoreHaste = (myColorMode == ColorMode::score && myScoreGlitch) ? 1 : 0;
  applyColors();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Playfield::toggleEnabled(bool enabled)
{
  myIsSuppressed = !enabled;

  updatePattern();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Playfield::toggleCollisions(bool enabled)
{
  // Only keep bit 15 active if collisions are disabled.
  myCollisionMaskEnabled = enabled ? 0xFFFF : (0x8000 | myCollisionMaskDisabled);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Playfield::setColor(uInt8 color)
{
  if (color != myObjectColor && myColorMode == ColorMode::normal) myTIA->flushLineCache();

  myObjectColor = color;
  applyColors();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Playfield::setColorP0(uInt8 color)
{
  if (color != myColorP0 && myColorMode == ColorMode::score) myTIA->flushLineCache();

  myColorP0 = color;
  applyColors();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Playfield::setColorP1(uInt8 color)
{
  if (color != myColorP1 && myColorMode == ColorMode::score) myTIA->flushLineCache();

  myColorP1 = color;
  applyColors();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Playfield::setScoreGlitch(bool enable)
{
  myScoreGlitch = enable;
  myScoreHaste = (myColorMode == ColorMode::score && myScoreGlitch) ? 1 : 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Playfield::setDebugColor(uInt8 color)
{
  myTIA->flushLineCache();
  // allow slight luminance variations without changing color
  if((color & 0xe) == 0xe)
    color -= 2;
  if((color & 0xe) == 0x0)
    color += 2;
  myDebugColor = color;
  applyColors();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Playfield::enableDebugColors(bool enabled)
{
  myTIA->flushLineCache();
  myDebugEnabled = enabled;
  applyColors();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Playfield::applyColorLoss()
{
  myTIA->flushLineCache();
  applyColors();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Playfield::nextLine()
{
  collision = myCollisionMaskDisabled;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Playfield::applyColors()
{
  if (myDebugEnabled)
    myColorLeft = myColorRight = myDebugColor;
  else
  {
    switch (myColorMode)
    {
      case ColorMode::normal:
        if (myTIA->colorLossActive())
          myColorLeft = myColorRight = myObjectColor |= 0x01;
        else
          myColorLeft = myColorRight = myObjectColor &= 0xfe;
        break;

      case ColorMode::score:
        if (myTIA->colorLossActive())
        {
          myColorLeft  = myColorP0 |= 0x01;
          myColorRight = myColorP1 |= 0x01;
        }
        else
        {
          myColorLeft  = myColorP0 &= 0xfe;
          myColorRight = myColorP1 &= 0xfe;
        }
        break;
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 Playfield::getColor() const
{
  if (!myDebugEnabled)
    return myX < static_cast<uInt16>(TIAConstants::H_PIXEL / 2 - myScoreHaste) ? myColorLeft : myColorRight;
  else
  {
    if (myX < static_cast<uInt16>(TIAConstants::H_PIXEL / 2 - myScoreHaste))
    {
      // left side:
      if(myX < 16)
        return myDebugColor - 2;    // PF0
      if(myX < 48)
        return myDebugColor;        // PF1
    }
    else
    {
      // right side:
      if(!myReflected)
      {
        if(myX < TIAConstants::H_PIXEL / 2 + 16)
          return myDebugColor - 2;  // PF0
        if(myX < TIAConstants::H_PIXEL / 2 + 48)
          return myDebugColor;      // PF1
      }
      else
      {
        if(myX < TIAConstants::H_PIXEL / 2 + 32)
          return myDebugColor - 2;  // PF2
        if(myX < TIAConstants::H_PIXEL / 2 + 64)
          return myDebugColor;      // PF1
      }
    }
    return myDebugColor + 2;        // PF2/PF0
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Playfield::updatePattern()
{
  myEffectivePattern = myIsSuppressed ? 0 : myPattern;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Playfield::save(Serializer& out) const
{
  try
  {
    out.putInt(collision);
    out.putInt(myCollisionMaskDisabled);
    out.putInt(myCollisionMaskEnabled);

    out.putBool(myIsSuppressed);

    out.putByte(myColorLeft);
    out.putByte(myColorRight);
    out.putByte(myColorP0);
    out.putByte(myColorP1);
    out.putByte(myObjectColor);
    out.putByte(myDebugColor);
    out.putBool(myDebugEnabled);

    out.putByte(static_cast<uInt8>(myColorMode));
    out.putBool(myScoreGlitch);

    out.putInt(myPattern);
    out.putInt(myEffectivePattern);
    out.putBool(myRefp);
    out.putBool(myReflected);

    out.putByte(myPf0);
    out.putByte(myPf1);
    out.putByte(myPf2);

    out.putInt(myX);
  }
  catch(...)
  {
    cerr << "ERROR: TIA_Playfield::save\n";
    return false;
  }

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Playfield::load(Serializer& in)
{
  try
  {
    collision = in.getInt();
    myCollisionMaskDisabled = in.getInt();
    myCollisionMaskEnabled = in.getInt();

    myIsSuppressed = in.getBool();

    myColorLeft = in.getByte();
    myColorRight = in.getByte();
    myColorP0 = in.getByte();
    myColorP1 = in.getByte();
    myObjectColor = in.getByte();
    myDebugColor = in.getByte();
    myDebugEnabled = in.getBool();

    myColorMode = static_cast<ColorMode>(in.getByte());
    myScoreGlitch = in.getBool();
    myScoreHaste = myColorMode == ColorMode::score && myScoreGlitch ? 1 : 0;

    myPattern = in.getInt();
    myEffectivePattern = in.getInt();
    myRefp = in.getBool();
    myReflected = in.getBool();

    myPf0 = in.getByte();
    myPf1 = in.getByte();
    myPf2 = in.getByte();

    myX = in.getInt();

    applyColors();
    updatePattern();
  }
  catch(...)
  {
    cerr << "ERROR: TIA_Playfield::load\n";
    return false;
  }

  return true;
}
