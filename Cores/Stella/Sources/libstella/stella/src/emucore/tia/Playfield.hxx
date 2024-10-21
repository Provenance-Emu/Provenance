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

#ifndef TIA_PLAYFIELD
#define TIA_PLAYFIELD

class TIA;

#include "bspf.hxx"
#include "TIAConstants.hxx"
#include "Serializable.hxx"

class Playfield : public Serializable
{
  public:
    /**
      The collision mask is injected at construction
     */
    explicit Playfield(uInt32 collisionMask);

  public:

    /**
      Set the TIA instance
     */
    void setTIA(TIA* tia) { myTIA = tia; }

    /**
      Reset to initial state.
     */
    void reset();

    /**
      PF0 write.
     */
    void pf0(uInt8 value);

    /**
      PF1 write.
     */
    void pf1(uInt8 value);

    /**
      PF2 write.
     */
    void pf2(uInt8 value);

    /**
      CTRLPF write.
     */
    void ctrlpf(uInt8 value);

    /**
      Enable / disable PF display (debugging only, not used during normal emulation).
     */
    void toggleEnabled(bool enabled);

    /**
      Enable / disable PF collisions (debugging only, not used during normal emulation).
     */
    void toggleCollisions(bool enabled);

    /**
      Set color PF.
     */
    void setColor(uInt8 color);

    /**
      Set color P0.
    */
    void setColorP0(uInt8 color);

    /**
      Set color P1.
    */
    void setColorP1(uInt8 color);

    /**
      Set score mode color glitch.
    */
    void setScoreGlitch(bool enable);

    /**
      Set the color used in "debug colors" mode.
     */
    void setDebugColor(uInt8 color);

    /**
      Enable "debug colors" mode.
     */
    void enableDebugColors(bool enabled);

    /**
      Update internal state to use the color loss palette.
     */
    void applyColorLoss();

    /**
      Notify playfield of line change,
     */
    void nextLine();

    /**
      Is the playfield visible? This is determined by looking at bit 15
      of the collision mask.
     */
    inline bool isOn() const { return (collision & 0x8000); }

    /**
      Get the current color.
     */
    uInt8 getColor() const;

    /**
      Serializable methods (see that class for more information).
    */
    bool save(Serializer& out) const override;
    bool load(Serializer& in) override;

    /**
      Tick one color clock. Inline for performance (implementation below).
     */
    FORCE_INLINE void tick(uInt32 x);

  public:

    /**
      16 bit Collision mask. Each sprite is represented by a single bit in the mask
      (1 = active, 0 = inactive). All other bits are always 1. The highest bit is
      abused to store visibility (as the actual collision bit will always be zero
      if collisions are disabled).
     */
    uInt32 collision{0};

  private:

    /**
      Playfield color mode.
     */
    enum class ColorMode: uInt8 {normal, score};

  private:

    /**
      Recalculate playfield color based on COLUPF, debug colors, color loss, etc.
     */
    void applyColors();

    /**
      Recalculate the playfield pattern from PF0, PF1 and PF2.
     */
    void updatePattern();

  private:

    /**
      Collision mask values for active / inactive states. Disabling collisions
      will change those.
     */
    uInt32 myCollisionMaskDisabled{0};
    uInt32 myCollisionMaskEnabled{0xFFFF};

    /**
      Enable / disable PF (debugging).
     */
    bool myIsSuppressed{false};

    /**
      Left / right PF colors. Derifed from P0 / P1 color, COLUPF and playfield mode.
     */
    uInt8 myColorLeft{0};
    uInt8 myColorRight{0};

    /**
      P0 / P1 colors
     */
    uInt8 myColorP0{0};
    uInt8 myColorP1{0};

    /**
      COLUPF and debug colors
     */
    uInt8 myObjectColor{0}, myDebugColor{0};

    /**
      Debug colors enabled?
     */
    bool myDebugEnabled{false};

    /**
     * Playfield color mode.
     */
    ColorMode myColorMode{ColorMode::normal};

    /**
     * Score mode color glitch.
     */
    bool myScoreGlitch{false};

    /**
     * Score mode color switch haste.
     */
    uInt8 myScoreHaste{0};

    /**
      Pattern derifed from PF0, PF1, PF2
     */
    uInt32 myPattern{0};

    /**
      "Effective pattern". Will be 0 if playfield is disabled (debug), otherwise the same as myPattern.
     */
    uInt32 myEffectivePattern{0};

    /**
      Reflected mode on / off.
     */
    bool myReflected{false};

    /**
     * Are we currently drawing the reflected PF?
     */
    bool myRefp{false};

    /**
      PF registers.
    */
    uInt8 myPf0{0};
    uInt8 myPf1{0};
    uInt8 myPf2{0};

    /**
      The current scanline position (0 .. 159).
     */
    uInt32 myX{0};

    /**
      TIA instance. Required for flushing the line cache.
     */
    TIA* myTIA{nullptr};

  private:
    Playfield() = delete;
    Playfield(const Playfield&) = delete;
    Playfield(Playfield&&) = delete;
    Playfield& operator=(const Playfield&) = delete;
    Playfield& operator=(Playfield&&) = delete;
};

// ############################################################################
// Implementation
// ############################################################################

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Playfield::tick(uInt32 x)
{
  myX = x;

  // Reflected flag is updated only at x = 0 or x = 79
  if (myX == TIAConstants::H_PIXEL / 2-1 || myX == 0) myRefp = myReflected;

  if (x & 0x03) return;

  uInt32 currentPixel;

  if (myEffectivePattern == 0) {
      currentPixel = 0;
  } else if (x < TIAConstants::H_PIXEL / 2 - 1) {
      currentPixel = myEffectivePattern & (1 << (x >> 2));
  } else if (myRefp) {
      currentPixel = myEffectivePattern & (1 << (39 - (x >> 2)));
  } else {
      currentPixel = myEffectivePattern & (1 << ((x >> 2) - 20));
  }

  collision = currentPixel ? myCollisionMaskEnabled : myCollisionMaskDisabled;
}

#endif // TIA_PLAYFIELD
