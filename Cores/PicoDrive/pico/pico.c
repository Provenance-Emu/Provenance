/*
 * PicoDrive
 * (c) Copyright Dave, 2004
 * (C) notaz, 2006-2010
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#include "pico_int.h"
#include "sound/ym2612.h"

struct Pico Pico;
int PicoOpt;     
int PicoSkipFrame;     // skip rendering frame?
int PicoPad[2];        // Joypads, format is MXYZ SACB RLDU
int PicoPadInt[2];     // internal copy
int PicoAHW;           // active addon hardware: PAHW_*
int PicoQuirks;        // game-specific quirks
int PicoRegionOverride; // override the region detection 0: Auto, 1: Japan NTSC, 2: Japan PAL, 4: US, 8: Europe
int PicoAutoRgnOrder;

struct PicoSRAM SRam;
int emustatus;         // rapid_ym2612, multi_ym_updates
int scanlines_total;

void (*PicoWriteSound)(int len) = NULL; // called at the best time to send sound buffer (PsndOut) to hardware
void (*PicoResetHook)(void) = NULL;
void (*PicoLineHook)(void) = NULL;

// to be called once on emu init
void PicoInit(void)
{
  // Blank space for state:
  memset(&Pico,0,sizeof(Pico));
  memset(&PicoPad,0,sizeof(PicoPad));
  memset(&PicoPadInt,0,sizeof(PicoPadInt));

  // Init CPUs:
  SekInit();
  z80_init(); // init even if we aren't going to use it

  PicoInitMCD();
  PicoSVPInit();
  Pico32xInit();
}

// to be called once on emu exit
void PicoExit(void)
{
  if (PicoAHW & PAHW_MCD)
    PicoExitMCD();
  PicoCartUnload();
  z80_exit();

    if (SRam.data != NULL) {
        free(SRam.data);
        SRam.data = NULL;
        SRam.size = 0;
        SRam.start = SRam.end = 0;
    }
  pevt_dump();
}

void PicoPower(void)
{
  Pico.m.frame_count = 0;
  SekCycleCnt = SekCycleAim = 0;

  // clear all memory of the emulated machine
  memset(&Pico.ram,0,(unsigned char *)&Pico.rom - Pico.ram);

  memset(&Pico.video,0,sizeof(Pico.video));
  memset(&Pico.m,0,sizeof(Pico.m));

  Pico.video.pending_ints=0;
  z80_reset();

  // my MD1 VA6 console has this in IO
  Pico.ioports[1] = Pico.ioports[2] = Pico.ioports[3] = 0xff;

  // default VDP register values (based on Fusion)
  Pico.video.reg[0] = Pico.video.reg[1] = 0x04;
  Pico.video.reg[0xc] = 0x81;
  Pico.video.reg[0xf] = 0x02;

  if (PicoAHW & PAHW_MCD)
    PicoPowerMCD();

  if (PicoOpt & POPT_EN_32X)
    PicoPower32x();

  PicoReset();
}

PICO_INTERNAL void PicoDetectRegion(void)
{
  int support=0, hw=0, i;
  unsigned char pal=0;

  if (PicoRegionOverride)
  {
    support = PicoRegionOverride;
  }
  else
  {
    // Read cartridge region data:
    unsigned short *rd = (unsigned short *)(Pico.rom + 0x1f0);
    int region = (rd[0] << 16) | rd[1];

    for (i = 0; i < 4; i++)
    {
      int c;

      c = region >> (i<<3);
      c &= 0xff;
      if (c <= ' ') continue;

           if (c=='J')  support|=1;
      else if (c=='U')  support|=4;
      else if (c=='E')  support|=8;
      else if (c=='j') {support|=1; break; }
      else if (c=='u') {support|=4; break; }
      else if (c=='e') {support|=8; break; }
      else
      {
        // New style code:
        char s[2]={0,0};
        s[0]=(char)c;
        support|=strtol(s,NULL,16);
      }
    }
  }

  // auto detection order override
  if (PicoAutoRgnOrder) {
         if (((PicoAutoRgnOrder>>0)&0xf) & support) support = (PicoAutoRgnOrder>>0)&0xf;
    else if (((PicoAutoRgnOrder>>4)&0xf) & support) support = (PicoAutoRgnOrder>>4)&0xf;
    else if (((PicoAutoRgnOrder>>8)&0xf) & support) support = (PicoAutoRgnOrder>>8)&0xf;
  }

  // Try to pick the best hardware value for English/50hz:
       if (support&8) { hw=0xc0; pal=1; } // Europe
  else if (support&4)   hw=0x80;          // USA
  else if (support&2) { hw=0x40; pal=1; } // Japan PAL
  else if (support&1)   hw=0x00;          // Japan NTSC
  else hw=0x80; // USA

  Pico.m.hardware=(unsigned char)(hw|0x20); // No disk attached
  Pico.m.pal=pal;
}

int PicoReset(void)
{
  if (Pico.romsize <= 0)
    return 1;

#if defined(CPU_CMP_R) || defined(CPU_CMP_W) || defined(DRC_CMP)
  PicoOpt |= POPT_DIS_VDP_FIFO|POPT_DIS_IDLE_DET;
#endif

  /* must call now, so that banking is reset, and correct vectors get fetched */
  if (PicoResetHook)
    PicoResetHook();

  memset(&PicoPadInt,0,sizeof(PicoPadInt));
  emustatus = 0;

  if (PicoAHW & PAHW_SMS) {
    PicoResetMS();
    return 0;
  }

  SekReset();
  // ..but do not reset SekCycle* to not desync with addons

  // s68k doesn't have the TAS quirk, so we just globally set normal TAS handler in MCD mode (used by Batman games).
  SekSetRealTAS(PicoAHW & PAHW_MCD);

  Pico.m.dirtyPal = 1;

  Pico.m.z80_bank68k = 0;
  Pico.m.z80_reset = 1;

  PicoDetectRegion();
  Pico.video.status = 0x3428 | Pico.m.pal; // 'always set' bits | vblank | collision | pal

  PsndReset(); // pal must be known here

  // create an empty "dma" to cause 68k exec start at random frame location
  if (Pico.m.dma_xfers == 0 && !(PicoOpt & POPT_DIS_VDP_FIFO))
    Pico.m.dma_xfers = rand() & 0x1fff;

  SekFinishIdleDet();

  if (PicoAHW & PAHW_MCD) {
    PicoResetMCD();
    return 0;
  }

  // reinit, so that checksum checks pass
  if (!(PicoOpt & POPT_DIS_IDLE_DET))
    SekInitIdleDet();

  if (PicoOpt & POPT_EN_32X)
    PicoReset32x();

  // reset sram state; enable sram access by default if it doesn't overlap with ROM
  Pico.m.sram_reg = 0;
  if ((SRam.flags & SRF_EEPROM) || Pico.romsize <= SRam.start)
    Pico.m.sram_reg |= SRR_MAPPED;

  if (SRam.flags & SRF_ENABLED)
    elprintf(EL_STATUS, "sram: %06x - %06x; eeprom: %i", SRam.start, SRam.end,
      !!(SRam.flags & SRF_EEPROM));

  return 0;
}

