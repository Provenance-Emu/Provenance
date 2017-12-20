// WARNING WARNING WARNING:  ONLY use CanRead() method of BlitterFIFO, and NOT CanWrite(), since the FIFO is larger than the actual PS1 GPU FIFO to accommodate
// our lack of fancy superscalarish command sequencer.

#ifndef __MDFN_PSX_GPU_H
#define __MDFN_PSX_GPU_H

#include "FastFIFO.h"

namespace MDFN_IEN_PSX
{

class PS_GPU;

struct CTEntry
{
 void (*func[4][8])(PS_GPU* g, const uint32 *cb);
 uint8 len;
 uint8 fifo_fb_len;
 bool ss_cmd;
};

struct tri_vertex
{
 int32 x, y;
 int32 u, v;
 int32 r, g, b;
};

struct i_group;
struct i_deltas;

struct line_point
{
 int32 x, y;
 uint8 r, g, b;
};

class PS_GPU
{
 public:

 PS_GPU(bool pal_clock_and_tv, int sls, int sle, bool show_h_overscan) MDFN_COLD;
 ~PS_GPU() MDFN_COLD;

 void FillVideoParams(MDFNGI* gi) MDFN_COLD;

 void Power(void) MDFN_COLD;

 void StateAction(StateMem *sm, const unsigned load, const bool data_only);

 void ResetTS(void);

 void StartFrame(EmulateSpecStruct *espec);

 pscpu_timestamp_t Update(const pscpu_timestamp_t timestamp);

 void Write(const pscpu_timestamp_t timestamp, uint32 A, uint32 V);

 INLINE bool CalcFIFOReadyBit(void)
 {
  if(InCmd & (INCMD_PLINE | INCMD_QUAD))
   return(false);

  if(BlitterFIFO.CanRead() == 0)
   return(true);

  if(InCmd & (INCMD_FBREAD | INCMD_FBWRITE))
   return(false);

  if(BlitterFIFO.CanRead() >= Commands[BlitterFIFO.Peek() >> 24].fifo_fb_len)
   return(false);

  return(true);
 }

 INLINE bool DMACanWrite(void)
 {
  return CalcFIFOReadyBit();
 }

 void WriteDMA(uint32 V);
 uint32 ReadDMA(void);

 uint32 Read(const pscpu_timestamp_t timestamp, uint32 A);

 inline int32 GetScanlineNum(void)
 {
  return(scanline);
 } 

 INLINE uint16 PeekRAM(uint32 A)
 {
  return(GPURAM[(A >> 10) & 0x1FF][A & 0x3FF]);
 }

 INLINE void PokeRAM(uint32 A, uint16 V)
 {
  GPURAM[(A >> 10) & 0x1FF][A & 0x3FF] = V;
 }

 private:

 uint16 CLUT_Cache[256];
 uint32 CLUT_Cache_VB;	// Don't try to be clever and reduce it to 16 bits... ~0U is value for invalidated state.

 template<uint32 TexMode_TA>
 void Update_CLUT_Cache(uint16 raw_clut);

 struct	// Speedup-cache varibles, derived from other variables; shouldn't be saved in save states.
 {
  // TW*_* variables derived from tww, twh, twx, twy, TexPageX, TexPageY
  uint32 TWX_AND;
  uint32 TWX_ADD;

  uint32 TWY_AND;
  uint32 TWY_ADD;
 } SUCV;
 void RecalcTexWindowStuff(void);

 struct
 {
  uint16 Data[4];
  uint32 Tag;
 } TexCache[256];

 void InvalidateTexCache(void);
 void InvalidateCache(void);

 void SetTPage(uint32);

 void ProcessFIFO(void);
 void WriteCB(uint32 data);
 uint32 ReadData(void);
 void SoftReset(void);

 uint32 DMAControl;

 //
 // Drawing stuff
 //
 //int32 TexPageX;	// 0, 64, 128, 192, etc up to 960
 //int32 TexPageY;	// 0 or 256
 //uint32 abr;		// Semi-transparency mode(0~3)
 //bool dtd;		// Dithering enable

 int32 ClipX0;
 int32 ClipY0;
 int32 ClipX1;
 int32 ClipY1;

 int32 OffsX;
 int32 OffsY;

 bool dtd;
 bool dfe;

 uint32 MaskSetOR;
 uint32 MaskEvalAND;

 bool TexDisable;
 bool TexDisableAllowChange;

 uint8 tww, twh, twx, twy;
 
 uint32 TexPageX;
 uint32 TexPageY;

 uint32 SpriteFlip;

 uint32 abr;
 uint32 TexMode;

 uint8 DitherLUT[4][4][512];	// Y, X, 8-bit source value(256 extra for saturation)

 bool LineSkipTest(unsigned y);

 template<int BlendMode, bool MaskEval_TA, bool textured>
 void PlotPixel(uint32 x, uint32 y, uint16 pix);

 template<uint32 TexMode_TA>
 uint16 GetTexel(uint32 u, uint32 v);

 uint16 ModTexel(uint16 texel, int32 r, int32 g, int32 b, const int32 dither_x, const int32 dither_y);

