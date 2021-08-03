/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

#include "snes9x.h"
#include "ppu.h"
#include "tile.h"
#include "controls.h"
#include "crosshairs.h"
#include "cheats.h"
#include "movie.h"
#include "screenshot.h"
#include "font.h"
#include "display.h"

extern struct SCheatData		Cheat;
extern struct SLineData			LineData[240];
extern struct SLineMatrixData	LineMatrixData[240];

void S9xComputeClipWindows (void);

static int	font_width = 8, font_height = 9;
void (*S9xCustomDisplayString) (const char *, int, int, bool, int) = NULL;

static void SetupOBJ (void);
static void DrawOBJS (int);
static void DisplayFrameRate (void);
static void DisplayPressedKeys (void);
static void DisplayWatchedAddresses (void);
static void DisplayStringFromBottom (const char *, int, int, bool);
static void DrawBackground (int, uint8, uint8);
static void DrawBackgroundMosaic (int, uint8, uint8);
static void DrawBackgroundOffset (int, uint8, uint8, int);
static void DrawBackgroundOffsetMosaic (int, uint8, uint8, int);
static inline void DrawBackgroundMode7 (int, void (*DrawMath) (uint32, uint32, int), void (*DrawNomath) (uint32, uint32, int), int);
static inline void DrawBackdrop (void);
static inline void RenderScreen (bool8);
static uint16 get_crosshair_color (uint8);
static void S9xDisplayStringType (const char *, int, int, bool, int);

#define TILE_PLUS(t, x)	(((t) & 0xfc00) | ((t + x) & 0x3ff))


bool8 S9xGraphicsInit (void)
{
	S9xInitTileRenderer();
	memset(BlackColourMap, 0, 256 * sizeof(uint16));

	GFX.RealPPL = GFX.Pitch >> 1;
	IPPU.OBJChanged = TRUE;
	Settings.BG_Forced = 0;
	S9xFixColourBrightness();
	S9xBuildDirectColourMaps();

	GFX.ZERO = (uint16 *) malloc(sizeof(uint16) * 0x10000);

	GFX.ScreenSize = GFX.Pitch / 2 * SNES_HEIGHT_EXTENDED * (Settings.SupportHiRes ? 2 : 1);
	GFX.SubScreen  = (uint16 *) malloc(GFX.ScreenSize * sizeof(uint16));
	GFX.ZBuffer    = (uint8 *)  malloc(GFX.ScreenSize);
	GFX.SubZBuffer = (uint8 *)  malloc(GFX.ScreenSize);

	if (!GFX.ZERO || !GFX.SubScreen || !GFX.ZBuffer || !GFX.SubZBuffer)
	{
		S9xGraphicsDeinit();
		return (FALSE);
	}

	// Lookup table for 1/2 color subtraction
	memset(GFX.ZERO, 0, 0x10000 * sizeof(uint16));
	for (uint32 r = 0; r <= MAX_RED; r++)
	{
		uint32	r2 = r;
		if (r2 & 0x10)
			r2 &= ~0x10;
		else
			r2 = 0;

		for (uint32 g = 0; g <= MAX_GREEN; g++)
		{
			uint32	g2 = g;
			if (g2 & GREEN_HI_BIT)
				g2 &= ~GREEN_HI_BIT;
			else
				g2 = 0;

			for (uint32 b = 0; b <= MAX_BLUE; b++)
			{
				uint32	b2 = b;
				if (b2 & 0x10)
					b2 &= ~0x10;
				else
					b2 = 0;

				GFX.ZERO[BUILD_PIXEL2(r, g, b)] = BUILD_PIXEL2(r2, g2, b2);
				GFX.ZERO[BUILD_PIXEL2(r, g, b) & ~ALPHA_BITS_MASK] = BUILD_PIXEL2(r2, g2, b2);
			}
		}
	}

	return (TRUE);
}

void S9xGraphicsDeinit (void)
{
	if (GFX.ZERO)       { free(GFX.ZERO);       GFX.ZERO       = NULL; }
	if (GFX.SubScreen)  { free(GFX.SubScreen);  GFX.SubScreen  = NULL; }
	if (GFX.ZBuffer)    { free(GFX.ZBuffer);    GFX.ZBuffer    = NULL; }
	if (GFX.SubZBuffer) { free(GFX.SubZBuffer); GFX.SubZBuffer = NULL; }
}

void S9xGraphicsScreenResize (void)
{
	IPPU.MaxBrightness = PPU.Brightness;

	IPPU.Interlace    = Memory.FillRAM[0x2133] & 1;
	IPPU.InterlaceOBJ = Memory.FillRAM[0x2133] & 2;
	IPPU.PseudoHires = Memory.FillRAM[0x2133] & 8;
		
	if (Settings.SupportHiRes && (PPU.BGMode == 5 || PPU.BGMode == 6 || IPPU.PseudoHires))
	{
		GFX.RealPPL = GFX.Pitch >> 1;
		IPPU.DoubleWidthPixels = TRUE;
		IPPU.RenderedScreenWidth = SNES_WIDTH << 1;
	}
	else
	{
		#ifdef USE_OPENGL
		if (Settings.OpenGLEnable)
			GFX.RealPPL = SNES_WIDTH;
		else
		#endif
			GFX.RealPPL = GFX.Pitch >> 1;

		IPPU.DoubleWidthPixels = FALSE;
		IPPU.RenderedScreenWidth = SNES_WIDTH;
	}

	if (Settings.SupportHiRes && IPPU.Interlace)
	{
		GFX.PPL = GFX.RealPPL << 1;
		IPPU.DoubleHeightPixels = TRUE;
		IPPU.RenderedScreenHeight = PPU.ScreenHeight << 1;
		GFX.DoInterlace++;
	}
	else
	{
		GFX.PPL = GFX.RealPPL;
		IPPU.DoubleHeightPixels = FALSE;
		IPPU.RenderedScreenHeight = PPU.ScreenHeight;
	}	
}

void S9xBuildDirectColourMaps (void)
{
	IPPU.XB = mul_brightness[PPU.Brightness];

	for (uint32 p = 0; p < 8; p++)
		for (uint32 c = 0; c < 256; c++)
			DirectColourMaps[p][c] = BUILD_PIXEL(IPPU.XB[((c & 7) << 2) | ((p & 1) << 1)], IPPU.XB[((c & 0x38) >> 1) | (p & 2)], IPPU.XB[((c & 0xc0) >> 3) | (p & 4)]);
}

void S9xStartScreenRefresh (void)
{
	GFX.InterlaceFrame = !GFX.InterlaceFrame;
	if (GFX.DoInterlace)
		GFX.DoInterlace--;

	if (IPPU.RenderThisFrame)
	{
		if (!GFX.DoInterlace || !GFX.InterlaceFrame)
		{
			if (!S9xInitUpdate())
			{
				IPPU.RenderThisFrame = FALSE;
				return;
			}

			S9xGraphicsScreenResize();

			IPPU.RenderedFramesCount++;
		}

		PPU.MosaicStart = 0;
		PPU.RecomputeClipWindows = TRUE;
		IPPU.PreviousLine = IPPU.CurrentLine = 0;

		memset(GFX.ZBuffer, 0, GFX.ScreenSize);
		memset(GFX.SubZBuffer, 0, GFX.ScreenSize);
	}

	if (++IPPU.FrameCount % Memory.ROMFramesPerSecond == 0)
	{
		IPPU.DisplayedRenderedFrameCount = IPPU.RenderedFramesCount;
		IPPU.RenderedFramesCount = 0;
		IPPU.FrameCount = 0;
	}

	if (GFX.InfoStringTimeout > 0 && --GFX.InfoStringTimeout == 0)
		GFX.InfoString = NULL;

	IPPU.TotalEmulatedFrames++;
}

void S9xEndScreenRefresh (void)
{
	if (IPPU.RenderThisFrame)
	{
		FLUSH_REDRAW();

		if (GFX.DoInterlace && GFX.InterlaceFrame == 0)
		{
			S9xControlEOF();
			S9xContinueUpdate(IPPU.RenderedScreenWidth, IPPU.RenderedScreenHeight);
		}
		else
		{
			if (IPPU.ColorsChanged)
			{
				uint32 saved = PPU.CGDATA[0];
				IPPU.ColorsChanged = FALSE;
				S9xSetPalette();
				PPU.CGDATA[0] = saved;
			}

			S9xControlEOF();

			if (Settings.TakeScreenshot)
				S9xDoScreenshot(IPPU.RenderedScreenWidth, IPPU.RenderedScreenHeight);

			if (Settings.AutoDisplayMessages)
				S9xDisplayMessages(GFX.Screen, GFX.RealPPL, IPPU.RenderedScreenWidth, IPPU.RenderedScreenHeight, 1);

			S9xDeinitUpdate(IPPU.RenderedScreenWidth, IPPU.RenderedScreenHeight);
		}
	}
	else
		S9xControlEOF();

	S9xUpdateCheatsInMemory ();

#ifdef DEBUGGER
	if (CPU.Flags & FRAME_ADVANCE_FLAG)
	{
		if (ICPU.FrameAdvanceCount)
		{
			ICPU.FrameAdvanceCount--;
			IPPU.RenderThisFrame = TRUE;
			IPPU.FrameSkip = 0;
		}
		else
		{
			CPU.Flags &= ~FRAME_ADVANCE_FLAG;
			CPU.Flags |= DEBUG_MODE_FLAG;
		}
	}
#endif

	if (CPU.SRAMModified)
	{
		if (!CPU.AutoSaveTimer)
		{
			if (!(CPU.AutoSaveTimer = Settings.AutoSaveDelay * Memory.ROMFramesPerSecond))
				CPU.SRAMModified = FALSE;
		}
		else
		{
			if (!--CPU.AutoSaveTimer)
			{
				S9xAutoSaveSRAM();
				CPU.SRAMModified = FALSE;
			}
		}
	}
}

