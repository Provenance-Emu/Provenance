#ifdef PPU_CPP

#include "render.cpp"

uint8 PPUDebugger::vram_mmio_read(uint16 addr) {
  uint8 data = PPU::vram_mmio_read(addr);
  debugger.breakpoint_test(Debugger::Breakpoint::VRAM, Debugger::Breakpoint::Read, addr, data);
  return data;
}

void PPUDebugger::vram_mmio_write(uint16 addr, uint8 data) {
  PPU::vram_mmio_write(addr, data);
  debugger.breakpoint_test(Debugger::Breakpoint::VRAM, Debugger::Breakpoint::Write, addr, data);
}

uint8 PPUDebugger::oam_mmio_read(uint16 addr) {
  uint8 data = PPU::oam_mmio_read(addr);
  debugger.breakpoint_test(Debugger::Breakpoint::OAM, Debugger::Breakpoint::Read, addr, data);
  return data;
}

void PPUDebugger::oam_mmio_write(uint16 addr, uint8 data) {
  PPU::oam_mmio_write(addr, data);
  debugger.breakpoint_test(Debugger::Breakpoint::OAM, Debugger::Breakpoint::Write, addr, data);
}

uint8 PPUDebugger::cgram_mmio_read(uint16 addr) {
  uint8 data = PPU::cgram_mmio_read(addr);
  debugger.breakpoint_test(Debugger::Breakpoint::CGRAM, Debugger::Breakpoint::Read, addr, data);
  return data;
}

void PPUDebugger::cgram_mmio_write(uint16 addr, uint8 data) {
  PPU::cgram_mmio_write(addr, data);
  debugger.breakpoint_test(Debugger::Breakpoint::CGRAM, Debugger::Breakpoint::Write, addr, data);
}

PPUDebugger::PPUDebugger() {
  bg1_enabled[0] = bg1_enabled[1] = true;
  bg2_enabled[0] = bg2_enabled[1] = true;
  bg3_enabled[0] = bg3_enabled[1] = true;
  bg4_enabled[0] = bg4_enabled[1] = true;
  oam_enabled[0] = oam_enabled[1] = oam_enabled[2] = oam_enabled[3] = true;
}

//===========
//PPUDebugger
//===========

//internal
unsigned PPUDebugger::ppu1_mdr() { return regs.ppu1_mdr; }
unsigned PPUDebugger::ppu2_mdr() { return regs.ppu2_mdr; }

//$2100
bool PPUDebugger::display_disable() { return regs.display_disabled; }
unsigned PPUDebugger::display_brightness() { return regs.display_brightness; }

//$2101
unsigned PPUDebugger::oam_base_size() { return regs.oam_basesize; }
unsigned PPUDebugger::oam_name_select() { return regs.oam_nameselect; }
unsigned PPUDebugger::oam_name_base_address() { return regs.oam_tdaddr; }

//$2102-$2103
unsigned PPUDebugger::oam_base_address() { return regs.oam_baseaddr; }
bool PPUDebugger::oam_priority() { return regs.oam_priority; }

//$2105
bool PPUDebugger::bg1_tile_size() { return regs.bg_tilesize[BG1]; }
bool PPUDebugger::bg2_tile_size() { return regs.bg_tilesize[BG2]; }
bool PPUDebugger::bg3_tile_size() { return regs.bg_tilesize[BG3]; }
bool PPUDebugger::bg4_tile_size() { return regs.bg_tilesize[BG4]; }
bool PPUDebugger::bg3_priority() { return regs.bg3_priority; }
unsigned PPUDebugger::bg_mode() { return regs.bg_mode; }

//$2106
unsigned PPUDebugger::mosaic_size() { return regs.mosaic_size; }
bool PPUDebugger::bg1_mosaic_enable() { return regs.mosaic_enabled[BG1]; }
bool PPUDebugger::bg2_mosaic_enable() { return regs.mosaic_enabled[BG2]; }
bool PPUDebugger::bg3_mosaic_enable() { return regs.mosaic_enabled[BG3]; }
bool PPUDebugger::bg4_mosaic_enable() { return regs.mosaic_enabled[BG4]; }