 template<bool goraud, bool textured, int BlendMode, bool TexMult, uint32 TexMode, bool MaskEval_TA>
 void DrawSpan(int y, const int32 x_start, const int32 x_bound, i_group ig, const i_deltas &idl);

 template<bool shaded, bool textured, int BlendMode, bool TexMult, uint32 TexMode_TA, bool MaskEval_TA>
 void DrawTriangle(tri_vertex *vertices);

 template<bool textured, int BlendMode, bool TexMult, uint32 TexMode_TA, bool MaskEval_TA, bool FlipX, bool FlipY>
 void DrawSprite(int32 x_arg, int32 y_arg, int32 w, int32 h, uint8 u_arg, uint8 v_arg, uint32 color);

 template<bool goraud, int BlendMode, bool MaskEval_TA>
 void DrawLine(line_point *vertices);


 public:
 template<int numvertices, bool shaded, bool textured, int BlendMode, bool TexMult, uint32 TexMode_TA, bool MaskEval_TA>
 void Command_DrawPolygon(const uint32 *cb);

 template<uint8 raw_size, bool textured, int BlendMode, bool TexMult, uint32 TexMode_TA, bool MaskEval_TA>
 void Command_DrawSprite(const uint32 *cb);

 template<bool polyline, bool goraud, int BlendMode, bool MaskEval_TA>
 void Command_DrawLine(const uint32 *cb);

 void Command_ClearCache(const uint32 *cb);
 void Command_IRQ(const uint32 *cb);

 void Command_FBFill(const uint32 *cb);
 void Command_FBCopy(const uint32 *cb);
 void Command_FBWrite(const uint32 *cb);
 void Command_FBRead(const uint32 *cb);

 void Command_DrawMode(const uint32 *cb);
 void Command_TexWindow(const uint32 *cb);
 void Command_Clip0(const uint32 *cb);
 void Command_Clip1(const uint32 *cb);
 void Command_DrawingOffset(const uint32 *cb);
 void Command_MaskSetting(const uint32 *cb);

 private:
 static CTEntry Commands[256];
 static const CTEntry Commands_00_1F[0x20];
 static const CTEntry Commands_20_3F[0x20];
 static const CTEntry Commands_40_5F[0x20];
 static const CTEntry Commands_60_7F[0x20];
 static const CTEntry Commands_80_FF[0x80];

 FastFIFO<uint32, 0x20> BlitterFIFO; // 0x10 on actual PS1 GPU, 0x20 here(see comment at top of gpu.h)
 uint32 DataReadBuffer;
 uint32 DataReadBufferEx;

 bool IRQPending;
 //
 //
 //
 // Powers of 2 for faster multiple equality testing(just for multi-testing; InCmd itself will only contain 0, or a power of 2).
 enum
 {
  INCMD_NONE = 0,
  INCMD_PLINE = (1 << 0),
  INCMD_QUAD = (1 << 1),
  INCMD_FBWRITE = (1 << 2),
  INCMD_FBREAD = (1 << 3)
 };
 uint8 InCmd;
 uint8 InCmd_CC;

 tri_vertex InQuad_F3Vertices[3];

 line_point InPLine_PrevPoint;

 uint32 FBRW_X;
 uint32 FBRW_Y;
 uint32 FBRW_W;
 uint32 FBRW_H;
 uint32 FBRW_CurY;
 uint32 FBRW_CurX;

 //
 // Display Parameters
 //
 uint32 DisplayMode;

 bool DisplayOff;
 uint32 DisplayFB_XStart;
 uint32 DisplayFB_YStart;

 uint32 HorizStart;
 uint32 HorizEnd;

 uint32 VertStart;
 uint32 VertEnd;

 //
 // Display work vars
 //
 uint32 DisplayFB_CurYOffset;
 uint32 DisplayFB_CurLineYReadout;

 bool InVBlank;

 //
 //
 //
 uint32 LinesPerField;
 uint32 scanline;
 bool field;
 bool field_ram_readout;
 bool PhaseChange;

 uint32 DotClockCounter;

 uint64 GPUClockCounter;
 uint32 GPUClockRatio;
 int32 LineClockCounter;
 int32 LinePhase;

 int32 DrawTimeAvail;

 pscpu_timestamp_t lastts;

 // Y, X
 uint16 GPURAM[512][1024];

 //
 //
 //
 int32 hmc_to_visible;
 bool hide_hoverscan;

 bool sl_zero_reached;
 //
 //

 EmulateSpecStruct *espec;
 MDFN_Surface *surface;
 MDFN_Rect *DisplayRect;
 int32 *LineWidths;
 bool skip;
 bool HardwarePALType;
 int LineVisFirst, LineVisLast;

 uint32 OutputLUT[384];
 void ReorderRGB_Var(uint32 out_Rshift, uint32 out_Gshift, uint32 out_Bshift, bool bpp24, const uint16 *src, uint32 *dest, const int32 dx_start, const int32 dx_end, int32 fb_x);

 template<uint32 out_Rshift, uint32 out_Gshift, uint32 out_Bshift>
 void ReorderRGB(bool bpp24, const uint16 *src, uint32 *dest, const int32 dx_start, const int32 dx_end, int32 fb_x) NO_INLINE;
};

}
#endif
