
 int32 cycles = md_timestamp - vdp_last_ts;
 bool hcell_mode = (reg[0x0C] & 1); // True on H40, FALSE on H32
 //bool do_skip = FALSE;

 /* Maximum FIFO wait times(there is no wait during vblank):
	5.98uSec - H32 cell mode
	4.77uSec - H40 cell mode

    Maximum VRAM(8-bit??)/CRAM(16-bit)/VSRAM(16-bit) FIFO writes during a scanline("unlimited" during vblank):
	16	- H32 cell mode
   
    Maximum v-bus(68K) to VRAM writes per line:
	16	- H32 cell mode, active display
       167	- H32 cell mode, vblank
	18	- H40 cell mode, active display
       205	- H40 cell mode, vblank
	
    Maximum VRAM fill writes per line:
	15	- H32 cell mode, active display
       166	- H32 cell mode, vblank
	17	- H40 cell mode, active display
       204	- H40 cell mode, vblank

    Maximum VRAM copy read/write combos per line:
	 8	- H32 cell mode, active display
	83	- H32 cell mode, vblank
	 9	- H40 cell mode, active display
       102	- H40 cell mode, vblank


 H display
 H retrace 

	
	Horizontal blanking(H40 cell mode):
	 Start: H-counter = 0xE4
	 End:   H-counter = 0x08 (of the next line)

	Horizontal blanking(H32 cell mode):
	 Start: H-counter = 0xE9
	 End:	H-counter = ?

	Vertical blanking(H40 cell mode, V28 cell mode):
	 Start:	V-Counter = 0xE0, H-counter = 0xAA
	 End:	V-Counter = 0xFF, H-counter = 0xAA

	Vertical interrupt(H40 cell mode, V28 cell mode):
	 Start: V-Counter = 0xE0, H-counter = 0x08+ish
	 End: ??


	/ 10 in H32 mode
	/ 8 in H40 mode?		 


	28 
 */
 //const int divider = hcell_mode ? 8 : 10;
 const int lines_per_frame = is_pal ? 313 : 262;
 static const int event_count = 8;

 // If we change this table, we need to fix "vdp_line_phase" and related init values in MDVDP::Reset(), and also handle old values
 // without crashing when loading save states.
 static struct
 {
  const void *lptr;
  int32 cyc_to_next[2];
 } line_event_table[event_count] =
 {
  { &&EVT_END_OF_ACTIVE, 	 {   160,    128  } },
  { &&EVT_RIGHT_BORDER, 	 {   140,    112  } },
  { &&EVT_RIGHT_BLANKING, 	 {    90,     72  } },
  { &&EVT_HSYNC, 		 {   260,    313  } },
  { &&EVT_LEFT_BLANKING, 	 {   138,    163  } },
  { &&EVT_VINT, 		 {   102,     96  } },
  { &&EVT_LEFT_BORDER, 		 {   130,    104  } },
  { &&EVT_REMAINING_AD, 	 {  2400,   2432  } },
 };

 if(fifo_simu_count)
 {
  bool in_vb = ((status & 0x8) >> 3) | (((reg[1] & 0x40) ^ 0x40) >> 6);
  int div = ((hcell_mode ? 190 : 214) << ((code & 0xF) == 0x1));
  int run_count = ((md_timestamp - vdp_hcounter_start_ts) / div) - ((vdp_last_ts - vdp_hcounter_start_ts) / div);

  if(in_vb)
   run_count = 1000;

  fifo_simu_count -= run_count;
  if(fifo_simu_count <= 0)
  {
   fifo_simu_count = 0;
  }

  Recalc68KSuspend();
 }


 vdp_cycle_counter -= cycles;
 while(vdp_cycle_counter <= 0)
 {
  vdp_line_phase = (vdp_line_phase + 1) % event_count;
  //printf("%d, %d\n", scanline, vdp_line_phase);

  goto *(line_event_table[vdp_line_phase].lptr);

  EVT_END_OF_ACTIVE:
        vdp_hcounter_start_ts = md_timestamp + vdp_cycle_counter;

        scanline = (scanline + 1) % lines_per_frame;
        v_counter = scanline;

        render_line(scanline);

        if(scanline < (visible_frame_end - 1))
         parse_satb(0x81 + scanline);
        else if(scanline == (lines_per_frame - 1))
         parse_satb(0x80);

        if(scanline <= visible_frame_end)
        {
         counter--;
         if(counter == 0xFFFF)
         {
          counter = reg[10];
          hint_pending = 1;
         }
        }
        else
        {
         counter = reg[10];
        }

	goto EVT_exit;

  EVT_RIGHT_BORDER:
    	if(scanline == visible_frame_end)
    	{
	 /* Set V-Blank flag */
     	 status |= 0x0008;
    	}

    	CheckDMA();

    	if(scanline == lines_per_frame - 1)
    	{
     	 rect->y = is_pal ? 0 : 8;
     	 rect->h = is_pal ? 240 : 224;

     	 if(im2_flag)
     	 {
      	  status ^= 0x0010;
      	  espec->InterlaceOn = true;
	  espec->InterlaceField = (bool)(status & 0x10);

	  // Double-vertical-resolution interlaced mode
	  rect->y *= 2;
	  rect->h *= 2;
	 }
	 else
	  status &= ~0x0010;

	 /* Clear V-Blank flag */
	 status &= ~0x0008;
	}
	goto EVT_exit;

  EVT_RIGHT_BLANKING:
        status |= 0x0004; // Set h-blank flag
	goto EVT_exit;

  EVT_HSYNC:
	goto EVT_exit;

  EVT_LEFT_BLANKING:
	goto EVT_exit;

  EVT_VINT:
        /* If a Z80 interrupt is still pending after a scanline, cancel it */
        if(zirq == 1)
        {
         zirq = 0;
         z80_set_interrupt(FALSE);
        }

        if(scanline == visible_frame_end)
        {
         status |= 0x0080;
         vint_pending = 1;

         z80_set_interrupt(TRUE);
         zirq = 1;
         MD_ExitCPULoop();
        }   

	goto EVT_exit;

  EVT_LEFT_BORDER:
	status &= ~0x0004;	// Clear h-blank flag
	goto EVT_exit;

  EVT_REMAINING_AD:
	goto EVT_exit;

  EVT_exit: ;
  vdp_cycle_counter += line_event_table[vdp_line_phase].cyc_to_next[hcell_mode];
 }