void RenderLine (uint8 C)
{
	if (IPPU.RenderThisFrame)
	{
		LineData[C].BG[0].VOffset = PPU.BG[0].VOffset + 1;
		LineData[C].BG[0].HOffset = PPU.BG[0].HOffset;
		LineData[C].BG[1].VOffset = PPU.BG[1].VOffset + 1;
		LineData[C].BG[1].HOffset = PPU.BG[1].HOffset;

		if (PPU.BGMode == 7)
		{
			struct SLineMatrixData *p = &LineMatrixData[C];
			p->MatrixA = PPU.MatrixA;
			p->MatrixB = PPU.MatrixB;
			p->MatrixC = PPU.MatrixC;
			p->MatrixD = PPU.MatrixD;
			p->CentreX = PPU.CentreX;
			p->CentreY = PPU.CentreY;
			p->M7HOFS  = PPU.M7HOFS;
			p->M7VOFS  = PPU.M7VOFS;
		}
		else
		{
			LineData[C].BG[2].VOffset = PPU.BG[2].VOffset + 1;
			LineData[C].BG[2].HOffset = PPU.BG[2].HOffset;
			LineData[C].BG[3].VOffset = PPU.BG[3].VOffset + 1;
			LineData[C].BG[3].HOffset = PPU.BG[3].HOffset;
		}

		IPPU.CurrentLine = C + 1;
	}
	else
	{
		// if we're not rendering this frame, we still need to update this
		// XXX: Check ForceBlank? Or anything else?
		if (IPPU.OBJChanged)
			SetupOBJ();
		PPU.RangeTimeOver |= GFX.OBJLines[C].RTOFlags;
	}
}

static inline void RenderScreen (bool8 sub)
{
	uint8	BGActive;
	int		D;

	if (!sub)
	{
		GFX.S = GFX.Screen;
		if (GFX.DoInterlace && GFX.InterlaceFrame)
			GFX.S += GFX.RealPPL;
		GFX.DB = GFX.ZBuffer;
		GFX.Clip = IPPU.Clip[0];
		BGActive = Memory.FillRAM[0x212c] & ~Settings.BG_Forced;
		D = 32;
	}
	else
	{
		GFX.S = GFX.SubScreen;
		GFX.DB = GFX.SubZBuffer;
		GFX.Clip = IPPU.Clip[1];
		BGActive = Memory.FillRAM[0x212d] & ~Settings.BG_Forced;
		D = (Memory.FillRAM[0x2130] & 2) << 4; // 'do math' depth flag
	}

	if (BGActive & 0x10)
	{
		BG.TileAddress = PPU.OBJNameBase;
		BG.NameSelect = PPU.OBJNameSelect;
		BG.EnableMath = !sub && (Memory.FillRAM[0x2131] & 0x10);
		BG.StartPalette = 128;
		S9xSelectTileConverter(4, FALSE, sub, FALSE);
		S9xSelectTileRenderers(PPU.BGMode, sub, TRUE);
		DrawOBJS(D + 4);
	}

	BG.NameSelect = 0;
	S9xSelectTileRenderers(PPU.BGMode, sub, FALSE);

	#define DO_BG(n, pal, depth, hires, offset, Zh, Zl, voffoff) \
		if (BGActive & (1 << n)) \
		{ \
			BG.StartPalette = pal; \
			BG.EnableMath = !sub && (Memory.FillRAM[0x2131] & (1 << n)); \
			BG.TileSizeH = (!hires && PPU.BG[n].BGSize) ? 16 : 8; \
			BG.TileSizeV = (PPU.BG[n].BGSize) ? 16 : 8; \
			S9xSelectTileConverter(depth, hires, sub, PPU.BGMosaic[n]); \
			\
			if (offset) \
			{ \
				BG.OffsetSizeH = (!hires && PPU.BG[2].BGSize) ? 16 : 8; \
				BG.OffsetSizeV = (PPU.BG[2].BGSize) ? 16 : 8; \
				\
				if (PPU.BGMosaic[n] && (hires || PPU.Mosaic > 1)) \
					DrawBackgroundOffsetMosaic(n, D + Zh, D + Zl, voffoff); \
				else \
					DrawBackgroundOffset(n, D + Zh, D + Zl, voffoff); \
			} \
			else \
			{ \
				if (PPU.BGMosaic[n] && (hires || PPU.Mosaic > 1)) \
					DrawBackgroundMosaic(n, D + Zh, D + Zl); \
				else \
					DrawBackground(n, D + Zh, D + Zl); \
			} \
		}

	switch (PPU.BGMode)
	{
		case 0:
			DO_BG(0,  0, 2, FALSE, FALSE, 15, 11, 0);
			DO_BG(1, 32, 2, FALSE, FALSE, 14, 10, 0);
			DO_BG(2, 64, 2, FALSE, FALSE,  7,  3, 0);
			DO_BG(3, 96, 2, FALSE, FALSE,  6,  2, 0);
			break;

		case 1:
			DO_BG(0,  0, 4, FALSE, FALSE, 15, 11, 0);
			DO_BG(1,  0, 4, FALSE, FALSE, 14, 10, 0);
			DO_BG(2,  0, 2, FALSE, FALSE, (PPU.BG3Priority ? 17 : 7), 3, 0);
			break;

		case 2:
			DO_BG(0,  0, 4, FALSE, TRUE,  15,  7, 8);
			DO_BG(1,  0, 4, FALSE, TRUE,  11,  3, 8);
			break;

		case 3:
			DO_BG(0,  0, 8, FALSE, FALSE, 15,  7, 0);
			DO_BG(1,  0, 4, FALSE, FALSE, 11,  3, 0);
			break;

		case 4:
			DO_BG(0,  0, 8, FALSE, TRUE,  15,  7, 0);
			DO_BG(1,  0, 2, FALSE, TRUE,  11,  3, 0);
			break;

		case 5:
			DO_BG(0,  0, 4, TRUE,  FALSE, 15,  7, 0);
			DO_BG(1,  0, 2, TRUE,  FALSE, 11,  3, 0);
			break;

		case 6:
			DO_BG(0,  0, 4, TRUE,  TRUE,  15,  7, 8);
			break;

		case 7:
			if (BGActive & 0x01)
			{
				BG.EnableMath = !sub && (Memory.FillRAM[0x2131] & 1);
				DrawBackgroundMode7(0, GFX.DrawMode7BG1Math, GFX.DrawMode7BG1Nomath, D);
			}

			if ((Memory.FillRAM[0x2133] & 0x40) && (BGActive & 0x02))
			{
				BG.EnableMath = !sub && (Memory.FillRAM[0x2131] & 2);
				DrawBackgroundMode7(1, GFX.DrawMode7BG2Math, GFX.DrawMode7BG2Nomath, D);
			}

			break;
	}

	#undef DO_BG

	BG.EnableMath = !sub && (Memory.FillRAM[0x2131] & 0x20);

	DrawBackdrop();
}

void S9xUpdateScreen (void)
{
	if (IPPU.OBJChanged || IPPU.InterlaceOBJ)
		SetupOBJ();

	// XXX: Check ForceBlank? Or anything else?
	PPU.RangeTimeOver |= GFX.OBJLines[GFX.EndY].RTOFlags;

	GFX.StartY = IPPU.PreviousLine;
	if ((GFX.EndY = IPPU.CurrentLine - 1) >= PPU.ScreenHeight)
		GFX.EndY = PPU.ScreenHeight - 1;

	if (!PPU.ForcedBlanking)
	{
		// If force blank, may as well completely skip all this. We only did
		// the OBJ because (AFAWK) the RTO flags are updated even during force-blank.

		if (PPU.RecomputeClipWindows)
		{
			S9xComputeClipWindows();
			PPU.RecomputeClipWindows = FALSE;
		}

		if (Settings.SupportHiRes)
		{
			if (!IPPU.DoubleWidthPixels && (PPU.BGMode == 5 || PPU.BGMode == 6 || IPPU.PseudoHires))
			{
				#ifdef USE_OPENGL
				if (Settings.OpenGLEnable && GFX.RealPPL == 256)
				{
					// Have to back out of the speed up hack where the low res.
					// SNES image was rendered into a 256x239 sized buffer,
					// ignoring the true, larger size of the buffer.
					GFX.RealPPL = GFX.Pitch >> 1;

					for (int32 y = (int32) GFX.StartY - 1; y >= 0; y--)
					{
						uint16	*p = GFX.Screen + y * GFX.PPL     + 255;
						uint16	*q = GFX.Screen + y * GFX.RealPPL + 510;

						for (int x = 255; x >= 0; x--, p--, q -= 2)
							*q = *(q + 1) = *p;
					}

					GFX.PPL = GFX.RealPPL; // = GFX.Pitch >> 1 above
				}
				else
				#endif
				// Have to back out of the regular speed hack
				for (uint32 y = 0; y < GFX.StartY; y++)
				{
					uint16	*p = GFX.Screen + y * GFX.PPL + 255;
					uint16	*q = GFX.Screen + y * GFX.PPL + 510;

					for (int x = 255; x >= 0; x--, p--, q -= 2)
						*q = *(q + 1) = *p;
				}

				IPPU.DoubleWidthPixels = TRUE;
				IPPU.RenderedScreenWidth = 512;
			}

			if (!IPPU.DoubleHeightPixels && IPPU.Interlace && (PPU.BGMode == 5 || PPU.BGMode == 6))
			{
				IPPU.DoubleHeightPixels = TRUE;
				IPPU.RenderedScreenHeight = PPU.ScreenHeight << 1;
				GFX.PPL = GFX.RealPPL << 1;
				GFX.DoInterlace = 2;

				for (int32 y = (int32) GFX.StartY - 2; y >= 0; y--)
					memmove(GFX.Screen + (y + 1) * GFX.PPL, GFX.Screen + y * GFX.RealPPL, GFX.PPL * sizeof(uint16));
			}
		}

		if ((Memory.FillRAM[0x2130] & 0x30) != 0x30 && (Memory.FillRAM[0x2131] & 0x3f))
			GFX.FixedColour = BUILD_PIXEL(IPPU.XB[PPU.FixedColourRed], IPPU.XB[PPU.FixedColourGreen], IPPU.XB[PPU.FixedColourBlue]);

		if (PPU.BGMode == 5 || PPU.BGMode == 6 || IPPU.PseudoHires ||
			((Memory.FillRAM[0x2130] & 0x30) != 0x30 && (Memory.FillRAM[0x2130] & 2) && (Memory.FillRAM[0x2131] & 0x3f) && (Memory.FillRAM[0x212d] & 0x1f)))
			// If hires (Mode 5/6 or pseudo-hires) or math is to be done
			// involving the subscreen, then we need to render the subscreen...
			RenderScreen(TRUE);

		RenderScreen(FALSE);
	}
	else
	{
		const uint16	black = BUILD_PIXEL(0, 0, 0);

		GFX.S = GFX.Screen + GFX.StartY * GFX.PPL;
		if (GFX.DoInterlace && GFX.InterlaceFrame)
			GFX.S += GFX.RealPPL;

		for (uint32 l = GFX.StartY; l <= GFX.EndY; l++, GFX.S += GFX.PPL)
			for (int x = 0; x < IPPU.RenderedScreenWidth; x++)
				GFX.S[x] = black;
	}

	IPPU.PreviousLine = IPPU.CurrentLine;
}

