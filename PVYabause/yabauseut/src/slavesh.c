/*  Copyright 2013-2014 Theo Berkau

    This file is part of YabauseUT

    YabauseUT is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    YabauseUT is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with YabauseUT; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#include <iapetus.h>
#include "tests.h"
#include "slavesh.h"

void slavesh2_deinit();

enum {
	SM_INIT,
	SM_ICINTERRUPT,
	SM_SCUMASK,
	SM_ICFLAG,
	SM_HBLANK,
	SM_VBLANK
} SLAVEMODE;

enum {
	SLST_STOPPED,
	SLST_RUNNING,
} SLAVE_STATUS;

volatile int slave_mode=SM_INIT;
volatile u32 slave_func_s;
#define slave_func_m	*(volatile u32 *)((u32)&slave_func_s+0x20000000)
volatile int slave_status_s = SLST_STOPPED;
#define slave_status_m	*(volatile int *)((int)&slave_status_s+0x20000000)
volatile int slave_counter_s=0;
#define slave_counter_m	*(volatile int *)((int)&slave_counter_s+0x20000000)

void slavesh2_ici() __attribute__ ((interrupt_handler));
void slavesh2_blank_s() __attribute__ ((interrupt_handler));

void slavesh2_ici()
{
	slave_status_s = SLST_RUNNING;
}

void slavesh2_blank_s()
{
	slave_counter_m = slave_counter_m+1;
}

void slavesh2_blank_m()
{
	slave_counter_m = slave_counter_m+1;
}

void slave_clear()
{
	slave_status_s = SLST_RUNNING;
}

void slavesh2_main()
{
	// Disable interrupts
	interrupt_set_level_mask(0xf);
	SH2_REG_IPRA = 0x0000;
	SH2_REG_IPRB = 0x0000;

   // Disable FRT Input Capture interrupt
	SH2_REG_TIER = 0x01;

	slave_status_m = SLST_RUNNING;

	if (slave_mode == SM_HBLANK || slave_mode == SM_VBLANK)
	   interrupt_set_level_mask(0x1);

	// Wait for further instructions
	for (;;)
	{
		// Poll ICF and see if there's a command
		if((SH2_REG_FTCSR & 0x80))
		{
			// Clear flag
			SH2_REG_FTCSR = 0x00;
			// Execute given function
			((void (*)())slave_func_s)();
			slave_func_s = NULL;
		}
	}
}

void slavesh2_main2()
{
	interrupt_set_level_mask(0xf);

	SH2_REG_TIER = 1;
	SH2_REG_CCR = 0x11;
	slave_status_m = SLST_RUNNING;
	if (slave_mode == SM_SCUMASK)
	   bios_set_scu_interrupt_mask(0xF);
	SH2_REG_IPRA = 0;
	SH2_REG_IPRB = 0xF00;
	SH2_REG_FTCSR = 0;
	SH2_REG_TIER = 0x81;
	interrupt_set_level_mask(0x6);
	SH2_REG_TCR = (SH2_REG_TCR & 0xFFFFFFFC) | 0x2;
	for (;;) {}
}

volatile int vblank_counter=0;

void vblankin_test()
{
	vblank_counter++;
}

void slavesh2_init()
{
	int i;
   slavesh2_deinit();

	smpc_wait_till_ready();
	for(i = 0 ; i < 1000; i++); // rest delay
	slave_status_m = SLST_STOPPED;
	bios_set_sh2_interrupt(0x164, 0);	
	bios_set_sh2_interrupt(0x141, 0);	
	bios_set_sh2_interrupt(0x143, 0);	

	switch (slave_mode)
	{
		case SM_ICINTERRUPT:
	      bios_set_sh2_interrupt(0x164, (void *)&slavesh2_ici);
	      for (i = 0; i < 0xA; i++) {} // Wait
	      bios_set_sh2_interrupt(0x94, (void *)&slavesh2_main2);
			break;
		case SM_HBLANK:
			bios_set_sh2_interrupt(0x141, (void *)&slavesh2_blank_s);	
			for (i = 0; i < 0xA; i++) {} // Wait
			bios_set_sh2_interrupt(0x94, (void *)&slavesh2_main);
			break;
		case SM_VBLANK:
			bios_set_sh2_interrupt(0x143, (void *)&slavesh2_blank_s);	
			for (i = 0; i < 0xA; i++) {} // Wait
			bios_set_sh2_interrupt(0x94, (void *)&slavesh2_main);
			break;
		case SM_INIT:
		case SM_ICFLAG:
		default: 
			bios_set_sh2_interrupt(0x94, (void *)&slavesh2_main);
			break;
	}

	smpc_issue_command(SMPC_CMD_SSHON);
	smpc_wait_till_ready();
}

void slavesh2_deinit()
{
	smpc_wait_till_ready();
	smpc_issue_command(SMPC_CMD_SSHOFF);
}

int wait_slavesh2_running()
{
	int i;
	for (i = 0; i < 750; i++)
	{
		if(slave_status_m == SLST_RUNNING)
			return TRUE;
	}
	return FALSE;
}

void test_slavesh2_init()
{
	stage_status = STAGESTAT_WAITINGFORINT;
	slave_mode = SM_INIT;
	slavesh2_init();
	stage_status = wait_slavesh2_running() ? STAGESTAT_DONE : STAGESTAT_BADINTERRUPT;
}

void test_slavesh2_icinterrupt()
{
	u32 old_scu_mask = bios_get_scu_interrupt_mask();
	u32 old_sh2_mask = interrupt_get_level_mask();
	bios_change_scu_interrupt_mask(~(MASK_VBLANKOUT | MASK_VBLANKIN | MASK_SYSTEMMANAGER), 0);

	stage_status = STAGESTAT_WAITINGFORINT;
	slave_mode = SM_ICINTERRUPT;
	slavesh2_init();

	wait_slavesh2_running();
	slave_status_m = SLST_STOPPED;
	slave_func_m = (u32)&slave_clear;
	SH2_REG_M_FRT_IC = 0xFFFF;

	stage_status = wait_slavesh2_running() ? STAGESTAT_DONE : STAGESTAT_BADINTERRUPT;
	bios_set_scu_interrupt_mask(old_scu_mask);
	interrupt_set_level_mask(old_sh2_mask);
}

void test_slavesh2_scumask()
{
	u32 old_sh2_mask = interrupt_get_level_mask();
	bios_set_scu_interrupt(0x40, slavesh2_blank_m);
	bios_change_scu_interrupt_mask(~(MASK_VBLANKOUT | MASK_VBLANKIN | MASK_SYSTEMMANAGER), 0);

	stage_status = STAGESTAT_WAITINGFORINT;
	slave_mode = SM_SCUMASK;
	slavesh2_init();

	wait_slavesh2_running();
	slave_status_m = SLST_STOPPED;
	slave_func_m = (u32)&slave_clear;
	SH2_REG_M_FRT_IC = 0xFFFF;

	wait_slavesh2_running();
	slave_counter_m = 0;
	interrupt_set_level_mask(0);
	vdp_vsync();
	bios_set_scu_interrupt(0x40, 0);
	stage_status = slave_counter_m > 0 ? STAGESTAT_DONE : STAGESTAT_BADINTERRUPT;
}

void test_slavesh2_icflag()
{
	stage_status = STAGESTAT_WAITINGFORINT;
	slave_mode = SM_ICFLAG;
	slavesh2_init();

	wait_slavesh2_running();
	slave_status_m = SLST_STOPPED;
   slave_func_m = (u32)&slave_clear;
	SH2_REG_M_FRT_IC = 0xFFFF;
	stage_status = wait_slavesh2_running() ? STAGESTAT_DONE : STAGESTAT_BADINTERRUPT;
}

void test_slavesh2_hblank()
{
	int min=1, max=3, count;
	stage_status = STAGESTAT_WAITINGFORINT;
	slave_mode = SM_HBLANK;
	slavesh2_init();

	wait_slavesh2_running();

	// wait until we're not in hblank then reset counter
	vdp_wait_hblankout();
   slave_counter_m = 0;
	vdp_wait_hblankin();
	vdp_wait_hblankout();
	count = slave_counter_m;

	// Make sure counter matches correct value
	if (count == 0)
		stage_status = STAGESTAT_BADINTERRUPT;
   else if (count < min || count > max)
		stage_status = STAGESTAT_BADTIMING;
	else
		stage_status = STAGESTAT_DONE;

	if (stage_status != STAGESTAT_DONE)
	   vdp_printf(&test_disp_font, 0 * 8, 20 * 8, 0xF, "hblank counter = %d(%d-%d)", count, min, max);
}

void test_slavesh2_vblank()
{
	int min=550, max=554, count;
	stage_status = STAGESTAT_WAITINGFORINT;
	slave_mode = SM_HBLANK;
	slavesh2_init();

	wait_slavesh2_running();

	// wait until we're not in vblank then reset counter
	vdp_wait_vblankout();
	slave_counter_m = 0;
	vdp_wait_vblankin();
	vdp_wait_vblankout();
	count = slave_counter_m;

	// Make sure counter matches correct value
	if (count == 0)
		stage_status = STAGESTAT_BADINTERRUPT;
	else if (count < min || count > max)
		stage_status = STAGESTAT_BADTIMING;
	else
		stage_status = STAGESTAT_DONE;

	if (stage_status != STAGESTAT_DONE)
	   vdp_printf(&test_disp_font, 0 * 8, 21 * 8, 0xF, "vblank counter = %d(%d-%d)", count, min, max);
}

void slavesh2_test()
{
	unregister_all_tests();

	register_test(&test_slavesh2_init, "Slave SH2 Init");
	register_test(&test_slavesh2_icinterrupt, "Input Capture Interrupt");
	register_test(&test_slavesh2_scumask, "SCU Mask Cache Quirk");
	register_test(&test_slavesh2_icflag, "Input Capture Flag");
	register_test(&test_slavesh2_hblank, "Slave HBlank");
	register_test(&test_slavesh2_vblank, "Slave VBlank");
	do_tests("Slave SH2 Tests", 0, 0);
	slavesh2_deinit();
}