//$2107
unsigned PPUDebugger::bg1_screen_address() { return regs.bg_scaddr[BG1]; }
unsigned PPUDebugger::bg1_screen_size() { return regs.bg_scsize[BG1]; }

//$2108
unsigned PPUDebugger::bg2_screen_address() { return regs.bg_scaddr[BG2]; }
unsigned PPUDebugger::bg2_screen_size() { return regs.bg_scsize[BG2]; }

//$2109
unsigned PPUDebugger::bg3_screen_address() { return regs.bg_scaddr[BG3]; }
unsigned PPUDebugger::bg3_screen_size() { return regs.bg_scsize[BG3]; }

//$210a
unsigned PPUDebugger::bg4_screen_address() { return regs.bg_scaddr[BG4]; }
unsigned PPUDebugger::bg4_screen_size() { return regs.bg_scsize[BG4]; }

//$210b
unsigned PPUDebugger::bg1_name_base_address() { return regs.bg_tdaddr[BG1]; }
unsigned PPUDebugger::bg2_name_base_address() { return regs.bg_tdaddr[BG2]; }

//$210c
unsigned PPUDebugger::bg3_name_base_address() { return regs.bg_tdaddr[BG3]; }
unsigned PPUDebugger::bg4_name_base_address() { return regs.bg_tdaddr[BG4]; }

//$210d
unsigned PPUDebugger::mode7_hoffset() { return regs.m7_hofs & 0x1fff; }
unsigned PPUDebugger::bg1_hoffset() { return regs.bg_hofs[BG1] & 0x03ff; }

//$210e
unsigned PPUDebugger::mode7_voffset() { return regs.m7_vofs & 0x1fff; }
unsigned PPUDebugger::bg1_voffset() { return regs.bg_vofs[BG1] & 0x03ff; }

//$210f
unsigned PPUDebugger::bg2_hoffset() { return regs.bg_hofs[BG2] & 0x03ff; }

//$2110
unsigned PPUDebugger::bg2_voffset() { return regs.bg_vofs[BG2] & 0x03ff; }

//$2111
unsigned PPUDebugger::bg3_hoffset() { return regs.bg_hofs[BG3] & 0x03ff; }

//$2112
unsigned PPUDebugger::bg3_voffset() { return regs.bg_vofs[BG3] & 0x03ff; }

//$2113
unsigned PPUDebugger::bg4_hoffset() { return regs.bg_hofs[BG4] & 0x03ff; }

//$2114
unsigned PPUDebugger::bg4_voffset() { return regs.bg_vofs[BG4] & 0x03ff; }

//$2115
bool PPUDebugger::vram_increment_mode() { return regs.vram_incmode; }
unsigned PPUDebugger::vram_increment_formation() { return regs.vram_mapping; }
unsigned PPUDebugger::vram_increment_size() { return regs.vram_incsize; }

//$2116-$2117
unsigned PPUDebugger::vram_address() { return regs.vram_addr; }

//$211a
unsigned PPUDebugger::mode7_repeat() { return regs.mode7_repeat; }
bool PPUDebugger::mode7_vflip() { return regs.mode7_vflip; }
bool PPUDebugger::mode7_hflip() { return regs.mode7_hflip; }

//$211b
unsigned PPUDebugger::mode7_a() { return regs.m7a; }

//$211c
unsigned PPUDebugger::mode7_b() { return regs.m7b; }

//$211d
unsigned PPUDebugger::mode7_c() { return regs.m7c; }

//$211e
unsigned PPUDebugger::mode7_d() { return regs.m7d; }

//$211f
unsigned PPUDebugger::mode7_x() { return regs.m7x; }

//$2120
unsigned PPUDebugger::mode7_y() { return regs.m7y; }