static void SetupOBJ (void)
{
	int	SmallWidth, SmallHeight, LargeWidth, LargeHeight;

	switch (PPU.OBJSizeSelect)
	{
		case 0:
			SmallWidth = SmallHeight = 8;
			LargeWidth = LargeHeight = 16;
			break;

		case 1:
			SmallWidth = SmallHeight = 8;
			LargeWidth = LargeHeight = 32;
			break;

		case 2:
			SmallWidth = SmallHeight = 8;
			LargeWidth = LargeHeight = 64;
			break;

		case 3:
			SmallWidth = SmallHeight = 16;
			LargeWidth = LargeHeight = 32;
			break;

		case 4:
			SmallWidth = SmallHeight = 16;
			LargeWidth = LargeHeight = 64;
			break;

		case 5:
		default:
			SmallWidth = SmallHeight = 32;
			LargeWidth = LargeHeight = 64;
			break;

		case 6:
			SmallWidth = 16; SmallHeight = 32;
			LargeWidth = 32; LargeHeight = 64;
			break;

		case 7:
			SmallWidth = 16; SmallHeight = 32;
			LargeWidth = LargeHeight = 32;
			break;
	}

	int	inc = IPPU.InterlaceOBJ ? 2 : 1;

	int startline = (IPPU.InterlaceOBJ && GFX.InterlaceFrame) ? 1 : 0;

	// OK, we have three cases here. Either there's no priority, priority is
	// normal FirstSprite, or priority is FirstSprite+Y. The first two are
	// easy, the last is somewhat more ... interesting. So we split them up.

	int		Height;
	uint8	S;

	if (!PPU.OAMPriorityRotation || !(PPU.OAMFlip & PPU.OAMAddr & 1)) // normal case
	{
		uint8	LineOBJ[SNES_HEIGHT_EXTENDED];
		memset(LineOBJ, 0, sizeof(LineOBJ));

		for (int i = 0; i < SNES_HEIGHT_EXTENDED; i++)
		{
			GFX.OBJLines[i].RTOFlags = 0;
			GFX.OBJLines[i].Tiles = Settings.MaxSpriteTilesPerLine;
			for (int j = 0; j < 32; j++)
				GFX.OBJLines[i].OBJ[j].Sprite = -1;
		}

		uint8	FirstSprite = PPU.FirstSprite;
		S = FirstSprite;

		do
		{
			if (PPU.OBJ[S].Size)
			{
				GFX.OBJWidths[S] = LargeWidth;
				Height = LargeHeight;
			}
			else
			{
				GFX.OBJWidths[S] = SmallWidth;
				Height = SmallHeight;
			}

			int	HPos = PPU.OBJ[S].HPos;
			if (HPos == -256)
				HPos = 0;

			if (HPos > -GFX.OBJWidths[S] && HPos <= 256)
			{
				if (HPos < 0)
					GFX.OBJVisibleTiles[S] = (GFX.OBJWidths[S] + HPos + 7) >> 3;
				else
				if (HPos + GFX.OBJWidths[S] > 255)
					GFX.OBJVisibleTiles[S] = (256 - HPos + 7) >> 3;
				else
					GFX.OBJVisibleTiles[S] = GFX.OBJWidths[S] >> 3;

				for (uint8 line = startline, Y = (uint8) (PPU.OBJ[S].VPos & 0xff); line < Height; Y++, line += inc)
				{
					if (Y >= SNES_HEIGHT_EXTENDED)
						continue;

					if (LineOBJ[Y] >= 32)
					{
						GFX.OBJLines[Y].RTOFlags |= 0x40;
						continue;
					}

					GFX.OBJLines[Y].Tiles -= GFX.OBJVisibleTiles[S];
					if (GFX.OBJLines[Y].Tiles < 0)
						GFX.OBJLines[Y].RTOFlags |= 0x80;

					GFX.OBJLines[Y].OBJ[LineOBJ[Y]].Sprite = S;
					if (PPU.OBJ[S].VFlip)
						// Yes, Width not Height. It so happens that the
						// sprites with H=2*W flip as two WxW sprites.
						GFX.OBJLines[Y].OBJ[LineOBJ[Y]].Line = line ^ (GFX.OBJWidths[S] - 1);
					else
						GFX.OBJLines[Y].OBJ[LineOBJ[Y]].Line = line;

					LineOBJ[Y]++;
				}
			}

			S = (S + 1) & 0x7f;
		} while (S != FirstSprite);

		for (int Y = 1; Y < SNES_HEIGHT_EXTENDED; Y++)
			GFX.OBJLines[Y].RTOFlags |= GFX.OBJLines[Y - 1].RTOFlags;
	}
	else // evil FirstSprite+Y case
	{
		// First, find out which sprites are on which lines
		uint8 OBJOnLine[SNES_HEIGHT_EXTENDED][128];
		// memset(OBJOnLine, 0, sizeof(OBJOnLine));
		/* Hold on here, that's a lot of bytes to initialise at once!
		 * So we only initialise them per line, as needed. [Neb]
		 * Bonus: We can quickly avoid looping if a line has no OBJs.
		 */
        bool8 AnyOBJOnLine[SNES_HEIGHT_EXTENDED];
        memset(AnyOBJOnLine, FALSE, sizeof(AnyOBJOnLine)); // better

		for (S = 0; S < 128; S++)
		{
			if (PPU.OBJ[S].Size)
			{
				GFX.OBJWidths[S] = LargeWidth;
				Height = LargeHeight;
			}
			else
			{
				GFX.OBJWidths[S] = SmallWidth;
				Height = SmallHeight;
			}

			int	HPos = PPU.OBJ[S].HPos;
			if (HPos == -256)
				HPos = 256;

			if (HPos > -GFX.OBJWidths[S] && HPos <= 256)
			{
				if (HPos < 0)
					GFX.OBJVisibleTiles[S] = (GFX.OBJWidths[S] + HPos + 7) >> 3;
				else
				if (HPos + GFX.OBJWidths[S] >= 257)
					GFX.OBJVisibleTiles[S] = (257 - HPos + 7) >> 3;
				else
					GFX.OBJVisibleTiles[S] = GFX.OBJWidths[S] >> 3;

				for (uint8 line = startline, Y = (uint8) (PPU.OBJ[S].VPos & 0xff); line < Height; Y++, line += inc)
				{
					if (Y >= SNES_HEIGHT_EXTENDED)
						continue;

					if (!AnyOBJOnLine[Y]) {
						memset(OBJOnLine[Y], 0, sizeof(OBJOnLine[Y]));
						AnyOBJOnLine[Y] = TRUE;
					}

					if (PPU.OBJ[S].VFlip)
						// Yes, Width not Height. It so happens that the
						// sprites with H=2*W flip as two WxW sprites.
						OBJOnLine[Y][S] = (line ^ (GFX.OBJWidths[S] - 1)) | 0x80;
					else
						OBJOnLine[Y][S] = line | 0x80;
				}
			}
		}

		// Now go through and pull out those OBJ that are actually visible.
		int	j;
		for (int Y = 0; Y < SNES_HEIGHT_EXTENDED; Y++)
		{
			GFX.OBJLines[Y].RTOFlags = Y ? GFX.OBJLines[Y - 1].RTOFlags : 0;
			GFX.OBJLines[Y].Tiles = Settings.MaxSpriteTilesPerLine;

			uint8	FirstSprite = (PPU.FirstSprite + Y) & 0x7f;
			S = FirstSprite;
			j = 0;

			if (AnyOBJOnLine[Y])
			{
				do
				{
					if (OBJOnLine[Y][S])
					{
						if (j >= 32)
						{
							GFX.OBJLines[Y].RTOFlags |= 0x40;
							break;
						}

						GFX.OBJLines[Y].Tiles -= GFX.OBJVisibleTiles[S];
						if (GFX.OBJLines[Y].Tiles < 0)
							GFX.OBJLines[Y].RTOFlags |= 0x80;
						GFX.OBJLines[Y].OBJ[j].Sprite = S;
						GFX.OBJLines[Y].OBJ[j++].Line = OBJOnLine[Y][S] & ~0x80;
					}

					S = (S + 1) & 0x7f;
				} while (S != FirstSprite);
			}

			if (j < 32)
				GFX.OBJLines[Y].OBJ[j].Sprite = -1;
		}
	}

	IPPU.OBJChanged = FALSE;
}