#if 0
 //while(cycles > 0)
 {
  vdp_cycle_counter -= cycles; //this_cycles;
  while(vdp_cycle_counter <= 0)
  {
   vdp_line_phase = (vdp_line_phase + 1) % VDPLP_TOTAL;
 
   // Now, we're going INTO the phase that the if statement corresponds to.
   if(vdp_line_phase == VDPLP_HRETRACE_0)
   {


   }
   else if(vdp_line_phase == VDPLP_HRETRACE_1)
   {
    //printf("%d\n", md_timestamp - vdp_hcounter_start_ts);
    //vdp_hcounter_start_ts = md_timestamp + vdp_cycle_counter;
    vdp_cycle_counter += divider * (hcell_mode ? 16 : 13);
   }
   else if(vdp_line_phase == VDPLP_VISIBLE_0)
   {
    status &= ~0x0004; //C lear h-blank flag

    vdp_cycle_counter += divider * (hcell_mode ? 4 : 4);

    /* If a Z80 interrupt is still pending after a scanline, cancel it */
    if(zirq == 1)
    {
     zirq = 0;
     z80_set_interrupt(FALSE);
    }
    if(scanline == visible_frame_end)
    {
     status |= 0x0080;
     vint_pending = 1;

     z80_set_interrupt(TRUE);
     zirq = 1;
     MD_ExitCPULoop();
    }   
   }
   else if(vdp_line_phase == VDPLP_VISIBLE_1)
   {
    vdp_cycle_counter += divider * (hcell_mode ? 320 : 256);
   }
   else if(vdp_line_phase == VDPLP_VISIBLE_2)
   {
    vdp_cycle_counter += divider * (hcell_mode ? 26 : 23);
   }
  }
 }
#endif

 if(!MD_Is68KSuspended())
 {
    if(vint_pending && (reg[1] & 0x20))
    {
     //printf("V-int: %d, %d\n", scanline, md_timestamp);
     Main68K.SetIPL(6);
    }
    else if(hint_pending && (reg[0] & 0x10))
    {
     //printf("H-int: %d %d\n", scanline, md_timestamp);
     Main68K.SetIPL(4);
    }
    else
    {
     //printf("Int end: %d %d\n", scanline, md_timestamp);
     Main68K.SetIPL(0);
    }
 }

 vdp_last_ts = md_timestamp;