//$2121
unsigned PPUDebugger::cgram_address() { return regs.cgram_addr; }

//$2123
bool PPUDebugger::bg1_window1_enable() { return regs.window1_enabled[BG1]; }
bool PPUDebugger::bg1_window1_invert() { return regs.window1_invert [BG1]; }
bool PPUDebugger::bg1_window2_enable() { return regs.window2_enabled[BG1]; }
bool PPUDebugger::bg1_window2_invert() { return regs.window2_invert [BG1]; }
bool PPUDebugger::bg2_window1_enable() { return regs.window1_enabled[BG2]; }
bool PPUDebugger::bg2_window1_invert() { return regs.window1_invert [BG2]; }
bool PPUDebugger::bg2_window2_enable() { return regs.window2_enabled[BG2]; }
bool PPUDebugger::bg2_window2_invert() { return regs.window2_invert [BG2]; }

//$2124
bool PPUDebugger::bg3_window1_enable() { return regs.window1_enabled[BG3]; }
bool PPUDebugger::bg3_window1_invert() { return regs.window1_invert [BG3]; }
bool PPUDebugger::bg3_window2_enable() { return regs.window2_enabled[BG3]; }
bool PPUDebugger::bg3_window2_invert() { return regs.window2_invert [BG3]; }
bool PPUDebugger::bg4_window1_enable() { return regs.window1_enabled[BG4]; }
bool PPUDebugger::bg4_window1_invert() { return regs.window1_invert [BG4]; }
bool PPUDebugger::bg4_window2_enable() { return regs.window2_enabled[BG4]; }
bool PPUDebugger::bg4_window2_invert() { return regs.window2_invert [BG4]; }

//$2125
bool PPUDebugger::oam_window1_enable() { return regs.window1_enabled[OAM]; }
bool PPUDebugger::oam_window1_invert() { return regs.window1_invert [OAM]; }
bool PPUDebugger::oam_window2_enable() { return regs.window2_enabled[OAM]; }
bool PPUDebugger::oam_window2_invert() { return regs.window2_invert [OAM]; }
bool PPUDebugger::color_window1_enable() { return regs.window1_enabled[COL]; }
bool PPUDebugger::color_window1_invert() { return regs.window1_invert [COL]; }
bool PPUDebugger::color_window2_enable() { return regs.window2_enabled[COL]; }
bool PPUDebugger::color_window2_invert() { return regs.window2_enabled[COL]; }

//$2126
unsigned PPUDebugger::window1_left() { return regs.window1_left; }

//$2127
unsigned PPUDebugger::window1_right() { return regs.window1_right; }

//$2128
unsigned PPUDebugger::window2_left() { return regs.window2_left; }

//$2129
unsigned PPUDebugger::window2_right() { return regs.window2_right; }

//$212a
unsigned PPUDebugger::bg1_window_mask() { return regs.window_mask[BG1]; }
unsigned PPUDebugger::bg2_window_mask() { return regs.window_mask[BG2]; }
unsigned PPUDebugger::bg3_window_mask() { return regs.window_mask[BG3]; }
unsigned PPUDebugger::bg4_window_mask() { return regs.window_mask[BG4]; }

//$212b
unsigned PPUDebugger::oam_window_mask() { return regs.window_mask[OAM]; }
unsigned PPUDebugger::color_window_mask() { return regs.window_mask[COL]; }

//$212c
bool PPUDebugger::bg1_mainscreen_enable() { return regs.bg_enabled[BG1]; }
bool PPUDebugger::bg2_mainscreen_enable() { return regs.bg_enabled[BG2]; }
bool PPUDebugger::bg3_mainscreen_enable() { return regs.bg_enabled[BG3]; }
bool PPUDebugger::bg4_mainscreen_enable() { return regs.bg_enabled[BG4]; }
bool PPUDebugger::oam_mainscreen_enable() { return regs.bg_enabled[OAM]; }

