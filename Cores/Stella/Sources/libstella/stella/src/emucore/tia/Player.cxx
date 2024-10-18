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

#include "Player.hxx"
#include "DrawCounterDecodes.hxx"
#include "TIA.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Player::Player(uInt32 collisionMask)
  : myCollisionMaskDisabled{collisionMask}
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Player::reset()
{
  myDecodes = DrawCounterDecodes::get().playerDecodes()[myDecodesOffset];
  myHmmClocks = 0;
  myCounter = 0;
  isMoving = false;
  myIsRendering = false;
  myRenderCounter = 0;
  myCopy = 1;
  myPatternOld = 0;
  myPatternNew = 0;
  myIsReflected = false;
  myIsDelaying = false;
  myColor = myObjectColor = myDebugColor = 0;
  myDebugEnabled = false;
  collision = myCollisionMaskDisabled;
  mySampleCounter = 0;
  myDividerPending = 0;
  myDividerChangeCounter = -1;
  myInvertedPhaseClock = false;
  myUseInvertedPhaseClock = false;
  myPattern = 0;

  setDivider(1);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Player::grp(uInt8 pattern)
{
  const uInt8 oldPatternNew = myPatternNew;

  myPatternNew = pattern;

  if (!myIsDelaying && myPatternNew != oldPatternNew) {
    myTIA->flushLineCache();
    updatePattern();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Player::hmp(uInt8 value)
{
  myHmmClocks = (value >> 4) ^ 0x08;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Player::nusiz(uInt8 value, bool hblank)
{
  myDecodesOffset = value & 0x07;

  switch (myDecodesOffset) {
    case 5:
      myDividerPending = 2;
      break;

    case 7:
      myDividerPending = 4;
      break;

    default:
      myDividerPending = 1;
      break;
  }

  const uInt8* oldDecodes = myDecodes;

  myDecodes = DrawCounterDecodes::get().playerDecodes()[myDecodesOffset];

  // Changing NUSIZ can trigger a decode in the same cycle
  // (https://github.com/stella-emu/stella/issues/1012)
  if (!myIsRendering && myDecodes[(myCounter + TIAConstants::H_PIXEL - 1) % TIAConstants::H_PIXEL]) {
    myIsRendering = true;
    mySampleCounter = 0;
    myRenderCounter = renderCounterOffset;
    myCopy = myDecodes[myCounter - 1];
  }

  if (
    myDecodes != oldDecodes &&
    myIsRendering &&
    (myRenderCounter - Count::renderCounterOffset) < 2 &&
    !myDecodes[(myCounter - myRenderCounter + Count::renderCounterOffset + TIAConstants::H_PIXEL - 1) % TIAConstants::H_PIXEL]
  ) {
    myIsRendering = false;
  }

  if (myDividerPending == myDivider) return;

  // The following is an effective description of the effects of NUSIZ during
  // decode and rendering.

  if (myIsRendering) {
    const Int8 delta = myRenderCounter - Count::renderCounterOffset;

    switch ((myDivider << 4) | myDividerPending) {
      case 0x12:
      case 0x14:
        if (hblank) {
          if (delta < 4)
            setDivider(myDividerPending);
          else
            myDividerChangeCounter = (delta < 5 ? 1 : 0);
        } else {
          if (delta < 3)
            setDivider(myDividerPending);
          else
            myDividerChangeCounter = 1;
        }

        break;

      case 0x21:
      case 0x41:
        if (delta < (hblank ? 4 : 3)) {
          setDivider(myDividerPending);
        } else if (delta < (hblank ? 6 : 5)) {
          setDivider(myDividerPending);
          --myRenderCounter;
        } else {
          myDividerChangeCounter = (hblank ? 0 : 1);
        }

        break;

      case 0x42:
      case 0x24:
        if (myRenderCounter < 1 || (hblank && (myRenderCounter % myDivider == 1)))
          setDivider(myDividerPending);
        else
          myDividerChangeCounter = (myDivider - (myRenderCounter - 1) % myDivider);
        break;

      default:
        // should never happen
        setDivider(myDividerPending);
        break;
    }

  } else {
    setDivider(myDividerPending);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Player::resp(uInt8 counter)
{
  myCounter = counter;

  // This tries to account for the effects of RESP during draw counter decode as
  // described in Andrew Towers' notes. Still room for tuning.'
  if (myIsRendering && (myRenderCounter - Count::renderCounterOffset) < 4)
    myRenderCounter = Count::renderCounterOffset + (counter - 157);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Player::refp(uInt8 value)
{
  const bool oldIsReflected = myIsReflected;

  myIsReflected = (value & 0x08) > 0;

  if (oldIsReflected != myIsReflected) {
    myTIA->flushLineCache();
    updatePattern();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Player::vdelp(uInt8 value)
{
  const bool oldIsDelaying = myIsDelaying;

  myIsDelaying = (value & 0x01) > 0;

  if (oldIsDelaying != myIsDelaying) {
    myTIA->flushLineCache();
    updatePattern();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Player::toggleEnabled(bool enabled)
{
  const bool oldIsSuppressed = myIsSuppressed;

  myIsSuppressed = !enabled;

  if (oldIsSuppressed != myIsSuppressed) updatePattern();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Player::toggleCollisions(bool enabled)
{
  myCollisionMaskEnabled = enabled ? 0xFFFF : (0x8000 | myCollisionMaskDisabled);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Player::setColor(uInt8 color)
{
  if (color != myObjectColor && myPattern) myTIA->flushLineCache();

  myObjectColor = color;
  applyColors();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Player::setDebugColor(uInt8 color)
{
  myTIA->flushLineCache();
  myDebugColor = color;
  applyColors();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Player::enableDebugColors(bool enabled)
{
  myTIA->flushLineCache();
  myDebugEnabled = enabled;
  applyColors();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Player::applyColorLoss()
{
  myTIA->flushLineCache();
  applyColors();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Player::setInvertedPhaseClock(bool enable)
{
  myUseInvertedPhaseClock = enable;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Player::startMovement()
{
  isMoving = true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Player::nextLine()
{
  if (!myIsRendering || myRenderCounter < myRenderCounterTripPoint)
    collision = myCollisionMaskDisabled;
  else
    collision = (myPattern & (1 << mySampleCounter)) ? myCollisionMaskEnabled : myCollisionMaskDisabled;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Player::shufflePatterns()
{
  const uInt8 oldPatternOld = myPatternOld;

  myPatternOld = myPatternNew;

  if (myIsDelaying && myPatternOld != oldPatternOld) {
    myTIA->flushLineCache();
    updatePattern();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 Player::getRespClock() const
{
  switch (myDivider)
  {
    case 1:
      return (myCounter + TIAConstants::H_PIXEL - 5) % TIAConstants::H_PIXEL;

    case 2:
      return (myCounter + TIAConstants::H_PIXEL - 8) % TIAConstants::H_PIXEL;

    case 4:
      return (myCounter + TIAConstants::H_PIXEL - 12) % TIAConstants::H_PIXEL;

    default:
      throw runtime_error("invalid width");
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Player::setGRPOld(uInt8 pattern)
{
  myTIA->flushLineCache();

  myPatternOld = pattern;
  updatePattern();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Player::updatePattern()
{
  if (myIsSuppressed) {
    myPattern = 0;
    return;
  }

  myPattern = myIsDelaying ? myPatternOld : myPatternNew;

  if (!myIsReflected) {
    myPattern = (
      ((myPattern & 0x01) << 7) |
      ((myPattern & 0x02) << 5) |
      ((myPattern & 0x04) << 3) |
      ((myPattern & 0x08) << 1) |
      ((myPattern & 0x10) >> 1) |
      ((myPattern & 0x20) >> 3) |
      ((myPattern & 0x40) >> 5) |
      ((myPattern & 0x80) >> 7)
    );
  }

  if (myIsRendering && myRenderCounter >= myRenderCounterTripPoint) {
    collision = (myPattern & (1 << mySampleCounter)) ? myCollisionMaskEnabled : myCollisionMaskDisabled;
    myTIA->scheduleCollisionUpdate();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Player::setDivider(uInt8 divider)
{
  myDivider = divider;
  myRenderCounterTripPoint = divider == 1 ? 0 : 1;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Player::applyColors()
{
  if (!myDebugEnabled)
  {
    if (myTIA->colorLossActive()) myObjectColor |= 0x01;
    else                          myObjectColor &= 0xfe;
    myColor = myObjectColor;
  }
  else
    myColor = myDebugColor;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 Player::getColor() const
{
  if(!myDebugEnabled)
    return myColor;
  else
    switch(myCopy)
    {
      case 2:
        return myColor - 2;
      case 3:
        return myColor + 2;
      default:
        return myColor;
    }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 Player::getPosition() const
{
  // Wide players are shifted by one pixel to the right
  const uInt8 shift = myDivider == 1 ? 0 : 1;

  // position =
  //    current playfield x +
  //    (current counter - 156 (the decode clock of copy 0)) +
  //    clock count after decode until first pixel +
  //    shift (accounts for wide player shift) +
  //    1 (it'll take another cycle after the decode for the render counter to start ticking)
  //
  // The result may be negative, so we add TIA::H_PIXEL and do the modulus -> 317 = 156 + TIA::H_PIXEL + 1
  //
  // Mind the sign of renderCounterOffset: it's defined negative above
  return (317 - myCounter - Count::renderCounterOffset + shift + myTIA->getPosition()) % TIAConstants::H_PIXEL;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Player::setPosition(uInt8 newPosition)
{
  myTIA->flushLineCache();

  const uInt8 shift = myDivider == 1 ? 0 : 1;

  // See getPosition for an explanation
  myCounter = (317 - newPosition - Count::renderCounterOffset + shift + myTIA->getPosition()) % TIAConstants::H_PIXEL;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Player::save(Serializer& out) const
{
  try
  {
    out.putInt(collision);
    out.putInt(myCollisionMaskDisabled);
    out.putInt(myCollisionMaskEnabled);

    out.putByte(myColor);
    out.putByte(myObjectColor);  out.putByte(myDebugColor);
    out.putBool(myDebugEnabled);

    out.putBool(myIsSuppressed);

    out.putByte(myHmmClocks);
    out.putByte(myCounter);
    out.putBool(isMoving);

    out.putBool(myIsRendering);
    out.putByte(myRenderCounter);
    out.putByte(myRenderCounterTripPoint);
    out.putByte(myCopy);
    out.putByte(myDivider);
    out.putByte(myDividerPending);
    out.putByte(mySampleCounter);
    out.putByte(myDividerChangeCounter);

    out.putByte(myDecodesOffset);

    out.putByte(myPatternOld);
    out.putByte(myPatternNew);
    out.putByte(myPattern);

    out.putBool(myIsReflected);
    out.putBool(myIsDelaying);
    out.putBool(myInvertedPhaseClock);
  }
  catch(...)
  {
    cerr << "ERROR: TIA_Player::save\n";
    return false;
  }

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Player::load(Serializer& in)
{
  try
  {
    collision = in.getInt();
    myCollisionMaskDisabled = in.getInt();
    myCollisionMaskEnabled = in.getInt();

    myColor = in.getByte();
    myObjectColor = in.getByte();  myDebugColor = in.getByte();
    myDebugEnabled = in.getBool();

    myIsSuppressed = in.getBool();

    myHmmClocks = in.getByte();
    myCounter = in.getByte();
    isMoving = in.getBool();

    myIsRendering = in.getBool();
    myRenderCounter = in.getByte();
    myRenderCounterTripPoint = in.getByte();
    myCopy = in.getByte();
    myDivider = in.getByte();
    myDividerPending = in.getByte();
    mySampleCounter = in.getByte();
    myDividerChangeCounter = in.getByte();

    myDecodesOffset = in.getByte();
    myDecodes = DrawCounterDecodes::get().playerDecodes()[myDecodesOffset];

    myPatternOld = in.getByte();
    myPatternNew = in.getByte();
    myPattern = in.getByte();

    myIsReflected = in.getBool();
    myIsDelaying = in.getBool();
    myInvertedPhaseClock = in.getBool();

    applyColors();
  }
  catch(...)
  {
    cerr << "ERROR: TIA_Player::load\n";
    return false;
  }

  return true;
}