// flush config changes before emu loop starts
void PicoLoopPrepare(void)
{
  if (PicoRegionOverride)
    // force setting possibly changed..
    Pico.m.pal = (PicoRegionOverride == 2 || PicoRegionOverride == 8) ? 1 : 0;

  // FIXME: PAL has 313 scanlines..
  scanlines_total = Pico.m.pal ? 312 : 262;

  Pico.m.dirtyPal = 1;
  rendstatus_old = -1;
}


// dma2vram settings are just hacks to unglitch Legend of Galahad (needs <= 104 to work)
// same for Outrunners (92-121, when active is set to 24)
// 96 is VR hack
static const int dma_timings[] = {
  167, 167, 166,  83, // vblank: 32cell: dma2vram dma2[vs|c]ram vram_fill vram_copy
  102, 205, 204, 102, // vblank: 40cell:
  16,   16,  15,   8, // active: 32cell:
  24,   18,  17,   9  // ...
};

static const int dma_bsycles[] = {
  (488<<8)/167, (488<<8)/167, (488<<8)/166, (488<<8)/83,
  (488<<8)/102, (488<<8)/233, (488<<8)/204, (488<<8)/102,
  (488<<8)/16,  (488<<8)/16,  (488<<8)/15,  (488<<8)/8,
  (488<<8)/24,  (488<<8)/18,  (488<<8)/17,  (488<<8)/9
};