//$212d
bool PPUDebugger::bg1_subscreen_enable() { return regs.bgsub_enabled[BG1]; }
bool PPUDebugger::bg2_subscreen_enable() { return regs.bgsub_enabled[BG2]; }
bool PPUDebugger::bg3_subscreen_enable() { return regs.bgsub_enabled[BG3]; }
bool PPUDebugger::bg4_subscreen_enable() { return regs.bgsub_enabled[BG4]; }
bool PPUDebugger::oam_subscreen_enable() { return regs.bgsub_enabled[OAM]; }

//$212e
bool PPUDebugger::bg1_mainscreen_window_enable() { return regs.window_enabled[BG1]; }
bool PPUDebugger::bg2_mainscreen_window_enable() { return regs.window_enabled[BG2]; }
bool PPUDebugger::bg3_mainscreen_window_enable() { return regs.window_enabled[BG3]; }
bool PPUDebugger::bg4_mainscreen_window_enable() { return regs.window_enabled[BG4]; }
bool PPUDebugger::oam_mainscreen_window_enable() { return regs.window_enabled[OAM]; }

//$212f
bool PPUDebugger::bg1_subscreen_window_enable() { return regs.sub_window_enabled[BG1]; }
bool PPUDebugger::bg2_subscreen_window_enable() { return regs.sub_window_enabled[BG2]; }
bool PPUDebugger::bg3_subscreen_window_enable() { return regs.sub_window_enabled[BG3]; }
bool PPUDebugger::bg4_subscreen_window_enable() { return regs.sub_window_enabled[BG4]; }
bool PPUDebugger::oam_subscreen_window_enable() { return regs.sub_window_enabled[OAM]; }

//$2130
unsigned PPUDebugger::color_mainscreen_window_mask() { return regs.color_mask; }
unsigned PPUDebugger::color_subscreen_window_mask() { return regs.colorsub_mask; }
bool PPUDebugger::color_add_subtract_mode() { return regs.addsub_mode; }
bool PPUDebugger::direct_color() { return regs.direct_color; }

//$2131
bool PPUDebugger::color_mode() { return regs.color_mode; }
bool PPUDebugger::color_halve() { return regs.color_halve; }
bool PPUDebugger::bg1_color_enable() { return regs.color_enabled[BG1]; }
bool PPUDebugger::bg2_color_enable() { return regs.color_enabled[BG2]; }
bool PPUDebugger::bg3_color_enable() { return regs.color_enabled[BG3]; }
bool PPUDebugger::bg4_color_enable() { return regs.color_enabled[BG4]; }
bool PPUDebugger::oam_color_enable() { return regs.color_enabled[OAM]; }
bool PPUDebugger::back_color_enable() { return regs.color_enabled[BACK]; }

//$2132
unsigned PPUDebugger::color_constant_blue() { return regs.color_b; }
unsigned PPUDebugger::color_constant_green() { return regs.color_g; }
unsigned PPUDebugger::color_constant_red() { return regs.color_r; }

//$2133
bool PPUDebugger::mode7_extbg() { return regs.mode7_extbg; }
bool PPUDebugger::pseudo_hires() { return regs.pseudo_hires; }
bool PPUDebugger::overscan() { return regs.overscan; }
bool PPUDebugger::oam_interlace() { return regs.oam_interlace; }
bool PPUDebugger::interlace() { return regs.interlace; }

//$213c
unsigned PPUDebugger::hcounter() { return PPU::hcounter(); }

//$213d
unsigned PPUDebugger::vcounter() { return PPU::vcounter(); }

//$213e
bool PPUDebugger::range_over() { return regs.range_over; }
bool PPUDebugger::time_over() { return regs.time_over; }
unsigned PPUDebugger::ppu1_version() { return PPU::ppu1_version; }

//$213f
bool PPUDebugger::field() { return cpu.field(); }
bool PPUDebugger::region() { return PPU::region; }
unsigned PPUDebugger::ppu2_version() { return PPU::ppu2_version; }

#endif
