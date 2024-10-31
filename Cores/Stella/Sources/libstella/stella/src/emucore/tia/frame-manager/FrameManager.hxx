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

#ifndef TIA_FRAME_MANAGER
#define TIA_FRAME_MANAGER

#include "AbstractFrameManager.hxx"
#include "TIAConstants.hxx"
#include "bspf.hxx"
#include "JitterEmulation.hxx"

class FrameManager: public AbstractFrameManager {
  public:

    enum Metrics : uInt32 {
      vblankNTSC = 37,
      vblankPAL = 45,
      vsync = 3,
      frameSizeNTSC = 262,
      frameSizePAL = 312,
      baseHeightNTSC = 228, // 217..239
      baseHeightPAL = 274, // 260..288
      maxHeight = static_cast<uInt32>(baseHeightPAL * 1.05 + 0.5), // 288
      maxLinesVsync = 50,
      initialGarbageFrames = TIAConstants::initialGarbageFrames,
      ystartNTSC = 23,
      ystartPAL = 32
    };


  public:

    FrameManager();

  public:
    void setJitterSensitivity(uInt8 sensitivity) override { myJitterEmulation.setSensitivity(sensitivity); }

    void setJitterRecovery(uInt8 factor) override { myJitterEmulation.setRecovery(factor); }

    bool jitterEnabled() const override { return myJitterEnabled; }

    void enableJitter(bool enabled) override { myJitterEnabled = enabled; }

    bool vsyncCorrect() const override { return !myJitterEnabled || myJitterEmulation.vsyncCorrect(); }

    uInt32 height() const override { return myHeight; }

    uInt32 getY() const override { return myY; }

    uInt32 scanlines() const override { return myCurrentFrameTotalLines; }

    Int32 missingScanlines() const override;

    void setVcenter(Int32 vcenter) override;

    Int32 vcenter() const override { return myVcenter; }

    Int32 minVcenter() const override { return TIAConstants::minVcenter; }

    Int32 maxVcenter() const override { return myMaxVcenter; }

    void setAdjustVSize(Int32 adjustVSize) override;

    Int32 adjustVSize() const override { return myVSizeAdjust; }

    uInt32 startLine() const override { return myYStart; }

    void setLayout(FrameLayout mode) override { layout(mode); }

    void onSetVsync(uInt64 cycles) override;

    void onNextLine() override;

    void onReset() override;

    void onLayoutChange() override;

    bool onSave(Serializer& out) const override;

    bool onLoad(Serializer& in) override;

  private:

    enum class State {
      waitForVsyncStart,
      waitForVsyncEnd,
      waitForFrameStart,
      frame
    };

  private:

    void setState(State state);

    void updateIsRendering();

    void recalculateMetrics();

  private:

    State myState{State::waitForVsyncStart};
    uInt32 myLineInState{0};
    uInt32 myVsyncLines{0};
    uInt32 myY{0}, myLastY{0};

    uInt32 myVblankLines{0};
    uInt32 myFrameLines{0};
    uInt32 myHeight{0};
    uInt32 myYStart{0};
    Int32 myVcenter{0};
    Int32 myMaxVcenter{0};
    Int32 myVSizeAdjust{0};

    uInt64 myVsyncStart{0};
    uInt64 myVsyncEnd{0};
    bool myJitterEnabled{false};

    JitterEmulation myJitterEmulation;

  private:

    FrameManager(const FrameManager&) = delete;
    FrameManager(FrameManager&&) = delete;
    FrameManager& operator=(const FrameManager&) = delete;
    FrameManager& operator=(FrameManager&&) = delete;
};

#endif // TIA_FRAME_MANAGER
