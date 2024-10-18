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

#ifndef TIA_ABSTRACT_FRAME_MANAGER
#define TIA_ABSTRACT_FRAME_MANAGER

#include <functional>

#include "Serializable.hxx"
#include "FrameLayout.hxx"
#include "bspf.hxx"

class AbstractFrameManager : public Serializable
{
  public:

    using callback = std::function<void()>;

  public:

    AbstractFrameManager();

  public:

    /**
     * Configure the various handler callbacks.
     */
    void setHandlers(
      const callback& frameStartCallback,
      const callback& frameCompletionCallback
    );

    /**
     * Clear the configured handler callbacks.
     */
    void clearHandlers();

    /**
     * Reset.
     */
    void reset();

    /**
     * Called by TIA to notify the start of the next scanline.
     */
    void nextLine();

    /**
     * Called by TIA on VBLANK writes.
     */
    void setVblank(bool vblank);

    /**
     * Called by TIA on VSYNC writes.
     */
    void setVsync(bool vsync, uInt64 cycles);

    /**
     * Called when a pixel is rendered.
    */
    virtual void pixelColor(uInt8 color) {}

    /**
     * Should the TIA render its frame? This is buffered in a flag for
     * performance reasons; descendants must update the flag.
     */
    inline bool isRendering() const { return myIsRendering; }

    /**
     * Is vsync on?
     */
    bool vsync() const { return myVsync; }

    /**
     * Is vblank on?
     */
    inline bool vblank() const { return myVblank; }

    /**
     * The number of scanlines in the last finished frame.
     */
    uInt32 scanlinesLastFrame() const { return myCurrentFrameFinalLines; }

    /**
     * Did the number of scanlines switch between even / odd (used for color loss
     * emulation).
     */
    bool scanlineParityChanged() const {
      return (myPreviousFrameFinalLines & 0x1) != (myCurrentFrameFinalLines & 0x1);
    }

    /**
     * The total number of frames. 32 bit should be good for > 2 years :)
     */
    uInt32 frameCount() const { return myTotalFrames; }

    /**
     * The configured (our autodetected) frame layout (PAL / NTSC).
     */
    FrameLayout layout() const { return myLayout; }

    /**
     * Save state.
     */
    bool save(Serializer& out) const override;

    /**
     * Restore state.
     */
    bool load(Serializer& in) override;

  public:
    // The following methods are implement as noops and should be overriden as
    // required. All of these are irrelevant if nothing is displayed (during
    // autodetect).

    /**
    * The jitter sensitivity determines jitter simulation sensitivity to unstable video signals.
    */
    virtual void setJitterSensitivity(uInt8 sensitivity) {}

    /**
     * The jitter factor determines the time jitter simulation takes to recover.
     */
    virtual void setJitterRecovery(uInt8 factor) {}

    /**
     * Is jitter simulation enabled?
     */
    virtual bool jitterEnabled() const { return false; }

    /**
     * Enable jitter simulation
     */
    virtual void enableJitter(bool enabled) {}

    /**
     * Is vsync according to spec?
     */
    virtual bool vsyncCorrect() const { return true; }

    /**
     * The scanline difference between the last two frames. Used in the TIA to
     * clear any scanlines that were not repainted.
     */
    virtual Int32 missingScanlines() const { return 0; }

    /**
     * Frame height.
     */
    virtual uInt32 height() const { return 0; }

    /**
     * The current y coordinate (valid only during rendering).
     */
    virtual uInt32 getY() const { return 0; }

    /**
     * The current number of scanlines in the current frame (including invisible
     * lines).
     */
    virtual uInt32 scanlines() const { return 0; }

    /**
     * Configure the vcenter value.
     */
    virtual void setVcenter(Int32 vcenter) {}

    /**
     * The configured vcenter value.
     */
    virtual Int32 vcenter() const { return 0; }

    /**
     * The calculated minimal vcenter value.
     */
    virtual Int32 minVcenter() const { return 0; }

    /**
     * The calculated maximal vcenter value.
     */
    virtual Int32 maxVcenter() const { return 0; }


    virtual void setAdjustVSize(Int32 adjustVSize) {}

    virtual Int32 adjustVSize() const { return 0; }

    /**
     * The corresponding start line.
     */
    virtual uInt32 startLine() const { return 0; }

    /**
     * Set the frame layout. This may be a noop (on the autodetection manager).
     */
    virtual void setLayout(FrameLayout mode) {}

  protected:
    // The following are template methods that can be implemented to hook into
    // the frame logic.

    /**
     * Called if vblank changes.
     */
    virtual void onSetVblank() {}

    /**
     * Called if vsync changes.
     */
    virtual void onSetVsync(uInt64 cycles) {}

    /**
     * Called if the next line is signalled, after the internal bookkeeping has
     * been updated.
     */
    virtual void onNextLine() {}

    /**
     * Called on reset (after the base class has reset).
     */
    virtual void onReset() {}

    /**
     * Called after a frame layout change.
     */
    virtual void onLayoutChange() {}

    /**
     * Called during state save (after the base class has serialized its state).
     */
    virtual bool onSave(Serializer& out) const { throw runtime_error("cannot be serialized"); }

    /**
     * Called during state restore (after the base class has restored its state).
     */
    virtual bool onLoad(Serializer& in) { throw runtime_error("cannot be serialized"); }

  protected:
    // These need to be called in order to drive the frame lifecycle of the
    // emulation.

    /**
     * Signal frame start.
     */
    void notifyFrameStart();

    /**
     * Signal frame stop.
     */
    void notifyFrameComplete();

    /**
     * The internal setter to update the frame layout.
     */
    void layout(FrameLayout layout);

  protected:

    /**
     * Rendering flag.
     */
    bool myIsRendering{false};

    /**
     * Vsync flag.
     */
    bool myVsync{false};

    /**
     * Vblank flag.
     */
    bool myVblank{false};

    /**
     * Current scanline count in the current frame.
     */
    uInt32 myCurrentFrameTotalLines{0};

    /**
     * Total number of scanlines in the last complete frame.
     */
    uInt32 myCurrentFrameFinalLines{0};

    /**
     * Total number of scanlines in the second last complete frame.
     */
    uInt32 myPreviousFrameFinalLines{0};

    /**
     * Total frame count.
     */
    uInt32 myTotalFrames{0};

  private:

    /**
     * Current frame layout.
     */
    FrameLayout myLayout{FrameLayout::pal};

    /**
     * The various lifecycle callbacks.
     */
    callback myOnFrameStart{nullptr};
    callback myOnFrameComplete{nullptr};

  private:

    AbstractFrameManager(const AbstractFrameManager&) = delete;
    AbstractFrameManager(AbstractFrameManager&&) = delete;
    AbstractFrameManager& operator=(const AbstractFrameManager&) = delete;
    AbstractFrameManager& operator=(AbstractFrameManager&&) = delete;

};

#endif // TIA_ABSTRACT_FRAME_MANAGER