#if defined(__GNUC__) && !defined(__clang__)
#pragma GCC push_options
#pragma GCC optimize ("no-tree-vrp")
#endif
static void DrawOBJS (int D)
{
	void (*DrawTile) (uint32, uint32, uint32, uint32) = NULL;
	void (*DrawClippedTile) (uint32, uint32, uint32, uint32, uint32, uint32) = NULL;

	int	PixWidth = IPPU.DoubleWidthPixels ? 2 : 1;
	BG.InterlaceLine = GFX.InterlaceFrame ? 8 : 0;
	GFX.Z1 = 2;

	for (uint32 Y = GFX.StartY, Offset = Y * GFX.PPL; Y <= GFX.EndY; Y++, Offset += GFX.PPL)
	{
		int	I = 0;
		int	tiles = GFX.OBJLines[Y].Tiles;

		for (int S = GFX.OBJLines[Y].OBJ[I].Sprite; S >= 0 && I < 32; S = GFX.OBJLines[Y].OBJ[++I].Sprite)
		{
			tiles += GFX.OBJVisibleTiles[S];
			if (tiles <= 0)
				continue;

			int	BaseTile = (((GFX.OBJLines[Y].OBJ[I].Line << 1) + (PPU.OBJ[S].Name & 0xf0)) & 0xf0) | (PPU.OBJ[S].Name & 0x100) | (PPU.OBJ[S].Palette << 10);
			int	TileX = PPU.OBJ[S].Name & 0x0f;
			int	TileLine = (GFX.OBJLines[Y].OBJ[I].Line & 7) * 8;
			int	TileInc = 1;

			if (PPU.OBJ[S].HFlip)
			{
				TileX = (TileX + (GFX.OBJWidths[S] >> 3) - 1) & 0x0f;
				BaseTile |= H_FLIP;
				TileInc = -1;
			}

			GFX.Z2 = D + PPU.OBJ[S].Priority * 4;

			int	DrawMode = 3;
			int	clip = 0, next_clip = -1000;
			int	X = PPU.OBJ[S].HPos;
			if (X == -256)
				X = 256;

			for (int t = tiles, O = Offset + X * PixWidth; X <= 256 && X < PPU.OBJ[S].HPos + GFX.OBJWidths[S]; TileX = (TileX + TileInc) & 0x0f, X += 8, O += 8 * PixWidth)
			{
				if (X < -7 || --t < 0 || X == 256)
					continue;

				for (int x = X; x < X + 8;)
				{
					if (x >= next_clip)
					{
						for (; clip < GFX.Clip[4].Count && GFX.Clip[4].Left[clip] <= x; clip++) ;
						if (clip == 0 || x >= GFX.Clip[4].Right[clip - 1])
						{
							DrawMode = 0;
							next_clip = ((clip < GFX.Clip[4].Count) ? GFX.Clip[4].Left[clip] : 1000);
						}
						else
						{
							DrawMode = GFX.Clip[4].DrawMode[clip - 1];
							next_clip = GFX.Clip[4].Right[clip - 1];
							GFX.ClipColors = !(DrawMode & 1);

							if (BG.EnableMath && (PPU.OBJ[S].Palette & 4) && (DrawMode & 2))
							{
								DrawTile = GFX.DrawTileMath;
								DrawClippedTile = GFX.DrawClippedTileMath;
							}
							else
							{
								DrawTile = GFX.DrawTileNomath;
								DrawClippedTile = GFX.DrawClippedTileNomath;
							}
						}
					}

					if (x == X && x + 8 < next_clip)
					{
						if (DrawMode)
							DrawTile(BaseTile | TileX, O, TileLine, 1);
						x += 8;
					}
					else
					{
						int	w = (next_clip <= X + 8) ? next_clip - x : X + 8 - x;
						if (DrawMode)
							DrawClippedTile(BaseTile | TileX, O, x - X, w, TileLine, 1);
						x += w;
					}
				}
			}
		}
	}
}
#if defined(__GNUC__) && !defined(__clang__)
#pragma GCC pop_options
#endif

static void DrawBackground (int bg, uint8 Zh, uint8 Zl)
{
	BG.TileAddress = PPU.BG[bg].NameBase << 1;

	uint32	Tile;
	uint16	*SC0, *SC1, *SC2, *SC3;

	SC0 = (uint16 *) &Memory.VRAM[PPU.BG[bg].SCBase << 1];
	SC1 = (PPU.BG[bg].SCSize & 1) ? SC0 + 1024 : SC0;
	if (SC1 >= (uint16 *) (Memory.VRAM + 0x10000))
		SC1 -= 0x8000;
	SC2 = (PPU.BG[bg].SCSize & 2) ? SC1 + 1024 : SC0;
	if (SC2 >= (uint16 *) (Memory.VRAM + 0x10000))
		SC2 -= 0x8000;
	SC3 = (PPU.BG[bg].SCSize & 1) ? SC2 + 1024 : SC2;
	if (SC3 >= (uint16 *) (Memory.VRAM + 0x10000))
		SC3 -= 0x8000;

	uint32	Lines;
	int		OffsetMask  = (BG.TileSizeH == 16) ? 0x3ff : 0x1ff;
	int		OffsetShift = (BG.TileSizeV == 16) ? 4 : 3;
	int		PixWidth = IPPU.DoubleWidthPixels ? 2 : 1;
	bool8	HiresInterlace = IPPU.Interlace && IPPU.DoubleWidthPixels;

	void (*DrawTile) (uint32, uint32, uint32, uint32);
	void (*DrawClippedTile) (uint32, uint32, uint32, uint32, uint32, uint32);

	for (int clip = 0; clip < GFX.Clip[bg].Count; clip++)
	{
		GFX.ClipColors = !(GFX.Clip[bg].DrawMode[clip] & 1);

		if (BG.EnableMath && (GFX.Clip[bg].DrawMode[clip] & 2))
		{
			DrawTile = GFX.DrawTileMath;
			DrawClippedTile = GFX.DrawClippedTileMath;
		}
		else
		{
			DrawTile = GFX.DrawTileNomath;
			DrawClippedTile = GFX.DrawClippedTileNomath;
		}

		for (uint32 Y = GFX.StartY; Y <= GFX.EndY; Y += Lines)
		{
			uint32	Y2 = HiresInterlace ? Y * 2 + GFX.InterlaceFrame : Y;
			uint32	VOffset = LineData[Y].BG[bg].VOffset + (HiresInterlace ? 1 : 0);
			uint32	HOffset = LineData[Y].BG[bg].HOffset;
			int		VirtAlign = ((Y2 + VOffset) & 7) >> (HiresInterlace ? 1 : 0);

			for (Lines = 1; Lines < GFX.LinesPerTile - VirtAlign; Lines++)
			{
				if ((VOffset != LineData[Y + Lines].BG[bg].VOffset) || (HOffset != LineData[Y + Lines].BG[bg].HOffset))
					break;
			}

			if (Y + Lines > GFX.EndY)
				Lines = GFX.EndY - Y + 1;

			VirtAlign <<= 3;

			uint32	t1, t2;
			uint32	TilemapRow = (VOffset + Y2) >> OffsetShift;
			BG.InterlaceLine = ((VOffset + Y2) & 1) << 3;

			if ((VOffset + Y2) & 8)
			{
				t1 = 16;
				t2 = 0;
			}
			else
			{
				t1 = 0;
				t2 = 16;
			}

			uint16	*b1, *b2;

			if (TilemapRow & 0x20)
			{
				b1 = SC2;
				b2 = SC3;
			}
			else
			{
				b1 = SC0;
				b2 = SC1;
			}

			b1 += (TilemapRow & 0x1f) << 5;
			b2 += (TilemapRow & 0x1f) << 5;

			uint32	Left   = GFX.Clip[bg].Left[clip];
			uint32	Right  = GFX.Clip[bg].Right[clip];
			uint32	Offset = Left * PixWidth + Y * GFX.PPL;
			uint32	HPos   = (HOffset + Left) & OffsetMask;
			uint32	HTile  = HPos >> 3;
			uint16	*t;

			if (BG.TileSizeH == 8)
			{
				if (HTile > 31)
					t = b2 + (HTile & 0x1f);
				else
					t = b1 + HTile;
			}
			else
			{
				if (HTile > 63)
					t = b2 + ((HTile >> 1) & 0x1f);
				else
					t = b1 + (HTile >> 1);
			}

			uint32	Width = Right - Left;

			if (HPos & 7)
			{
				uint32	l = HPos & 7;
				uint32	w = 8 - l;
				if (w > Width)
					w = Width;

				Offset -= l * PixWidth;
				Tile = READ_WORD(t);
				GFX.Z1 = GFX.Z2 = (Tile & 0x2000) ? Zh : Zl;

				if (BG.TileSizeV == 16)
					Tile = TILE_PLUS(Tile, ((Tile & V_FLIP) ? t2 : t1));

				if (BG.TileSizeH == 8)
				{
					DrawClippedTile(Tile, Offset, l, w, VirtAlign, Lines);
					t++;
					if (HTile == 31)
						t = b2;
					else
					if (HTile == 63)
						t = b1;
				}
				else
				{
					if (!(Tile & H_FLIP))
						DrawClippedTile(TILE_PLUS(Tile, (HTile & 1)), Offset, l, w, VirtAlign, Lines);
					else
						DrawClippedTile(TILE_PLUS(Tile, 1 - (HTile & 1)), Offset, l, w, VirtAlign, Lines);
					t += HTile & 1;
					if (HTile == 63)
						t = b2;
					else
					if (HTile == 127)
						t = b1;
				}

				HTile++;
				Offset += 8 * PixWidth;
				Width -= w;
			}

			while (Width >= 8)
			{
				Tile = READ_WORD(t);
				GFX.Z1 = GFX.Z2 = (Tile & 0x2000) ? Zh : Zl;

				if (BG.TileSizeV == 16)
					Tile = TILE_PLUS(Tile, ((Tile & V_FLIP) ? t2 : t1));

				if (BG.TileSizeH == 8)
				{
					DrawTile(Tile, Offset, VirtAlign, Lines);
					t++;
					if (HTile == 31)
						t = b2;
					else
					if (HTile == 63)
						t = b1;
				}
				else
				{
					if (!(Tile & H_FLIP))
						DrawTile(TILE_PLUS(Tile, (HTile & 1)), Offset, VirtAlign, Lines);
					else
						DrawTile(TILE_PLUS(Tile, 1 - (HTile & 1)), Offset, VirtAlign, Lines);
					t += HTile & 1;
					if (HTile == 63)
						t = b2;
					else
					if (HTile == 127)
						t = b1;
				}

				HTile++;
				Offset += 8 * PixWidth;
				Width -= 8;
			}

			if (Width)
			{
				Tile = READ_WORD(t);
				GFX.Z1 = GFX.Z2 = (Tile & 0x2000) ? Zh : Zl;

				if (BG.TileSizeV == 16)
					Tile = TILE_PLUS(Tile, ((Tile & V_FLIP) ? t2 : t1));

				if (BG.TileSizeH == 8)
					DrawClippedTile(Tile, Offset, 0, Width, VirtAlign, Lines);
				else
				{
					if (!(Tile & H_FLIP))
						DrawClippedTile(TILE_PLUS(Tile, (HTile & 1)), Offset, 0, Width, VirtAlign, Lines);
					else
						DrawClippedTile(TILE_PLUS(Tile, 1 - (HTile & 1)), Offset, 0, Width, VirtAlign, Lines);
				}
			}
		}
	}
}

