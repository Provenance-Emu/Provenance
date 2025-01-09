#ifdef SYSTEM_CPP

Video video;

const uint8_t Video::cursor[15][16] = {
  { 0,0,0,0,0,0,1,1,1,0,0,0,0,0,0 },
  { 0,0,0,0,1,1,2,2,2,1,1,0,0,0,0 },
  { 0,0,0,1,2,2,1,2,1,2,2,1,0,0,0 },
  { 0,0,1,2,1,1,0,1,0,1,1,2,1,0,0 },
  { 0,1,2,1,0,0,0,1,0,0,0,1,2,1,0 },
  { 0,1,2,1,0,0,1,2,1,0,0,1,2,1,0 },
  { 1,2,1,0,0,1,1,2,1,1,0,0,1,2,1 },
  { 1,2,2,1,1,2,2,2,2,2,1,1,2,2,1 },
  { 1,2,1,0,0,1,1,2,1,1,0,0,1,2,1 },
  { 0,1,2,1,0,0,1,2,1,0,0,1,2,1,0 },
  { 0,1,2,1,0,0,0,1,0,0,0,1,2,1,0 },
  { 0,0,1,2,1,1,0,1,0,1,1,2,1,0,0 },
  { 0,0,0,1,2,2,1,2,1,2,2,1,0,0,0 },
  { 0,0,0,0,1,1,2,2,2,1,1,0,0,0,0 },
  { 0,0,0,0,0,0,1,1,1,0,0,0,0,0,0 }
};

void Video::draw_cursor(const int rline, const bool hires, const uint16_t color, const int x, const int y)
{
 const int cy = rline - y + 7;

 if(cy < 0 || cy > 14)
  return;

 for(int cx = 0; cx < 15; cx++) {
   int vx = x + cx - 7;
   if(vx < 0 || vx >= 256) continue;  //do not draw offscreen
   uint8_t pixel = cursor[cy][cx];
   if(pixel == 0) continue;
   uint16_t pixelcolor = (pixel == 1) ? 0 : color;

   if(hires == false) {
     ppu.line_output[vx] = pixelcolor;
   } else {
     ppu.line_output[vx * 2 + 0] = pixelcolor;
     ppu.line_output[vx * 2 + 1] = pixelcolor;
   }
 }
}

void Video::update() {
  frame_interlace = false;
}

void Video::scanline() {
  unsigned y = cpu.vcounter();
  if(y >= 240) return;

  if(y == 0)
  {
   frame_field = cpu.field();
   frame_interlace = ppu.interlace();
  }
}

void Video::render_scanline(unsigned line)
{
  const bool hires = ppu.hires();
  unsigned yoffset = 1;  //scanline 0 is always black, skip this line for video output
  unsigned width = (hires ? 512 : 256);
  unsigned height;

  switch(input.port[1].device) {
    case Input::DeviceSuperScope: draw_cursor(line, hires, 0x001f, input.port[1].superscope.x, input.port[1].superscope.y); break;
    case Input::DeviceJustifiers: draw_cursor(line, hires, 0x02e0, input.port[1].justifier.x2, input.port[1].justifier.y2); //fallthrough
    case Input::DeviceJustifier:  draw_cursor(line, hires, 0x001f, input.port[1].justifier.x1, input.port[1].justifier.y1); break;
  }

  if(mode == ModeNTSC && ppu.overscan()) yoffset += 8;  //NTSC overscan centers x240 height image
  //printf("%u\n", ppu.overscan());
  switch(mode) {
    default:
    case ModeNTSC: { height = 224; } break;
    case ModePAL:  { height = 239; } break;
  }

  if(line >= yoffset && line < (yoffset + height))
  {
   //printf("%d --- %d\n", line, line - yoffset);
   system.interface->video_scanline(ppu.line_output, line - yoffset, width, height, frame_interlace, frame_field);
  }
}

void Video::set_mode(Mode mode_) {
  mode = mode_;
}

void Video::init() {
  frame_interlace = false;
  frame_field = false;
  set_mode(ModeNTSC);
}

#endif
