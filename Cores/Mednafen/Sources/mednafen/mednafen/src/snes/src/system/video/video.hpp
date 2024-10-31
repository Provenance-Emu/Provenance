class Video {
public:
  enum Mode {
    ModeNTSC,
    ModePAL,
  };
  void set_mode(Mode);

private:
  Mode mode;
  bool frame_interlace;
  bool frame_field;

  void update();
  void scanline();
  void render_scanline(unsigned line);
  void init();

  static const uint8_t cursor[15][16];
  void draw_cursor(const int rline, const bool hires, const uint16_t color, const int x, const int y);

  friend class System;
  friend class PPU;	// Just for render_scanline()
};

extern Video video;
