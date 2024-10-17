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

#ifndef TIA_PLAYER
#define TIA_PLAYER

class TIA;

#include "bspf.hxx"
#include "Serializable.hxx"
#include "TIAConstants.hxx"

class Player : public Serializable
{
  public:
    explicit Player(uInt32 collisionMask);

  public:

    void setTIA(TIA* tia) { myTIA = tia; }

    void reset();

    void grp(uInt8 pattern);

    void hmp(uInt8 value);

    void nusiz(uInt8 value, bool hblank);

    void resp(uInt8 counter);

    void refp(uInt8 value);

    void vdelp(uInt8 value);

    void toggleEnabled(bool enabled);

    void toggleCollisions(bool enabled);

    void setColor(uInt8 color);

    void setDebugColor(uInt8 color);
    void enableDebugColors(bool enabled);

    void applyColorLoss();

    void setInvertedPhaseClock(bool enable);

    void startMovement();

    void nextLine();

    uInt8 getClock() const { return myCounter; }

    inline bool isOn() const { return (collision & 0x8000); }
    uInt8 getColor() const;

    void shufflePatterns();

    uInt8 getRespClock() const;

    uInt8 getPosition() const;
    void setPosition(uInt8 newPosition);

    uInt8 getGRPOld() const { return myPatternOld; }
    uInt8 getGRPNew() const { return myPatternNew; }

    void setGRPOld(uInt8 pattern);

    /**
      Serializable methods (see that class for more information).
    */
    bool save(Serializer& out) const override;
    bool load(Serializer& in) override;

    FORCE_INLINE void movementTick(uInt32 clock, bool hblank);

    FORCE_INLINE void tick();

  public:

    uInt32 collision{0};
    bool isMoving{false};

  private:

    void updatePattern();
    void applyColors();
    void setDivider(uInt8 divider);

  private:

    enum Count: Int8 {
      renderCounterOffset = -5,
    };

  private:

    uInt32 myCollisionMaskDisabled{0};
    uInt32 myCollisionMaskEnabled{0xFFFF};

    uInt8 myColor{0};
    uInt8 myObjectColor{0}, myDebugColor{0};
    bool myDebugEnabled{0};

    bool myIsSuppressed{false};

    uInt8 myHmmClocks{0};
    uInt8 myCounter{0};

    bool myIsRendering{false};
    Int8 myRenderCounter{0};
    Int8 myRenderCounterTripPoint{0};
    Int8 myCopy{1};
    uInt8 myDivider{0};
    uInt8 myDividerPending{0};
    uInt8 mySampleCounter{0};
    Int8 myDividerChangeCounter{-1};

    const uInt8* myDecodes{nullptr};
    uInt8 myDecodesOffset{0};  // needed for state saving

    uInt8 myPatternOld{0};
    uInt8 myPatternNew{0};
    uInt8 myPattern{0};

    bool myIsReflected{false};
    bool myIsDelaying{false};
    bool myInvertedPhaseClock{false};
    bool myUseInvertedPhaseClock{false};

    TIA* myTIA{nullptr};

  private:
    Player(const Player&) = delete;
    Player(Player&&) = delete;
    Player& operator=(const Player&) = delete;
    Player& operator=(Player&&) = delete;
};

// ############################################################################
// Implementation
// ############################################################################

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Player::movementTick(uInt32 clock, bool hblank)
{
  if(isMoving)
  {
    // Stop movement once the number of clocks according to HMPx is reached
    if (clock == myHmmClocks)
      isMoving = false;
    else
    {
      // Process the tick if we are in hblank. Otherwise, the tick is either masked
      // by an ordinary tick or merges two consecutive ticks into a single tick (inverted
      // movement clock phase mode).
      if(hblank) tick();
      // Track a tick outside hblank for later processing
      myInvertedPhaseClock = !hblank;
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Player::tick()
{
  // If we are in inverted movement clock phase mode and a movement tick occurred, it
  // will supress the tick.
  if(myUseInvertedPhaseClock && myInvertedPhaseClock)
  {
    myInvertedPhaseClock = false;
    return;
  }

  if (!myIsRendering || myRenderCounter < myRenderCounterTripPoint)
    collision = myCollisionMaskDisabled;
  else
    collision = (myPattern & (1 << mySampleCounter)) ? myCollisionMaskEnabled : myCollisionMaskDisabled;

  if (myDecodes[myCounter]) {
    myIsRendering = true;
    mySampleCounter = 0;
    myRenderCounter = renderCounterOffset;
    myCopy = myDecodes[myCounter];
  } else if (myIsRendering) {
    ++myRenderCounter;

    switch (myDivider) {
      case 1:
        if (myRenderCounter > 0)
          ++mySampleCounter;

        if (myRenderCounter >= 0 && myDividerChangeCounter >= 0 && myDividerChangeCounter-- == 0)
          setDivider(myDividerPending);

        break;

      default:
        if (myRenderCounter > 1 && (((myRenderCounter - 1) % myDivider) == 0))
          ++mySampleCounter;

        if (myRenderCounter > 0 && myDividerChangeCounter >= 0 && myDividerChangeCounter-- == 0)
          setDivider(myDividerPending);

        break;
    }

    if (mySampleCounter > 7) myIsRendering = false;
  }

  if (++myCounter >= TIAConstants::H_PIXEL) myCounter = 0;
}

#endif // TIA_PLAYER