static void DrawBackgroundMosaic (int bg, uint8 Zh, uint8 Zl)
{
	BG.TileAddress = PPU.BG[bg].NameBase << 1;

	uint32	Tile;
	uint16	*SC0, *SC1, *SC2, *SC3;

	SC0 = (uint16 *) &Memory.VRAM[PPU.BG[bg].SCBase << 1];
	SC1 = (PPU.BG[bg].SCSize & 1) ? SC0 + 1024 : SC0;
	if (SC1 >= (uint16 *) (Memory.VRAM + 0x10000))
		SC1 -= 0x8000;
	SC2 = (PPU.BG[bg].SCSize & 2) ? SC1 + 1024 : SC0;
	if (SC2 >= (uint16 *) (Memory.VRAM + 0x10000))
		SC2 -= 0x8000;
	SC3 = (PPU.BG[bg].SCSize & 1) ? SC2 + 1024 : SC2;
	if (SC3 >= (uint16 *) (Memory.VRAM + 0x10000))
		SC3 -= 0x8000;

	int	Lines;
	int	OffsetMask  = (BG.TileSizeH == 16) ? 0x3ff : 0x1ff;
	int	OffsetShift = (BG.TileSizeV == 16) ? 4 : 3;
	int	PixWidth = IPPU.DoubleWidthPixels ? 2 : 1;
	bool8	HiresInterlace = IPPU.Interlace && IPPU.DoubleWidthPixels;

	void (*DrawPix) (uint32, uint32, uint32, uint32, uint32, uint32);

	int	MosaicStart = ((uint32) GFX.StartY - PPU.MosaicStart) % PPU.Mosaic;

	for (int clip = 0; clip < GFX.Clip[bg].Count; clip++)
	{
		GFX.ClipColors = !(GFX.Clip[bg].DrawMode[clip] & 1);

		if (BG.EnableMath && (GFX.Clip[bg].DrawMode[clip] & 2))
			DrawPix = GFX.DrawMosaicPixelMath;
		else
			DrawPix = GFX.DrawMosaicPixelNomath;

		for (uint32 Y = GFX.StartY - MosaicStart; Y <= GFX.EndY; Y += PPU.Mosaic)
		{
			uint32	Y2 = HiresInterlace ? Y * 2 : Y;
			uint32	VOffset = LineData[Y + MosaicStart].BG[bg].VOffset + (HiresInterlace ? 1 : 0);
			uint32	HOffset = LineData[Y + MosaicStart].BG[bg].HOffset;

			Lines = PPU.Mosaic - MosaicStart;
			if (Y + MosaicStart + Lines > GFX.EndY)
				Lines = GFX.EndY - Y - MosaicStart + 1;

			int	VirtAlign = (((Y2 + VOffset) & 7) >> (HiresInterlace ? 1 : 0)) << 3;

			uint32	t1, t2;
			uint32	TilemapRow = (VOffset + Y2) >> OffsetShift;
			BG.InterlaceLine = ((VOffset + Y2) & 1) << 3;

			if ((VOffset + Y2) & 8)
			{
				t1 = 16;
				t2 = 0;
			}
			else
			{
				t1 = 0;
				t2 = 16;
			}

			uint16	*b1, *b2;

			if (TilemapRow & 0x20)
			{
				b1 = SC2;
				b2 = SC3;
			}
			else
			{
				b1 = SC0;
				b2 = SC1;
			}

			b1 += (TilemapRow & 0x1f) << 5;
			b2 += (TilemapRow & 0x1f) << 5;

			uint32	Left   = GFX.Clip[bg].Left[clip];
			uint32	Right  = GFX.Clip[bg].Right[clip];
			uint32	Offset = Left * PixWidth + (Y + MosaicStart) * GFX.PPL;
			uint32	HPos   = (HOffset + Left - (Left % PPU.Mosaic)) & OffsetMask;
			uint32	HTile  = HPos >> 3;
			uint16	*t;

			if (BG.TileSizeH == 8)
			{
				if (HTile > 31)
					t = b2 + (HTile & 0x1f);
				else
					t = b1 + HTile;
			}
			else
			{
				if (HTile > 63)
					t = b2 + ((HTile >> 1) & 0x1f);
				else
					t = b1 + (HTile >> 1);
			}

			uint32	Width = Right - Left;

			HPos &= 7;

			while (Left < Right)
			{
				uint32	w = PPU.Mosaic - (Left % PPU.Mosaic);
				if (w > Width)
					w = Width;

				Tile = READ_WORD(t);
				GFX.Z1 = GFX.Z2 = (Tile & 0x2000) ? Zh : Zl;

				if (BG.TileSizeV == 16)
					Tile = TILE_PLUS(Tile, ((Tile & V_FLIP) ? t2 : t1));

				if (BG.TileSizeH == 8)
					DrawPix(Tile, Offset, VirtAlign, HPos & 7, w, Lines);
				else
				{
					if (!(Tile & H_FLIP))
						DrawPix(TILE_PLUS(Tile, (HTile & 1)), Offset, VirtAlign, HPos & 7, w, Lines);
					else
						DrawPix(TILE_PLUS(Tile, 1 - (HTile & 1)), Offset, VirtAlign, HPos & 7, w, Lines);
				}

				HPos += PPU.Mosaic;

				while (HPos >= 8)
				{
					HPos -= 8;

					if (BG.TileSizeH == 8)
					{
						t++;
						if (HTile == 31)
							t = b2;
						else
						if (HTile == 63)
							t = b1;
					}
					else
					{
						t += HTile & 1;
						if (HTile == 63)
							t = b2;
						else
						if (HTile == 127)
							t = b1;
					}

					HTile++;
				}

				Offset += w * PixWidth;
				Width -= w;
				Left += w;
			}

			MosaicStart = 0;
		}
	}
}

