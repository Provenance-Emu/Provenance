/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

#include "snes9x.h"
#include "memmap.h"

static uint8	region_map[6][6] =
{
	{ 0, 0x01, 0x03, 0x07, 0x0f, 0x1f },
	{ 0,    0, 0x02, 0x06, 0x0e, 0x1e },
	{ 0,    0,    0, 0x04, 0x0c, 0x1c },
	{ 0,    0,    0,    0, 0x08, 0x18 },
	{ 0,    0,    0,    0,    0, 0x10 }
};

static inline uint8 CalcWindowMask (int, uint8, uint8);
static inline void StoreWindowRegions (uint8, struct ClipData *, int, int16 *, uint8 *, bool8, bool8 s = FALSE);


static inline uint8 CalcWindowMask (int i, uint8 W1, uint8 W2)
{
	if (!PPU.ClipWindow1Enable[i])
	{
		if (!PPU.ClipWindow2Enable[i])
			return (0);
		else
		{
			if (!PPU.ClipWindow2Inside[i])
				return (~W2);
			return (W2);
		}
	}
	else
	{
		if (!PPU.ClipWindow2Enable[i])
		{
			if (!PPU.ClipWindow1Inside[i])
				return (~W1);
			return (W1);
		}
		else
		{
			if (!PPU.ClipWindow1Inside[i])
				W1 = ~W1;
			if (!PPU.ClipWindow2Inside[i])
				W2 = ~W2;

			switch (PPU.ClipWindowOverlapLogic[i])
			{
				case 0: // OR
					return (W1 | W2);

				case 1: // AND
					return (W1 & W2);

				case 2: // XOR
					return (W1 ^ W2);

				case 3: // XNOR
					return (~(W1 ^ W2));
			}
		}
	}

	// Never get here
	return (0);
}

static inline void StoreWindowRegions (uint8 Mask, struct ClipData *Clip, int n_regions, int16 *windows, uint8 *drawing_modes, bool8 sub, bool8 StoreMode0)
{
	int	ct = 0;

	for (int j = 0; j < n_regions; j++)
	{
		int	DrawMode = drawing_modes[j];
		if (sub)
			DrawMode |= 1;
		if (Mask & (1 << j))
			DrawMode = 0;

		if (!StoreMode0 && !DrawMode)
			continue;

		if (ct > 0 && Clip->Right[ct - 1] == windows[j] && Clip->DrawMode[ct - 1] == DrawMode)
			Clip->Right[ct - 1] = windows[j + 1]; // This region borders with and has the same drawing mode as the previous region: merge them.
		else
		{
			// Add a new region to the BG
			Clip->Left[ct]     = windows[j];
			Clip->Right[ct]    = windows[j + 1];
			Clip->DrawMode[ct] = DrawMode;
			ct++;
		}
	}

	Clip->Count = ct;
}

void S9xComputeClipWindows (void)
{
	int16	windows[6] = { 0, 256, 256, 256, 256, 256 };
	uint8	drawing_modes[5] = { 0, 0, 0, 0, 0 };
	int		n_regions = 1;
	int		i, j;

	// Calculate window regions. We have at most 5 regions, because we have 6 control points
	// (screen edges, window 1 left & right, and window 2 left & right).

	if (PPU.Window1Left <= PPU.Window1Right)
	{
		if (PPU.Window1Left > 0)
		{
			windows[2] = 256;
			windows[1] = PPU.Window1Left;
			n_regions = 2;
		}

		if (PPU.Window1Right < 255)
		{
			windows[n_regions + 1] = 256;
			windows[n_regions] = PPU.Window1Right + 1;
			n_regions++;
		}
	}

	if (PPU.Window2Left <= PPU.Window2Right)
	{
		for (i = 0; i <= n_regions; i++)
		{
			if (PPU.Window2Left == windows[i])
				break;

			if (PPU.Window2Left <  windows[i])
			{
				for (j = n_regions; j >= i; j--)
					windows[j + 1] = windows[j];

				windows[i] = PPU.Window2Left;
				n_regions++;
				break;
			}
		}

		for (; i <= n_regions; i++)
		{
			if (PPU.Window2Right + 1 == windows[i])
				break;

			if (PPU.Window2Right + 1 <  windows[i])
			{
				for (j = n_regions; j >= i; j--)
					windows[j + 1] = windows[j];

				windows[i] = PPU.Window2Right + 1;
				n_regions++;
				break;
			}
		}
	}

	// Get a bitmap of which regions correspond to each window.

	uint8	W1, W2;

	if (PPU.Window1Left <= PPU.Window1Right)
	{
		for (i = 0; windows[i] != PPU.Window1Left; i++) ;
		for (j = i; windows[j] != PPU.Window1Right + 1; j++) ;
		W1 = region_map[i][j];
	}
	else
		W1 = 0;

	if (PPU.Window2Left <= PPU.Window2Right)
	{
		for (i = 0; windows[i] != PPU.Window2Left; i++) ;
		for (j = i; windows[j] != PPU.Window2Right + 1; j++) ;
		W2 = region_map[i][j];
	}
	else
		W2 = 0;

	// Color Window affects the drawing mode for each region.
	// Modes are: 3=Draw as normal, 2=clip color (math only), 1=no math (draw only), 0=nothing.

	uint8	CW_color = 0, CW_math = 0;
	uint8	CW = CalcWindowMask(5, W1, W2);

	switch (Memory.FillRAM[0x2130] & 0xc0)
	{
		case 0x00:	CW_color = 0;		break;
		case 0x40:	CW_color = ~CW;		break;
		case 0x80:	CW_color = CW;		break;
		case 0xc0:	CW_color = 0xff;	break;
	}

	switch (Memory.FillRAM[0x2130] & 0x30)
	{
		case 0x00:	CW_math  = 0;		break;
		case 0x10:	CW_math  = ~CW;		break;
		case 0x20:	CW_math  = CW;		break;
		case 0x30:	CW_math  = 0xff;	break;
	}

	for (i = 0; i < n_regions; i++)
	{
		if (!(CW_color & (1 << i)))
			drawing_modes[i] |= 1;
		if (!(CW_math  & (1 << i)))
			drawing_modes[i] |= 2;
	}

	// Store backdrop clip window (draw everywhere color window allows)

	StoreWindowRegions(0, &IPPU.Clip[0][5], n_regions, windows, drawing_modes, FALSE, TRUE);
	StoreWindowRegions(0, &IPPU.Clip[1][5], n_regions, windows, drawing_modes, TRUE,  TRUE);

	// Store per-BG and OBJ clip windows

	for (j = 0; j < 5; j++)
	{
		uint8	W = Settings.DisableGraphicWindows ? 0 : CalcWindowMask(j, W1, W2);
		for (int sub = 0; sub < 2; sub++)
		{
			if (Memory.FillRAM[sub + 0x212e] & (1 << j))
				StoreWindowRegions(W, &IPPU.Clip[sub][j], n_regions, windows, drawing_modes, sub);
			else
				StoreWindowRegions(0, &IPPU.Clip[sub][j], n_regions, windows, drawing_modes, sub);
		}
	}
}
