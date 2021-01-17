/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

#ifdef DEBUGGER

#ifndef _MISSING_H_
#define _MISSING_H_

struct MissingHDMA
{
	uint8	used;
	uint8	bbus_address;
	uint8	abus_bank;
	uint16	abus_address;
	uint8	indirect_address;
	uint8	force_table_address_write;
	uint8	force_table_address_read;
	uint8	line_count_write;
	uint8	line_count_read;
};

struct Missing
{
	struct MissingHDMA hdma[8];
	uint8	emulate6502;
	uint8	decimal_mode;
	uint8	mv_8bit_index;
	uint8	mv_8bit_acc;
	uint8	interlace;
	uint8	lines_239;
	uint8	pseudo_512;
	uint8	modes[8];
	uint8	mode7_fx;
	uint8	mode7_flip;
	uint8	mode7_bgmode;
	uint8	direct;
	uint8	matrix_multiply;
	uint8	oam_read;
	uint8	vram_read;
	uint8	cgram_read;
	uint8	wram_read;
	uint8	dma_read;
	uint8	vram_inc;
	uint8	vram_full_graphic_inc;
	uint8	virq;
	uint8	hirq;
	uint16	virq_pos;
	uint16	hirq_pos;
	uint8	h_v_latch;
	uint8	h_counter_read;
	uint8	v_counter_read;
	uint8	fast_rom;
	uint8	window1[6];
	uint8	window2[6];
	uint8	sprite_priority_rotation;
	uint8	subscreen;
	uint8	subscreen_add;
	uint8	subscreen_sub;
	uint8	fixed_colour_add;
	uint8	fixed_colour_sub;
	uint8	mosaic;
	uint8	sprite_double_height;
	uint8	dma_channels;
	uint8	dma_this_frame;
	uint8	oam_address_read;
	uint8	bg_offset_read;
	uint8	matrix_read;
	uint8	hdma_channels;
	uint8	hdma_this_frame;
	uint16	unknownppu_read;
	uint16	unknownppu_write;
	uint16	unknowncpu_read;
	uint16	unknowncpu_write;
	uint16	unknowndsp_read;
	uint16	unknowndsp_write;
};

extern struct Missing	missing;

#endif

#endif
