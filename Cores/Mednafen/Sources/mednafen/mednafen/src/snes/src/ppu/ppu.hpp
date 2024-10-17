#if defined(DEBUGGER)
  #include "ppu-debugger.hpp"
#endif

//PPUcounter emulates the H/V latch counters of the S-PPU2.
//
//real hardware has the S-CPU maintain its own copy of these counters that are
//updated based on the state of the S-PPU Vblank and Hblank pins. emulating this
//would require full lock-step synchronization for every clock tick.
//to bypass this and allow the two to run out-of-order, both the CPU and PPU
//classes inherit PPUcounter and keep their own counters.
//the timers are kept in sync, as the only differences occur on V=240 and V=261,
//based on interlace. thus, we need only synchronize and fetch interlace at any
//point before this in the frame, which is handled internally by this class at
//V=128.

class PPUcounter {
public:
  alwaysinline void tick();
  alwaysinline void tick(unsigned clocks);

  alwaysinline bool   field   () const;
  alwaysinline uint16 vcounter() const;
  alwaysinline uint16 hcounter() const;
  inline uint16 hdot() const;
  inline uint16 lineclocks() const;

  alwaysinline bool   field   (unsigned offset) const;
  alwaysinline uint16 vcounter(unsigned offset) const;
  alwaysinline uint16 hcounter(unsigned offset) const;

  inline void reset();
  function<void ()> scanline;
  void serialize(serializer&);

private:
  inline void vcounter_tick();

  struct {
    bool interlace;
    bool field;
    uint16 vcounter;
    uint16 hcounter;
  } status;

  struct {
    bool field[2048];
    uint16 vcounter[2048];
    uint16 hcounter[2048];

    int32 index;
  } history;
};

class PPU : public PPUcounter, public MMIO {
public:
  uint16 line_output[512];

  struct {
    bool render_output;
    bool frame_executed;
    bool frames_updated;
    unsigned frames_rendered;
    unsigned frames_executed;
  } status;

  //PPU1 version number
  //* 1 is known
  //* reported by $213e
  uint8 ppu1_version;

  //PPU2 version number
  //* 1 and 3 are known
  //* reported by $213f
  uint8 ppu2_version;

  virtual void enable_renderer(bool r);
  virtual bool renderer_enabled();

  #include "memory/memory.hpp"
  #include "mmio/mmio.hpp"
  #include "render/render.hpp"

  void enter();
  void add_clocks(unsigned clocks);

  uint8 region;
  unsigned line;

  enum { NTSC = 0, PAL = 1 };
  enum { BG1 = 0, BG2 = 1, BG3 = 2, BG4 = 3, OAM = 4, BACK = 5, COL = 5 };
  enum { SC_32x32 = 0, SC_64x32 = 1, SC_32x64 = 2, SC_64x64 = 3 };

  struct {
    bool interlace;
    bool overscan;
  } display;

  struct {
    //$2101
    uint8  oam_basesize;
    uint8  oam_nameselect;
    uint16 oam_tdaddr;

    //$210d-$210e
    uint16 m7_hofs, m7_vofs;

    //$211b-$2120
    uint16 m7a, m7b, m7c, m7d, m7x, m7y;
  } cache;

  alwaysinline bool interlace() const { return display.interlace; }
  alwaysinline bool overscan()  const { return display.overscan;  }
  alwaysinline bool hires()     const { return (regs.pseudo_hires || regs.bg_mode == 5 || regs.bg_mode == 6); }

  uint16 light_table_b[16][32];
  uint16 light_table_gr[16][32 * 32];
  uint16 mosaic_table[16][4096];
  void render_line();

  void update_oam_status();
  //required functions
  void run();
  void scanline();
  void render_scanline();
  void frame();
  void power();
  void reset();

  void serialize(serializer&);
  PPU();
  ~PPU();

  friend class PPUDebug;
};

#if defined(DEBUGGER)
  #include "debugger/debugger.hpp"
  extern PPUDebugger ppu;
#else
  extern PPU ppu;
#endif
