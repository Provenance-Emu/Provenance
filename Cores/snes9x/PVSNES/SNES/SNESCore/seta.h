/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

#ifndef _SETA_H_
#define _SETA_H_

#define ST_010	0x01
#define ST_011	0x02
#define ST_018	0x03

struct SST010
{
	uint8	input_params[16];
	uint8	output_params[16];
	uint8	op_reg;
	uint8	execute;
	bool8	control_enable;
};

struct SST011
{
	bool8	waiting4command;
	uint8	status;
	uint8	command;
	uint32	in_count;
	uint32	in_index;
	uint32	out_count;
	uint32	out_index;
	uint8	parameters[512];
	uint8	output[512];
};

struct SST018
{
	bool8	waiting4command;
	uint8	status;
	uint8	part_command;
	uint8	pass;
	uint32	command;
	uint32	in_count;
	uint32	in_index;
	uint32	out_count;
	uint32	out_index;
	uint8	parameters[512];
	uint8	output[512];
};

extern struct SST010	ST010;
extern struct SST011	ST011;
extern struct SST018	ST018;

uint8 S9xGetST010 (uint32);
void S9xSetST010 (uint32, uint8);
uint8 S9xGetST011 (uint32);
void S9xSetST011 (uint32, uint8);
uint8 S9xGetST018 (uint32);
void S9xSetST018 (uint8, uint32);
uint8 S9xGetSetaDSP (uint32);
void S9xSetSetaDSP (uint8, uint32);

extern uint8 (*GetSETA) (uint32);
extern void (*SetSETA) (uint32, uint8);

#endif