static void DrawBackgroundOffset (int bg, uint8 Zh, uint8 Zl, int VOffOff)
{
	BG.TileAddress = PPU.BG[bg].NameBase << 1;

	uint32	Tile;
	uint16	*SC0, *SC1, *SC2, *SC3;
	uint16	*BPS0, *BPS1, *BPS2, *BPS3;

	BPS0 = (uint16 *) &Memory.VRAM[PPU.BG[2].SCBase << 1];
	BPS1 = (PPU.BG[2].SCSize & 1) ? BPS0 + 1024 : BPS0;
	if (BPS1 >= (uint16 *) (Memory.VRAM + 0x10000))
		BPS1 -= 0x8000;
	BPS2 = (PPU.BG[2].SCSize & 2) ? BPS1 + 1024 : BPS0;
	if (BPS2 >= (uint16 *) (Memory.VRAM + 0x10000))
		BPS2 -= 0x8000;
	BPS3 = (PPU.BG[2].SCSize & 1) ? BPS2 + 1024 : BPS2;
	if (BPS3 >= (uint16 *) (Memory.VRAM + 0x10000))
		BPS3 -= 0x8000;

	SC0 = (uint16 *) &Memory.VRAM[PPU.BG[bg].SCBase << 1];
	SC1 = (PPU.BG[bg].SCSize & 1) ? SC0 + 1024 : SC0;
	if (SC1 >= (uint16 *) (Memory.VRAM + 0x10000))
		SC1 -= 0x8000;
	SC2 = (PPU.BG[bg].SCSize & 2) ? SC1 + 1024 : SC0;
	if (SC2 >= (uint16 *) (Memory.VRAM + 0x10000))
		SC2 -= 0x8000;
	SC3 = (PPU.BG[bg].SCSize & 1) ? SC2 + 1024 : SC2;
	if (SC3 >= (uint16 *) (Memory.VRAM + 0x10000))
		SC3 -= 0x8000;

	int	OffsetMask   = (BG.TileSizeH   == 16) ? 0x3ff : 0x1ff;
	int	OffsetShift  = (BG.TileSizeV   == 16) ? 4 : 3;
	int	Offset2Mask  = (BG.OffsetSizeH == 16) ? 0x3ff : 0x1ff;
	int	Offset2Shift = (BG.OffsetSizeV == 16) ? 4 : 3;
	int	OffsetEnableMask = 0x2000 << bg;
	int	PixWidth = IPPU.DoubleWidthPixels ? 2 : 1;
	bool8	HiresInterlace = IPPU.Interlace && IPPU.DoubleWidthPixels;

	void (*DrawClippedTile) (uint32, uint32, uint32, uint32, uint32, uint32);

	for (int clip = 0; clip < GFX.Clip[bg].Count; clip++)
	{
		GFX.ClipColors = !(GFX.Clip[bg].DrawMode[clip] & 1);

		if (BG.EnableMath && (GFX.Clip[bg].DrawMode[clip] & 2))
		{
			DrawClippedTile = GFX.DrawClippedTileMath;
		}
		else
		{
			DrawClippedTile = GFX.DrawClippedTileNomath;
		}

		for (uint32 Y = GFX.StartY; Y <= GFX.EndY; Y++)
		{
			uint32	Y2 = HiresInterlace ? Y * 2 + GFX.InterlaceFrame : Y;
			uint32	VOff = LineData[Y].BG[2].VOffset - 1;
			uint32	HOff = LineData[Y].BG[2].HOffset;
			uint32	HOffsetRow = VOff >> Offset2Shift;
			uint32	VOffsetRow = (VOff + VOffOff) >> Offset2Shift;
			uint16	*s, *s1, *s2;

			if (HOffsetRow & 0x20)
			{
				s1 = BPS2;
				s2 = BPS3;
			}
			else
			{
				s1 = BPS0;
				s2 = BPS1;
			}

			s1 += (HOffsetRow & 0x1f) << 5;
			s2 += (HOffsetRow & 0x1f) << 5;
			s = ((VOffsetRow & 0x20) ? BPS2 : BPS0) + ((VOffsetRow & 0x1f) << 5);
			int32	VOffsetOffset = s - s1;

			uint32	Left  = GFX.Clip[bg].Left[clip];
			uint32	Right = GFX.Clip[bg].Right[clip];
			uint32	Offset = Left * PixWidth + Y * GFX.PPL;
			uint32	HScroll = LineData[Y].BG[bg].HOffset;
			bool8	left_edge = (Left < (8 - (HScroll & 7)));
			uint32	Width = Right - Left;

			while (Left < Right)
			{
				uint32	VOffset, HOffset;

				if (left_edge)
				{
					// SNES cannot do OPT for leftmost tile column
					VOffset = LineData[Y].BG[bg].VOffset;
					HOffset = HScroll;
					left_edge = FALSE;
				}
				else
				{
					int HOffTile = ((HOff + Left - 1) & Offset2Mask) >> 3;

					if (BG.OffsetSizeH == 8)
					{
						if (HOffTile > 31)
							s = s2 + (HOffTile & 0x1f);
						else
							s = s1 + HOffTile;
					}
					else
					{
						if (HOffTile > 63)
							s = s2 + ((HOffTile >> 1) & 0x1f);
						else
							s = s1 + (HOffTile >> 1);
					}

					uint16	HCellOffset = READ_WORD(s);
					uint16	VCellOffset;

					if (VOffOff)
						VCellOffset = READ_WORD(s + VOffsetOffset);
					else
					{
						if (HCellOffset & 0x8000)
						{
							VCellOffset = HCellOffset;
							HCellOffset = 0;
						}
						else
							VCellOffset = 0;
					}

					if (VCellOffset & OffsetEnableMask)
						VOffset = VCellOffset + 1;
					else
						VOffset = LineData[Y].BG[bg].VOffset;

					if (HCellOffset & OffsetEnableMask)
						HOffset = (HCellOffset & ~7) | (HScroll & 7);
					else
						HOffset = HScroll;
				}

				if (HiresInterlace)
					VOffset++;

				uint32	t1, t2;
				int		VirtAlign = (((Y2 + VOffset) & 7) >> (HiresInterlace ? 1 : 0)) << 3;
				int		TilemapRow = (VOffset + Y2) >> OffsetShift;
				BG.InterlaceLine = ((VOffset + Y2) & 1) << 3;

				if ((VOffset + Y2) & 8)
				{
					t1 = 16;
					t2 = 0;
				}
				else
				{
					t1 = 0;
					t2 = 16;
				}

				uint16	*b1, *b2;

				if (TilemapRow & 0x20)
				{
					b1 = SC2;
					b2 = SC3;
				}
				else
				{
					b1 = SC0;
					b2 = SC1;
				}

				b1 += (TilemapRow & 0x1f) << 5;
				b2 += (TilemapRow & 0x1f) << 5;

				uint32	HPos = (HOffset + Left) & OffsetMask;
				uint32	HTile = HPos >> 3;
				uint16	*t;

				if (BG.TileSizeH == 8)
				{
					if (HTile > 31)
						t = b2 + (HTile & 0x1f);
					else
						t = b1 + HTile;
				}
				else
				{
					if (HTile > 63)
						t = b2 + ((HTile >> 1) & 0x1f);
					else
						t = b1 + (HTile >> 1);
				}

				uint32	l = HPos & 7;
				uint32	w = 8 - l;
				if (w > Width)
					w = Width;

				Offset -= l * PixWidth;
				Tile = READ_WORD(t);
				GFX.Z1 = GFX.Z2 = (Tile & 0x2000) ? Zh : Zl;

				if (BG.TileSizeV == 16)
					Tile = TILE_PLUS(Tile, ((Tile & V_FLIP) ? t2 : t1));

				if (BG.TileSizeH == 8)
				{
					DrawClippedTile(Tile, Offset, l, w, VirtAlign, 1);
				}
				else
				{
					if (!(Tile & H_FLIP))
						DrawClippedTile(TILE_PLUS(Tile, (HTile & 1)), Offset, l, w, VirtAlign, 1);
					else
						DrawClippedTile(TILE_PLUS(Tile, 1 - (HTile & 1)), Offset, l, w, VirtAlign, 1);
				}

				Left += w;
				Offset += 8 * PixWidth;
				Width -= w;
			}
		}
	}
}