// grossly inaccurate.. FIXME FIXXXMEE
PICO_INTERNAL int CheckDMA(void)
{
  int burn = 0, xfers_can, dma_op = Pico.video.reg[0x17]>>6; // see gens for 00 and 01 modes
  int xfers = Pico.m.dma_xfers;
  int dma_op1;

  if(!(dma_op&2)) dma_op = (Pico.video.type==1) ? 0 : 1; // setting dma_timings offset here according to Gens
  dma_op1 = dma_op;
  if(Pico.video.reg[12] & 1) dma_op |= 4; // 40 cell mode?
  if(!(Pico.video.status&8)&&(Pico.video.reg[1]&0x40)) dma_op|=8; // active display?
  xfers_can = dma_timings[dma_op];
  if(xfers <= xfers_can)
  {
    if(dma_op&2) Pico.video.status&=~2; // dma no longer busy
    else {
      burn = xfers * dma_bsycles[dma_op] >> 8; // have to be approximate because can't afford division..
    }
    Pico.m.dma_xfers = 0;
  } else {
    if(!(dma_op&2)) burn = 488;
    Pico.m.dma_xfers -= xfers_can;
  }

  elprintf(EL_VDPDMA, "~Dma %i op=%i can=%i burn=%i [%i]", Pico.m.dma_xfers, dma_op1, xfers_can, burn, SekCyclesDone());
  //dprintf("~aim: %i, cnt: %i", SekCycleAim, SekCycleCnt);
  return burn;
}

#include "pico_cmn.c"

unsigned int last_z80_sync; /* in 68k cycles */
int z80_cycle_cnt;
int z80_cycle_aim;
int z80_scanline;
int z80_scanline_cycles;  /* cycles done until z80_scanline */

/* sync z80 to 68k */
PICO_INTERNAL void PicoSyncZ80(unsigned int m68k_cycles_done)
{
  int m68k_cnt;
  int cnt;

  m68k_cnt = m68k_cycles_done - last_z80_sync;
  z80_cycle_aim += cycles_68k_to_z80(m68k_cnt);
  cnt = z80_cycle_aim - z80_cycle_cnt;
  last_z80_sync = m68k_cycles_done;

  pprof_start(z80);

  elprintf(EL_BUSREQ, "z80 sync %i (%u|%u -> %u|%u)", cnt,
    z80_cycle_cnt, z80_cycle_cnt / 288,
    z80_cycle_aim, z80_cycle_aim / 288);

  if (cnt > 0)
    z80_cycle_cnt += z80_run(cnt);

  pprof_end(z80);
}


void PicoFrame(void)
{
  pprof_start(frame);

  Pico.m.frame_count++;

  if (PicoAHW & PAHW_SMS) {
    PicoFrameMS();
    goto end;
  }

  if (PicoAHW & PAHW_32X) {
    PicoFrame32x(); // also does MCD+32X
    goto end;
  }

  if (PicoAHW & PAHW_MCD) {
    PicoFrameMCD();
    goto end;
  }

  //if(Pico.video.reg[12]&0x2) Pico.video.status ^= 0x10; // change odd bit in interlace mode

  PicoFrameStart();
  PicoFrameHints();

end:
  pprof_end(frame);
}

void PicoFrameDrawOnly(void)
{
  if (!(PicoAHW & PAHW_SMS)) {
    PicoFrameStart();
    PicoDrawSync(223, 0);
  } else {
    PicoFrameDrawOnlyMS();
  }
}

void PicoGetInternal(pint_t which, pint_ret_t *r)
{
  switch (which)
  {
    case PI_ROM:         r->vptr = Pico.rom; break;
    case PI_ISPAL:       r->vint = Pico.m.pal; break;
    case PI_IS40_CELL:   r->vint = Pico.video.reg[12]&1; break;
    case PI_IS240_LINES: r->vint = Pico.m.pal && (Pico.video.reg[1]&8); break;
  }
}

// callback to output message from emu
void (*PicoMessage)(const char *msg)=NULL;

