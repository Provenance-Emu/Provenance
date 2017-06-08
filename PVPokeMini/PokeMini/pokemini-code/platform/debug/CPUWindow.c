/*
  PokeMini - Pokémon-Mini Emulator
  Copyright (C) 2009-2015  JustBurn

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdarg.h>
#include <math.h>
#include <unistd.h>

#include "SDL.h"
#include "PokeMini.h"
#include "PokeMini_Debug.h"
#include "Hardware_Debug.h"
#include "ExportBMP.h"
#include "ExportWAV.h"

#include "PokeMiniIcon_96x128.h"
#include "InstructionProc.h"
#include "InstructionInfo.h"
#include "HelpSupport.h"
#include "FileAssociation.h"

#include "CPUWindow.h"
#include "InputWindow.h"
#include "PalEditWindow.h"
#include "MemWindow.h"
#include "PRCTilesWindow.h"
#include "PRCMapWindow.h"
#include "PRCSprWindow.h"
#include "TimersWindow.h"
#include "HardIOWindow.h"
#include "IRQWindow.h"
#include "MiscWindow.h"
#include "SymbWindow.h"
#include "TraceWindow.h"
#include "ExternalWindow.h"

#include <gtk/gtk.h>
#include "GtkXDialogs.h"
#include "SGtkXDrawingView.h"

const char *AboutTxt = "PokeMini " PokeMini_Version " Debugger"
	"\n\n"
	"Coded by JustBurn\n"
	"Thanks to p0p, Dave|X,\n"
	"Onori, goldmono, Agilo,\n"
	"DarkFader, asterick,\n"
	"MrBlinky, Wa, Lupin and\n"
	"everyone in #pmdev on\n"
	"IRC EFNET!\n\n"
	"Please check readme.txt\n\n"
	"For latest version visit:\n"
	"http://pokemini.sourceforge.net/\n\n"
	"Special thanks to:\n"
	"Museum of Electronic Games & Art\n"
	"http://m-e-g-a.org\n"
	"MEGA supports preservation\n"
	"projects of digital art & culture\n";

const char *WebsiteTxt = "http://pokemini.sourceforge.net/";

// Loaded color info file
char ColorInfoFile[PMTMPV] = {0};

static int CPUWindow_InConfigs = 0;

GtkWindow *MainWindow;
static int MainWindow_minimized;
static GtkItemFactory *ItemFactory;
static GtkAccelGroup *AccelGroup;
static GtkBox *VBox1;
static GtkMenuBar *MenuBar;
static GtkTable *MTable;
static SGtkXDrawingView ProgramView;
static SGtkXDrawingView RegistersView;
static SGtkXDrawingView StackView;
static GtkNotebook *BottomNB;
static SGtkXDrawingView RAMView;
static SGtkXDrawingView EEPROMView;
static SGtkXDrawingView IOView;
static GtkScrolledWindow *EditInfoMsgSW;
static GtkTextView *EditInfoMsg;
static GtkTextBuffer *EditInfoMsgBuf;
static GtkScrolledWindow *EditInfoDebugSW;
static GtkTextView *EditInfoDebug;
static GtkTextBuffer *EditInfoDebugBuf;
static GtkFrame *StatusFrame;
static GtkLabel *StatusLabel;

static const char *CartridgeIRQVectStr[27] = {
	"Reset Location",
	"PRC Frame Copy IRQ",
	"PRC Render IRQ",
	"Timer 2 Underflow (upper) IRQ",
	"Timer 2 Underflow (lower) IRQ",
	"Timer 1 Underflow (upper) IRQ",
	"Timer 1 Underflow (lower) IRQ",
	"Timer 3 Underflow (upper) IRQ",
	"Timer 3 Comparator IRQ",
	"32hz Timer (256hz linked) IRQ",
	"8hz Timer (256hz linked) IRQ",
	"2hz Timer (256hz linked) IRQ",
	"1hz Timer (256hz linked) IRQ",
	"IR Receiver IRQ",
	"Shake Sensor IRQ",
	"Power Key IRQ",
	"Right Key IRQ",
	"Left Key IRQ",
	"Down Key IRQ",
	"Up Key IRQ",
	"C Key IRQ",
	"B Key IRQ",
	"A Key IRQ",
	"Unknown 1 IRQ",
	"Unknown 2 IRQ",
	"Unknown 3 IRQ",
	"Cartridge IRQ",
};

static uint32_t CartridgeIRQVectAddr[27] = {
	0x2102, 0x2108, 0x210E, 0x2114,
	0x211A, 0x2120, 0x2126, 0x212C,
	0x2132, 0x2138, 0x213E, 0x2144,
	0x214A, 0x2150, 0x2156, 0x215C,
	0x2162, 0x2168, 0x216E, 0x2174,
	0x217A, 0x2180, 0x2186, 0x218C,
	0x2192, 0x2198, 0x219E
};

void Set_StatusLabel(const char *format, ...)
{
	char txt[4096];

	va_list args;
	va_start (args, format);
	vsprintf (txt, format, args);
	gtk_label_set_text(StatusLabel, txt);
	va_end (args);
}

void Add_InfoMessage(const char *format, ...)
{
	GtkTextIter textiter;
	char txt[4096];
	int si;

	va_list args;
	va_start (args, format);
	vsprintf (txt, format, args);
	gtk_text_buffer_get_end_iter(EditInfoMsgBuf, &textiter);
	gtk_text_buffer_insert(EditInfoMsgBuf, &textiter, txt, -1);
	GtkAdjustment *adj = gtk_scrolled_window_get_vadjustment(EditInfoMsgSW);
	gtk_adjustment_set_value(adj, adj->upper);
	va_end (args);

	si = strlen(txt);
	if (txt[si-1] == '\n') txt[si-1] = 0;
	gtk_label_set_text(StatusLabel, txt);
}

char *DebugOutBuff = NULL;
int DebugOutBuffMode = 0;	// 0 = Disabled, 1 = Add, 2 = Clear & Add
int DebugOutBuffSize = 0;
int DebugOutBuffAlloc = 0;

static void Print_DebugOutput(const char *txt, int size)
{
	GtkTextIter textiter;

	if (!DebugOutBuffMode) {
		// Directly
		gtk_text_buffer_get_end_iter(EditInfoDebugBuf, &textiter);
		gtk_text_buffer_insert(EditInfoDebugBuf, &textiter, txt, size);
		if ((dclc_autodebugout) && (gtk_notebook_get_current_page(BottomNB) != 4)) {
			gtk_notebook_set_current_page(BottomNB, 4);
		}
		GtkAdjustment *adj = gtk_scrolled_window_get_vadjustment(EditInfoDebugSW);
		gtk_adjustment_set_value(adj, adj->upper-1);
	} else {
		// Buffered
		if ((DebugOutBuffSize + size) >= 1048576) return;
		if (DebugOutBuffAlloc <= (DebugOutBuffSize + size + 1)) {
			DebugOutBuffAlloc += (size < 1024) ? 1024 : size;
			DebugOutBuff = (char *)realloc(DebugOutBuff, DebugOutBuffAlloc);
		}
		memcpy((char *)DebugOutBuff + DebugOutBuffSize, txt, size);
		DebugOutBuffSize += size;
		DebugOutBuff[DebugOutBuffSize] = 0;
	}
}

void Cmd_DebugOutput(int ctrl)
{
	GtkTextIter startiter, enditer;

	if (ctrl < 0) {
		// Initialize
		DebugOutBuffMode = 0;
		DebugOutBuffAlloc = 0;
		DebugOutBuffSize = 0;
		if (DebugOutBuff) {
			free(DebugOutBuff);
			DebugOutBuff = NULL;
		}
		if (ctrl <= -2) {
			gtk_text_buffer_get_start_iter(EditInfoDebugBuf, &startiter);
			gtk_text_buffer_get_end_iter(EditInfoDebugBuf, &enditer);
			gtk_text_buffer_delete(EditInfoDebugBuf, &startiter, &enditer);
		}
	} else if (ctrl == 'C') {
		// Clear debug output
		if (DebugOutBuffMode) {
			DebugOutBuffMode = 2;
			DebugOutBuffSize = 0;
		} else {
			gtk_text_buffer_get_start_iter(EditInfoDebugBuf, &startiter);
			gtk_text_buffer_get_end_iter(EditInfoDebugBuf, &enditer);
			gtk_text_buffer_delete(EditInfoDebugBuf, &startiter, &enditer);
		}
	} else if (ctrl == 'L') {
		// Lock (Buffer)
		if (DebugOutBuffMode) return;
		if (!DebugOutBuff) {
			DebugOutBuffAlloc = 1024;
			DebugOutBuff = (char *)malloc(DebugOutBuffAlloc);
		}
		if (DebugOutBuff) {
			DebugOutBuffMode = 1;
			DebugOutBuffSize = 0;
		}
	} else if (ctrl == 'U') {
		// Unlock (Unbuffer)
		if (!DebugOutBuffMode) return;
		if (DebugOutBuffMode == 2) {
			gtk_text_buffer_get_start_iter(EditInfoDebugBuf, &startiter);
			gtk_text_buffer_get_end_iter(EditInfoDebugBuf, &enditer);
			gtk_text_buffer_delete(EditInfoDebugBuf, &startiter, &enditer);
		}
		gtk_text_buffer_get_end_iter(EditInfoDebugBuf, &enditer);
		gtk_text_buffer_insert(EditInfoDebugBuf, &enditer, DebugOutBuff, DebugOutBuffSize);
		if ((dclc_autodebugout) && (gtk_notebook_get_current_page(BottomNB) != 4)) {
			gtk_notebook_set_current_page(BottomNB, 4);
		}
		GtkAdjustment *adj = gtk_scrolled_window_get_vadjustment(EditInfoDebugSW);
		gtk_adjustment_set_value(adj, adj->upper-1);
		DebugOutBuffMode = 0;
		DebugOutBuffSize = 0;
	}
}

void Add_DebugOutputChar(unsigned char ch)
{
	char txt[2] = {ch, 0};

	if ((ch < 0x20) && (ch != 0x0A)) return;	// Disallow controls except new lines
	Print_DebugOutput(txt, 1);
}

void Add_DebugOutputNumber8(unsigned char num, int reg)
{
	char txt[16];

	if (reg == 1) sprintf(txt, "%02X", num);
	else if (reg == 2) sprintf(txt, "%i", num);
	else {
		if (num & 0x80) sprintf(txt, "%i", -256 + num);
		else sprintf(txt, "%i", num);
	}
	Print_DebugOutput(txt, strlen(txt));
}

void Add_DebugOutputNumber16(unsigned char num, int reg)
{
	static unsigned char numlow = 0x00;
	char txt[16];

	if (reg & 1) {
		if (reg & 2) {
			if (num & 0x80) sprintf(txt, "%i", -65536 + (numlow + num * 256));
			else sprintf(txt, "%i", (numlow + num * 256));
		} else sprintf(txt, "%i", numlow + num * 256);

		Print_DebugOutput(txt, strlen(txt));
	} else {
		numlow = num;
	}
}

void Add_DebugOutputFixed8_8(unsigned char num, int reg)
{
	static unsigned char numlow = 0x00;
	char txt[64];
	float f;
	

	if (reg & 1) {
		if (num & 0x80) {
			f = (float)numlow / 256.0f + (float)(-256 + num);
			sprintf(txt, "%.2f", f);
		} else {
			f = (float)numlow / 256.0f + (float)num;
			sprintf(txt, "%.2f", f);
		}
		Print_DebugOutput(txt, strlen(txt));
	} else {
		numlow = num;
	}
}

// ------
// DisAsm
// ------

static char *ColDCPUInstructions_Operand[] = {
	"",
	"\e234%j", "\e234%J", "\e234%i", "\e234%u", "\e234%U", "\e234%s", "\e234%S",
	"\e240A", "\e240B", "\e234%u", "\e203[HL]",
	"\e203[N+\e234%u\e203]", "\e203[\e234%U\e203]", "\e203[X]", "\e203[Y]",
	"\e240L", "\e240H", "\e240N", "\e240SP", 
	"\e240BA", "\e240HL", "\e240X", "\e240Y",
	"\e240F", "\e240I", "\e240XI", "\e240YI",
	"\e203[X+\e234%s\e203]", "\e203[Y+\e234%s\e203]", "\e203[X+L]", "\e203[Y+L]",
	"\e240U", "\e240V", "\e240XI", "\e240YI",
	"\e203[SP+\e234%s\e203]", "\e240PC", "\e234%h",
	NULL
};

// Disassembler with color codes
TSOpcDec CDisAsm_SOpcDec = {
	DefaultOperandNumberDec,	// Operand number decode
	DefaultOperandNumberEnc,	// Operand number encode
	DebugCPUInstructions_Opcode,	// Opcode dictionary
	ColDCPUInstructions_Operand,	// Operand dictionary
	"\e024",			// Opcode pre-text
	" ",				// Opcode post-text
	"\e024, "			// Operand separator
};

// -------
// Viewers
// -------

static uint32_t *ProgramView_Table = NULL;

// Get physical address of program view top
uint32_t ProgramView_GetTop(void)
{
	int pp = ProgramView.sboffset;
	if (!dclc_fullrange) {
		if (pp >= 0x8000) {
			pp = (MinxCPU.PC.B.I << 15) | (pp & 0x7FFF);
		}
	}
	return pp;
}

// Recalculate program view table
uint32_t ProgramView_Recalc(uint32_t addr)
{
	int y, size;
	for (y=0; y<ProgramView.total_lines; y++) {
		GetInstructionInfo(MinxCPU_OnRead, 1, addr, NULL, &size);
		ProgramView_Table[y] = addr;
		addr += size;
	}
	return addr;
}

// Syncronize program view
int ProgramView_Sync(void)
{
	int pp;

	// Check if the calculated begin/end match the real location
	pp = ProgramView_GetTop();
	if (pp != ProgramView.first_addr) {
		ProgramView.first_addr = pp;
		ProgramView.last_addr = ProgramView_Recalc(pp);
		return 1;
	}
	return 0;
}

// Program view go to addr
void ProgramView_GotoAddr(uint32_t addr, int highlight)
{
	int offset, laddr = addr;
	if (addr >= 0x8000) laddr = 0x8000 | (addr & 0x7FFF);

	// Sync program viewI should had them separate
	ProgramView_Sync();

	// Highlight address
	if (highlight) {
		ProgramView.highlight_addr = addr;
		ProgramView.highlight_rem = 16;
	}

	// Try to point at the center
	if ((addr < ProgramView.first_addr) || (addr >= ProgramView.last_addr)) {
		// Not exactly in the center, but oh well
		offset = ProgramView.total_lines >> 1;
		if (dclc_fullrange) {
			sgtkx_drawing_view_sbvalue(&ProgramView, addr - offset);
		} else {
			sgtkx_drawing_view_sbvalue(&ProgramView, laddr - offset);
		}
	}
}

// Program view go to SP
void StackView_GotoSP(void)
{
	int val, begin, end;

	begin = ProgramView.sboffset;
	end = begin + StackView.total_lines;
	val = MinxCPU.SP.W.L - 1;
	if ((val < begin) || (val >= end)) {
		sgtkx_drawing_view_sbvalue(&StackView, (val - 0x1000) - (StackView.total_lines >> 1));
	}
}

static const char *ProgramView_CurType[4] = { "", "!", "->", "!>" };

// Program view resize event
static int ProgramView_resize(SGtkXDrawingView *widg, int width, int height, int _c)
{
	int newsize;

	newsize = height / 12;
	if (newsize != widg->total_lines) {
		widg->total_lines = newsize;
		sgtkx_drawing_view_sbpage(widg, widg->total_lines - 1, widg->total_lines - 2);

		// Resize table
		ProgramView_Table = (uint32_t *)realloc(ProgramView_Table, ProgramView.total_lines * sizeof(uint32_t));	
		ProgramView_Sync();
	}

	return (emumode == EMUMODE_STOP);
}

// Program view exposure event
static int ProgramView_exposure(SGtkXDrawingView *widg, int width, int height, int pitch)
{
	uint32_t color;
	int stripe, spp, pp, lastpp, lp, pPC;
	InstructionInfo *opcode;
	uint8_t data[4];
	char opcodename[PMTMPV];
	int size, onCur;
	int y, yc, ys = -1;

	// Calculate height and selected item
	yc = height / 12;
	if ((widg->mouseinside) && (widg->mousey >= 12)) ys = (widg->mousey - 12) / 12;

	// Get physical cursor location and PC
	lp = pp = spp = widg->sboffset;
	if (!dclc_fullrange) {
		if (lp >= 0x8000) {
			pp = (MinxCPU.PC.B.I << 15) | (lp & 0x7FFF);
		}
	}
	pPC = PhysicalPC();

	// Decrement highlighting remain timer
	if (ProgramView.highlight_rem) {
		ProgramView.highlight_rem--;
		sgtkx_drawing_view_repaint_after(&ProgramView, 250);
	}

	// Draw content
	widg->first_addr = stripe = pp;
	lastpp = pp - 1;
	for (y=1; y<yc+1; y++) {
		// Recalculate physical address on logical mode
		if (!dclc_fullrange) {
			if (lp >= 0x8000) {
				pp = (MinxCPU.PC.B.I << 15) | (lp & 0x7FFF);
			}
		}

		// Bar color
		onCur = 0;
		if (emumode != EMUMODE_RUNFULL) {
			if (ProgramView.highlight_rem && ((ProgramView.highlight_addr > lastpp) & (ProgramView.highlight_addr <= pp))) {
				lastpp = pp = ProgramView.highlight_addr;
				color = 0xFFE060;
			} else if ((pPC > lastpp) & (pPC <= pp)) {
				lastpp = pp = pPC;
				if (!dclc_fullrange) {
					if (lp >= 0x8000) {
						pp = (MinxCPU.PC.B.I << 15) | (lp & 0x7FFF);
					}
				}
				if (PMD_TrapPoints[pp & PM_ROM_Mask] & TRAPPOINT_BREAK) {
					color = 0xFF8000;
					onCur = 3;
				} else {
					color = 0xFFCC98;
					onCur = 2;
				}
			} else if (PMD_TrapPoints[pp & PM_ROM_Mask] & TRAPPOINT_BREAK) {
				color = 0xFF2000;
				onCur = 1;
			} else if ((y-1) == ys) {
				if (stripe & 1) color = 0xF8F8DC;
				else color = 0xF8F8F8;
			} else {
				if (stripe & 1) color = 0xFFFFE4;
				else color = 0xFFFFFF;
			}
		} else {
			if (stripe & 1) color = 0x808064;
			else color = 0x808080;
		}
		sgtkx_drawing_view_drawfrect(widg, 0, y * 12, widg->width, 12, color);
		stripe++;

		// Decode instruction
		ProgramView_Table[y-1] = lastpp;
		if (pp >= PM_ROM_Size) continue;
		if (!dclc_fullrange && (lp >= 65536)) continue;
		opcode = GetInstructionInfo(MinxCPU_OnRead, 1, pp, data, &size);
		DisasmSingleOpcode(opcode, pp, data, opcodename, &CDisAsm_SOpcDec);
		ProgramView_Table[y-1] = pp;

		// Draw instruction
		if (onCur) sgtkx_drawing_view_drawtext(widg, 4, y * 12, 0x603000, "%s", ProgramView_CurType[onCur]);
		if (dclc_fullrange) {
			sgtkx_drawing_view_drawtext(widg, 20, y * 12, 0x4C3000, "$%06X", pp);
		} else {
			sgtkx_drawing_view_drawtext(widg, 20, y * 12, 0x406080, "%02X\e320@%04X", (int)MinxCPU.PC.B.I, lp);
		}
		if (size >= 1) sgtkx_drawing_view_drawtext(widg, 84, y * 12, 0x605020, "%02X", data[0]);
		if (size >= 2) sgtkx_drawing_view_drawtext(widg, 100, y * 12, 0x605040, "%02X", data[1]);
		if (size >= 3) sgtkx_drawing_view_drawtext(widg, 116, y * 12, 0x605060, "%02X", data[2]);
		if (size >= 4) sgtkx_drawing_view_drawtext(widg, 132, y * 12, 0x605080, "%02X", data[3]);
		sgtkx_drawing_view_drawtext(widg, 156, y * 12, 0x4C3000, "%s", opcodename);

		// Next one...
		lastpp = pp;
		pp += size; lp += size;
	}
	widg->last_addr = pp;

	// Draw top bar
	if (emumode != EMUMODE_RUNFULL) {
		sgtkx_drawing_view_drawfrect(widg, 0, 0, widg->width, 12, 0xD8D8CC);
	} else {
		sgtkx_drawing_view_drawfrect(widg, 0, 0, widg->width, 12, 0x68685C);
	}
	if (ys >= 0) {
		lp = pp = ProgramView_Table[ys];
		if (pp >= 0x8000) lp = 0x8000 | (pp & 0x7FFF);
		sgtkx_drawing_view_drawtext(widg, 4, 0, 0x00004C, "Program Viewer - \e345%02X\e320$%04X / $%06X", (int)MinxCPU.PC.B.I, (int)lp, pp);
	} else {
		sgtkx_drawing_view_drawtext(widg, 4, 0, 0x00004C, "Program Viewer");
	}

	return 1;
}

static GtkXCustomDialog ProgramView_leftbpress[] = {
	{GTKXCD_CHECK, "Change Opcode:", 1},
	{GTKXCD_ENTRY, ""},
	{GTKXCD_CHECK, "Enable breakpoint", 1},
	{GTKXCD_EOL, ""}
};

// Program view button press
static int ProgramView_buttonpress(SGtkXDrawingView *widg, int button, int press, int _c)
{
	InstructionInfo *opcode;
	uint8_t data[16];
	char opcodename[PMTMPV], errfail[PMTMPV];
	int size, pp, ys;

	// Calculate selected item
	if  (emumode == EMUMODE_RUNFULL) return 0;
	if ((!widg->mouseinside) || (widg->mousey < 12)) return 0;
	ys = (widg->mousey - 12) / 12;

	set_emumode(EMUMODE_STOP, 1);

	// Process selected item
	pp = ProgramView_Table[ys];
	opcode = GetInstructionInfo(MinxCPU_OnRead, 1, pp, data, &size);
	DisasmSingleOpcode(opcode, pp, data, opcodename, &DefaultSOpcDec);
	strcpy(ProgramView_leftbpress[1].text, opcodename);
	ProgramView_leftbpress[2].number = PMD_TrapPoints[pp & PM_ROM_Mask] & TRAPPOINT_BREAK;
	if (button == SGTKXDV_BLEFT) {
		if (CustomDialog(MainWindow, "Modify opcode", ProgramView_leftbpress)) {
			if (ProgramView_leftbpress[0].number) {
				// Change opcode
				opcode = AsmSingleOpcode(ProgramView_leftbpress[1].text, pp, data, &DefaultSOpcDec, errfail);
				if (opcode) {
					if (opcode->size != size) {
						if (!YesNoDialog(MainWindow, "Opcode size doesn't match\nChange anyway?", "Change opcode", GTK_MESSAGE_QUESTION, NULL)) pp = -1;
					}
					if (pp == -1) {
						// Do nothing...
					} else if (pp < 0x1000) {
						memset(&PM_BIOS[pp], 0xFF, size);	// NOP extra space
						memcpy(&PM_BIOS[pp], data, opcode->size);
					} else if (pp < 0x2000) {
						memset(&PM_RAM[pp-0x1000], 0xFF, size);	// NOP extra space
						memcpy(&PM_RAM[pp-0x1000], data, opcode->size);
					} else if (pp < 0x2100) {
						MessageDialog(MainWindow, "Cannot assembly hardware I/O!", "Modify opcode", GTK_MESSAGE_ERROR, NULL);
					} else {
						memset(&PM_ROM[pp & PM_ROM_Mask], 0xFF, size);	// NOP extra space
						memcpy(&PM_ROM[pp & PM_ROM_Mask], data, opcode->size);
					}
				} else {
					MessageDialog(MainWindow, errfail, "Modify opcode", GTK_MESSAGE_ERROR, NULL);
				}
			}
			// Change breakpoint
			PMD_TrapPoints[pp & PM_ROM_Mask] &= ~TRAPPOINT_BREAK;
			if (ProgramView_leftbpress[2].number) PMD_TrapPoints[pp & PM_ROM_Mask] |= TRAPPOINT_BREAK;
			refresh_debug(1);
		}
	} else if ((button == SGTKXDV_BMIDDLE) || (button == SGTKXDV_BRIGHT)) {
		// Toggle breakpoint
		PMD_TrapPoints[pp & PM_ROM_Mask] ^= TRAPPOINT_BREAK;
		refresh_debug(1);
	}

	set_emumode(EMUMODE_RESTORE, 1);

	return 1;
}

// CPU status string
static const char *CPUStatusStr[4] = {
	"Normal",
	"Halt",
	"Stop",
	"IRQ"
};

// Registers view exposure event
static int RegistersView_exposure(SGtkXDrawingView *widg, int width, int height, int pitch)
{
	uint32_t color;
	int y, yc, ys = -1;

	// Calculate height and selected item
	yc = height / 12;
	if ((widg->mouseinside) && (widg->mousey >= 12)) {
		ys = (widg->mousey - 12) / 12;
	}

	// Draw background
	for (y=1; y<yc; y++) {
		if (emumode != EMUMODE_RUNFULL) {
			if ((y-1) == ys) {
				if (y & 1) color = 0xF8F8DC;
				else color = 0xF8F8F8;
			} else {
				if (y & 1) color = 0xFFFFE4;
				else color = 0xFFFFFF;
			}
		} else {
			if (y & 1) color = 0x808064;
			else color = 0x808080;
		}
		sgtkx_drawing_view_drawfrect(widg, 0, y * 12, widg->width, 12, color);
	}

	// Draw top bar
	if (emumode != EMUMODE_RUNFULL) {
		sgtkx_drawing_view_drawfrect(widg, 0, 0, widg->width, 12, 0xD8D8CC);
	} else {
		sgtkx_drawing_view_drawfrect(widg, 0, 0, widg->width, 12, 0x68685C);
	}
	sgtkx_drawing_view_drawtext(widg, 4, 0, 0x00004C, "Registers Viewer");

	// Draw registers
	y = 12;
	sgtkx_drawing_view_drawtext(widg, 4, y, 0x00004C, "BA =   $%04X,%i", (int)MinxCPU.BA.W.L, (int)MinxCPU.BA.W.L);
	y += 12;
	sgtkx_drawing_view_drawtext(widg, 4, y, 0x00004C, "HL = $\e345%02X\e003%04X,%i", (int)MinxCPU.HL.B.I, (int)MinxCPU.HL.W.L, (int)MinxCPU.HL.W.L);
	y += 12;
	sgtkx_drawing_view_drawtext(widg, 4, y, 0x00004C, " X = $\e345%02X\e003%04X,%i", (int)MinxCPU.X.B.I, (int)MinxCPU.X.W.L, (int)MinxCPU.X.W.L);
	y += 12;
	sgtkx_drawing_view_drawtext(widg, 4, y, 0x00004C, " Y = $\e345%02X\e003%04X,%i", (int)MinxCPU.Y.B.I, (int)MinxCPU.Y.W.L, (int)MinxCPU.Y.W.L);
	y += 12;
	sgtkx_drawing_view_drawtext(widg, 4, y, 0x00004C, "SP =   $%04X,%i", (int)MinxCPU.SP.W.L, (int)MinxCPU.SP.W.L);
	y += 12;
	sgtkx_drawing_view_drawtext(widg, 4, y, 0x00004C, "PC = \e345%02X\e003$%04X,%i", (int)MinxCPU.PC.B.I, (int)MinxCPU.PC.W.L, (int)MinxCPU.PC.W.L);
	y += 12;
	sgtkx_drawing_view_drawtext(widg, 4, y, 0x00004C, " U = $%02X->$%02X (%i)", (int)MinxCPU.U1, (int)MinxCPU.U2, (int)MinxCPU.Shift_U);
	y += 12;
	sgtkx_drawing_view_drawtext(widg, 4, y, 0x00004C, " V = $%02X,%i", (int)MinxCPU.PC.B.I, (int)MinxCPU.PC.B.I);
	y += 12;
	sgtkx_drawing_view_drawtext(widg, 4, y, 0x00004C, " N = $%02X,%i", (int)MinxCPU.N.B.H, (int)MinxCPU.N.B.H);
	y += 12;
	sgtkx_drawing_view_drawtext(widg, 4, y, 0x00004C, " I = $%02X,%i", (int)MinxCPU.HL.B.I, (int)MinxCPU.HL.B.I);
	y += 12;
	sgtkx_drawing_view_drawtext(widg, 4, y, 0x00004C, "XI = $%02X,%i", (int)MinxCPU.X.B.I, (int)MinxCPU.X.B.I);
	y += 12;
	sgtkx_drawing_view_drawtext(widg, 4, y, 0x00004C, "YI = $%02X,%i", (int)MinxCPU.Y.B.I, (int)MinxCPU.Y.B.I);
	y += 12;
	sgtkx_drawing_view_drawtext(widg, 4, y, 0x00004C, " A = $%02X,%i", (int)MinxCPU.BA.B.L, (int)MinxCPU.BA.B.L);
	y += 12;
	sgtkx_drawing_view_drawtext(widg, 4, y, 0x00004C, " B = $%02X,%i", (int)MinxCPU.BA.B.H, (int)MinxCPU.BA.B.H);
	y += 12;
	sgtkx_drawing_view_drawtext(widg, 4, y, 0x00004C, " L = $%02X,%i", (int)MinxCPU.HL.B.L, (int)MinxCPU.HL.B.L);
	y += 12;
	sgtkx_drawing_view_drawtext(widg, 4, y, 0x00004C, " H = $%02X,%i", (int)MinxCPU.HL.B.H, (int)MinxCPU.HL.B.H);
	y += 12;
	sgtkx_drawing_view_drawtext(widg, 4, y, 0x00004C, " F = $%02X,%i", (int)MinxCPU.F, (int)MinxCPU.F);
	y += 12;
	if (emumode != EMUMODE_RUNFULL) {
		sgtkx_drawing_view_drawtext(widg, 4, y, 0x00004C, "\e%sI.D. \e%sI.F. \e%sNib. \e%sBCD",
		 (MinxCPU.F & 0x80) ? "003" : "766",
		 (MinxCPU.F & 0x40) ? "003" : "766",
		 (MinxCPU.F & 0x20) ? "003" : "766",
		 (MinxCPU.F & 0x10) ? "003" : "766");
		y += 12;
		sgtkx_drawing_view_drawtext(widg, 4, y, 0x00004C, "\e%sSign \e%sOvFl \e%sCar. \e%sZe.",
		 (MinxCPU.F & 0x08) ? "003" : "766",
		 (MinxCPU.F & 0x04) ? "003" : "766",
		 (MinxCPU.F & 0x02) ? "003" : "766",
		 (MinxCPU.F & 0x01) ? "003" : "766");
		y += 12;
	} else {
		sgtkx_drawing_view_drawtext(widg, 4, y, 0x00004C, "\e%sI.D. \e%sI.F. \e%sNib. \e%sBCD",
		 (MinxCPU.F & 0x80) ? "003" : "433",
		 (MinxCPU.F & 0x40) ? "003" : "433",
		 (MinxCPU.F & 0x20) ? "003" : "433",
		 (MinxCPU.F & 0x10) ? "003" : "433");
		y += 12;
		sgtkx_drawing_view_drawtext(widg, 4, y, 0x00004C, "\e%sSign \e%sOvFl \e%sCar. \e%sZe.",
		 (MinxCPU.F & 0x08) ? "003" : "433",
		 (MinxCPU.F & 0x04) ? "003" : "433",
		 (MinxCPU.F & 0x02) ? "003" : "433",
		 (MinxCPU.F & 0x01) ? "003" : "433");
		y += 12;
	}
	if (MinxCPU.Status == MINX_STATUS_IRQ) {
		sgtkx_drawing_view_drawtext(widg, 4, y, 0x00004C, "CPU Status: %s $%02X", CPUStatusStr[MinxCPU.Status], MinxCPU.IRQ_Vector);
	} else sgtkx_drawing_view_drawtext(widg, 4, y, 0x00004C, "CPU Status: %s", CPUStatusStr[MinxCPU.Status]);

	return 1;
}

static GtkXCustomDialog RegistersView_Uregister[] = {
	{GTKXCD_LABEL, "Set U (Latch 1):"},
	{GTKXCD_NUMIN, "", 0, 2, 1, -255, 255},
	{GTKXCD_LABEL, "Set U (Latch 2):"},
	{GTKXCD_NUMIN, "", 0, 2, 1, -255, 255},
	{GTKXCD_LABEL, "Shift U ammount:"},
	{GTKXCD_NUMIN, "", 0, 2, 0, 0, 3},
	{GTKXCD_EOL, ""}
};

static GtkXCustomDialog RegistersView_CPUStatus[] = {
	{GTKXCD_RADIO, "Normal", 1},
	{GTKXCD_RADIO, "Halt", 0},
	{GTKXCD_RADIO, "Stop", 0},
	{GTKXCD_RADIO, "IRQ", 0},
	{GTKXCD_LABEL, "IRQ Vector:"},
	{GTKXCD_NUMIN, "", 0, 2, 0, 0, 127},
	{GTKXCD_EOL, ""}
};

// Registers view button press
static int RegistersView_buttonpress(SGtkXDrawingView *widg, int button, int press, int _c)
{
	int result = 0, val;
	int ys = -1, xs = -1;

	// Calculate selected item
	if  (emumode == EMUMODE_RUNFULL) return 0;
	if ((!widg->mouseinside) || (widg->mousey < 12)) return 0;
	ys = (widg->mousey - 12) / 12;
	xs = widg->mousex / 40;

	set_emumode(EMUMODE_STOP, 1);

	if (button == SGTKXDV_BLEFT) {
		switch (ys) {
			case 0: result = EnterNumberDialog(MainWindow, "Change register", "Set BA value:", &val, (int)MinxCPU.BA.W.L, 4, 1, -65535, 65535);
				break;
			case 1: result = EnterNumberDialog(MainWindow, "Change register", "Set HL value:", &val, (int)MinxCPU.HL.W.L, 4, 1, -65535, 65535);
				break;
			case 2: result = EnterNumberDialog(MainWindow, "Change register", "Set X value:", &val, (int)MinxCPU.X.W.L, 4, 1, -65535, 65535);
				break;
			case 3: result = EnterNumberDialog(MainWindow, "Change register", "Set Y value:", &val, (int)MinxCPU.Y.W.L, 4, 1, -65535, 65535);
				break;
			case 4: result = EnterNumberDialog(MainWindow, "Change register", "Set SP value:", &val, (int)MinxCPU.SP.W.L, 4, 1, -65535, 65535);
				break;
			case 5: result = EnterNumberDialog(MainWindow, "Change register", "Set PC value:", &val, (int)MinxCPU.PC.W.L, 4, 1, -65535, 65535);
				break;
			case 6: RegistersView_Uregister[1].number = (int)MinxCPU.U1;
				RegistersView_Uregister[3].number = (int)MinxCPU.U2;
				RegistersView_Uregister[5].number = (int)MinxCPU.Shift_U;
				result = CustomDialog(MainWindow, "Change register", RegistersView_Uregister);
				break;
			case 7: result = EnterNumberDialog(MainWindow, "Change register", "Set V value:", &val, (int)MinxCPU.PC.B.I, 2, 1, -255, 255);
				break;
			case 8: result = EnterNumberDialog(MainWindow, "Change register", "Set N value:", &val, (int)MinxCPU.N.B.H, 2, 1, -255, 255);
				break;
			case 9: result = EnterNumberDialog(MainWindow, "Change register", "Set I value:", &val, (int)MinxCPU.HL.B.I, 2, 1, -255, 255);
				break;
			case 10:result = EnterNumberDialog(MainWindow, "Change register", "Set XI value:", &val, (int)MinxCPU.X.B.I, 2, 1, -255, 255);
				break;
			case 11:result = EnterNumberDialog(MainWindow, "Change register", "Set YI value:", &val, (int)MinxCPU.Y.B.I, 2, 1, -255, 255);
				break;
			case 12:result = EnterNumberDialog(MainWindow, "Change register", "Set A value:", &val, (int)MinxCPU.BA.B.L, 2, 1, -255, 255);
				break;
			case 13:result = EnterNumberDialog(MainWindow, "Change register", "Set B value:", &val, (int)MinxCPU.BA.B.H, 2, 1, -255, 255);
				break;
			case 14:result = EnterNumberDialog(MainWindow, "Change register", "Set L value:", &val, (int)MinxCPU.HL.B.L, 2, 1, -255, 255);
				break;
			case 15:result = EnterNumberDialog(MainWindow, "Change register", "Set H value:", &val, (int)MinxCPU.HL.B.H, 2, 1, -255, 255);
				break;
			case 16:result = EnterNumberDialog(MainWindow, "Change register", "Set F value:", &val, (int)MinxCPU.F, 2, 1, -255, 255);
				break;
			case 17:if (xs == 0) MinxCPU.F ^= 0x80;
				if (xs == 1) MinxCPU.F ^= 0x40;
				if (xs == 2) MinxCPU.F ^= 0x20;
				if (xs == 3) MinxCPU.F ^= 0x10;
				break;
			case 18:if (xs == 0) MinxCPU.F ^= 0x08;
				if (xs == 1) MinxCPU.F ^= 0x04;
				if (xs == 2) MinxCPU.F ^= 0x02;
				if (xs == 3) MinxCPU.F ^= 0x01;
				break;
			case 19:RegistersView_CPUStatus[0].number = (MinxCPU.Status == MINX_STATUS_NORMAL);
				RegistersView_CPUStatus[1].number = (MinxCPU.Status == MINX_STATUS_HALT);
				RegistersView_CPUStatus[2].number = (MinxCPU.Status == MINX_STATUS_STOP);
				RegistersView_CPUStatus[3].number = (MinxCPU.Status == MINX_STATUS_IRQ);
				RegistersView_CPUStatus[5].number = MinxCPU.IRQ_Vector >> 1;
				result = CustomDialog(MainWindow, "Change register", RegistersView_CPUStatus);
				break;
		}
		if (result == 1) {
			switch (ys) {
				case 0: MinxCPU.BA.W.L = val;
					break;
				case 1: MinxCPU.HL.W.L = val;
					break;
				case 2: MinxCPU.X.W.L = val;
					break;
				case 3: MinxCPU.Y.W.L = val;
					break;
				case 4: MinxCPU.SP.W.L = val;
					break;
				case 5: MinxCPU.PC.W.L = val;
					break;
				case 6: MinxCPU.U1 = RegistersView_Uregister[1].number;
					MinxCPU.U2 = RegistersView_Uregister[3].number = (int)MinxCPU.U2;
					MinxCPU.Shift_U = RegistersView_Uregister[5].number & 3;
					break;
				case 7: MinxCPU.PC.B.I = val;
					break;
				case 8: MinxCPU.N.B.H = val;
					break;
				case 9: MinxCPU.HL.B.I = val;
					break;
				case 10:MinxCPU.X.B.I = val;
					break;
				case 11:MinxCPU.Y.B.I = val;
					break;
				case 12:MinxCPU.BA.B.L = val;
					break;
				case 13:MinxCPU.BA.B.H = val;
					break;
				case 14:MinxCPU.HL.B.L = val;
					break;
				case 15:MinxCPU.HL.B.H = val;
					break;
				case 16:MinxCPU.F = val;
					break;
				case 19: // Status
					if (RegistersView_CPUStatus[0].number) MinxCPU.Status = MINX_STATUS_NORMAL;
					if (RegistersView_CPUStatus[1].number) MinxCPU.Status = MINX_STATUS_HALT;
					if (RegistersView_CPUStatus[2].number) MinxCPU.Status = MINX_STATUS_STOP;
					if (RegistersView_CPUStatus[3].number) MinxCPU.Status = MINX_STATUS_IRQ;
					MinxCPU.IRQ_Vector = RegistersView_CPUStatus[5].number << 1;
					break;
			}
		} else if (result == -1) {
			MessageDialog(MainWindow, "Invalid number", "Change register", GTK_MESSAGE_ERROR, NULL);
		}
	}

	set_emumode(EMUMODE_RESTORE, 1);

	return 1;
}

// Stack view exposure event
static int StackView_exposure(SGtkXDrawingView *widg, int width, int height, int pitch)
{
	uint32_t color;
	uint8_t dat, watch;
	int pp, y, yc, ys = -1;

	// Calculate height and selected item
	yc = height / 12;
	if ((widg->mouseinside) && (widg->mousey >= 12)) {
		ys = (widg->mousey - 12) / 12;
	}

	// Draw content
	pp = widg->sboffset + 0x1000;
	for (y=1; y<yc+1; y++) {
		if (emumode != EMUMODE_RUNFULL) {
			watch = PMD_TrapPoints[pp & PM_ROM_Mask] & TRAPPOINT_WATCH;
			if ((MinxCPU.SP.W.L - 1) == pp) {
				if (watch) {
					color = AnyView_TrapColor[watch + 1];
				} else {
					color = 0xFFCC98;
				}
			} else if (watch) {
				color = AnyView_TrapColor[watch];
			} else {
				if ((y-1) == ys) {
					if (pp & 1) color = 0xF8F8DC;
					else color = 0xF8F8F8;
				} else {
					if (pp & 1) color = 0xFFFFE4;
					else color = 0xFFFFFF;
				}
			}
		} else {
			if (pp & 1) color = 0x808064;
			else color = 0x808080;
		}
		sgtkx_drawing_view_drawfrect(widg, 0, y * 12, widg->width, 12, color);

		if (pp >= 0x2000) continue;
		dat = PM_RAM[pp & 4095];
		sgtkx_drawing_view_drawtext(widg, 4, y * 12, 0x4C3000, "$%04X: $%02X,%d", pp, (int)dat, (int)dat);
		pp++;
	}

	// Draw top bar
	if (emumode != EMUMODE_RUNFULL) {
		sgtkx_drawing_view_drawfrect(widg, 0, 0, widg->width, 12, 0xD8D8CC);
	} else {
		sgtkx_drawing_view_drawfrect(widg, 0, 0, widg->width, 12, 0x68685C);
	}
	sgtkx_drawing_view_drawtext(widg, 4, 0, 0x00004C, "Stack Viewer");

	return 1;
}

// Stack view button press
static int StackView_buttonpress(SGtkXDrawingView *widg, int button, int press, int _c)
{
	int pp, ys = -1;

	// Calculate selected item
	if  (emumode == EMUMODE_RUNFULL) return 0;
	if ((!widg->mouseinside) || (widg->mousey < 12)) return 0;
	ys = (widg->mousey - 12) / 12;

	set_emumode(EMUMODE_STOP, 1);

	// Process selected item
	pp = widg->sboffset + 0x1000 + ys;
	if (button == SGTKXDV_BLEFT) {
		if (pp < 0x2000) {
			AnyView_NewValue_CD[1].number = (int)PM_RAM[pp & 4095];
			AnyView_NewValue_CD[3].number = PMD_TrapPoints[pp] & TRAPPOINT_WATCHREAD;
			AnyView_NewValue_CD[4].number = PMD_TrapPoints[pp] & TRAPPOINT_WATCHWRITE;
			sprintf(AnyView_NewValue_CD[0].text, "Set new value for $%04X:", pp);
			if (CustomDialog(MainWindow, "Change stack", AnyView_NewValue_CD)) {
				PM_RAM[pp & 4095] = AnyView_NewValue_CD[1].number;
				PMD_TrapPoints[pp] &= ~TRAPPOINT_WATCH;
				if (AnyView_NewValue_CD[3].number) PMD_TrapPoints[pp] |= TRAPPOINT_WATCHREAD;
				if (AnyView_NewValue_CD[4].number) PMD_TrapPoints[pp] |= TRAPPOINT_WATCHWRITE;
				refresh_debug(1);
			}
		}
	}

	set_emumode(EMUMODE_RESTORE, 1);

	return 1;
}

// RAM view go to addr
void RAMView_GotoAddr(uint32_t addr, int highlight)
{
	int set_line = (addr - 0x1000) >> 4;

	// Don't do anything if it's outside range
	if ((addr < 0x1000) || (addr > 0x1FFF)) return;

	// Highlight address
	if (highlight) {
		RAMView.highlight_addr = addr;
		RAMView.highlight_rem = 16;
	}

	// Try to point at the top
	if ((set_line < RAMView.sboffset) || (set_line >= (RAMView.sboffset + RAMView.total_lines - 1))) {
		sgtkx_drawing_view_sbvalue(&RAMView, set_line - (RAMView.total_lines >> 1));
	}
}

// RAM view exposure event
static int RAMView_exposure(SGtkXDrawingView *widg, int width, int height, int pitch)
{
	uint32_t color;
	uint8_t dat, sdat, watch;
	int x, y, pp, spp;
	int yc, xs = -1, ys = -1;

	// Calculate height and selected item
	yc = height / 12;
	if ((widg->mouseinside) && (widg->mousey >= 12)) {
		if ((widg->mousex >= 56) && (widg->mousex < 376)) {
			xs = (widg->mousex - 56) / 20;
			ys = (widg->mousey - 12) / 12;
		} else if ((widg->mousex >= 376) && (widg->mousex < 504)) {
			xs = (widg->mousex - 376) / 8;
			ys = (widg->mousey - 12) / 12;
		}
	}

	// Decrement highlighting remain timer
	if (RAMView.highlight_rem) {
		RAMView.highlight_rem--;
		sgtkx_drawing_view_repaint_after(&RAMView, 250);		
	}

	// Draw content
	pp = spp = widg->sboffset * 16 + 0x1000;
	for (y=1; y<yc+1; y++) {
		if (emumode != EMUMODE_RUNFULL) {
			if ((y-1) == ys) {
				if (pp & 16) color = 0xF8F8DC;
				else color = 0xF8F8F8;
			} else {
				if (pp & 16) color = 0xFFFFE4;
				else color = 0xFFFFFF;
			}
		} else {
			if (pp & 16) color = 0x808064;
			else color = 0x808080;
		}

		sgtkx_drawing_view_drawfrect(widg, 0, y * 12, widg->width, 12, color);
		if (RAMView.highlight_rem && ((RAMView.highlight_addr & ~15) == pp)) {
			dat = RAMView.highlight_addr & 15;
			sgtkx_drawing_view_drawfrect(widg, 56+dat*20, y * 12, 16, 12, 0xFFE060);
			sgtkx_drawing_view_drawfrect(widg, 376+dat*8, y * 12, 8, 12, 0xFFE060);
		}
		if (((y-1) == ys) && (xs >= 0)) {
			sgtkx_drawing_view_drawfrect(widg, 56+xs*20, y * 12, 16, 12, color - 0x181818);
			sgtkx_drawing_view_drawfrect(widg, 376+xs*8, y * 12, 8, 12, color - 0x181818);
		}

		if (pp >= 0x2000) continue;
		sgtkx_drawing_view_drawtext(widg, 4, y * 12, 0x4C3000, "$%04X:", pp);
		for (x=0; x<16; x++) {
			dat = PM_RAM[pp & 4095];
			sdat = (dat < 0x01) ? '.' : dat;
			watch = PMD_TrapPoints[pp & PM_ROM_Mask] & TRAPPOINT_WATCH;
			if (watch) {
				sgtkx_drawing_view_drawfrect(widg, 56 + x * 20, y * 12, 16, 12, AnyView_TrapColor[watch]);
			}
			sgtkx_drawing_view_drawtext(widg, 56 + x * 20, y * 12, 0x4C4C00, "%02X", (int)dat);
			sgtkx_drawing_view_drawchar(widg, 376 + x * 8, y * 12, 0x304C00, sdat);
			pp++;
		}
	}

	// Draw top bar
	if (emumode != EMUMODE_RUNFULL) {
		sgtkx_drawing_view_drawfrect(widg, 0, 0, widg->width, 12, 0xD8D8CC);
	} else {
		sgtkx_drawing_view_drawfrect(widg, 0, 0, widg->width, 12, 0x68685C);
	}
	pp = spp + ys * 16 + xs;
	if ((ys >= 0) && (pp < 0x2000)) {
		dat = PM_RAM[pp & 4095];
		sgtkx_drawing_view_drawtext(widg, 4, 0, 0x00004C, "RAM Content  [ $%04X => $%02X, %i ]", pp, dat, dat);
	} else {
		sgtkx_drawing_view_drawtext(widg, 4, 0, 0x00004C, "RAM Content");
	}

	return 1;
}

// RAM view button press
static int RAMView_buttonpress(SGtkXDrawingView *widg, int button, int press, int _c)
{
	int pp, xs = -1, ys = -1;
	uint8_t val;

	// Calculate selected item
	if  (emumode == EMUMODE_RUNFULL) return 0;
	if ((!widg->mouseinside) || (widg->mousey < 12)) return 0;
	if ((widg->mousex >= 56) && (widg->mousex < 376)) {
		xs = (widg->mousex - 56) / 20;
		ys = (widg->mousey - 12) / 12;
	} else if ((widg->mousex >= 376) && (widg->mousex < 504)) {
		xs = (widg->mousex - 376) / 8;
		ys = (widg->mousey - 12) / 12;
	} else return 0;

	set_emumode(EMUMODE_STOP, 1);

	// Process selected item
	pp = widg->sboffset * 16 + 0x1000 + ys * 16 + xs;
	if (button == SGTKXDV_BLEFT) {
		if (pp < 0x2000) {
			AnyView_NewValue_CD[1].number = (int)PM_RAM[pp & 4095];
			AnyView_NewValue_CD[3].number = PMD_TrapPoints[pp] & TRAPPOINT_WATCHREAD;
			AnyView_NewValue_CD[4].number = PMD_TrapPoints[pp] & TRAPPOINT_WATCHWRITE;
			sprintf(AnyView_NewValue_CD[0].text, "Set new value for $%04X:", pp);
			if (CustomDialog(MainWindow, "Change RAM", AnyView_NewValue_CD)) {
				PM_RAM[pp & 4095] = AnyView_NewValue_CD[1].number;
				PMD_TrapPoints[pp] &= ~TRAPPOINT_WATCH;
				if (AnyView_NewValue_CD[3].number) PMD_TrapPoints[pp] |= TRAPPOINT_WATCHREAD;
				if (AnyView_NewValue_CD[4].number) PMD_TrapPoints[pp] |= TRAPPOINT_WATCHWRITE;
				refresh_debug(1);
			}
		}
	} else if (button == SGTKXDV_BMIDDLE) {
		if (pp < 0x2000) {
			val = PMD_TrapPoints[pp];
				switch (val & TRAPPOINT_WATCH) {
				case 0: val = TRAPPOINT_WATCHREAD | TRAPPOINT_WATCHWRITE; break;
				case TRAPPOINT_WATCHREAD | TRAPPOINT_WATCHWRITE: val = TRAPPOINT_WATCHREAD; break;
				case TRAPPOINT_WATCHREAD: val = TRAPPOINT_WATCHWRITE; break;
				case TRAPPOINT_WATCHWRITE: val = 0; break;
			}
			PMD_TrapPoints[pp] &= ~TRAPPOINT_WATCH;
			PMD_TrapPoints[pp] |= val;
			refresh_debug(1);
		}
	} else if (button == SGTKXDV_BRIGHT) {
		if (pp < 0x2000) {
			val = PMD_TrapPoints[pp];
				switch (val & TRAPPOINT_WATCH) {
				case TRAPPOINT_WATCHREAD | TRAPPOINT_WATCHWRITE: val = 0;  break;
				case TRAPPOINT_WATCHREAD: val = TRAPPOINT_WATCHREAD | TRAPPOINT_WATCHWRITE; break;
				case TRAPPOINT_WATCHWRITE: val = TRAPPOINT_WATCHREAD; break;
				case 0: val = TRAPPOINT_WATCHWRITE; break;
			}
			PMD_TrapPoints[pp] &= ~TRAPPOINT_WATCH;
			PMD_TrapPoints[pp] |= val;
			refresh_debug(1);
		}
	}

	set_emumode(EMUMODE_RESTORE, 1);

	return 1;
}

// Hardware IO exposure event
static int IOView_exposure(SGtkXDrawingView *widg, int width, int height, int pitch)
{
	uint32_t color;
	uint8_t dat, sdat, watch;
	int x, y, pp, spp;
	int yc, xs = -1, ys = -1;

	// Calculate height and selected item
	yc = height / 12;
	if ((widg->mouseinside) && (widg->mousey >= 12)) {
		if ((widg->mousex >= 56) && (widg->mousex < 376)) {
			xs = (widg->mousex - 56) / 20;
			ys = (widg->mousey - 12) / 12;
		} else if ((widg->mousex >= 376) && (widg->mousex < 504)) {
			xs = (widg->mousex - 376) / 8;
			ys = (widg->mousey - 12) / 12;
		}
	}

	// Draw content
	pp = spp = widg->sboffset * 16 + 0x2000;
	for (y=1; y<yc+1; y++) {
		if (emumode != EMUMODE_RUNFULL) {
			if ((y-1) == ys) {
				if (pp & 16) color = 0xF8F8DC;
				else color = 0xF8F8F8;
			} else {
				if (pp & 16) color = 0xFFFFE4;
				else color = 0xFFFFFF;
			}
		} else {
			if (pp & 16) color = 0x808064;
			else color = 0x808080;
		}
		sgtkx_drawing_view_drawfrect(widg, 0, y * 12, widg->width, 12, color);
		if (((y-1) == ys) && (xs >= 0)) {
			sgtkx_drawing_view_drawfrect(widg, 56+xs*20, y * 12, 16, 12, color - 0x181818);
			sgtkx_drawing_view_drawfrect(widg, 376+xs*8, y * 12, 8, 12, color - 0x181818);
		}

		if (pp >= 0x2100) continue;
		sgtkx_drawing_view_drawtext(widg, 4, y * 12, 0x4C3000, "$%04X:", pp);
		for (x=0; x<16; x++) {
			dat = MinxCPU_OnRead(0, pp);
			sdat = (dat < 0x01) ? '.' : dat;
			watch = PMD_TrapPoints[pp & PM_ROM_Mask] & TRAPPOINT_WATCH;
			if (watch) {
				sgtkx_drawing_view_drawfrect(widg, 56 + x * 20, y * 12, 16, 12, AnyView_TrapColor[watch]);
			}
			sgtkx_drawing_view_drawtext(widg, 56 + x * 20, y * 12, 0x4C4C00, "%02X", (int)dat);
			sgtkx_drawing_view_drawchar(widg, 376 + x * 8, y * 12, 0x304C00, sdat);
			pp++;
		}
	}

	// Draw top bar
	if (emumode != EMUMODE_RUNFULL) {
		sgtkx_drawing_view_drawfrect(widg, 0, 0, widg->width, 12, 0xD8D8CC);
	} else {
		sgtkx_drawing_view_drawfrect(widg, 0, 0, widg->width, 12, 0x68685C);
	}
	pp = spp + ys * 16 + xs;
	if ((ys >= 0) && (pp < 0x2100)) {
		dat = MinxCPU_OnRead(0, pp);
		sgtkx_drawing_view_drawtext(widg, 4, 0, 0x00004C, "Hardware I/O  [ $%04X => $%02X, %i ]", pp, dat, dat);
	} else {
		sgtkx_drawing_view_drawtext(widg, 4, 0, 0x00004C, "Hardware I/O");
	}

	return 1;
}

// Hardware IO view button press
static int IOView_buttonpress(SGtkXDrawingView *widg, int button, int press, int _c)
{
	int pp, xs = -1, ys = -1;
	uint8_t val;

	// Calculate selected item
	if  (emumode == EMUMODE_RUNFULL) return 0;
	if ((!widg->mouseinside) || (widg->mousey < 12)) return 0;
	if ((widg->mousex >= 56) && (widg->mousex < 376)) {
		xs = (widg->mousex - 56) / 20;
		ys = (widg->mousey - 12) / 12;
	} else if ((widg->mousex >= 376) && (widg->mousex < 504)) {
		xs = (widg->mousex - 376) / 8;
		ys = (widg->mousey - 12) / 12;
	} else return 0;

	set_emumode(EMUMODE_STOP, 1);

	// Process selected item
	pp = widg->sboffset * 16 + 0x2000 + ys * 16 + xs;
	if (button == SGTKXDV_BLEFT) {
		if (pp < 0x2100) {
			AnyView_NewValue_CD[1].number = (int)MinxCPU_OnRead(0, pp);
			AnyView_NewValue_CD[3].number = PMD_TrapPoints[pp] & TRAPPOINT_WATCHREAD;
			AnyView_NewValue_CD[4].number = PMD_TrapPoints[pp] & TRAPPOINT_WATCHWRITE;
			sprintf(AnyView_NewValue_CD[0].text, "Set new value for $%04X:", pp);
			if (CustomDialog(MainWindow, "Change Hardware IO", AnyView_NewValue_CD)) {
				MinxCPU_OnWrite(0, pp, AnyView_NewValue_CD[1].number);
				PMD_TrapPoints[pp] &= ~TRAPPOINT_WATCH;
				if (AnyView_NewValue_CD[3].number) PMD_TrapPoints[pp] |= TRAPPOINT_WATCHREAD;
				if (AnyView_NewValue_CD[4].number) PMD_TrapPoints[pp] |= TRAPPOINT_WATCHWRITE;
				refresh_debug(1);
			}
		}
	} else if (button == SGTKXDV_BMIDDLE) {
		if (pp < 0x2100) {
			val = PMD_TrapPoints[pp];
				switch (val & TRAPPOINT_WATCH) {
				case 0: val = TRAPPOINT_WATCHREAD | TRAPPOINT_WATCHWRITE; break;
				case TRAPPOINT_WATCHREAD | TRAPPOINT_WATCHWRITE: val = TRAPPOINT_WATCHREAD; break;
				case TRAPPOINT_WATCHREAD: val = TRAPPOINT_WATCHWRITE; break;
				case TRAPPOINT_WATCHWRITE: val = 0; break;
			}
			PMD_TrapPoints[pp] &= ~TRAPPOINT_WATCH;
			PMD_TrapPoints[pp] |= val;
			refresh_debug(1);
		}
	} else if (button == SGTKXDV_BRIGHT) {
		if (pp < 0x2100) {
			val = PMD_TrapPoints[pp];
				switch (val & TRAPPOINT_WATCH) {
				case TRAPPOINT_WATCHREAD | TRAPPOINT_WATCHWRITE: val = 0;  break;
				case TRAPPOINT_WATCHREAD: val = TRAPPOINT_WATCHREAD | TRAPPOINT_WATCHWRITE; break;
				case TRAPPOINT_WATCHWRITE: val = TRAPPOINT_WATCHREAD; break;
				case 0: val = TRAPPOINT_WATCHWRITE; break;
			}
			PMD_TrapPoints[pp] &= ~TRAPPOINT_WATCH;
			PMD_TrapPoints[pp] |= val;
			refresh_debug(1);
		}
	}

	set_emumode(EMUMODE_RESTORE, 1);

	return 1;
}

// EEPROM view exposure event
static int EEPROMView_exposure(SGtkXDrawingView *widg, int width, int height, int pitch)
{
	uint32_t color;
	uint8_t dat, sdat;
	int x, y, pp, spp;
	int yc, xs = -1, ys = -1;

	// Calculate height and selected item
	yc = height / 12;
	if ((widg->mouseinside) && (widg->mousey >= 12)) {
		if ((widg->mousex >= 56) && (widg->mousex < 376)) {
			xs = (widg->mousex - 56) / 20;
			ys = (widg->mousey - 12) / 12;
		} else if ((widg->mousex >= 376) && (widg->mousex < 504)) {
			xs = (widg->mousex - 376) / 8;
			ys = (widg->mousey - 12) / 12;
		}
	}

	// Draw content
	pp = spp = widg->sboffset * 16;
	for (y=1; y<yc+1; y++) {
		if (emumode != EMUMODE_RUNFULL) {
			if ((y-1) == ys) {
				if (pp & 16) color = 0xF8F8DC;
				else color = 0xF8F8F8;
			} else {
				if (pp & 16) color = 0xFFFFE4;
				else color = 0xFFFFFF;
			}
		} else {
			if (pp & 16) color = 0x808064;
			else color = 0x808080;
		}
		sgtkx_drawing_view_drawfrect(widg, 0, y * 12, widg->width, 12, color);
		if (((y-1) == ys) && (xs >= 0)) {
			sgtkx_drawing_view_drawfrect(widg, 56+xs*20, y * 12, 16, 12, color - 0x181818);
			sgtkx_drawing_view_drawfrect(widg, 376+xs*8, y * 12, 8, 12, color - 0x181818);
		}

		if (pp >= 0x2000) continue;
		sgtkx_drawing_view_drawtext(widg, 4, y * 12, 0x4C3000, "$%04X:", pp);
		for (x=0; x<16; x++) {
			dat = EEPROM[pp & 8191];
			sdat = (dat < 0x01) ? '.' : dat;
			sgtkx_drawing_view_drawtext(widg, 56 + x * 20, y * 12, 0x4C4C00, "%02X", (int)dat);
			sgtkx_drawing_view_drawchar(widg, 376 + x * 8, y * 12, 0x304C00, sdat);
			pp++;
		}
	}

	// Draw top bar
	if (emumode != EMUMODE_RUNFULL) {
		sgtkx_drawing_view_drawfrect(widg, 0, 0, widg->width, 12, 0xD8D8CC);
	} else {
		sgtkx_drawing_view_drawfrect(widg, 0, 0, widg->width, 12, 0x68685C);
	}
	pp = spp + ys * 16 + xs;
	if (ys >= 0) {
		dat = EEPROM[pp & 8191];
		sgtkx_drawing_view_drawtext(widg, 4, 0, 0x00004C, "EEPROM Content  [ $%04X => $%02X, %i ]", pp, dat, dat);
	} else {
		sgtkx_drawing_view_drawtext(widg, 4, 0, 0x00004C, "EEPROM Content");
	}

	return 1;
}

// EEPROM view button press
static int EEPROMView_buttonpress(SGtkXDrawingView *widg, int button, int press, int _c)
{
	int pp, val;
	int xs = -1, ys = -1;
	char tmp[64];

	// Calculate selected item
	if  (emumode == EMUMODE_RUNFULL) return 0;
	if ((!widg->mouseinside) || (widg->mousey < 12)) return 0;
	if ((widg->mousex >= 56) && (widg->mousex < 376)) {
		xs = (widg->mousex - 56) / 20;
		ys = (widg->mousey - 12) / 12;
	} else if ((widg->mousex >= 376) && (widg->mousex < 504)) {
		xs = (widg->mousex - 376) / 8;
		ys = (widg->mousey - 12) / 12;
	} else return 0;

	set_emumode(EMUMODE_STOP, 1);

	// Process selected item
	pp = widg->sboffset * 16 + ys * 16 + xs;
	if (button == SGTKXDV_BLEFT) {
		if (pp < 0x2000) {
			sprintf(tmp, "Set new value for $%04X:", pp);
			if (EnterNumberDialog(MainWindow, "Change EEPROM", tmp, &val, (int)EEPROM[pp & 8191], 2, 1, -255, 255)) {
				EEPROM[pp & 8191] = val;
				refresh_debug(1);
			}
		}
	}

	set_emumode(EMUMODE_RESTORE, 1);

	return 1;
}

void AnyView_DrawBackground(SGtkXDrawingView *widg, int width, int height, int zoom)
{
	uint32_t *scanptr;
	int x, y, xp, yp;

	// Sane size
	if ((width <= 0) || (width >= widg->width)) width = widg->width;
	if ((height <= 0) || (height >= widg->height)) height = widg->height;

	// Draw pattern
	for (y=0; y<widg->height; y++) {
		yp = y / zoom;
		scanptr = &widg->imgptr[y * widg->pitch];
		for (x=0; x<widg->width; x++) {
			xp = x / zoom;
			scanptr[x] = ((yp ^ xp) & 1) ? 0x808080 : 0x404040;
		}
	}
}

void AnyView_DrawDisableMask(SGtkXDrawingView *widg)
{
	uint32_t *scanptr;
	int x, y;

	// Draw mask
	for (y=0; y<widg->height; y++) {
		scanptr = &widg->imgptr[y * widg->pitch];
		for (x=0; x<widg->width; x++) {
			if ((y ^ x) & 1) scanptr[x] = 0x808080;
		}
	}
}

uint32_t AnyView_TrapColor[8] = {
	0x000000,	// No Watch
	0x000000,	// No Watch (trace over)
	0xE02000,	// Watch Read
	0xFF8040,	// Watch Read (trace over)
	0x20E000,	// Watch Write
	0x80FF40,	// Watch Write (trace over)
	0xE0D000,	// Watch RW
	0xFFE040,	// Watch RW (trace over)
};

GtkXCustomDialog AnyView_NewValue_CD[] = {
	{GTKXCD_LABEL, "Set new value for $XXXX:"},
	{GTKXCD_NUMIN, "", 0, 2, 1, -255, 255},
	{GTKXCD_LABEL, "Prefix \"$\" for hexadecimal numbers"},
	{GTKXCD_CHECK, "Watchpoint Read access", 1},
	{GTKXCD_CHECK, "Watchpoint Write access", 1},
	{GTKXCD_LABEL, "Warning: Watchpoints are only triggered at\nthe end of the instruction causing it."},
	{GTKXCD_EOL, ""}
};

GtkXCustomDialog AnyView_AddWPAt_CD[] = {
	{GTKXCD_LABEL, "Watchpoint address:"},
	{GTKXCD_NUMIN, "", 0, 6, 1, 0, 2097151},
	{GTKXCD_LABEL, "Watchpoint size:"},
	{GTKXCD_NUMIN, "", 1, 2, 0, 0, 2097151},
	{GTKXCD_LABEL, "Prefix \"$\" for hexadecimal numbers"},
	{GTKXCD_CHECK, "Read access", 1},
	{GTKXCD_CHECK, "Write access", 1},
	{GTKXCD_LABEL, "Warning: Watchpoints are only triggered at\nthe end of the instruction causing it."},
	{GTKXCD_EOL, ""}
};

static GtkXCustomDialog CPUWindow_GotoCartIRQ_CD[] = {
	{GTKXCD_LABEL, "Go to cartridge IRQ:"},
	{GTKXCD_COMBO, "", 0, 27, 0, 0, 0, CartridgeIRQVectStr},
	{GTKXCD_CHECK, "Decode address from IRQ code", 1},
	{GTKXCD_EOL, ""}
};

int AnyView_scroll(SGtkXDrawingView *widg, int value, int min, int max)
{
	return (emumode == EMUMODE_STOP);
}

int AnyView_resize(SGtkXDrawingView *widg, int width, int height, int _c)
{
	widg->total_lines = height / 12;
	sgtkx_drawing_view_sbpage(widg, widg->total_lines - 1, widg->total_lines - 2);

	return (emumode == EMUMODE_STOP);
}

int AnyView_enterleave(SGtkXDrawingView *widg, int inside, int _b, int _c)
{
	return (emumode == EMUMODE_STOP);
}

int AnyView_motion(SGtkXDrawingView *widg, int x, int y, int _c)
{
	return (emumode == EMUMODE_STOP);
}

// --------------
// Menu callbacks
// --------------

void CPUWindow_AddMinOnRecent(const char *filename)
{
	int i, x;
	for (x=0; x<9; x++) {
		if (!strcmp(filename, dclc_recent[x])) break;
	}
	if (x == 10) {
		// Not found, shift down
		for (i=8; i>=0; i--) {
			strcpy(dclc_recent[i+1], dclc_recent[i]);
		}
	} else if (x == 0) {
		// Last loaded, do nothing
		return;
	} else {
		// Found at x, shift middle
		for (i=x-1; i>=0; i--) {
			strcpy(dclc_recent[i+1], dclc_recent[i]);
		}
	}
	strcpy(dclc_recent[0], filename);
}

static void CPUWindow_CheckDirtyROM(void)
{
	char tmp[PMTMPV];
	if (clc_fullscreen) return;	// Dialog + Fullscreen = Hazard
	if (PM_MM_Dirty) {
		if (YesNoDialog(MainWindow, "ROM has been changed by Flash I/O, save MIN?", "ROM changed", GTK_MESSAGE_QUESTION, NULL)) {
			if (SaveFileDialogEx(MainWindow, "Save MIN", tmp, CommandLine.min_file, "MIN Rom (*.min)\0*.min\0All (*.*)\0*.*\0", 0)) {
				if (ExtensionCheck(tmp, ".zip")) {
					RemoveExtension(tmp);
					strcat(tmp, ".min");
				}
				if (!PokeMini_SaveMINFile(tmp)) {
					MessageDialog(MainWindow, "Error saving ROM", "MIN save error", GTK_MESSAGE_ERROR, NULL);
				}
				PM_MM_Dirty = 0;
			}
		}
	}
}

static void Menu_File_OpenMIN(GtkWidget *widget, gpointer data)
{
	char tmp[PMTMPV];
	set_emumode(EMUMODE_STOP, 1);
	if (OpenFileDialogEx(MainWindow, "Open MIN", tmp, CommandLine.min_file, "ZIP Package or MIN Rom (*.zip;*.min)\0*.zip;*.min\0ZIP Package (*.zip)\0*.zip\0MIN Rom (*.min)\0*.min\0All (*.*)\0*.*\0", 0)) {
		if (!ExtensionCheck(tmp, ".zip") && !ExtensionCheck(tmp, ".min") && !ExtensionCheck(tmp, ".minc")) {
			if (!YesNoDialog(MainWindow, "File extension should be .zip or .min, continue?", "File Extension", GTK_MESSAGE_QUESTION, NULL)) {
				set_emumode(EMUMODE_RESTORE, 1);
				return;
			}
		}
		CPUWindow_CheckDirtyROM();
		if (!PokeMini_LoadROM(tmp)) {
			MessageDialog(MainWindow, "Error loading ROM", "MIN load error", GTK_MESSAGE_ERROR, NULL);
			set_emumode(EMUMODE_RESTORE, 1);
			return;
		}
		strcpy(CommandLine.rom_dir, PokeMini_CurrDir);
		CPUWindow_AddMinOnRecent(CommandLine.min_file);
		ExtractPath(tmp, 0);
		PokeMini_SetCurrentDir(tmp);
		CPUWindow_UpdateConfigs();
		PokeMini_ApplyChanges();
		set_emumode(EMUMODE_RESTORE, 1);
		switch (clc_autorun) {
			case 1: set_emumode(EMUMODE_RUNFULL, 0); break;
			case 2: set_emumode(EMUMODE_RUNDEBFRAMESND, 0); break;
			case 3: set_emumode(EMUMODE_RUNDEBFRAME, 0); break;
		}
	} else set_emumode(EMUMODE_RESTORE, 1);
}

static void Menu_File_OpenBIOS(GtkWidget *widget, gpointer data)
{
	char tmp[PMTMPV];
	set_emumode(EMUMODE_STOP, 1);
	if (OpenFileDialogEx(MainWindow, "Open BIOS", tmp, CommandLine.bios_file, "MIN Rom (*.min)\0*.min\0All (*.*)\0*.*\0", 0)) {
		if (!ExtensionCheck(tmp, ".min")) {
			if (!YesNoDialog(MainWindow, "File extension should be .min, continue?", "File Extension", GTK_MESSAGE_QUESTION, NULL)) {
				set_emumode(EMUMODE_RESTORE, 1);
				return;
			}	
		}
		if (YesNoDialog(MainWindow, "Loading new BIOS will reset emulation\nContinue?", "Open BIOS", GTK_MESSAGE_QUESTION, NULL)) {
			if (!PokeMini_LoadBIOSFile(tmp)) {
				MessageDialog(MainWindow, "Error loading BIOS\nReverting to FreeBIOS", "BIOS load error", GTK_MESSAGE_ERROR, NULL);
				PokeMini_LoadFreeBIOS();
				return;
			}
			strcpy(CommandLine.bios_file, tmp);
			PokeMini_Reset(0);
		}
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

static void Menu_File_ReloadMIN(GtkWidget *widget, gpointer data)
{
	if (clc_fullscreen) return;	// Dialog + Fullscreen = Hazard
	set_emumode(EMUMODE_STOP, 1);
	if (!StringIsSet(CommandLine.min_file)) {
		Menu_File_OpenMIN(widget, data);
	} else {
		CPUWindow_CheckDirtyROM();
		if (!PokeMini_LoadROM(CommandLine.min_file)) {
			MessageDialog(MainWindow, "Error loading ROM", "MIN load error", GTK_MESSAGE_ERROR, NULL);
			set_emumode(EMUMODE_RESTORE, 1);
		}
		CPUWindow_AddMinOnRecent(CommandLine.min_file);
		CPUWindow_UpdateConfigs();
		PokeMini_ApplyChanges();
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

static void Menu_File_FreeBIOS(GtkWidget *widget, gpointer data)
{
	set_emumode(EMUMODE_STOP, 1);
	if (YesNoDialog(MainWindow, "Loading FreeBIOS will reset emulation\nContinue?", "FreeBIOS", GTK_MESSAGE_QUESTION, NULL)) {
		PokeMini_LoadFreeBIOS();
		CommandLine.bios_file[0] = 0;
		PokeMini_Reset(0);
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

static void Menu_File_Autorun(GtkWidget *widget, gpointer data)
{
	int index = (int)data;
	clc_autorun = index;
}

static void Menu_File_OpenColor(GtkWidget *widget, gpointer data)
{
	char tmp[PMTMPV];
	set_emumode(EMUMODE_STOP, 1);
	sprintf(tmp, "%sc", CommandLine.min_file);
	if (OpenFileDialogEx(MainWindow, "Open Color Info", tmp, tmp, "Color Info (*.minc)\0*.minc\0All (*.*)\0*.*\0", 0)) {
		if (!ExtensionCheck(tmp, ".minc")) {
			if (!YesNoDialog(MainWindow, "File extension should be .minc, continue?", "File Extension", GTK_MESSAGE_QUESTION, NULL)) {
				set_emumode(EMUMODE_RESTORE, 1);
				return;
			}	
		}
		if (!PokeMini_LoadColorFile(tmp)) {
			MessageDialog(MainWindow, "Error loading color info", "Color Info load error", GTK_MESSAGE_ERROR, NULL);
		}
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

static void Menu_File_ReloadColor(GtkWidget *widget, gpointer data)
{
	if (clc_fullscreen) return;	// Dialog + Fullscreen = Hazard
	set_emumode(EMUMODE_STOP, 1);
	if (ExtensionCheck(ColorInfoFile, ".zip")) {
		MessageDialog(MainWindow, "Cannot reload color file from a ZIP package", "Color Info load error", GTK_MESSAGE_ERROR, NULL);
		set_emumode(EMUMODE_RESTORE, 1);
		return;	
	}
	if (!StringIsSet(ColorInfoFile)) {
		MessageDialog(MainWindow, "Error loading color info", "Color Info load error", GTK_MESSAGE_ERROR, NULL);
		set_emumode(EMUMODE_RESTORE, 1);
		return;
	}
	if (!PokeMini_LoadColorFile(ColorInfoFile)) {
		MessageDialog(MainWindow, "Error reloading color info", "Color Info load error", GTK_MESSAGE_ERROR, NULL);
	}
	set_emumode(EMUMODE_RESTORE, 1);	
}

static void Menu_Capt_Snapshot1x(GtkWidget *widget, gpointer data)
{
	char filename[PMTMPV];
	cairo_surface_t *surface;
	uint32_t *imgptr = NULL;
	cairo_status_t cairerr;
	FILE *capf;
	int y;

	set_emumode(EMUMODE_STOP, 1);
	if (SaveFileDialogEx(MainWindow, "Save snapshot (1x preview)", filename, "snapshot.png", "PNG (*.png)\0*.png\0BMP (*.bmp)\0*.bmp\0", 0)) {
		surface = cairo_image_surface_create(CAIRO_FORMAT_RGB24, 96, 64);
		imgptr = (uint32_t *)cairo_image_surface_get_data(surface);
		PokeMini_VideoPreview_32(imgptr, 96, PokeMini_LCDMode);
		if (ExtensionCheck(filename, ".png")) {
			cairerr = cairo_surface_write_to_png(surface, filename);
			if (cairerr == CAIRO_STATUS_SUCCESS) {
				Add_InfoMessage("[Info] Snapshot saved to '%s'\n", filename);
			} else if (cairerr == CAIRO_STATUS_NO_MEMORY) {
				MessageDialog(MainWindow, "No enough memory!", "Save snapshot error", GTK_MESSAGE_ERROR, NULL);
			} else if (cairerr == CAIRO_STATUS_SURFACE_TYPE_MISMATCH) {
				MessageDialog(MainWindow, "Surface mismatch", "Save snapshot error", GTK_MESSAGE_ERROR, NULL);
			} else if (cairerr == CAIRO_STATUS_WRITE_ERROR) {
				MessageDialog(MainWindow, "Write I/O error", "Save snapshot error", GTK_MESSAGE_ERROR, NULL);
			}
		} else if (ExtensionCheck(filename, ".bmp")) {
			capf = Open_ExportBMP(filename, 96, 64);
			if (!capf) {
				MessageDialog(MainWindow, "Open failed", "Save snapshot error", GTK_MESSAGE_ERROR, NULL);
				set_emumode(EMUMODE_RESTORE, 1);
				return;
			}
			for (y=0; y<64; y++) {
				WriteArray_ExportBMP(capf, (uint32_t *)&imgptr[(63-y) * 96], 96);
			}
			Close_ExportBMP(capf);
			Add_InfoMessage("[Info] Snapshot saved to '%s'\n", filename);
		} else {
			MessageDialog(MainWindow, "Unsupported extension", "Save snapshot error", GTK_MESSAGE_ERROR, NULL);
		}
		cairo_surface_destroy(surface);
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

static void Menu_Capt_SnapshotLCD(GtkWidget *widget, gpointer data)
{
	char filename[PMTMPV];
	cairo_surface_t *surface;
	uint32_t *imgptr = NULL;
	cairo_status_t cairerr;
	FILE *capf;
	int w, h, y;

	w = 96 * PMZoom;
	h = 64 * PMZoom;
	set_emumode(EMUMODE_STOP, 1);
	if (SaveFileDialogEx(MainWindow, "Save snapshot (from LCD)", filename, "snapshot.png", "PNG (*.png)\0*.png\0BMP (*.bmp)\0*.bmp\0", 0)) {
		surface = cairo_image_surface_create(CAIRO_FORMAT_RGB24, w, h);
		imgptr = (uint32_t *)cairo_image_surface_get_data(surface);
		PokeMini_VideoBlit32(imgptr, w);
		if (ExtensionCheck(filename, ".png")) {
			cairerr = cairo_surface_write_to_png(surface, filename);
			if (cairerr == CAIRO_STATUS_SUCCESS) {
				Add_InfoMessage("[Info] Snapshot saved to '%s'\n", filename);
			} else if (cairerr == CAIRO_STATUS_NO_MEMORY) {
				MessageDialog(MainWindow, "No enough memory!", "Save snapshot error", GTK_MESSAGE_ERROR, NULL);
			} else if (cairerr == CAIRO_STATUS_SURFACE_TYPE_MISMATCH) {
				MessageDialog(MainWindow, "Surface mismatch", "Save snapshot error", GTK_MESSAGE_ERROR, NULL);
			} else if (cairerr == CAIRO_STATUS_WRITE_ERROR) {
				MessageDialog(MainWindow, "Write I/O error", "Save snapshot error", GTK_MESSAGE_ERROR, NULL);
			}
		} else if (ExtensionCheck(filename, ".bmp")) {
			capf = Open_ExportBMP(filename, w, h);
			if (!capf) {
				MessageDialog(MainWindow, "Open failed", "Save snapshot error", GTK_MESSAGE_ERROR, NULL);
				set_emumode(EMUMODE_RESTORE, 1);
				return;
			}
			for (y=0; y<h; y++) {
				WriteArray_ExportBMP(capf, (uint32_t *)&imgptr[((h-1)-y) * w], w);
			}
			Close_ExportBMP(capf);
			Add_InfoMessage("[Info] Snapshot saved to '%s'\n", filename);
		} else {
			MessageDialog(MainWindow, "Unsupported extension", "Save snapshot error", GTK_MESSAGE_ERROR, NULL);
		}
		cairo_surface_destroy(surface);
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

static void Menu_Capt_Sound(GtkWidget *widget, gpointer data)
{
	char filename[PMTMPV];

	set_emumode(EMUMODE_STOP, 1);
	if (sdump) {
		// Stop recording
		Close_ExportWAV(sdump);
		sdump = NULL;
		Add_InfoMessage("[Info] Sound recording stoped\n", filename);
		gtk_frame_set_label(StatusFrame, NULL);
	} else {
		// Start recording
		if (SaveFileDialogEx(MainWindow, "Save sound", filename, "sound.wav", "16-Bits Mono WAV (*.wav)\0*.wav\0", 0)) {
			sdump = Open_ExportWAV(filename, EXPORTWAV_44KHZ | EXPORTWAV_MONO | EXPORTWAV_16BITS);
			if (!sdump) {
				MessageDialog(MainWindow, "Error opening sound export file", "Save sound error", GTK_MESSAGE_ERROR, NULL);
				set_emumode(EMUMODE_RESTORE, 1);
				return;
			}
			Add_InfoMessage("[Info] Sound recording to '%s' started\n", filename);
			sdumptime = 0.0;
			gtk_frame_set_label(StatusFrame, "Recording audio: 0.00 sec(s)");
		}
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

static void Menu_Recent_Run(GtkWidget *widget, gpointer data)
{
	char tmp[PMTMPV];
	int index = (int)data;

	if (strlen(dclc_recent[index]) == 0) return;
	strcpy(tmp, dclc_recent[index]);

	set_emumode(EMUMODE_STOP, 1);
	CPUWindow_CheckDirtyROM();
	if (!PokeMini_LoadROM(tmp)) {
		MessageDialog(MainWindow, "Error loading ROM", "MIN load error", GTK_MESSAGE_ERROR, NULL);
		set_emumode(EMUMODE_RESTORE, 1);
		return;
	}
	ExtractPath(tmp, 0);
	PokeMini_SetCurrentDir(tmp);
	CPUWindow_UpdateConfigs();
	PokeMini_ApplyChanges();
	set_emumode(EMUMODE_RESTORE, 1);
	switch (clc_autorun) {
		case 1: set_emumode(EMUMODE_RUNFULL, 0); break;
		case 2: set_emumode(EMUMODE_RUNDEBFRAMESND, 0); break;
		case 3: set_emumode(EMUMODE_RUNDEBFRAME, 0); break;
	}
}

static void Menu_Recent_Clear(GtkWidget *widget, gpointer data)
{
	int i;
	for (i=0; i<10; i++) dclc_recent[i][0] = 0;
}

static void Menu_File_LoadState(GtkWidget *widget, gpointer data)
{
	char tmp[PMTMPV], romfile[PMTMPV];
	set_emumode(EMUMODE_STOP, 1);
	sprintf(tmp, "%s.sta", CommandLine.min_file);
	if (OpenFileDialogEx(MainWindow, "Load state", tmp, tmp, "State (*.sta)\0*.sta\0All (*.*)\0*.*\0", 0)) {
		if (!PokeMini_CheckSSFile(tmp, romfile)) {
			MessageDialog(MainWindow, "Invalid state file", "Load state error", GTK_MESSAGE_ERROR, NULL);
			set_emumode(EMUMODE_RESTORE, 1);
			return;
		}
		if (strcmp(romfile, CommandLine.min_file)) {
			if (!YesNoDialog(MainWindow, "Assigned ROM does not match, continue?", "Load state", GTK_MESSAGE_QUESTION, NULL)) {
				if (YesNoDialog(MainWindow, "Want to load with the assigned ROM?", "Load state", GTK_MESSAGE_QUESTION, NULL)) {
					CPUWindow_CheckDirtyROM();
					if (!PokeMini_LoadROM(romfile)) {
						MessageDialog(MainWindow, "Error loading ROM", "MIN load error", GTK_MESSAGE_ERROR, NULL);
						set_emumode(EMUMODE_RESTORE, 1);
						return;
					}
					ExtractPath(romfile, 0);
					PokeMini_SetCurrentDir(romfile);
					if (!PokeMini_LoadSSFile(tmp)) {
						MessageDialog(MainWindow, "Error loading state", "Load state error", GTK_MESSAGE_ERROR, NULL);
					}
					CPUWindow_UpdateConfigs();
					PokeMini_ApplyChanges();
				}
				set_emumode(EMUMODE_RESTORE, 1);
				return;
			}
		}
		if (!PokeMini_LoadSSFile(tmp)) {
			MessageDialog(MainWindow, "Error loading state", "Load state error", GTK_MESSAGE_ERROR, NULL);
		}
		PokeMini_ApplyChanges();
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

static void Menu_File_SaveState(GtkWidget *widget, gpointer data)
{
	char tmp[PMTMPV];
	set_emumode(EMUMODE_STOP, 1);
	sprintf(tmp, "%s.sta", CommandLine.min_file);
	if (SaveFileDialogEx(MainWindow, "Save state", tmp, tmp, "State (*.sta)\0*.sta\0All (*.*)\0*.*\0", 0)) {
		if (!PokeMini_SaveSSFile(tmp, CommandLine.min_file)) {
			MessageDialog(MainWindow, "Error saving state", "Save state error", GTK_MESSAGE_ERROR, NULL);
		}
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

static void Menu_File_SaveMIN(GtkWidget *widget, gpointer data)
{
	char tmp[PMTMPV];
	set_emumode(EMUMODE_STOP, 1);
	if (SaveFileDialogEx(MainWindow, "Save MIN", tmp, CommandLine.min_file, "MIN Rom (*.min)\0*.min\0All (*.*)\0*.*\0", 0)) {
		if (ExtensionCheck(tmp, ".zip")) {
			RemoveExtension(tmp);
			strcat(tmp, ".min");
		}
		if (!PokeMini_SaveMINFile(tmp)) {
			MessageDialog(MainWindow, "Error saving ROM", "MIN save error", GTK_MESSAGE_ERROR, NULL);
		}
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

static void Menu_File_SaveBIOS(GtkWidget *widget, gpointer data)
{
	char tmp[PMTMPV];
	set_emumode(EMUMODE_STOP, 1);
	if (SaveFileDialogEx(MainWindow, "Save BIOS", tmp, CommandLine.bios_file, "MIN Rom (*.min)\0*.min\0All (*.*)\0*.*\0", 0)) {
		if (!PokeMini_SaveBIOSFile(tmp)) {
			MessageDialog(MainWindow, "Error saving BIOS", "BIOS save error", GTK_MESSAGE_ERROR, NULL);
		}
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

static void Menu_File_Quit(GtkWidget *widget, gpointer data)
{
	set_emumode(EMUMODE_STOP, 0);
	emurunning = 0;
}

static void Menu_Options_Zoom(GtkWidget *widget, gpointer data)
{
	int index = (int)data;
	if (clc_zoom != index) {
		clc_zoom = index;
		setup_screen();
	}
}

static void Menu_Options_BPP(GtkWidget *widget, gpointer data)
{
	int index = (int)data;
	if (clc_bpp != index) {
		clc_bpp = index;
		setup_screen();
	}
}

static void Menu_Options_Palette(GtkWidget *widget, gpointer data)
{
	int index = (int)data;
	if (CommandLine.palette != index) {
		CommandLine.palette = index;
		PokeMini_VideoPalette_Index(CommandLine.palette, CommandLine.custompal, CommandLine.lcdcontrast, CommandLine.lcdbright);
	}
}

static void Menu_Options_LCDMode(GtkWidget *widget, gpointer data)
{
	int index = (int)data;
	GtkWidget *widg;
	if (CommandLine.lcdmode != index) {
		CommandLine.lcdmode = index;
		if ((CommandLine.lcdmode == 3) && !PRCColorMap) {
			widg = gtk_item_factory_get_item(ItemFactory, "/Options/LCD Mode/Analog");
			gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
			CommandLine.lcdmode = 0;
		}
		PokeMini_ApplyChanges();
	}
}

static void Menu_Options_LCDFilt(GtkWidget *widget, gpointer data)
{
	int index = (int)data;
	if (CommandLine.lcdfilter != index) {
		CommandLine.lcdfilter = index;
		PokeMini_ApplyChanges();
	}
}

static void Menu_Options_LCDContrast(GtkWidget *widget, gpointer data)
{
	int index = (int)data;
	GtkWidget *widg;
	if (CommandLine.lcdcontrast != index) {
		if (index == -1) {
			index = CommandLine.lcdcontrast;
			set_emumode(EMUMODE_STOP, 1);
			if (!EnterNumberDialog(MainWindow, "LCD Contrast...", "Set percentage of contrast boost:", &index, index, 2, 0, 0, 100)) {
				widg = gtk_item_factory_get_item(ItemFactory, "/Options/LCD Contrast/Default");
				gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
				index = 64;
			}
			set_emumode(EMUMODE_RESTORE, 1);
		}
		CommandLine.lcdcontrast = index;
		PokeMini_VideoPalette_Index(CommandLine.palette, CommandLine.custompal, CommandLine.lcdcontrast, CommandLine.lcdbright);
		PokeMini_ApplyChanges();
	}
}

static void Menu_Options_LCDBright(GtkWidget *widget, gpointer data)
{
	int index = (int)data;
	GtkWidget *widg;
	if (CommandLine.lcdbright != index) {
		if (index == -200) {
			index = CommandLine.lcdbright;
			set_emumode(EMUMODE_STOP, 1);
			if (!EnterNumberDialog(MainWindow, "LCD Bright...", "Set percentage of bright offset:", &index, index, 2, 0, -100, 100)) {
				widg = gtk_item_factory_get_item(ItemFactory, "/Options/LCD Bright/Default");
				gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
				index = 0;
			}
			set_emumode(EMUMODE_RESTORE, 1);
		}
		CommandLine.lcdbright = index;
		PokeMini_VideoPalette_Index(CommandLine.palette, CommandLine.custompal, CommandLine.lcdcontrast, CommandLine.lcdbright);
		PokeMini_ApplyChanges();
	}
}

static void Menu_Options_RumbleLvl(GtkWidget *widget, gpointer data)
{
	int index = (int)data;
	if (CommandLine.rumblelvl != index) {
		CommandLine.rumblelvl = index;
		PokeMini_ApplyChanges();
	}
}

static void Menu_Options_Sound(GtkWidget *widget, gpointer data)
{
	int index = (int)data;
	CommandLine.sound = index;
	if (emumode & EMUMODE_SOUND) enablesound(CommandLine.sound);
}

static void Menu_Options_PiezoFilter(GtkWidget *widget, gpointer data)
{
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/Options/Piezo Filter");
	CommandLine.piezofilter = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
	PokeMini_ApplyChanges();
}

static void Menu_Options_SyncCyc(GtkWidget *widget, gpointer data)
{
	int index = (int)data;
	CommandLine.synccycles = index;
}

static void Menu_Options_LowBatt(GtkWidget *widget, gpointer data)
{
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/Options/Low Battery");
	CommandLine.low_battery = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
	PokeMini_ApplyChanges();
}

static void Menu_Options_RTC(GtkWidget *widget, gpointer data)
{
	if (CPUWindow_InConfigs) return;
	CommandLine.updatertc = (int)data;
}

static void Menu_Options_ShareEEP(GtkWidget *widget, gpointer data)
{
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/Options/Share EEPROM");
	CommandLine.eeprom_share = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
	PokeMini_ApplyChanges();
}

static void Menu_Options_Multicart(GtkWidget *widget, gpointer data)
{
	int index = (int)data;
	if (CPUWindow_InConfigs) return;
	if (CommandLine.multicart != index) {
		CommandLine.multicart = index;
		MessageDialog(MainWindow, "Changing multicart require a reset or reload\nCheck Multicart Internals under Misc. Window", "Multicart", GTK_MESSAGE_WARNING, NULL);
	}
}

static void Menu_Options_FreeBIOS(GtkWidget *widget, gpointer data)
{
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/Options/Force FreeBIOS");
	CommandLine.forcefreebios = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
	PokeMini_ApplyChanges();
}

static void Menu_FileAss_Reg(GtkWidget *widget, gpointer data)
{
	int ret;
	set_emumode(EMUMODE_STOP, 1);
	if (YesNoDialog(MainWindow, "Are you sure you want to add\n.min and .minc associations?", "Question", GTK_MESSAGE_QUESTION, NULL)) {
		ret = FileAssociation_DoRegister();
		if (ret == 2) {
			MessageDialog(MainWindow, ".min and .minc have been successfuly registered", "Success", GTK_MESSAGE_INFO, NULL);
		} else if (ret == 1) {
			MessageDialog(MainWindow, ".min and .minc are still associated with other program", "Note", GTK_MESSAGE_INFO, NULL);
		} else if (ret == 0) {
			MessageDialog(MainWindow, "Error while trying to associate extensions", "Error", GTK_MESSAGE_ERROR, NULL);
		} else if (ret == -1) {
			MessageDialog(MainWindow, "Unsupported for this platform", "Error", GTK_MESSAGE_ERROR, NULL);
		}
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

static void Menu_FileAss_Unreg(GtkWidget *widget, gpointer data)
{
	int ret;
	set_emumode(EMUMODE_STOP, 1);
	if (YesNoDialog(MainWindow, "Are you sure you want to remove\n.min and .minc associations?", "Question", GTK_MESSAGE_QUESTION, NULL)) {
		ret = FileAssociation_DoUnregister();
		if (ret == 2) {
			MessageDialog(MainWindow, ".min and .minc have been successfuly unregistered", "Success", GTK_MESSAGE_INFO, NULL);
		} else if (ret == 1) {
			MessageDialog(MainWindow, ".min and .minc are still associated with other program", "Note", GTK_MESSAGE_INFO, NULL);
		} else if (ret == 0) {
			MessageDialog(MainWindow, "Error while trying to remove association", "Error", GTK_MESSAGE_ERROR, NULL);
		} else if (ret == -1) {
			MessageDialog(MainWindow, "Unsupported for this platform", "Error", GTK_MESSAGE_ERROR, NULL);
		}
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

static void Menu_Options_PalEdit(GtkWidget *widget, gpointer data)
{
	PalEditWindow_Activate();
}

static void Menu_Options_DefKeyboard(GtkWidget *widget, gpointer data)
{
	InputWindow_Activate(0);
}

static void Menu_Options_DefJoystick(GtkWidget *widget, gpointer data)
{
	InputWindow_Activate(1);
}

static void Menu_Options_UpdEEPROM(GtkWidget *widget, gpointer data)
{
	PokeMini_SaveFromCommandLines(1);
	Add_InfoMessage("[Info] EEPROM Updated\n");
}

static void Menu_Debug_FullRange(GtkWidget *widget, gpointer data)
{
	int val;
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/Debugger/Physical range");
	dclc_fullrange = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
	val = ProgramView.sboffset;
	if (dclc_fullrange) {
		if (val >= 0x8000) val = (MinxCPU.PC.B.I << 15) | (val & 0x7FFF);
		sgtkx_drawing_view_sbminmax(&ProgramView, 0, PM_ROM_Size-1);
		sgtkx_drawing_view_sbvalue(&ProgramView, val);
	} else {
		if (val >= 0x8000) val = 0x8000 | (val & 0x7FFF);
		if (PM_ROM_Size <= 65535) sgtkx_drawing_view_sbminmax(&ProgramView, 0, PM_ROM_Size-1);
		else sgtkx_drawing_view_sbminmax(&ProgramView, 0, 65535);
		sgtkx_drawing_view_sbvalue(&ProgramView, val);
	}
	refresh_debug(1);
}

static void Menu_Debug_FollowPC(GtkWidget *widget, gpointer data)
{
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/Debugger/Follow PC");
	dclc_followPC = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
}

static void Menu_Debug_FollowSP(GtkWidget *widget, gpointer data)
{
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/Debugger/Follow SP");
	dclc_followSP = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
}

static void Menu_Debug_GotoProgAddr(GtkWidget *widget, gpointer data)
{
	int addr = PhysicalPC();

	set_emumode(EMUMODE_STOP, 1);
	if (EnterNumberDialog(MainWindow, "Go to program address...", "Go to program address:", &addr, addr, 6, 1, 0, PM_ROM_Size-1)) {
		ProgramView_GotoAddr(addr, 1);
		refresh_debug(1);
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

static void Menu_Debug_GotoRAMAddr(GtkWidget *widget, gpointer data)
{
	int addr = 0x1000 + (RAMView.sboffset * 16);

	set_emumode(EMUMODE_STOP, 1);
	if (EnterNumberDialog(MainWindow, "Go to RAM address...", "Go to RAM address:", &addr, addr, 4, 1, 0x1000, 0x1FFF)) {
		RAMView_GotoAddr(addr, 1);
		refresh_debug(1);
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

static void Menu_Debug_GotoBIOSIRQ(GtkWidget *widget, gpointer data)
{
	uint32_t addr;
	int irq;

	set_emumode(EMUMODE_STOP, 1);
	if (EnterNumberDialog(MainWindow, "Go to IRQ...", "Go to IRQ:", &irq, 0, 2, 0, 0, 127)) {
		addr = (PM_BIOS[irq*2+1] << 8) | PM_BIOS[irq*2];
		ProgramView_GotoAddr(addr, 1);
		refresh_debug(1);
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

static void Menu_Debug_GotoCartIRQ(GtkWidget *widget, gpointer data)
{
	uint32_t addr;
	uint16_t laddr;
	uint8_t dat, haddr;
	int result, aoff;

	set_emumode(EMUMODE_STOP, 1);

	result = CustomDialog(MainWindow, "Go to cartridge IRQ", CPUWindow_GotoCartIRQ_CD);
	if (result == 1) {
		if (CPUWindow_GotoCartIRQ_CD[2].number) {
			// Decode
			haddr = 0;
			laddr = 0;
			addr = CartridgeIRQVectAddr[CPUWindow_GotoCartIRQ_CD[1].number];

			// Try to decode a few instructions
			for (aoff = 0; aoff < 6; ) {
				dat = MinxCPU_OnRead(0, addr + aoff);
				if (aoff++ == 6) break;
				if (dat == 0xCE) {
					// EXPAND
					dat = MinxCPU_OnRead(0, addr + aoff);
					if (aoff++ == 6) break;
					if (dat == 0xC4) {
						// MOV U, #nn
						haddr = MinxCPU_OnRead(0, addr + aoff);
						if (aoff++ == 6) break;
					}
				} else if (dat == 0xF1) {
					// JMPb @nn
					laddr = MinxCPU_OnRead(0, addr + aoff);
					if (aoff++ == 6) break;
					if (laddr & 0x80) laddr |= 0xFF00;
					laddr = addr + aoff + laddr - 1;
					addr = (haddr << 16) | laddr;
					break;		
				} else if (dat == 0xF3) {
					// JMPw @nnnn
					laddr = MinxCPU_OnRead(0, addr + aoff);
					if (aoff++ == 6) break;
					laddr |= MinxCPU_OnRead(0, addr + aoff) << 8;
					if (aoff++ == 6) break;
					laddr = addr + aoff + laddr - 1;
					addr = (haddr << 16) | laddr;
					break;
				} else {
					// RETI
					break;
				}
			}
			ProgramView_GotoAddr(addr, 1);
			refresh_debug(1);
		} else {
			// Don't decode
			addr = CartridgeIRQVectAddr[CPUWindow_GotoCartIRQ_CD[1].number];
			ProgramView_GotoAddr(addr, 1);
			refresh_debug(1);
		}
	} else if (result == -1) {
		MessageDialog(MainWindow, "Invalid number", "Manage data symbol", GTK_MESSAGE_ERROR, NULL);
	}

	set_emumode(EMUMODE_RESTORE, 1);
}

static void Menu_Debug_GotoPC(GtkWidget *widget, gpointer data)
{
	ProgramView_GotoAddr(PhysicalPC(), 0);
}

static void Menu_Debug_GotoSP(GtkWidget *widget, gpointer data)
{
	StackView_GotoSP();
}

static void Menu_DebPRC_ShowBG(GtkWidget *widget, gpointer data)
{
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/Debugger/PRC/Show Background");
	dclc_PRC_bg = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
	PRCRenderBD = !dclc_PRC_bg;
	PRCRenderBG = dclc_PRC_bg;
}

static void Menu_DebPRC_ShowSpr(GtkWidget *widget, gpointer data)
{
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/Debugger/PRC/Show Sprites");
	dclc_PRC_spr = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
	PRCRenderSpr = dclc_PRC_spr;
}

static void Menu_DebPRC_StallCPU(GtkWidget *widget, gpointer data)
{
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/Debugger/PRC/Stall CPU");
	dclc_PRC_stallcpu = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
	PRCAllowStall = dclc_PRC_stallcpu;
}

static void Menu_DebPRC_StallCycles(GtkWidget *widget, gpointer data)
{
	int val;

	set_emumode(EMUMODE_STOP, 1);
	if (EnterNumberDialog(MainWindow, "Stall Idle Cycles", "Number of idle cycles on stall:", &val, StallCycles, 2, 0, 8, 64)) {
		StallCycles = val;
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

static void Menu_Debug_IRQCall(GtkWidget *widget, gpointer data)
{
	int val;

	set_emumode(EMUMODE_STOP, 1);
	if (EnterNumberDialog(MainWindow, "IRQ Call...", "IRQ call vector:", &val, (int)0, 2, 1, 0, 127)) {
		MinxCPU.Status = MINX_STATUS_IRQ;
		MinxCPU.IRQ_Vector = (val & 0x7F) << 1;
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

void Menu_Debug_RunFull(GtkWidget *widget, gpointer data)
{
	set_emumode(EMUMODE_RUNFULL, 0);
}

void Menu_Debug_RunDFrameSnd(GtkWidget *widget, gpointer data)
{
	set_emumode(EMUMODE_RUNDEBFRAMESND, 0);
}

void Menu_Debug_RunDFrame(GtkWidget *widget, gpointer data)
{
	set_emumode(EMUMODE_RUNDEBFRAME, 0);
}

void Menu_Debug_RunDStep(GtkWidget *widget, gpointer data)
{
	set_emumode(EMUMODE_RUNDEBSTEP, 0);
}

void Menu_Debug_SingleFrame(GtkWidget *widget, gpointer data)
{
	set_emumode(EMUMODE_FRAME, 0);
}

void Menu_Debug_SingleStep(GtkWidget *widget, gpointer data)
{
	set_emumode(EMUMODE_STEP, 0);
}

void Menu_Debug_StepSkip(GtkWidget *widget, gpointer data)
{
	set_emumode(EMUMODE_STEPSKIP, 0);
}

void Menu_Debug_Stop(GtkWidget *widget, gpointer data)
{
	set_emumode(EMUMODE_STOP, 0);
}

static void Menu_Debug_ResetHard(GtkWidget *widget, gpointer data)
{
	Add_InfoMessage("[Info] Emulator has been hard reset (Full)\n");
	PokeMini_Reset(1);
	refresh_debug(1);
}

static void Menu_Debug_ResetSoft(GtkWidget *widget, gpointer data)
{
	Add_InfoMessage("[Info] Emulator has been soft reset (Partial)\n");
	PokeMini_Reset(0);
	refresh_debug(1);
}

static void Menu_Break_EnableBP(GtkWidget *widget, gpointer data)
{
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/Break/Enable breakpoints");
	PMD_EnableBreakpoints = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
}

static void Menu_Break_AddBPAt(GtkWidget *widget, gpointer data)
{
	int addr = PhysicalPC();

	set_emumode(EMUMODE_STOP, 1);
	if (EnterNumberDialog(MainWindow, "Add breakpoint at...", "Breakpoint address:", &addr, addr, 6, 1, 0, PM_ROM_Size-1)) {
		if ((addr < 0) || (addr >= PM_ROM_Size)) {
			MessageDialog(MainWindow, "Address out of range", "Add breakpoint at...", GTK_MESSAGE_ERROR, NULL);
			set_emumode(EMUMODE_RESTORE, 1);
			return;
		}
		PMD_TrapPoints[addr] |= TRAPPOINT_BREAK;
		refresh_debug(1);
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

static void Menu_Break_DelBPAt(GtkWidget *widget, gpointer data)
{
	int addr = PhysicalPC();

	set_emumode(EMUMODE_STOP, 1);
	if (EnterNumberDialog(MainWindow, "Delete breakpoint at...", "Breakpoint address:", &addr, addr, 6, 1, 0, PM_ROM_Size-1)) {
		PMD_TrapPoints[addr] &= ~TRAPPOINT_BREAK;
		refresh_debug(1);
	}
	set_emumode(EMUMODE_RESTORE, 1);
}

static void Menu_Break_DelAllBP(GtkWidget *widget, gpointer data)
{
	int i;
	for (i=0; i<PM_ROM_Size; i++) PMD_TrapPoints[i] &= ~TRAPPOINT_BREAK;
	refresh_debug(1);
}

static void Menu_Break_EnableWP(GtkWidget *widget, gpointer data)
{
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/Break/Enable watchpoints");
	PMD_EnableWatchpoints = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
}

static void Menu_Break_AddWPAt(GtkWidget *widget, gpointer data)
{
	int i, num;

	set_emumode(EMUMODE_STOP, 1);

	AnyView_AddWPAt_CD[1].number = 0x1000;
	AnyView_AddWPAt_CD[3].number = 1;
	AnyView_AddWPAt_CD[5].number = 1;
	AnyView_AddWPAt_CD[6].number = 1;
	if (CustomDialog(MainWindow, "Add watchpoing at...", AnyView_AddWPAt_CD)) {
		for (i=0; i<AnyView_AddWPAt_CD[3].number; i++) {
			num = AnyView_AddWPAt_CD[1].number + i;
			if ((num < 0) || (num >= PM_ROM_Size)) {
				MessageDialog(MainWindow, "Address out of range", "Add watchpoint at...", GTK_MESSAGE_ERROR, NULL);
				set_emumode(EMUMODE_RESTORE, 1);
				return;
			}
			PMD_TrapPoints[num] &= ~TRAPPOINT_WATCH;
			if (AnyView_AddWPAt_CD[5].number) PMD_TrapPoints[num] |= TRAPPOINT_WATCHREAD;
			if (AnyView_AddWPAt_CD[6].number) PMD_TrapPoints[num] |= TRAPPOINT_WATCHWRITE;
		}
		refresh_debug(1);
	}

	set_emumode(EMUMODE_RESTORE, 1);
}

static void Menu_Break_DelAllWP(GtkWidget *widget, gpointer data)
{
	int i;
	for (i=0; i<PM_ROM_Size; i++) PMD_TrapPoints[i] &= ~TRAPPOINT_WATCH;
	refresh_debug(1);
}

static void Menu_Break_EnableEx(GtkWidget *widget, gpointer data)
{
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/Break/Enable exceptions");
	PMD_EnableExceptions = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
}

static void Menu_Break_EnableHalt(GtkWidget *widget, gpointer data)
{
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/Break/Enable HALT break");
	PMD_EnableHalt = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
}

static void Menu_Break_EnableStop(GtkWidget *widget, gpointer data)
{
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/Break/Enable STOP break");
	PMD_EnableStop = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
}

static void Menu_View_Memory(GtkWidget *widget, gpointer data)
{
	MemWindow_Activate();
}

static void Menu_View_PRCTiles(GtkWidget *widget, gpointer data)
{
	PRCTilesWindow_Activate();
}

static void Menu_View_PRCMap(GtkWidget *widget, gpointer data)
{
	PRCMapWindow_Activate();
}

static void Menu_View_PRCSpr(GtkWidget *widget, gpointer data)
{
	PRCSprWindow_Activate();
}

static void Menu_View_HardIO(GtkWidget *widget, gpointer data)
{
	HardIOWindow_Activate();
}

static void Menu_View_IRQ(GtkWidget *widget, gpointer data)
{
	IRQWindow_Activate();
}

static void Menu_View_Timers(GtkWidget *widget, gpointer data)
{
	TimersWindow_Activate();
}

static void Menu_View_Misc(GtkWidget *widget, gpointer data)
{
	MiscWindow_Activate();
}

static void Menu_View_Symb(GtkWidget *widget, gpointer data)
{
	SymbWindow_Activate();
}

static void Menu_View_Trace(GtkWidget *widget, gpointer data)
{
	TraceWindow_Activate();
}

static void Menu_External_Run(GtkWidget *widget, gpointer data)
{
	int index = (int)data;
	int ret = ExternalWindow_Launch(dclc_extapp_exec[index], dclc_extapp_atcurrdir[index]);
	if (ret == 0) {
		MessageDialog(MainWindow, "File not found, no assoc. or fork error", "Launch failed", GTK_MESSAGE_ERROR, NULL);
	} else if (ret == -1) {
		MessageDialog(MainWindow, "Command requires ROM to be loaded", "Launch failed", GTK_MESSAGE_ERROR, NULL);
	}
}

static void Menu_External_Conf(GtkWidget *widget, gpointer data)
{
	ExternalWindow_Activate(ItemFactory);
}

static void Menu_Messages_BPMsg(GtkWidget *widget, gpointer data)
{
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/Messages/Enable messages/Breakpoints");
	PMD_MessageBreakpoints = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
}

static void Menu_Messages_WPMsg(GtkWidget *widget, gpointer data)
{
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/Messages/Enable messages/Watchpoints");
	PMD_MessageWatchpoints = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
}

static void Menu_Messages_ExMsg(GtkWidget *widget, gpointer data)
{
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/Messages/Enable messages/Exceptions");
	PMD_MessageExceptions = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
}

static void Menu_Messages_HaltMsg(GtkWidget *widget, gpointer data)
{
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/Messages/Enable messages/HALT break");
	PMD_MessageHalt = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
}

static void Menu_Messages_StopMsg(GtkWidget *widget, gpointer data)
{
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/Messages/Enable messages/STOP break");
	PMD_MessageStop = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
}

static void Menu_Messages_EnableDbgOut(GtkWidget *widget, gpointer data)
{
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/Messages/Enable debug output");
	dclc_debugout = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
}

static void Menu_Messages_AutoDbgOut(GtkWidget *widget, gpointer data)
{
	GtkWidget *widg = gtk_item_factory_get_item(ItemFactory, "/Messages/Auto-open debug output");
	dclc_autodebugout = (gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(widg)) == TRUE);
}

static void Menu_Messages_ClearMsgs(GtkWidget *widget, gpointer data)
{
	GtkTextIter startiter, enditer;
	gtk_text_buffer_get_start_iter(EditInfoMsgBuf, &startiter);
	gtk_text_buffer_get_end_iter(EditInfoMsgBuf, &enditer);
	gtk_text_buffer_delete(EditInfoMsgBuf, &startiter, &enditer);
}

static void Menu_Messages_ClearDebugOut(GtkWidget *widget, gpointer data)
{
	Cmd_DebugOutput(-2);
}

static void Menu_Refresh_Now(GtkWidget *widget, gpointer data)
{
	refresh_debug(1);
}

static void Menu_Refresh(GtkWidget *widget, gpointer data)
{
	int val, index = (int)data;
	static int lastrefrindex = -2;

	if (lastrefrindex == index) return;
	lastrefrindex = index;
	if (CPUWindow_InConfigs) return;

	if (index >= 0) {
		dclc_cpuwin_refresh = index;
	} else {
		set_emumode(EMUMODE_STOP, 1);
		if (EnterNumberDialog(MainWindow, "Custom refresh rate", "Frames skip per refresh:", &val, dclc_cpuwin_refresh, 4, 0, 0, 1000)) {
			dclc_cpuwin_refresh = val;
		}
		set_emumode(EMUMODE_RESTORE, 1);
	}
}

static void Menu_Help_CommandLine(GtkWidget *widget, gpointer data)
{
	set_emumode(EMUMODE_STOP, 1);
	display_commandline();
	set_emumode(EMUMODE_RESTORE, 1);
}

static void Menu_Help_Documentation(GtkWidget *widget, gpointer data)
{
	HelpLaunchDoc("index");
}

static void Menu_Help_VisitWebsite(GtkWidget *widget, gpointer data)
{
	HelpLaunchURL(WebsiteTxt);
}

static void Menu_Help_About(GtkWidget *widget, gpointer data)
{
	set_emumode(EMUMODE_STOP, 1);
	MessageDialog(MainWindow, AboutTxt, "About...", GTK_MESSAGE_INFO, PokeMiniIcon_96x128);
	set_emumode(EMUMODE_RESTORE, 1);
}

static gint MainWindow_delete_event(GtkWidget *widget, GdkEvent *event, gpointer data)
{
	set_emumode(EMUMODE_STOP, 0);
	emurunning = 0;

	return TRUE;
}

static gboolean MainWindow_state_event(GtkWidget *widget, GdkEventWindowState *event, gpointer user_data)
{
	if (event->changed_mask & GDK_WINDOW_STATE_ICONIFIED) MainWindow_minimized = event->new_window_state & GDK_WINDOW_STATE_ICONIFIED;
	return TRUE;
}

static void MainWindow_drag_data_received(GtkWidget *widget, GdkDragContext *context, gint x, gint y, GtkSelectionData *selection_data, guint target_type, guint time, gpointer data)
{
	char tmp[PMTMPV], *ptr = NULL;
	gchar **urilist;

	// Must contain data
	if((selection_data == NULL) || (selection_data->length < 0)) {
		gtk_drag_finish(context, FALSE, FALSE, time);
		return;
	}

	// Get URI convert to filename
	urilist = gtk_selection_data_get_uris(selection_data);
	if (urilist[0]) {
		ptr = g_filename_from_uri(urilist[0], NULL, NULL);
	}
	g_strfreev(urilist);
	if (!ptr) {
		gtk_drag_finish(context, FALSE, FALSE, time);
		return;		
	}
	strncpy(tmp, ptr, PMTMPV);
	tmp[PMTMPV-1] = 0;
	g_free(ptr);
	gtk_drag_finish(context, TRUE, FALSE, time);

	set_emumode(EMUMODE_STOP, 1);
	if (!ExtensionCheck(tmp, ".zip") && !ExtensionCheck(tmp, ".min") && !ExtensionCheck(tmp, ".minc")) {
		if (!YesNoDialog(MainWindow, "File extension should be .zip or .min, continue?", "File Extension", GTK_MESSAGE_QUESTION, NULL)) {
			set_emumode(EMUMODE_RESTORE, 1);
			return;
		}
	}
	CPUWindow_CheckDirtyROM();
	if (!PokeMini_LoadROM(tmp)) {
		MessageDialog(MainWindow, "Error loading ROM", "MIN load error", GTK_MESSAGE_ERROR, NULL);
		set_emumode(EMUMODE_RESTORE, 1);
		return;
	}
	CPUWindow_AddMinOnRecent(CommandLine.min_file);
	ExtractPath(tmp, 0);
	PokeMini_SetCurrentDir(tmp);
	CPUWindow_UpdateConfigs();
	PokeMini_ApplyChanges();
	set_emumode(EMUMODE_RESTORE, 1);
	switch (clc_autorun) {
		case 1: set_emumode(EMUMODE_RUNFULL, 0); break;
		case 2: set_emumode(EMUMODE_RUNDEBFRAMESND, 0); break;
		case 3: set_emumode(EMUMODE_RUNDEBFRAME, 0); break;
	}
}

// Mod: 0 = None, 1 = Ctrl, 2 = Shift, 4 = Alt
TMenu_items_accel Menu_item_accel[] = {
	{ SDLK_o,  5, Menu_File_ReloadMIN },
	{ SDLK_c,  5, Menu_File_ReloadColor },
	{ SDLK_q,  1, Menu_File_Quit },
	{ SDLK_F5, 0, Menu_Debug_RunFull },
	{ SDLK_F5, 2, Menu_Debug_RunDFrameSnd },
	{ SDLK_F5, 1, Menu_Debug_RunDFrame },
	{ SDLK_F3, 1, Menu_Debug_RunDStep },
	{ SDLK_F4, 0, Menu_Debug_SingleFrame },
	{ SDLK_F3, 0, Menu_Debug_SingleStep },
	{ SDLK_F3, 2, Menu_Debug_StepSkip },
	{ SDLK_F2, 0, Menu_Debug_Stop },
	{ SDLK_r,  1, Menu_Debug_ResetHard },
	{ SDLK_r,  2, Menu_Debug_ResetSoft },
	{ 0, 0, NULL }
};
static GtkItemFactoryEntry CPUWindow_MenuItems[] = {
	{ "/_File",                              NULL,           NULL,                         0, "<Branch>" },
	{ "/File/Open _Min...",                  "<CTRL>O",      Menu_File_OpenMIN,            0, "<Item>" },
	{ "/File/Open _BIOS...",                 "<CTRL>B",      Menu_File_OpenBIOS,           0, "<Item>" },
	{ "/File/_Reload Min",                   "<CTRL><ALT>O", Menu_File_ReloadMIN,          0, "<Item>" },
	{ "/File/Use internal _FreeBIOS",        NULL,           Menu_File_FreeBIOS,           0, "<Item>" },
	{ "/File/Autorun/Disabled",              NULL,           Menu_File_Autorun,            0, "<RadioItem>" },
	{ "/File/Autorun/Run full speed",        NULL,           Menu_File_Autorun,            1, "/File/Autorun/Disabled" },
	{ "/File/Autorun/Debug frames (Sound)",  NULL,           Menu_File_Autorun,            2, "/File/Autorun/Disabled" },
	{ "/File/Autorun/Debug frames",          NULL,           Menu_File_Autorun,            3, "/File/Autorun/Disabled" },
	{ "/File/sep0",                          NULL,           NULL,                         0, "<Separator>" },
	{ "/File/_Recent",                       NULL,           NULL,                         0, "<Branch>" },
	{ "/File/Recent/ROM0",                   "<CTRL><SHIFT>1",Menu_Recent_Run,             0, "<Item>" },
	{ "/File/Recent/ROM1",                   "<CTRL><SHIFT>2",Menu_Recent_Run,             1, "<Item>" },
	{ "/File/Recent/ROM2",                   "<CTRL><SHIFT>3",Menu_Recent_Run,             2, "<Item>" },
	{ "/File/Recent/ROM3",                   "<CTRL><SHIFT>4",Menu_Recent_Run,             3, "<Item>" },
	{ "/File/Recent/ROM4",                   "<CTRL><SHIFT>5",Menu_Recent_Run,             4, "<Item>" },
	{ "/File/Recent/ROM5",                   "<CTRL><SHIFT>6",Menu_Recent_Run,             5, "<Item>" },
	{ "/File/Recent/ROM6",                   "<CTRL><SHIFT>7",Menu_Recent_Run,             6, "<Item>" },
	{ "/File/Recent/ROM7",                   "<CTRL><SHIFT>8",Menu_Recent_Run,             7, "<Item>" },
	{ "/File/Recent/ROM8",                   "<CTRL><SHIFT>9",Menu_Recent_Run,             8, "<Item>" },
	{ "/File/Recent/ROM9",                   "<CTRL><SHIFT>0",Menu_Recent_Run,             9, "<Item>" },
	{ "/File/Recent/sep1",                   NULL,           NULL,                         0, "<Separator>" },
	{ "/File/Recent/Clear List",             NULL,           Menu_Recent_Clear,            0, "<Item>" },
	{ "/File/sep1",                          NULL,           NULL,                         0, "<Separator>" },
	{ "/File/_Load state...",                NULL,           Menu_File_LoadState,          0, "<Item>" },
	{ "/File/_Save state...",                NULL,           Menu_File_SaveState,          0, "<Item>" },
	{ "/File/sep2",                          NULL,           NULL,                         0, "<Separator>" },
	{ "/File/Open _Color Info...",           "<CTRL><ALT>C",Menu_File_OpenColor,           0, "<Item>" },
	{ "/File/Reload _Color Info",            "<CTRL><SHIFT>C",Menu_File_ReloadColor,       0, "<Item>" },
	{ "/File/sep3",                          NULL,           NULL,                         0, "<Separator>" },
	{ "/File/_Capture",                      NULL,           NULL,                         0, "<Branch>" },
	{ "/File/Capture/Snapshot 1x preview",   NULL,           Menu_Capt_Snapshot1x,         0, "<Item>" },
	{ "/File/Capture/Snapshot from LCD",     NULL,           Menu_Capt_SnapshotLCD,        0, "<Item>" },
	{ "/File/Capture/Sound (Start & Stop)",  NULL,           Menu_Capt_Sound,              0, "<Item>" },
	{ "/File/Save _Min...",                  "<CTRL>S",      Menu_File_SaveMIN,            0, "<Item>" },
	{ "/File/Save _BIOS...",                 NULL,           Menu_File_SaveBIOS,           0, "<Item>" },
	{ "/File/sep4",                          NULL,           NULL,                         0, "<Separator>" },
	{ "/File/_Quit",                         "<CTRL>Q",      Menu_File_Quit,               0, "<Item>" },

	{ "/_Options",                           NULL,           NULL,                         0, "<Branch>" },
	{ "/Options/_Zoom",                      NULL,           NULL,                         0, "<Branch>" },
	{ "/Options/Zoom/1x (96x64)",            NULL,           Menu_Options_Zoom,            1, "<RadioItem>" },
	{ "/Options/Zoom/2x (192x128)",          NULL,           Menu_Options_Zoom,            2, "/Options/Zoom/1x (96x64)" },
	{ "/Options/Zoom/3x (288x192)",          NULL,           Menu_Options_Zoom,            3, "/Options/Zoom/1x (96x64)" },
	{ "/Options/Zoom/4x (384x256)",          NULL,           Menu_Options_Zoom,            4, "/Options/Zoom/1x (96x64)" },
	{ "/Options/Zoom/5x (480x320)",          NULL,           Menu_Options_Zoom,            5, "/Options/Zoom/1x (96x64)" },
	{ "/Options/Zoom/6x (576x384)",          NULL,           Menu_Options_Zoom,            6, "/Options/Zoom/1x (96x64)" },
	{ "/Options/_Bits-Per-Pixel",            NULL,           NULL,                         0, "<Branch>" },
	{ "/Options/Bits-Per-Pixel/16 bpp",      NULL,           Menu_Options_BPP,            16, "<RadioItem>" },
	{ "/Options/Bits-Per-Pixel/32 bpp",      NULL,           Menu_Options_BPP,            32, "/Options/Bits-Per-Pixel/16 bpp" },
	{ "/Options/_Palette",                   NULL,           NULL,                         0, "<Branch>" },
	{ "/Options/Palette/Default",            NULL,           Menu_Options_Palette,         0, "<RadioItem>" },
	{ "/Options/Palette/Old",                NULL,           Menu_Options_Palette,         1, "/Options/Palette/Default" },
	{ "/Options/Palette/Black & White",      NULL,           Menu_Options_Palette,         2, "/Options/Palette/Default" },
	{ "/Options/Palette/Green Palette",      NULL,           Menu_Options_Palette,         3, "/Options/Palette/Default" },
	{ "/Options/Palette/Green Vector",       NULL,           Menu_Options_Palette,         4, "/Options/Palette/Default" },
	{ "/Options/Palette/Red Palette",        NULL,           Menu_Options_Palette,         5, "/Options/Palette/Default" },
	{ "/Options/Palette/Red Vector",         NULL,           Menu_Options_Palette,         6, "/Options/Palette/Default" },
	{ "/Options/Palette/Blue LCD",           NULL,           Menu_Options_Palette,         7, "/Options/Palette/Default" },
	{ "/Options/Palette/LED Backlight",      NULL,           Menu_Options_Palette,         8, "/Options/Palette/Default" },
	{ "/Options/Palette/Girl Power",         NULL,           Menu_Options_Palette,         9, "/Options/Palette/Default" },
	{ "/Options/Palette/Blue Palette",       NULL,           Menu_Options_Palette,        10, "/Options/Palette/Default" },
	{ "/Options/Palette/Blue Vector",        NULL,           Menu_Options_Palette,        11, "/Options/Palette/Default" },
	{ "/Options/Palette/Sepia",              NULL,           Menu_Options_Palette,        12, "/Options/Palette/Default" },
	{ "/Options/Palette/Inverted B&W",       NULL,           Menu_Options_Palette,        13, "/Options/Palette/Default" },
	{ "/Options/Palette/Custom 1",           NULL,           Menu_Options_Palette,        14, "/Options/Palette/Default" },
	{ "/Options/Palette/Custom 2",           NULL,           Menu_Options_Palette,        15, "/Options/Palette/Default" },
	{ "/Options/_LCD Mode",                  NULL,           NULL,                         0, "<Branch>" },
	{ "/Options/LCD Mode/Analog",            NULL,           Menu_Options_LCDMode,         0, "<RadioItem>" },
	{ "/Options/LCD Mode/3-Shades",          NULL,           Menu_Options_LCDMode,         1, "/Options/LCD Mode/Analog" },
	{ "/Options/LCD Mode/2-Shades",          NULL,           Menu_Options_LCDMode,         2, "/Options/LCD Mode/Analog" },
	{ "/Options/LCD Mode/Colors*",           NULL,           Menu_Options_LCDMode,         3, "/Options/LCD Mode/Analog" },
	{ "/Options/LCD _Filter",                NULL,           NULL,                         0, "<Branch>" },
	{ "/Options/LCD Filter/None",            NULL,           Menu_Options_LCDFilt,         0, "<RadioItem>" },
	{ "/Options/LCD Filter/Dot-Matrix",      NULL,           Menu_Options_LCDFilt,         1, "/Options/LCD Filter/None" },
	{ "/Options/LCD Filter/50% Scanline",    NULL,           Menu_Options_LCDFilt,         2, "/Options/LCD Filter/None" },
	{ "/Options/LCD _Contrast",              NULL,           NULL,                         0, "<Branch>" },
	{ "/Options/LCD Contrast/Default",       NULL,           Menu_Options_LCDContrast,    64, "<RadioItem>" },
	{ "/Options/LCD Contrast/Lowest",        NULL,           Menu_Options_LCDContrast,     0, "/Options/LCD Contrast/Default" },
	{ "/Options/LCD Contrast/Low",           NULL,           Menu_Options_LCDContrast,    25, "/Options/LCD Contrast/Default" },
	{ "/Options/LCD Contrast/Medium",        NULL,           Menu_Options_LCDContrast,    50, "/Options/LCD Contrast/Default" },
	{ "/Options/LCD Contrast/High",          NULL,           Menu_Options_LCDContrast,    75, "/Options/LCD Contrast/Default" },
	{ "/Options/LCD Contrast/Highest",       NULL,           Menu_Options_LCDContrast,   100, "/Options/LCD Contrast/Default" },
	{ "/Options/LCD Contrast/Custom...",     NULL,           Menu_Options_LCDContrast,    -1, "<Item>" },
	{ "/Options/LCD _Brightness",            NULL,           NULL,                         0, "<Branch>" },
	{ "/Options/LCD Brightness/Default",     NULL,           Menu_Options_LCDBright,       0, "<RadioItem>" },
	{ "/Options/LCD Brightness/Lighter",     NULL,           Menu_Options_LCDBright,      24, "/Options/LCD Brightness/Default" },
	{ "/Options/LCD Brightness/Light",       NULL,           Menu_Options_LCDBright,      12, "/Options/LCD Brightness/Default" },
	{ "/Options/LCD Brightness/Dark",        NULL,           Menu_Options_LCDBright,     -12, "/Options/LCD Brightness/Default" },
	{ "/Options/LCD Brightness/Darker",      NULL,           Menu_Options_LCDBright,     -24, "/Options/LCD Brightness/Default" },
	{ "/Options/LCD Brightness/Custom...",   NULL,           Menu_Options_LCDBright,    -200, "<Item>" },
	{ "/Options/_Rumble Level",              NULL,           NULL,                         0, "<Branch>" },
	{ "/Options/Rumble Level/None",          NULL,           Menu_Options_RumbleLvl,       0, "<RadioItem>" },
	{ "/Options/Rumble Level/Weak",          NULL,           Menu_Options_RumbleLvl,       1, "/Options/Rumble Level/None" },
	{ "/Options/Rumble Level/Medium",        NULL,           Menu_Options_RumbleLvl,       2, "/Options/Rumble Level/None" },
	{ "/Options/Rumble Level/Strong",        NULL,           Menu_Options_RumbleLvl,       3, "/Options/Rumble Level/None" },
	{ "/Options/sep1",                       NULL,           NULL,                         0, "<Separator>" },
	{ "/Options/_Sound",                     NULL,           NULL,                         0, "<Branch>" },
	{ "/Options/Sound/Disabled",             NULL,           Menu_Options_Sound,           0, "<RadioItem>" },
	{ "/Options/Sound/Generated",            NULL,           Menu_Options_Sound,           1, "/Options/Sound/Disabled" },
	{ "/Options/Sound/Direct",               NULL,           Menu_Options_Sound,           2, "/Options/Sound/Disabled" },
	{ "/Options/Sound/Emulated",             NULL,           Menu_Options_Sound,           3, "/Options/Sound/Disabled" },
	{ "/Options/Sound/Direct PWM",           NULL,           Menu_Options_Sound,           4, "/Options/Sound/Disabled" },
	{ "/Options/Pie_zo Filter",              NULL,           Menu_Options_PiezoFilter,     0, "<CheckItem>" },
	{ "/Options/sep2",                       NULL,           NULL,                         0, "<Separator>" },
	{ "/Options/_Sync Cycles",               NULL,           NULL,                         0, "<Branch>" },
	{ "/Options/Sync Cycles/  8 (Accurancy)",       NULL,    Menu_Options_SyncCyc,         8, "<RadioItem>" },
	{ "/Options/Sync Cycles/ 16",                   NULL,    Menu_Options_SyncCyc,        16, "/Options/Sync Cycles/  8 (Accurancy)" },
	{ "/Options/Sync Cycles/ 32",                   NULL,    Menu_Options_SyncCyc,        32, "/Options/Sync Cycles/  8 (Accurancy)" },
	{ "/Options/Sync Cycles/ 64 (Performance)",     NULL,    Menu_Options_SyncCyc,        64, "/Options/Sync Cycles/  8 (Accurancy)" },
	{ "/Options/sep3",                       NULL,           NULL,                         0, "<Separator>" },
	{ "/Options/_Low Battery",               NULL,           Menu_Options_LowBatt,         0, "<CheckItem>" },
	{ "/Options/_RTC",                       NULL,           NULL,                         0, "<Branch>" },
	{ "/Options/RTC/No RTC",                 NULL,           Menu_Options_RTC,             0, "<RadioItem>" },
	{ "/Options/RTC/State time difference",  NULL,           Menu_Options_RTC,             1, "/Options/RTC/No RTC" },
	{ "/Options/RTC/RTC from Host",          NULL,           Menu_Options_RTC,             2, "/Options/RTC/No RTC" },
	{ "/Options/Share _EEPROM",              NULL,           Menu_Options_ShareEEP,        0, "<CheckItem>" },
	{ "/Options/_Multicart",                 NULL,           NULL,                         0, "<Branch>" },
	{ "/Options/Multicart/Disabled",         NULL,           Menu_Options_Multicart,       0, "<RadioItem>" },
	{ "/Options/Multicart/Flash 512KB (AM29LV040B)",NULL,    Menu_Options_Multicart,       1, "/Options/Multicart/Disabled" },
	{ "/Options/Multicart/Lupin 512KB (AM29LV040B)",NULL,    Menu_Options_Multicart,       2, "/Options/Multicart/Disabled" },
	{ "/Options/Force Free_BIOS",            NULL,           Menu_Options_FreeBIOS,        0, "<CheckItem>" },
	{ "/Options/sep3",                       NULL,           NULL,                         0, "<Separator>" },
	{ "/Options/File association",           NULL,           NULL,                         0, "<Branch>" },
	{ "/Options/File association/Register",  NULL,           Menu_FileAss_Reg,             0, "<Item>" },
	{ "/Options/File association/Unregister", NULL,          Menu_FileAss_Unreg,           0, "<Item>" },
	{ "/Options/sep4",                       NULL,           NULL,                         0, "<Separator>" },
	{ "/Options/_Custom Palette Edit...",    NULL,           Menu_Options_PalEdit,         0, "<Item>" },
	{ "/Options/Define _Keyboard...",        NULL,           Menu_Options_DefKeyboard,     0, "<Item>" },
	{ "/Options/Define _Joystick...",        NULL,           Menu_Options_DefJoystick,     0, "<Item>" },
	{ "/Options/_Update EEPROM",             NULL,           Menu_Options_UpdEEPROM,       0, "<Item>" },

	{ "/_Debugger",                          NULL,           NULL,                         0, "<Branch>" },
	{ "/Debugger/_Run full speed",           "F5",           Menu_Debug_RunFull,           0, "<Item>" },
	{ "/Debugger/Run debug frames (_Sound)", "<SHIFT>F5",    Menu_Debug_RunDFrameSnd,      0, "<Item>" },
	{ "/Debugger/Run debug _frames",         "<CTRL>F5",     Menu_Debug_RunDFrame,         0, "<Item>" },
	{ "/Debugger/Run debug _steps",          "<CTRL>F3",     Menu_Debug_RunDStep,          0, "<Item>" },
	{ "/Debugger/Single _frame",             "F4",           Menu_Debug_SingleFrame,       0, "<Item>" },
	{ "/Debugger/Single _step",              "F3",           Menu_Debug_SingleStep,        0, "<Item>" },
	{ "/Debugger/Step s_kip",                "<SHIFT>F3",    Menu_Debug_StepSkip,          0, "<Item>" },
	{ "/Debugger/_Stop",                     "F2",           Menu_Debug_Stop,              0, "<Item>" },
	{ "/Debugger/sep1",                      NULL,           NULL,                         0, "<Separator>" },
	{ "/Debugger/_Physical range",           "<CTRL>P",      Menu_Debug_FullRange,         0, "<CheckItem>" },
	{ "/Debugger/_Follow PC",                "<CTRL>F",      Menu_Debug_FollowPC,          0, "<CheckItem>" },
	{ "/Debugger/_Follow SP",                "<CTRL><ALT>F", Menu_Debug_FollowSP,          0, "<CheckItem>" },
	{ "/Debugger/_Go to program address...", "<CTRL>G",      Menu_Debug_GotoProgAddr,      0, "<Item>" },
	{ "/Debugger/_Go to RAM address...",     "<SHIFT>G",     Menu_Debug_GotoRAMAddr,       0, "<Item>" },
	{ "/Debugger/_Go to BIOS IRQ...",        NULL,           Menu_Debug_GotoBIOSIRQ,       0, "<Item>" },
	{ "/Debugger/_Go to cartridge IRQ...",   "<CTRL><ALT>G", Menu_Debug_GotoCartIRQ,       0, "<Item>" },
	{ "/Debugger/Go to _PC",                 "<SHIFT>P",     Menu_Debug_GotoPC,            0, "<Item>" },
	{ "/Debugger/Go to _SP",                 "<SHIFT>S",     Menu_Debug_GotoSP,            0, "<Item>" },
	{ "/Debugger/sep2",                      NULL,           NULL,                         0, "<Separator>" },
	{ "/Debugger/_PRC",                      NULL,           NULL,                         0, "<Branch>" },
	{ "/Debugger/PRC/Show _Background",      NULL,           Menu_DebPRC_ShowBG,           0, "<CheckItem>" },
	{ "/Debugger/PRC/Show _Sprites",         NULL,           Menu_DebPRC_ShowSpr,          0, "<CheckItem>" },
	{ "/Debugger/PRC/Stall _CPU",            NULL,           Menu_DebPRC_StallCPU,         0, "<CheckItem>" },
	{ "/Debugger/PRC/Stall _Cycles...",      NULL,           Menu_DebPRC_StallCycles,      0, "<Item>" },
	{ "/Debugger/_IRQ call...",              NULL,           Menu_Debug_IRQCall,           0, "<Item>" },
	{ "/Debugger/_Reset",                    NULL,           NULL,                         0, "<Branch>" },
	{ "/Debugger/Reset/_Soft (Partial)",     "<SHIFT>R",     Menu_Debug_ResetSoft,         0, "<Item>" },
	{ "/Debugger/Reset/_Hard (Full)",        "<CTRL>R",      Menu_Debug_ResetHard,         0, "<Item>" },

	{ "/_Break",                             NULL,           NULL,                         0, "<Branch>" },
	{ "/Break/_Enable breakpoints",          "<ALT><SHIFT>B",Menu_Break_EnableBP,          0, "<CheckItem>" },
	{ "/Break/_Add breakpoint at...",        "<SHIFT>B",     Menu_Break_AddBPAt,           0, "<Item>" },
	{ "/Break/_Delete breakpoint at...",     "<CTRL><SHIFT>B",Menu_Break_DelBPAt,          0, "<Item>" },
	{ "/Break/_Delete all breakpoints",      NULL,           Menu_Break_DelAllBP,          0, "<Item>" },
	{ "/Break/sep1",                         NULL,           NULL,                         0, "<Separator>" },
	{ "/Break/_Enable watchpoints",          "<ALT><SHIFT>W",Menu_Break_EnableWP,          0, "<CheckItem>" },
	{ "/Break/_Add Watchpoint at...",        "<SHIFT>W",     Menu_Break_AddWPAt,           0, "<Item>" },
	{ "/Break/_Delete all watchpoints",      NULL,           Menu_Break_DelAllWP,          0, "<Item>" },
	{ "/Break/sep1",                         NULL,           NULL,                         0, "<Separator>" },
	{ "/Break/_Enable exceptions",           NULL,           Menu_Break_EnableEx,          0, "<CheckItem>" },
	{ "/Break/_Enable HALT break",           NULL,           Menu_Break_EnableHalt,        0, "<CheckItem>" },
	{ "/Break/_Enable STOP break",           NULL,           Menu_Break_EnableStop,        0, "<CheckItem>" },

	{ "/_Viewers",                           NULL,           NULL,                         0, "<Branch>" },
	{ "/Viewers/_Memory View",               "<CTRL>1",      Menu_View_Memory,             0, "<Item>" },
	{ "/Viewers/_PRC Tiles View",            "<CTRL>2",      Menu_View_PRCTiles,           0, "<Item>" },
	{ "/Viewers/_PRC Map View",              "<CTRL>3",      Menu_View_PRCMap,             0, "<Item>" },
	{ "/Viewers/_PRC Sprites View",          "<CTRL>4",      Menu_View_PRCSpr,             0, "<Item>" },
	{ "/Viewers/_Timers View",               "<CTRL>5",      Menu_View_Timers,             0, "<Item>" },
	{ "/Viewers/_Hardware IO View",          "<CTRL>6",      Menu_View_HardIO,             0, "<Item>" },
	{ "/Viewers/_IRQ View",                  "<CTRL>7",      Menu_View_IRQ,                0, "<Item>" },
	{ "/Viewers/_Misc. View",                "<CTRL>8",      Menu_View_Misc,               0, "<Item>" },
	{ "/Viewers/_Symbols List View",         "<CTRL>9",      Menu_View_Symb,               0, "<Item>" },
	{ "/Viewers/_Run Trace View",            "<CTRL>0",      Menu_View_Trace,              0, "<Item>" },

	{ "/_External",                          NULL,           NULL,                         0, "<Branch>" },
	{ "/External/App1",                      "<CTRL><ALT>1", Menu_External_Run,            0, "<Item>" },
	{ "/External/App2",                      "<CTRL><ALT>2", Menu_External_Run,            1, "<Item>" },
	{ "/External/App3",                      "<CTRL><ALT>3", Menu_External_Run,            2, "<Item>" },
	{ "/External/App4",                      "<CTRL><ALT>4", Menu_External_Run,            3, "<Item>" },
	{ "/External/App5",                      "<CTRL><ALT>5", Menu_External_Run,            4, "<Item>" },
	{ "/External/App6",                      "<CTRL><ALT>6", Menu_External_Run,            5, "<Item>" },
	{ "/External/App7",                      "<CTRL><ALT>7", Menu_External_Run,            6, "<Item>" },
	{ "/External/App8",                      "<CTRL><ALT>8", Menu_External_Run,            7, "<Item>" },
	{ "/External/App9",                      "<CTRL><ALT>9", Menu_External_Run,            8, "<Item>" },
	{ "/External/App10",                     "<CTRL><ALT>0", Menu_External_Run,            9, "<Item>" },
	{ "/External/sep1",                      NULL,           NULL,                         0, "<Separator>" },
	{ "/External/Configure...",              NULL,           Menu_External_Conf,           0, "<Item>" },

	{ "/Messages/Enable _messages",          NULL,           NULL,                         0, "<Branch>" },
	{ "/Messages/Enable messages/Breakpoints",NULL,          Menu_Messages_BPMsg,          0, "<CheckItem>" },
	{ "/Messages/Enable messages/Watchpoints",NULL,          Menu_Messages_WPMsg,          0, "<CheckItem>" },
	{ "/Messages/Enable messages/Exceptions", NULL,          Menu_Messages_ExMsg,          0, "<CheckItem>" },
	{ "/Messages/Enable messages/HALT break", NULL,          Menu_Messages_HaltMsg,        0, "<CheckItem>" },
	{ "/Messages/Enable messages/STOP break", NULL,          Menu_Messages_StopMsg,        0, "<CheckItem>" },
	{ "/Messages/sep1",                      NULL,           NULL,                         0, "<Separator>" },
	{ "/Messages/_Enable debug output",      NULL,           Menu_Messages_EnableDbgOut,   0, "<CheckItem>" },
	{ "/Messages/_Auto-open debug output",   NULL,           Menu_Messages_AutoDbgOut,     0, "<CheckItem>" },
	{ "/Messages/sep2",                      NULL,           NULL,                         0, "<Separator>" },
	{ "/Messages/Clear _messages",           NULL,           Menu_Messages_ClearMsgs,      0, "<Item>" },
	{ "/Messages/Clear debug _output",       NULL,           Menu_Messages_ClearDebugOut,  0, "<Item>" },

	{ "/_Refresh",                           NULL,           NULL,                         0, "<Branch>" },
	{ "/Refresh/Now!",                       NULL,           Menu_Refresh_Now,             0, "<Item>" },
	{ "/Refresh/sep1",                       NULL,           NULL,                         0, "<Separator>" },
	{ "/Refresh/100% 72fps",                 NULL,           Menu_Refresh,                 0, "<RadioItem>" },
	{ "/Refresh/ 50% 36fps",                 NULL,           Menu_Refresh,                 1, "/Refresh/100% 72fps" },
	{ "/Refresh/ 33% 24fps",                 NULL,           Menu_Refresh,                 2, "/Refresh/100% 72fps" },
	{ "/Refresh/ 25% 18fps",                 NULL,           Menu_Refresh,                 3, "/Refresh/100% 72fps" },
	{ "/Refresh/ 17% 12fps",                 NULL,           Menu_Refresh,                 5, "/Refresh/100% 72fps" },
	{ "/Refresh/ 12%  9fps",                 NULL,           Menu_Refresh,                 7, "/Refresh/100% 72fps" },
	{ "/Refresh/  8%  6fps",                 NULL,           Menu_Refresh,                11, "/Refresh/100% 72fps" },
	{ "/Refresh/  3%  2fps",                 NULL,           Menu_Refresh,                35, "/Refresh/100% 72fps" },
	{ "/Refresh/  1%  1fps",                 NULL,           Menu_Refresh,                71, "/Refresh/100% 72fps" },
	{ "/Refresh/Custom...",                  NULL,           Menu_Refresh,                -1, "/Refresh/100% 72fps" },

	{ "/_Help",                              NULL,           NULL,                         0, "<Branch>" },
	{ "/Help/_Documentation",                "F1",           Menu_Help_Documentation,      0, "<Item>" },
	{ "/Help/_Visit website",                NULL,           Menu_Help_VisitWebsite,       0, "<Item>" },
	{ "/Help/sep1",                          NULL,           NULL,                         0, "<Separator>" },
	{ "/Help/_Command-line switches...",     NULL,           Menu_Help_CommandLine,        0, "<Item>" },
	{ "/Help/_About...",                     NULL,           Menu_Help_About,              0, "<Item>" },
};
static gint CPUWindow_MenuItemsNum = sizeof(CPUWindow_MenuItems) / sizeof(*CPUWindow_MenuItems);

// Process menu item accelerator, execute callback and return if match
int ProcessMenuItemAccel(int key, int modifier, TMenu_items_accel *list)
{
	if (!list) return 0;
	while (list->callback) {
		if ((list->key == key) && (list->modifier == modifier)) {
			list->callback(NULL, NULL);
			return 1;
		}
		list++;
	}
	return 0;
}

// ----------
// CPU Window
// ----------

static GtkTargetEntry drag_target_list[] = {
	{ "text/uri-list", 0, 0 }
};

int CPUWindow_Create(void)
{
	// Window
	MainWindow = GTK_WINDOW(gtk_window_new(GTK_WINDOW_TOPLEVEL));
	gtk_window_set_title(GTK_WINDOW(MainWindow), AppName);
	gtk_widget_set_size_request(GTK_WIDGET(MainWindow), 500, 500);
	gtk_window_set_default_size(MainWindow, 500, 500);
	g_signal_connect(MainWindow, "delete_event", G_CALLBACK(MainWindow_delete_event), NULL);
	g_signal_connect(MainWindow, "window-state-event", G_CALLBACK(MainWindow_state_event), NULL);
	VBox1 = GTK_BOX(gtk_vbox_new(FALSE, 0));
	gtk_container_add(GTK_CONTAINER(MainWindow), GTK_WIDGET(VBox1));
	gtk_widget_show(GTK_WIDGET(VBox1));
	gtk_drag_dest_set(GTK_WIDGET(MainWindow), GTK_DEST_DEFAULT_ALL, drag_target_list, 1, GDK_ACTION_COPY | GDK_ACTION_MOVE);
	g_signal_connect(MainWindow, "drag-data-received", G_CALLBACK(MainWindow_drag_data_received), NULL);

	// Menu bar
	AccelGroup = gtk_accel_group_new();
	ItemFactory = gtk_item_factory_new(GTK_TYPE_MENU_BAR, "<main>", AccelGroup);
	gtk_item_factory_create_items(ItemFactory, CPUWindow_MenuItemsNum, CPUWindow_MenuItems, NULL);
	gtk_window_add_accel_group(MainWindow, AccelGroup);
	MenuBar = GTK_MENU_BAR(gtk_item_factory_get_widget(ItemFactory, "<main>"));
	gtk_box_pack_start(VBox1, GTK_WIDGET(MenuBar), FALSE, TRUE, 0);
	gtk_widget_show(GTK_WIDGET(MenuBar));

	// Table on middle
	MTable = GTK_TABLE(gtk_table_new(3, 2, FALSE));
	gtk_box_pack_start(VBox1, GTK_WIDGET(MTable), TRUE, TRUE, 0);
	gtk_widget_show(GTK_WIDGET(MTable));

	// Program View
	ProgramView.on_exposure = SGtkXDVCB(ProgramView_exposure);
	ProgramView.on_scroll = SGtkXDVCB(AnyView_scroll);
	ProgramView.on_resize = SGtkXDVCB(ProgramView_resize);
	ProgramView.on_motion = SGtkXDVCB(AnyView_motion);
	ProgramView.on_buttonpress = SGtkXDVCB(ProgramView_buttonpress);
	ProgramView.on_enterleave = SGtkXDVCB(AnyView_enterleave);
	ProgramView.total_lines = ProgramView.height / 12;
	ProgramView_Table = (uint32_t *)malloc(ProgramView.total_lines * sizeof(uint32_t));
	sgtkx_drawing_view_new(&ProgramView, 1);
	sgtkx_drawing_view_sbminmax(&ProgramView, 0, 0x001FFF);	// $0000 to $1FFF
	gtk_table_attach(MTable, GTK_WIDGET(ProgramView.box), 0, 1, 0, 2, GTK_FILL | GTK_EXPAND, GTK_FILL | GTK_EXPAND, 2, 2);
	gtk_widget_show(GTK_WIDGET(ProgramView.box));

	// Registers View
	RegistersView.on_exposure = SGtkXDVCB(RegistersView_exposure);
	RegistersView.on_scroll = SGtkXDVCB(AnyView_scroll);
	RegistersView.on_resize = SGtkXDVCB(AnyView_resize);
	RegistersView.on_motion = SGtkXDVCB(AnyView_motion);
	RegistersView.on_buttonpress = SGtkXDVCB(RegistersView_buttonpress);
	RegistersView.on_enterleave = SGtkXDVCB(AnyView_enterleave);
	sgtkx_drawing_view_new(&RegistersView, 0);
	gtk_widget_set_size_request(GTK_WIDGET(RegistersView.box), 160, 252);
	gtk_table_attach(MTable, GTK_WIDGET(RegistersView.box), 1, 2, 0, 1, GTK_FILL, GTK_FILL, 2, 2);
	gtk_widget_show(GTK_WIDGET(RegistersView.box));

	// Stack View
	StackView.on_exposure = SGtkXDVCB(StackView_exposure);
	StackView.on_scroll = SGtkXDVCB(AnyView_scroll);
	StackView.on_resize = SGtkXDVCB(AnyView_resize);
	StackView.on_motion = SGtkXDVCB(AnyView_motion);
	StackView.on_buttonpress = SGtkXDVCB(StackView_buttonpress);
	StackView.on_enterleave = SGtkXDVCB(AnyView_enterleave);
	sgtkx_drawing_view_new(&StackView, 1);
	sgtkx_drawing_view_sbminmax(&StackView, 0, 0xFFF);	// $1000 to $FFF
	gtk_widget_set_size_request(GTK_WIDGET(StackView.box), 160, 48);
	gtk_table_attach(MTable, GTK_WIDGET(StackView.box), 1, 2, 1, 2, GTK_FILL, GTK_FILL | GTK_EXPAND, 2, 2);
	gtk_widget_show(GTK_WIDGET(StackView.box));

	// RAM View
	RAMView.on_exposure = SGtkXDVCB(RAMView_exposure);
	RAMView.on_scroll = SGtkXDVCB(AnyView_scroll);
	RAMView.on_resize = SGtkXDVCB(AnyView_resize);
	RAMView.on_motion = SGtkXDVCB(AnyView_motion);
	RAMView.on_buttonpress = SGtkXDVCB(RAMView_buttonpress);
	RAMView.on_enterleave = SGtkXDVCB(AnyView_enterleave);
	sgtkx_drawing_view_new(&RAMView, 1);
	sgtkx_drawing_view_sbminmax(&RAMView, 0, 255);	// $1000 to $1FFF
	gtk_widget_set_size_request(GTK_WIDGET(RAMView.box), 192, 108);
	gtk_widget_show(GTK_WIDGET(RAMView.box));

	// IO View
	IOView.on_exposure = SGtkXDVCB(IOView_exposure);
	IOView.on_scroll = SGtkXDVCB(AnyView_scroll);
	IOView.on_resize = SGtkXDVCB(AnyView_resize);
	IOView.on_motion = SGtkXDVCB(AnyView_motion);
	IOView.on_buttonpress = SGtkXDVCB(IOView_buttonpress);
	IOView.on_enterleave = SGtkXDVCB(AnyView_enterleave);
	sgtkx_drawing_view_new(&IOView, 1);
	sgtkx_drawing_view_sbminmax(&IOView, 0, 15);	// $2100 to $21FF
	gtk_widget_set_size_request(GTK_WIDGET(IOView.box), 192, 108);
	gtk_widget_show(GTK_WIDGET(IOView.box));

	// EEPROM View
	EEPROMView.on_exposure = SGtkXDVCB(EEPROMView_exposure);
	EEPROMView.on_scroll = SGtkXDVCB(AnyView_scroll);
	EEPROMView.on_resize = SGtkXDVCB(AnyView_resize);
	EEPROMView.on_motion = SGtkXDVCB(AnyView_motion);
	EEPROMView.on_buttonpress = SGtkXDVCB(EEPROMView_buttonpress);
	EEPROMView.on_enterleave = SGtkXDVCB(AnyView_enterleave);
	sgtkx_drawing_view_new(&EEPROMView, 1);
	sgtkx_drawing_view_sbminmax(&EEPROMView, 0, 511);	// $0000 to $1FFF
	gtk_widget_set_size_request(GTK_WIDGET(EEPROMView.box), 192, 108);
	gtk_widget_show(GTK_WIDGET(EEPROMView.box));

	// Info Messages Text
	EditInfoMsgBuf = GTK_TEXT_BUFFER(gtk_text_buffer_new(NULL));
	EditInfoMsg = GTK_TEXT_VIEW(gtk_text_view_new_with_buffer(EditInfoMsgBuf));
	gtk_text_view_set_editable(EditInfoMsg, FALSE);
	gtk_text_view_set_cursor_visible(EditInfoMsg, FALSE);
	gtk_widget_show(GTK_WIDGET(EditInfoMsg));
	EditInfoMsgSW = GTK_SCROLLED_WINDOW(gtk_scrolled_window_new(NULL, NULL));
	gtk_scrolled_window_set_policy(EditInfoMsgSW, GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
	gtk_container_add(GTK_CONTAINER(EditInfoMsgSW), GTK_WIDGET(EditInfoMsg));
	gtk_widget_show(GTK_WIDGET(EditInfoMsgSW));

	// Info Debug Text
	EditInfoDebugBuf = GTK_TEXT_BUFFER(gtk_text_buffer_new(NULL));
	EditInfoDebug = GTK_TEXT_VIEW(gtk_text_view_new_with_buffer(EditInfoDebugBuf));
	gtk_widget_show(GTK_WIDGET(EditInfoDebug));
	EditInfoDebugSW = GTK_SCROLLED_WINDOW(gtk_scrolled_window_new(NULL, NULL));
	gtk_scrolled_window_set_policy(EditInfoDebugSW, GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
	gtk_container_add(GTK_CONTAINER(EditInfoDebugSW), GTK_WIDGET(EditInfoDebug));
	gtk_widget_show(GTK_WIDGET(EditInfoDebugSW));

	// Bottom Notebook
	BottomNB = GTK_NOTEBOOK(gtk_notebook_new());
	gtk_table_attach(MTable, GTK_WIDGET(BottomNB), 0, 2, 2, 3, GTK_FILL | GTK_SHRINK, GTK_FILL, 2, 2);
	gtk_notebook_append_page(GTK_NOTEBOOK(BottomNB), GTK_WIDGET(RAMView.box), gtk_label_new("RAM"));
	gtk_notebook_append_page(GTK_NOTEBOOK(BottomNB), GTK_WIDGET(IOView.box), gtk_label_new("Hard. I/O"));
	gtk_notebook_append_page(GTK_NOTEBOOK(BottomNB), GTK_WIDGET(EEPROMView.box), gtk_label_new("EEPROM"));
	gtk_notebook_append_page(GTK_NOTEBOOK(BottomNB), GTK_WIDGET(EditInfoMsgSW), gtk_label_new("Messages"));
	gtk_notebook_append_page(GTK_NOTEBOOK(BottomNB), GTK_WIDGET(EditInfoDebugSW), gtk_label_new("Debug output"));
	gtk_widget_show(GTK_WIDGET(BottomNB));

	// Status bar on the bottom
	StatusFrame = GTK_FRAME(gtk_frame_new(NULL));
	gtk_frame_set_label_align(StatusFrame, 1.0f, 0.5f);
	gtk_box_pack_start(VBox1, GTK_WIDGET(StatusFrame), FALSE, FALSE, 0);
	gtk_widget_show(GTK_WIDGET(StatusFrame));
	StatusLabel = GTK_LABEL(gtk_label_new(""));
	gtk_label_set_justify(StatusLabel, GTK_JUSTIFY_LEFT);
	gtk_label_set_ellipsize(StatusLabel, PANGO_ELLIPSIZE_END);
	gtk_container_add(GTK_CONTAINER(StatusFrame), GTK_WIDGET(StatusLabel));
	gtk_widget_show(GTK_WIDGET(StatusLabel));

	return 1;
}

void CPUWindow_Destroy(void)
{
	int x, y, width, height;
	gtk_window_deiconify(MainWindow);
	gtk_window_get_position(MainWindow, &x, &y);
	gtk_window_get_size(MainWindow, &width, &height);
	dclc_cpuwin_winx = x;
	dclc_cpuwin_winy = y;
	dclc_cpuwin_winw = width;
	dclc_cpuwin_winh = height;
	CPUWindow_CheckDirtyROM();
}

void CPUWindow_Activate(void)
{
	gtk_widget_realize(GTK_WIDGET(MainWindow));
	if ((dclc_cpuwin_winx > -15) && (dclc_cpuwin_winy > -16)) {
		gtk_window_move(MainWindow, dclc_cpuwin_winx, dclc_cpuwin_winy);
	}
	if ((dclc_cpuwin_winw > 0) && (dclc_cpuwin_winh > 0)) {
		gtk_window_resize(MainWindow, dclc_cpuwin_winw, dclc_cpuwin_winh);
	}
	gtk_widget_show(GTK_WIDGET(MainWindow));

	CPUWindow_Refresh(1);
	if (dclc_followPC) ProgramView_GotoAddr(PhysicalPC(), 0);
	if (dclc_followSP) StackView_GotoSP();
}

void CPUWindow_UpdateConfigs(void)
{
	char tmp[PMTMPV];
	GtkWidget *widg;
	int i, j;

	CPUWindow_InConfigs = 1;

	// Refresh recent list
	for (i=0; i<10; i++) {
		sprintf(tmp, "/File/Recent/ROM%i", i);
		if (strlen(dclc_recent[i]) > 0) {
			for (j=(int)strlen(dclc_recent[i])-1; j>=0; j--) if ((dclc_recent[i][j] == '/') || (dclc_recent[i][j] == '\\')) { j++; break; }
			widg = gtk_item_factory_get_item(ItemFactory, tmp);
			gtk_menu_item_set_label(GTK_MENU_ITEM(widg), &dclc_recent[i][j]);
		} else {
			widg = gtk_item_factory_get_item(ItemFactory, tmp);
			gtk_menu_item_set_label(GTK_MENU_ITEM(widg), "---");
		}
	}

	// Apply all options
	widg = gtk_item_factory_get_item(ItemFactory, "/File/Autorun/Disabled");
	if (clc_autorun == 0) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/File/Autorun/Run full speed");
	if (clc_autorun == 1) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/File/Autorun/Debug frames (Sound)");
	if (clc_autorun == 2) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/File/Autorun/Debug frames");
	if (clc_autorun == 3) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);

	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Zoom/1x (96x64)");
	if (clc_zoom == 1) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Zoom/2x (192x128)");
	if (clc_zoom == 2) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Zoom/3x (288x192)");
	if (clc_zoom == 3) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Zoom/4x (384x256)");
	if (clc_zoom == 4) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Zoom/5x (480x320)");
	if (clc_zoom == 5) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Zoom/6x (576x384)");
	if (clc_zoom == 6) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);

	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Bits-Per-Pixel/16 bpp");
	if (clc_bpp == 16) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Bits-Per-Pixel/32 bpp");
	if (clc_bpp == 32) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);

	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Palette/Default");
	if (CommandLine.palette == 0) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Palette/Old");
	if (CommandLine.palette == 1) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Palette/Black & White");
	if (CommandLine.palette == 2) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Palette/Green Palette");
	if (CommandLine.palette == 3) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Palette/Green Vector");
	if (CommandLine.palette == 4) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Palette/Red Palette");
	if (CommandLine.palette == 5) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Palette/Red Vector");
	if (CommandLine.palette == 6) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Palette/Blue LCD");
	if (CommandLine.palette == 7) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Palette/LED Backlight");
	if (CommandLine.palette == 8) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Palette/Girl Power");
	if (CommandLine.palette == 9) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Palette/Blue Palette");
	if (CommandLine.palette == 10) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Palette/Blue Vector");
	if (CommandLine.palette == 11) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Palette/Sepia");
	if (CommandLine.palette == 12) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Palette/Inverted B&W");
	if (CommandLine.palette == 13) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Palette/Custom 1");
	if (CommandLine.palette == 14) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Palette/Custom 2");
	if (CommandLine.palette == 15) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);

	widg = gtk_item_factory_get_item(ItemFactory, "/Options/LCD Mode/Analog");
	if (CommandLine.lcdmode == 0) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/LCD Mode/3-Shades");
	if (CommandLine.lcdmode == 1) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/LCD Mode/2-Shades");
	if (CommandLine.lcdmode == 2) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/LCD Mode/Colors*");
	if (CommandLine.lcdmode == 3) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);

	widg = gtk_item_factory_get_item(ItemFactory, "/Options/LCD Filter/None");
	if (CommandLine.lcdfilter == 0) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/LCD Filter/Dot-Matrix");
	if (CommandLine.lcdfilter == 1) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/LCD Filter/50% Scanline");
	if (CommandLine.lcdfilter == 2) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);

	widg = gtk_item_factory_get_item(ItemFactory, "/Options/LCD Contrast/Default");
	if (CommandLine.lcdcontrast == 64) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/LCD Contrast/Lowest");
	if (CommandLine.lcdcontrast == 0) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/LCD Contrast/Low");
	if (CommandLine.lcdcontrast == 25) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/LCD Contrast/Medium");
	if (CommandLine.lcdcontrast == 50) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/LCD Contrast/High");
	if (CommandLine.lcdcontrast == 75) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/LCD Contrast/Highest");
	if (CommandLine.lcdcontrast == 100) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);

	widg = gtk_item_factory_get_item(ItemFactory, "/Options/LCD Brightness/Default");
	if (CommandLine.lcdbright == 0) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/LCD Brightness/Lighter");
	if (CommandLine.lcdbright == 24) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/LCD Brightness/Light");
	if (CommandLine.lcdbright == 12) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/LCD Brightness/Dark");
	if (CommandLine.lcdbright == -12) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/LCD Brightness/Darker");
	if (CommandLine.lcdbright == -24) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);

	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Rumble Level/None");
	if (CommandLine.rumblelvl == 0) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Rumble Level/Weak");
	if (CommandLine.rumblelvl == 1) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Rumble Level/Medium");
	if (CommandLine.rumblelvl == 2) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Rumble Level/Strong");
	if (CommandLine.rumblelvl == 3) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);

	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Sound/Disabled");
	if (CommandLine.sound == 0) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Sound/Generated");
	if (CommandLine.sound == 1) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Sound/Direct");
	if (CommandLine.sound == 2) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Sound/Emulated");
	if (CommandLine.sound == 3) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Sound/Direct PWM");
	if (CommandLine.sound == 4) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);

	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Sync Cycles/  8 (Accurancy)");
	if (CommandLine.synccycles == 8) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Sync Cycles/ 16");
	if (CommandLine.synccycles == 16) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Sync Cycles/ 32");
	if (CommandLine.synccycles == 32) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Sync Cycles/ 64 (Performance)");
	if (CommandLine.synccycles == 64) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);

	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Piezo Filter");
	if (CommandLine.piezofilter) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Low Battery");
	if (CommandLine.low_battery) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/RTC/No RTC");
	if (CommandLine.updatertc == 0) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/RTC/State time difference");
	if (CommandLine.updatertc == 1) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/RTC/RTC from Host");
	if (CommandLine.updatertc == 2) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Share EEPROM");
	if (CommandLine.eeprom_share) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Multicart/Disabled");
	if (CommandLine.multicart == 0) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Multicart/Flash 512KB (AM29LV040B)");
	if (CommandLine.multicart == 1) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Multicart/Lupin 512KB (AM29LV040B)");
	if (CommandLine.multicart == 2) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Options/Force Free BIOS");
	if (CommandLine.forcefreebios) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);

	widg = gtk_item_factory_get_item(ItemFactory, "/Debugger/Physical range");
	if (dclc_fullrange) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Debugger/Follow PC");
	if (dclc_followPC) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Debugger/Follow SP");
	if (dclc_followSP) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Debugger/PRC/Show Background");
	if (dclc_PRC_bg) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Debugger/PRC/Show Sprites");
	if (dclc_PRC_spr) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Debugger/PRC/Stall CPU");
	if (dclc_PRC_stallcpu) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	PRCRenderBD = !dclc_PRC_bg;
	PRCRenderBG = dclc_PRC_bg;
	PRCRenderSpr = dclc_PRC_spr;
	PRCAllowStall = dclc_PRC_stallcpu;

	widg = gtk_item_factory_get_item(ItemFactory, "/Break/Enable breakpoints");
	if (PMD_EnableBreakpoints) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Break/Enable watchpoints");
	if (PMD_EnableWatchpoints) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Break/Enable exceptions");
	if (PMD_EnableExceptions) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Break/Enable HALT break");
	if (PMD_EnableHalt) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Break/Enable STOP break");
	if (PMD_EnableStop) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);

	widg = gtk_item_factory_get_item(ItemFactory, "/Messages/Enable messages/Breakpoints");
	if (PMD_MessageBreakpoints) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Messages/Enable messages/Watchpoints");
	if (PMD_MessageWatchpoints) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Messages/Enable messages/Exceptions");
	if (PMD_MessageExceptions) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Messages/Enable messages/HALT break");
	if (PMD_MessageHalt) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Messages/Enable messages/STOP break");
	if (PMD_MessageStop) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Messages/Enable debug output");
	if (dclc_debugout) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);
	widg = gtk_item_factory_get_item(ItemFactory, "/Messages/Auto-open debug output");
	if (dclc_autodebugout) gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(widg), 1);

	// Update external items
	ExternalWindow_UpdateMenu(ItemFactory);

	switch (dclc_cpuwin_refresh) {
		case 0: gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(gtk_item_factory_get_item(ItemFactory, "/Refresh/100% 72fps")), 1);
			break;
		case 1: gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(gtk_item_factory_get_item(ItemFactory, "/Refresh/ 50% 36fps")), 1);
			break;
		case 2: gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(gtk_item_factory_get_item(ItemFactory, "/Refresh/ 33% 24fps")), 1);
			break;
		case 3: gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(gtk_item_factory_get_item(ItemFactory, "/Refresh/ 25% 18fps")), 1);
			break;
		case 5: gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(gtk_item_factory_get_item(ItemFactory, "/Refresh/ 17% 12fps")), 1);
			break;
		case 7: gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(gtk_item_factory_get_item(ItemFactory, "/Refresh/ 12%  9fps")), 1);
			break;
		case 11: gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(gtk_item_factory_get_item(ItemFactory, "/Refresh/  8%  6fps")), 1);
			break;
		case 19: gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(gtk_item_factory_get_item(ItemFactory, "/Refresh/  6%  3fps")), 1);
			break;
		default: gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(gtk_item_factory_get_item(ItemFactory, "/Refresh/Custom...")), 1);
			break;
	}

	CPUWindow_InConfigs = 0;
}

void CPUWindow_ROMResized(void)
{
	if (dclc_fullrange) {
		sgtkx_drawing_view_sbminmax(&ProgramView, 0, PM_ROM_Size-1);
	} else {
		if (PM_ROM_Size <= 65535) sgtkx_drawing_view_sbminmax(&ProgramView, 0, PM_ROM_Size-1);
		sgtkx_drawing_view_sbminmax(&ProgramView, 0, 65535);
	}
	if (!PMHD_MINLoaded()) {
		MessageDialog(MainWindow, "Memory allocation error!", "Allocation error", GTK_MESSAGE_ERROR, NULL);
	}
}

void CPUWindow_EmumodeChanged(void)
{
	if (dclc_followPC) ProgramView_GotoAddr(PhysicalPC(), 0);
	if (dclc_followSP) StackView_GotoSP();
}

void CPUWindow_Refresh(int now)
{
	static int refreshcnt = 0;
	if ((refreshcnt <= 0) || (now)) {
		refreshcnt = dclc_cpuwin_refresh;
		if (!now) {
			if (!gtk_widget_get_visible(GTK_WIDGET(MainWindow)) || MainWindow_minimized) return;
		}
		if (emumode != EMUMODE_STOP) {
			if (dclc_followPC) ProgramView_GotoAddr(PhysicalPC(), 0);
			if (dclc_followSP) StackView_GotoSP();
		}
		sgtkx_drawing_view_refresh(&ProgramView);
		sgtkx_drawing_view_refresh(&RegistersView);
		sgtkx_drawing_view_refresh(&StackView);
		sgtkx_drawing_view_refresh(&RAMView);
		sgtkx_drawing_view_refresh(&IOView);
		sgtkx_drawing_view_refresh(&EEPROMView);
	} else refreshcnt--;
}

void CPUWindow_FrameRendered(void)
{
	char tmp[128];
	if (sdump) {
		sprintf(tmp, "Recording audio: %.2f sec(s)", sdumptime);
		gtk_frame_set_label(StatusFrame, tmp);
	}
}