static void DrawBackgroundOffsetMosaic (int bg, uint8 Zh, uint8 Zl, int VOffOff)
{
	BG.TileAddress = PPU.BG[bg].NameBase << 1;

	uint32	Tile;
	uint16	*SC0, *SC1, *SC2, *SC3;
	uint16	*BPS0, *BPS1, *BPS2, *BPS3;

	BPS0 = (uint16 *) &Memory.VRAM[PPU.BG[2].SCBase << 1];
	BPS1 = (PPU.BG[2].SCSize & 1) ? BPS0 + 1024 : BPS0;
	if (BPS1 >= (uint16 *) (Memory.VRAM + 0x10000))
		BPS1 -= 0x8000;
	BPS2 = (PPU.BG[2].SCSize & 2) ? BPS1 + 1024 : BPS0;
	if (BPS2 >= (uint16 *) (Memory.VRAM + 0x10000))
		BPS2 -= 0x8000;
	BPS3 = (PPU.BG[2].SCSize & 1) ? BPS2 + 1024 : BPS2;
	if (BPS3 >= (uint16 *) (Memory.VRAM + 0x10000))
		BPS3 -= 0x8000;

	SC0 = (uint16 *) &Memory.VRAM[PPU.BG[bg].SCBase << 1];
	SC1 = (PPU.BG[bg].SCSize & 1) ? SC0 + 1024 : SC0;
	if (SC1 >= (uint16 *) (Memory.VRAM + 0x10000))
		SC1 -= 0x8000;
	SC2 = (PPU.BG[bg].SCSize & 2) ? SC1 + 1024 : SC0;
	if (SC2 >= (uint16 *) (Memory.VRAM + 0x10000))
		SC2 -= 0x8000;
	SC3 = (PPU.BG[bg].SCSize & 1) ? SC2 + 1024 : SC2;
	if (SC3 >= (uint16 *) (Memory.VRAM + 0x10000))
		SC3 -= 0x8000;

	int	Lines;
	int	OffsetMask   = (BG.TileSizeH   == 16) ? 0x3ff : 0x1ff;
	int	OffsetShift  = (BG.TileSizeV   == 16) ? 4 : 3;
	int	Offset2Shift = (BG.OffsetSizeV == 16) ? 4 : 3;
	int	OffsetEnableMask = 0x2000 << bg;
	int	PixWidth = IPPU.DoubleWidthPixels ? 2 : 1;
	bool8	HiresInterlace = IPPU.Interlace && IPPU.DoubleWidthPixels;

	void (*DrawPix) (uint32, uint32, uint32, uint32, uint32, uint32);

	int	MosaicStart = ((uint32) GFX.StartY - PPU.MosaicStart) % PPU.Mosaic;

	for (int clip = 0; clip < GFX.Clip[bg].Count; clip++)
	{
		GFX.ClipColors = !(GFX.Clip[bg].DrawMode[clip] & 1);

		if (BG.EnableMath && (GFX.Clip[bg].DrawMode[clip] & 2))
			DrawPix = GFX.DrawMosaicPixelMath;
		else
			DrawPix = GFX.DrawMosaicPixelNomath;

		for (uint32 Y = GFX.StartY - MosaicStart; Y <= GFX.EndY; Y += PPU.Mosaic)
		{
			uint32	Y2 = HiresInterlace ? Y * 2 : Y;
			uint32	VOff = LineData[Y + MosaicStart].BG[2].VOffset - 1;
			uint32	HOff = LineData[Y + MosaicStart].BG[2].HOffset;

			Lines = PPU.Mosaic - MosaicStart;
			if (Y + MosaicStart + Lines > GFX.EndY)
				Lines = GFX.EndY - Y - MosaicStart + 1;

			uint32	HOffsetRow = VOff >> Offset2Shift;
			uint32	VOffsetRow = (VOff + VOffOff) >> Offset2Shift;
			uint16	*s, *s1, *s2;

			if (HOffsetRow & 0x20)
			{
				s1 = BPS2;
				s2 = BPS3;
			}
			else
			{
				s1 = BPS0;
				s2 = BPS1;
			}

			s1 += (HOffsetRow & 0x1f) << 5;
			s2 += (HOffsetRow & 0x1f) << 5;
			s = ((VOffsetRow & 0x20) ? BPS2 : BPS0) + ((VOffsetRow & 0x1f) << 5);
			int32	VOffsetOffset = s - s1;

			uint32	Left =  GFX.Clip[bg].Left[clip];
			uint32	Right = GFX.Clip[bg].Right[clip];
			uint32	Offset = Left * PixWidth + (Y + MosaicStart) * GFX.PPL;
			uint32	HScroll = LineData[Y + MosaicStart].BG[bg].HOffset;
			uint32	Width = Right - Left;

			while (Left < Right)
			{
				uint32	VOffset, HOffset;

				if (Left < (8 - (HScroll & 7)))
				{
					// SNES cannot do OPT for leftmost tile column
					VOffset = LineData[Y + MosaicStart].BG[bg].VOffset;
					HOffset = HScroll;
				}
				else
				{
					int HOffTile = (((Left + (HScroll & 7)) - 8) + (HOff & ~7)) >> 3;

					if (BG.OffsetSizeH == 8)
					{
						if (HOffTile > 31)
							s = s2 + (HOffTile & 0x1f);
						else
							s = s1 + HOffTile;
					}
					else
					{
						if (HOffTile > 63)
							s = s2 + ((HOffTile >> 1) & 0x1f);
						else
							s = s1 + (HOffTile >> 1);
					}

					uint16	HCellOffset = READ_WORD(s);
					uint16	VCellOffset;

					if (VOffOff)
						VCellOffset = READ_WORD(s + VOffsetOffset);
					else
					{
						if (HCellOffset & 0x8000)
						{
							VCellOffset = HCellOffset;
							HCellOffset = 0;
						}
						else
							VCellOffset = 0;
					}

					if (VCellOffset & OffsetEnableMask)
						VOffset = VCellOffset + 1;
					else
						VOffset = LineData[Y + MosaicStart].BG[bg].VOffset;

					if (HCellOffset & OffsetEnableMask)
						HOffset = (HCellOffset & ~7) | (HScroll & 7);
					else
						HOffset = HScroll;
				}

				if (HiresInterlace)
					VOffset++;

				uint32	t1, t2;
				int		VirtAlign = (((Y2 + VOffset) & 7) >> (HiresInterlace ? 1 : 0)) << 3;
				int		TilemapRow = (VOffset + Y2) >> OffsetShift;
				BG.InterlaceLine = ((VOffset + Y2) & 1) << 3;

				if ((VOffset + Y2) & 8)
				{
					t1 = 16;
					t2 = 0;
				}
				else
				{
					t1 = 0;
					t2 = 16;
				}

				uint16	*b1, *b2;

				if (TilemapRow & 0x20)
				{
					b1 = SC2;
					b2 = SC3;
				}
				else
				{
					b1 = SC0;
					b2 = SC1;
				}

				b1 += (TilemapRow & 0x1f) << 5;
				b2 += (TilemapRow & 0x1f) << 5;

				uint32	HPos = (HOffset + Left - (Left % PPU.Mosaic)) & OffsetMask;
				uint32	HTile = HPos >> 3;
				uint16	*t;

				if (BG.TileSizeH == 8)
				{
					if (HTile > 31)
						t = b2 + (HTile & 0x1f);
					else
						t = b1 + HTile;
				}
				else
				{
					if (HTile > 63)
						t = b2 + ((HTile >> 1) & 0x1f);
					else
						t = b1 + (HTile >> 1);
				}

				uint32	w = PPU.Mosaic - (Left % PPU.Mosaic);
				if (w > Width)
					w = Width;

				Tile = READ_WORD(t);
				GFX.Z1 = GFX.Z2 = (Tile & 0x2000) ? Zh : Zl;

				if (BG.TileSizeV == 16)
					Tile = TILE_PLUS(Tile, ((Tile & V_FLIP) ? t2 : t1));

				if (BG.TileSizeH == 8)
					DrawPix(Tile, Offset, VirtAlign, HPos & 7, w, Lines);
				else
				{
					if (!(Tile & H_FLIP))
						DrawPix(TILE_PLUS(Tile, (HTile & 1)), Offset, VirtAlign, HPos & 7, w, Lines);
					else
					if (!(Tile & V_FLIP))
						DrawPix(TILE_PLUS(Tile, 1 - (HTile & 1)), Offset, VirtAlign, HPos & 7, w, Lines);
				}

				Left += w;
				Offset += w * PixWidth;
				Width -= w;
			}

			MosaicStart = 0;
		}
	}
}

static inline void DrawBackgroundMode7 (int bg, void (*DrawMath) (uint32, uint32, int), void (*DrawNomath) (uint32, uint32, int), int D)
{
	for (int clip = 0; clip < GFX.Clip[bg].Count; clip++)
	{
		GFX.ClipColors = !(GFX.Clip[bg].DrawMode[clip] & 1);

		if (BG.EnableMath && (GFX.Clip[bg].DrawMode[clip] & 2))
			DrawMath(GFX.Clip[bg].Left[clip], GFX.Clip[bg].Right[clip], D);
		else
			DrawNomath(GFX.Clip[bg].Left[clip], GFX.Clip[bg].Right[clip], D);
	}
}

static inline void DrawBackdrop (void)
{
	uint32	Offset = GFX.StartY * GFX.PPL;

	for (int clip = 0; clip < GFX.Clip[5].Count; clip++)
	{
		GFX.ClipColors = !(GFX.Clip[5].DrawMode[clip] & 1);

		if (BG.EnableMath && (GFX.Clip[5].DrawMode[clip] & 2))
			GFX.DrawBackdropMath(Offset, GFX.Clip[5].Left[clip], GFX.Clip[5].Right[clip]);
		else
			GFX.DrawBackdropNomath(Offset, GFX.Clip[5].Left[clip], GFX.Clip[5].Right[clip]);
	}
}

void S9xReRefresh (void)
{
	// Be careful when calling this function from the thread other than the emulation one...
	// Here it's assumed no drawing occurs from the emulation thread when Settings.Paused is TRUE.
	if (Settings.Paused)
		S9xDeinitUpdate(IPPU.RenderedScreenWidth, IPPU.RenderedScreenHeight);
}

void S9xSetInfoString (const char *string)
{
	if (Settings.InitialInfoStringTimeout > 0)
	{
		GFX.InfoString = string;
		GFX.InfoStringTimeout = Settings.InitialInfoStringTimeout;
		S9xReRefresh();
	}
}

void S9xDisplayChar (uint16 *s, uint8 c)
{
	const uint16	black = BUILD_PIXEL(0, 0, 0);

	int	line   = ((c - 32) >> 4) * font_height;
	int	offset = ((c - 32) & 15) * font_width;

	for (int h = 0; h < font_height; h++, line++, s += GFX.RealPPL - font_width)
	{
		for (int w = 0; w < font_width; w++, s++)
		{
			char	p = font[line][offset + w];

			if (p == '#')
				*s = Settings.DisplayColor;
			else
			if (p == '.')
				*s = black;
		}
	}
}

static void DisplayStringFromBottom (const char *string, int linesFromBottom, int pixelsFromLeft, bool allowWrap)
{
	if (S9xCustomDisplayString)
	{
		S9xCustomDisplayString (string, linesFromBottom, pixelsFromLeft, allowWrap, S9X_NO_INFO);
		return;
	}

	if (linesFromBottom <= 0)
		linesFromBottom = 1;

	uint16	*dst = GFX.Screen + (IPPU.RenderedScreenHeight - font_height * linesFromBottom) * GFX.RealPPL + pixelsFromLeft;

	int	len = strlen(string);
	int	max_chars = IPPU.RenderedScreenWidth / (font_width - 1);
	int	char_count = 0;

	for (int i = 0 ; i < len ; i++, char_count++)
	{
		if (char_count >= max_chars || (uint8) string[i] < 32)
		{
			if (!allowWrap)
				break;

			dst += font_height * GFX.RealPPL - (font_width - 1) * max_chars;
			if (dst >= GFX.Screen + IPPU.RenderedScreenHeight * GFX.RealPPL)
				break;

			char_count -= max_chars;
		}

		if ((uint8) string[i] < 32)
			continue;

		S9xDisplayChar(dst, string[i]);
		dst += font_width - 1;
	}
}

static void S9xDisplayStringType (const char *string, int linesFromBottom, int pixelsFromLeft, bool allowWrap, int type)
{
    if (S9xCustomDisplayString)
    {
            S9xCustomDisplayString (string, linesFromBottom, pixelsFromLeft, allowWrap, type);
            return;
    }

    S9xDisplayString (string, linesFromBottom, pixelsFromLeft, allowWrap);
}

static void DisplayFrameRate (void)
{
	char	string[10];
	static uint32 lastFrameCount = 0, calcFps = 0;
	static time_t lastTime = time(NULL);

	time_t currTime = time(NULL);
	if (lastTime != currTime) {
		if (lastFrameCount < IPPU.TotalEmulatedFrames) {
			calcFps = (IPPU.TotalEmulatedFrames - lastFrameCount) / (uint32)(currTime - lastTime);
		}
		lastTime = currTime;
		lastFrameCount = IPPU.TotalEmulatedFrames;
	}
	sprintf(string, "%u fps", calcFps);
	S9xDisplayString(string, 2, IPPU.RenderedScreenWidth - (font_width - 1) * strlen(string) - 1, false);

#ifdef DEBUGGER
	const int	len = 8;
	sprintf(string, "%02d/%02d %02d", (int) IPPU.DisplayedRenderedFrameCount, (int) Memory.ROMFramesPerSecond, (int) IPPU.FrameCount);
#else
	const int	len = 5;
	sprintf(string, "%02d/%02d",      (int) IPPU.DisplayedRenderedFrameCount, (int) Memory.ROMFramesPerSecond);
#endif

	S9xDisplayString(string, 1, IPPU.RenderedScreenWidth - (font_width - 1) * len - 1, false);
}

