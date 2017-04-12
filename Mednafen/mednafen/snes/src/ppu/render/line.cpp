#ifdef PPU_CPP

alwaysinline uint16 PPU::get_palette(uint8 index) {
  const unsigned addr = index << 1;
  return memory::cgram[addr] + (memory::cgram[addr + 1] << 8);
}

//p = 00000bgr <palette data>
//t = BBGGGRRR <tilemap data>
//r = 0BBb00GGGg0RRRr0 <return data>
alwaysinline uint16 PPU::get_direct_color(uint8 p, uint8 t) {
  return ((t & 7) << 2) | ((p & 1) << 1) |
    (((t >> 3) & 7) << 7) | (((p >> 1) & 1) << 6) |
    ((t >> 6) << 13) | ((p >> 2) << 12);
}

alwaysinline uint16 PPU::get_pixel_normal(uint32 x) {
  pixel_t &p = pixel_cache[x];
  uint16 src_main, src_sub;
  uint8  bg_sub;
  src_main = p.src_main;

  if(!regs.addsub_mode) {
    bg_sub  = BACK;
    src_sub = regs.color_rgb;
  } else {
    bg_sub  = p.bg_sub;
    src_sub = p.src_sub;
  }

  if(!window[COL].main[x]) {
    if(!window[COL].sub[x]) {
      return 0x0000;
    }
    src_main = 0x0000;
  }

  if(!p.ce_main && regs.color_enabled[p.bg_main] && window[COL].sub[x]) {
    bool halve = false;
    if(regs.color_halve && window[COL].main[x]) {
      if(regs.addsub_mode && bg_sub == BACK);
      else {
        halve = true;
      }
    }
    return addsub(src_main, src_sub, halve);
  }

  return src_main;
}

alwaysinline uint16 PPU::get_pixel_swap(uint32 x) {
  pixel_t &p = pixel_cache[x];
  uint16 src_main, src_sub;
  uint8  bg_sub;
  src_main = p.src_sub;

  if(!regs.addsub_mode) {
    bg_sub  = BACK;
    src_sub = regs.color_rgb;
  } else {
    bg_sub  = p.bg_main;
    src_sub = p.src_main;
  }

  if(!window[COL].main[x]) {
    if(!window[COL].sub[x]) {
      return 0x0000;
    }
    src_main = 0x0000;
  }

  if(!p.ce_sub && regs.color_enabled[p.bg_sub] && window[COL].sub[x]) {
    bool halve = false;
    if(regs.color_halve && window[COL].main[x]) {
      if(regs.addsub_mode && bg_sub == BACK);
      else {
        halve = true;
      }
    }
    return addsub(src_main, src_sub, halve);
  }

  return src_main;
}

alwaysinline void PPU::render_line_output() {
  //printf("RLO: %u\n", line);
  uint16 *ptr  = line_output;
  uint16 *luma_b  = light_table_b [regs.display_brightness];
  uint16 *luma_gr = light_table_gr[regs.display_brightness];
  uint16 curr;

  if(!regs.pseudo_hires && regs.bg_mode != 5 && regs.bg_mode != 6) {
    if(regs.display_brightness == 15) {
      for(unsigned x = 0; x < 256; x++) {
        *ptr++ = get_pixel_normal(x);
      }
    } else {
      for(unsigned x = 0; x < 256; x++) {
        curr = get_pixel_normal(x);
        *ptr++ = luma_b[curr >> 10] + luma_gr[curr & 0x3ff];
      }
    }
  } else {
    //printf("%d %d\n", regs.pseudo_hires, regs.bg_mode);
    if(regs.display_brightness == 15) {
      for(unsigned x = 0, prev = 0; x < 256; x++) {
        *ptr++ = get_pixel_swap(x);
        *ptr++ = get_pixel_normal(x);
      }
    } else {
      for(unsigned x = 0, prev = 0; x < 256; x++) {
        curr = get_pixel_swap(x);
        *ptr++ = luma_b[curr >> 10] + luma_gr[curr & 0x3ff];

        curr = get_pixel_normal(x);
        *ptr++ = luma_b[curr >> 10] + luma_gr[curr & 0x3ff];
      }
    }
    line_output[0] = (line_output[0] & 0x7FFF) | (regs.pseudo_hires ? 0x8000 : 0);
  }
}

alwaysinline void PPU::render_line_clear() {
  uint16 width = (!regs.pseudo_hires && regs.bg_mode != 5 && regs.bg_mode != 6) ? 256 : 512;
  memset(line_output, 0, width * sizeof(uint16));
}

#endif