static void DisplayPressedKeys (void)
{
	static unsigned char	KeyMap[]   = { '0', '1', '2', 'R', 'L', 'X', 'A', 225, 224, 227, 226, 'S', 's', 'Y', 'B' };
	static int		KeyOrder[] = { 8, 10, 7, 9, 0, 6, 14, 13, 5, 1, 4, 3, 2, 11, 12 }; // < ^ > v   A B Y X  L R  S s

	enum controllers	controller;
    int					line = Settings.DisplayMovieFrame && S9xMovieActive() ? 2 : 1;
	int8				ids[4];
	char				string[255];

	for (int port = 0; port < 2; port++)
	{
		S9xGetController(port, &controller, &ids[0], &ids[1], &ids[2], &ids[3]);

		switch (controller)
		{
			case CTL_MOUSE:
			{
				uint8 buf[5];
				if (!MovieGetMouse(port, buf))
					break;
				int16 x = READ_WORD(buf);
				int16 y = READ_WORD(buf + 2);
				uint8 buttons = buf[4];
				sprintf(string, "#%d %d: (%03d,%03d) %c%c", port + 1, ids[0] + 1, x, y,
						(buttons & 0x40) ? 'L' : ' ', (buttons & 0x80) ? 'R' : ' ');
				S9xDisplayStringType(string, line++, 1, false, S9X_PRESSED_KEYS_INFO);
				break;
			}

			case CTL_SUPERSCOPE:
			{
				uint8 buf[6];
				if (!MovieGetScope(port, buf))
					break;
				int16 x = READ_WORD(buf);
				int16 y = READ_WORD(buf + 2);
				uint8 buttons = buf[4];
				sprintf(string, "#%d %d: (%03d,%03d) %c%c%c%c", port + 1, ids[0] + 1, x, y,
						(buttons & 0x80) ? 'F' : ' ', (buttons & 0x40) ? 'C' : ' ',
						(buttons & 0x20) ? 'T' : ' ', (buttons & 0x10) ? 'P' : ' ');
				S9xDisplayStringType(string, line++, 1, false, S9X_PRESSED_KEYS_INFO);
				break;
			}

			case CTL_JUSTIFIER:
			{
				uint8 buf[11];
				if (!MovieGetJustifier(port, buf))
					break;
				int16 x1 = READ_WORD(buf);
				int16 x2 = READ_WORD(buf + 2);
				int16 y1 = READ_WORD(buf + 4);
				int16 y2 = READ_WORD(buf + 6);
				uint8 buttons = buf[8];
				bool8 offscreen1 = buf[9];
				bool8 offscreen2 = buf[10];
				sprintf(string, "#%d %d: (%03d,%03d) %c%c%c / (%03d,%03d) %c%c%c", port + 1, ids[0] + 1,
						x1, y1, (buttons & 0x80) ? 'T' : ' ', (buttons & 0x20) ? 'S' : ' ', offscreen1 ? 'O' : ' ',
						x2, y2, (buttons & 0x40) ? 'T' : ' ', (buttons & 0x10) ? 'S' : ' ', offscreen2 ? 'O' : ' ');
				S9xDisplayStringType(string, line++, 1, false, S9X_PRESSED_KEYS_INFO);
				break;
			}

			case CTL_JOYPAD:
			{
				sprintf(string, "#%d %d:                  ", port + 1, ids[0] + 1);
				uint16 pad = MovieGetJoypad(ids[0]);
				for (int i = 0; i < 15; i++)
				{
					int j = KeyOrder[i];
					int mask = (1 << (j + 1));
					string[6 + i]= (pad & mask) ? KeyMap[j] : ' ';
				}

				S9xDisplayStringType(string, line++, 1, false, S9X_PRESSED_KEYS_INFO);
				break;
			}

			case CTL_MP5:
			{
				for (int n = 0; n < 4; n++)
				{
					if (ids[n] != -1)
					{
						sprintf(string, "#%d %d:                  ", port + 1, ids[n] + 1);
						uint16 pad = MovieGetJoypad(ids[n]);
						for (int i = 0; i < 15; i++)
						{
							int j = KeyOrder[i];
							int mask = (1 << (j + 1));
							string[6 + i]= (pad & mask) ? KeyMap[j] : ' ';
						}

						S9xDisplayStringType(string, line++, 1, false, S9X_PRESSED_KEYS_INFO);
					}
				}

				break;
			}

			case CTL_MACSRIFLE:
			{
				/*
				uint8 buf[6], *p = buf;
				MovieGetScope(port, buf);
				int16 x = READ_WORD(p);
				int16 y = READ_WORD(p + 2);
				uint8 buttons = buf[4];
				sprintf(string, "#%d %d: (%03d,%03d) %c%c%c%c", port, ids[0], x, y,
						(buttons & 0x80) ? 'F' : ' ', (buttons & 0x40) ? 'C' : ' ',
						(buttons & 0x20) ? 'T' : ' ', (buttons & 0x10) ? 'P' : ' ');
				S9xDisplayString(string, line++, 1, false);
				*/
				break;
			}

			case CTL_NONE:
			{
				// Display Nothing
				break;
			}
		}
	}
}

static void DisplayWatchedAddresses (void)
{
	for (unsigned int i = 0; i < sizeof(watches) / sizeof(watches[0]); i++)
	{
		if (!watches[i].on)
			break;

		int32	displayNumber = 0;
		char	buf[32];

		for (int r = 0; r < watches[i].size; r++)
			displayNumber += (Cheat.CWatchRAM[(watches[i].address - 0x7E0000) + r]) << (8 * r);

		if (watches[i].format == 1)
			sprintf(buf, "%s,%du = %u", watches[i].desc, watches[i].size, (unsigned int) displayNumber);
		else
		if (watches[i].format == 3)
			sprintf(buf, "%s,%dx = %X", watches[i].desc, watches[i].size, (unsigned int) displayNumber);
		else // signed
		{
			if (watches[i].size == 1)
				displayNumber = (int32) ((int8)  displayNumber);
			else
			if (watches[i].size == 2)
				displayNumber = (int32) ((int16) displayNumber);
			else
			if (watches[i].size == 3)
				if (displayNumber >= 8388608)
					displayNumber -= 16777216;

			sprintf(buf, "%s,%ds = %d", watches[i].desc, watches[i].size, (int) displayNumber);
		}

		S9xDisplayString(buf, 6 + i, 1, false);
	}
}

void S9xDisplayMessages (uint16 *screen, int ppl, int width, int height, int scale)
{
	if (Settings.DisplayFrameRate)
		DisplayFrameRate();

	if (Settings.DisplayWatchedAddresses)
		DisplayWatchedAddresses();

	if (Settings.DisplayPressedKeys)
		DisplayPressedKeys();

	if (Settings.DisplayMovieFrame && S9xMovieActive())
		S9xDisplayString(GFX.FrameDisplayString, 1, 1, false);

	if (GFX.InfoString && *GFX.InfoString)
		S9xDisplayString(GFX.InfoString, 5, 1, true);
}

static uint16 get_crosshair_color (uint8 color)
{
	switch (color & 15)
	{
		case  0: return (BUILD_PIXEL( 0,  0,  0)); // transparent, shouldn't be used
		case  1: return (BUILD_PIXEL( 0,  0,  0)); // Black
		case  2: return (BUILD_PIXEL( 8,  8,  8)); // 25Grey
		case  3: return (BUILD_PIXEL(16, 16, 16)); // 50Grey
		case  4: return (BUILD_PIXEL(23, 23, 23)); // 75Grey
		case  5: return (BUILD_PIXEL(31, 31, 31)); // White
		case  6: return (BUILD_PIXEL(31,  0,  0)); // Red
		case  7: return (BUILD_PIXEL(31, 16,  0)); // Orange
		case  8: return (BUILD_PIXEL(31, 31,  0)); // Yellow
		case  9: return (BUILD_PIXEL( 0, 31,  0)); // Green
		case 10: return (BUILD_PIXEL( 0, 31, 31)); // Cyan
		case 11: return (BUILD_PIXEL( 0, 23, 31)); // Sky
		case 12: return (BUILD_PIXEL( 0,  0, 31)); // Blue
		case 13: return (BUILD_PIXEL(23,  0, 31)); // Violet
		case 14: return (BUILD_PIXEL(31,  0, 31)); // Magenta
		case 15: return (BUILD_PIXEL(31,  0, 16)); // Purple
	}

	return (0);
}

void S9xDrawCrosshair (const char *crosshair, uint8 fgcolor, uint8 bgcolor, int16 x, int16 y)
{
    // OpenEmu
	//if (!crosshair)
		return;

	int16	r, rx = 1, c, cx = 1, W = SNES_WIDTH, H = PPU.ScreenHeight;
	uint16	fg, bg;

	x -= 7;
	y -= 7;

	if (IPPU.DoubleWidthPixels)  { cx = 2; x *= 2; W *= 2; }
	if (IPPU.DoubleHeightPixels) { rx = 2; y *= 2; H *= 2; }

	fg = get_crosshair_color(fgcolor);
	bg = get_crosshair_color(bgcolor);

	uint16	*s = GFX.Screen + y * (int32)GFX.RealPPL + x;

	for (r = 0; r < 15 * rx; r++, s += GFX.RealPPL - 15 * cx)
	{
		if (y + r < 0)
		{
			s += 15 * cx;
			continue;
		}

		if (y + r >= H)
			break;

		for (c = 0; c < 15 * cx; c++, s++)
		{
			if (x + c < 0 || s < GFX.Screen)
				continue;

			if (x + c >= W)
			{
				s += 15 * cx - c;
				break;
			}

			uint8	p = crosshair[(r / rx) * 15 + (c / cx)];

			if (p == '#' && fgcolor)
				*s = (fgcolor & 0x10) ? COLOR_ADD1_2(fg, *s) : fg;
			else
			if (p == '.' && bgcolor)
				*s = (bgcolor & 0x10) ? COLOR_ADD1_2(*s, bg) : bg;
		}
	}
}

