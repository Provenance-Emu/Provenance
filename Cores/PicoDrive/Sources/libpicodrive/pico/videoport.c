/*
 * PicoDrive
 * (c) Copyright Dave, 2004
 * (C) notaz, 2006-2009
 * (C) irixxxx, 2020-2024
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#include "pico_int.h"
#define NEED_DMA_SOURCE
#include "memory.h"


enum { clkdiv = 2 };    // CPU clock granularity: one of 1,2,4,8

// VDP Slot timing, taken from http://gendev.spritesmind.net/
//     forum/viewtopic.php?f=22&t=851&sid=d5701a71396ee7f700c74fb7cd85cb09
//     http://plutiedev.com/mirror/kabuto-hardware-notes
// Thank you very much for the great work, Nemesis, Kabuto!

// Slot clock is sysclock/20 for h32 and sysclock/16 for h40.
// One scanline is 63.7us/64.3us (ntsc/pal) long which is ~488.57 68k cycles.
// Approximate by 488 for VDP.
// 1 slot is 20/7 = 2.857 68k cycles in h32, and 16/7 = 2.286 in h40. That's
// 171 slots in h32, and ~214 (really 193 plus 17 prolonged in HSYNC) in h40.
enum { slcpu = 488 };

// VDP has a slot counter running from 0x00 to 0xff every scanline, but it has
// a gap depending on the video mode. The slot in which a horizontal interrupt
// is generated also depends on the video mode.
// NB Kabuto says gapend40 is 0xe4. That's technically correct, since slots 0xb6
// and 0xe4 are only half slots. Ignore 0xe4 here and make 0xb6 a full slot.
enum { hint32 = 0x85, gapstart32 = 0x94, gapend32 = 0xe9};
enum { hint40 = 0xa5, gapstart40 = 0xb7, gapend40 = 0xe5};

// Basic timing in h32: 38 slots (~108.5 cycles) from hint to VDP output start
// at slot 0x00. vint takes place on the 1st VBLANK line in slot 0x01 (~111.5).
// Rendering takes 128 slots (~365.5), and right border starts at slot 0x80
// (~474 cycles). hint occurs after 5 slots into the border (~488.5 cycles).

// The horizontal sync period (HBLANK) is 30/37 slots (h32/h40):
// h32: 4 slots front porch (1.49us), 13 HSYNC (4.84us), 13 back porch (4.84us)
// h40: 5 slots front porch (1.49us), 16 HSYNC (4.77us), 16 back porch (4.77us)
// HBLANK starts at slot 0x93/0xb4 and ends in the middle of slot 0x05/0x06,
// NB VDP slows down the h40 clock to h32 during HSYNC for 17 slots to get the
// right sync timing. Ignored in the slot calculation, but hblen40 is correct.
enum { hboff32 = 0x93-hint32, hblen32 = 0xf8-(gapend32-gapstart32)-hint32};//30
enum { hboff40 = 0xb4-hint40, hblen40 = 0xf8-(gapend40-gapstart40)-hint40};//37

// number of slots in a scanline
#define slots32	(0x100-(gapend32-gapstart32)) // 171
#define slots40	(0x100-(gapend40-gapstart40)) // 210

// In blanked display, all slots but the refresh slots are usable for transfers,
// in active display only 16(h32) / 18(h40) slots can be used.

// dma and refresh slots for active display, 16 for H32
static u8 dmaslots32[] =
    { 145,243, 2,10,18, 34,42,50, 66,74,82, 98,106,114, 129,130 };
static u8 refslots32[] =
    {        250,     26,       58,       90,         122 };
// dma and refresh slots for active display, 18 for H40
static u8 dmaslots40[] =
    {     232, 2,10,18, 34,42,50, 66,74,82, 98,106,114, 130,138,146, 161,162 };
static u8 refslots40[] =
    {        250,     26,       58,       90,         122,         154 };

// table sizes
enum { cycsz = slcpu/clkdiv };
enum { sl32blsz=slots32-sizeof(refslots32)+1, sl32acsz=sizeof(dmaslots32)+1 };
enum { sl40blsz=slots40-sizeof(refslots40)+1, sl40acsz=sizeof(dmaslots40)+1 };

// Tables must be considerably larger than one scanline, since 68k emulation
// isn't stopping in the middle of an operation. If the last op is a 32 bit
// VDP access 2 slots may need to be taken from the next scanline, which can be
// more than 100 CPU cycles. For safety just cover 2 scanlines.

// table for hvcounter mapping. check: Sonic 3D Blast bonus, Cannon Fodder,
// Chase HQ II, 3 Ninjas kick back, Road Rash 3, Skitchin', Wheel of Fortune
static u8  hcounts_32[2*cycsz], hcounts_40[2*cycsz];
// tables mapping cycles to slots
static u16 vdpcyc2sl_32_bl[2*cycsz],vdpcyc2sl_40_bl[2*cycsz];
static u16 vdpcyc2sl_32_ac[2*cycsz],vdpcyc2sl_40_ac[2*cycsz];
// tables mapping slots to cycles
// NB the sl2cyc tables must cover all slots present in the cyc2sl tables.
static u16 vdpsl2cyc_32_bl[2*sl32blsz],vdpsl2cyc_40_bl[2*sl40blsz];
static u16 vdpsl2cyc_32_ac[2*sl32acsz],vdpsl2cyc_40_ac[2*sl40acsz];


// calculate timing tables for one mode (H32 or H40)
// NB tables aligned to HINT, since the main loop uses HINT as synchronization
#define INITTABLES(s) { \
  float factor = (float)slcpu/slots##s;					\
  int ax, bx, rx, ac, bc;						\
  int i, n;								\
									\
  /* calculate internal VDP slot numbers */				\
  for (i = 0; i < cycsz; i++) {						\
    n = hint##s + i*clkdiv/factor;					\
    if (n >= gapstart##s) n += gapend##s-gapstart##s;			\
    hcounts_##s[i] = n % 256;						\
  }									\
									\
  ax = bx = ac = bc = rx = 0;						\
  for (i = 0; i < cycsz; i++) {						\
    n = hcounts_##s[i];							\
    if (i == 0 || n != hcounts_##s[i-1]) {				\
      /* fill slt <=> cycle tables, active scanline */			\
      if (ax < ARRAY_SIZE(dmaslots##s) && dmaslots##s[ax] == n) {	\
        vdpsl2cyc_##s##_ac[++ax]=i;					\
        while (ac < i) vdpcyc2sl_##s##_ac[ac++] = ax-1;			\
      }									\
      /* fill slt <=> cycle tables, scanline off */			\
      if (rx >= ARRAY_SIZE(refslots##s) || refslots##s[rx] != n) {	\
        vdpsl2cyc_##s##_bl[++bx]=i;					\
        while (bc < i) vdpcyc2sl_##s##_bl[bc++] = bx-1;			\
      } else								\
        ++rx;								\
    }									\
  }									\
  /* fill up cycle to slot mappings for last slot */			\
  while (ac < cycsz)							\
    vdpcyc2sl_##s##_ac[ac] = ARRAY_SIZE(dmaslots##s),		ac++;	\
  while (bc < cycsz)							\
    vdpcyc2sl_##s##_bl[bc] = slots##s-ARRAY_SIZE(refslots##s),	bc++;	\
									\
  /* extend tables for 2nd scanline */					\
  memcpy(hcounts_##s+cycsz, hcounts_##s, ARRAY_SIZE(hcounts_##s)-cycsz);\
  i = ARRAY_SIZE(dmaslots##s);						\
  while (ac < ARRAY_SIZE(vdpcyc2sl_##s##_ac))				\
    vdpcyc2sl_##s##_ac[ac] = vdpcyc2sl_##s##_ac[ac-cycsz]+i,	ac++;	\
  while (ax < ARRAY_SIZE(vdpsl2cyc_##s##_ac)-1)			ax++,	\
    vdpsl2cyc_##s##_ac[ax] = vdpsl2cyc_##s##_ac[ax-i]+cycsz;		\
  i = slots##s - ARRAY_SIZE(refslots##s);				\
  while (bc < ARRAY_SIZE(vdpcyc2sl_##s##_bl))				\
    vdpcyc2sl_##s##_bl[bc] = vdpcyc2sl_##s##_bl[bc-cycsz]+i,	bc++;	\
  while (bx < ARRAY_SIZE(vdpsl2cyc_##s##_bl)-1)			bx++,	\
    vdpsl2cyc_##s##_bl[bx] = vdpsl2cyc_##s##_bl[bx-i]+cycsz;		\
}
 

// initialize VDP timing tables
void PicoVideoInit(void)
{
  INITTABLES(32);
  INITTABLES(40);
}


static int linedisabled;    // display disabled on this line
static int lineenabled;     // display enabled on this line
static int lineoffset;      // offset at which dis/enable took place

u32 SATaddr, SATmask;       // VRAM addr of sprite attribute table

int (*PicoDmaHook)(u32 source, int len, unsigned short **base, u32 *mask) = NULL;


/* VDP FIFO implementation
 * 
 * fifo_slot: last slot executed in this scanline
 * fifo_total: #total FIFO entries pending
 * fifo_data: last values transferred through fifo
 * fifo_queue: fifo transfer queue (#writes, flags)
 *
 * FIFO states:		empty	total=0
 *			inuse	total>0 && total<4
 *			full	total==4
 *			wait	total>4
 * Conditions:
 * fifo_slot is normally behind slot2cyc[cycles]. Advancing it beyond cycles
 * implies blocking the 68k up to that slot.
 *
 * A FIFO write goes to the end of the FIFO queue, but DMA running in background
 * is always the last queue entry (transfers by CPU intervene and come 1st).
 * There can be more pending writes than FIFO slots, but the CPU will be blocked
 * until FIFO level (without background DMA) <= 4.
 * This is only about correct timing, data xfer must be handled by the caller.
 * Blocking the CPU means burning cycles via SekCyclesBurn*(), which is to be
 * executed by the caller.
 *
 * FIFOSync "executes" FIFO write slots up to the given cycle in the current
 * scanline. A queue entry completely executed is removed from the queue.
 * FIFOWrite pushes writes to the transfer queue. If it's a blocking write, 68k
 * is blocked if more than 4 FIFO writes are pending.
 * FIFORead executes a 68k read. 68k is blocked until the next transfer slot.
 */

// NB code assumes fifo_* arrays have size 2^n
static struct VdpFIFO { // XXX this must go into save file!
  // last transferred FIFO data, ...x = index  XXX currently only CPU
  u16 fifo_data[4], fifo_dx;

  // queued FIFO transfers, ...x = index, ...l = queue length
  // each entry has 2 values: [n]>>3 = #writes, [n]&7 = flags (FQ_*)
  u32 fifo_queue[8], fifo_qx, fifo_ql;
  int fifo_total;             // total# of pending FIFO entries (w/o BGDMA)

  unsigned short fifo_slot;   // last executed slot in current scanline
  unsigned short fifo_maxslot;// #slots in scanline

  const unsigned short *fifo_cyc2sl;
  const unsigned short *fifo_sl2cyc;
  const unsigned char  *fifo_hcounts;
} VdpFIFO;

enum { FQ_BYTE = 1, FQ_BGDMA = 2, FQ_FGDMA = 4 }; // queue flags, NB: BYTE = 1!


// NB should limit cyc2sl to table size in case 68k overdraws its aim. That can
// happen if the last op is a blocking acess to VDP, or for exceptions (e.g.irq)
#define Cyc2Sl(vf,lc)   ((vf)->fifo_cyc2sl[(lc)/clkdiv])
#define Sl2Cyc(vf,sl)   ((vf)->fifo_sl2cyc[sl]*clkdiv)

// do the FIFO math
static int AdvanceFIFOEntry(struct VdpFIFO *vf, struct PicoVideo *pv, int slots)
{
  u32 *qx = &vf->fifo_queue[vf->fifo_qx];
  int l = slots, b = *qx & FQ_BYTE;
  int cnt = *qx >> 3;

  // advance currently active FIFO entry
  if (l > cnt)
    l = cnt;
  if (!(*qx & FQ_BGDMA))
    vf->fifo_total -= ((cnt & b) + l) >> b;
  *qx -= l << 3;

  // if entry has been processed...
  if (cnt == l) {
    // remove entry from FIFO
    *qx = 0;
    vf->fifo_qx = (vf->fifo_qx+1) & 7;
    vf->fifo_ql --;
  }

  return l;
}

static void SetFIFOState(struct VdpFIFO *vf, struct PicoVideo *pv)
{
  u32 st = pv->status, cmd = pv->command;
  // release CPU and terminate DMA if FIFO isn't blocking the 68k anymore
  if (vf->fifo_total <= 4) {
    st &= ~PVS_CPUWR;
    if (!(st & (PVS_DMABG|PVS_DMAFILL))) {
      st &= ~SR_DMA;
      cmd &= ~0x80;
    }
  }
  if (vf->fifo_ql == 0) {
    st &= ~PVS_CPURD;
    // terminate DMA if applicable
    if (!(st & PVS_DMAFILL)) {
      st &= ~(SR_DMA|PVS_DMABG);
      cmd &= ~0x80;
    }
  }
  pv->status = st;
  pv->command = cmd;
}

// sync FIFO to cycles
void PicoVideoFIFOSync(int cycles)
{
  struct VdpFIFO *vf = &VdpFIFO;
  struct PicoVideo *pv = &Pico.video;
  int slots, done;

  // calculate #slots since last executed slot
  slots = Cyc2Sl(vf, cycles) - vf->fifo_slot;
  if (slots <= 0 || !vf->fifo_ql) return;

  // advance FIFO queue by #done slots
  done = slots;
  while (done > 0 && vf->fifo_ql) {
    int l = AdvanceFIFOEntry(vf, pv, done);
    vf->fifo_slot += l;
    done -= l;
  }

  if (done != slots)
    SetFIFOState(vf, pv);
}

// drain FIFO, blocking 68k on the way. FIFO must be synced prior to drain.
static int PicoVideoFIFODrain(int level, int cycles, int bgdma)
{
  struct VdpFIFO *vf = &VdpFIFO;
  struct PicoVideo *pv = &Pico.video;
  unsigned ocyc = cycles;
  int bd = vf->fifo_queue[vf->fifo_qx] & bgdma;
  int burn = 0;

  if (!(vf->fifo_ql && ((vf->fifo_total > level) | bd))) return 0;

  // process FIFO entries until low level is reached
  while (vf->fifo_slot < vf->fifo_maxslot &&
         vf->fifo_ql && ((vf->fifo_total > level) | bd)) {
    int b = vf->fifo_queue[vf->fifo_qx] & FQ_BYTE;
    int c = vf->fifo_queue[vf->fifo_qx] >> 3;
    int cnt = bd ? c : ((vf->fifo_total-level)<<b) - (c&b);
    int slot = (c < cnt ? c : cnt) + vf->fifo_slot;

    if (slot > vf->fifo_maxslot) {
      // target slot in later scanline, advance to eol
      slot = vf->fifo_maxslot;
    }
    if (slot > vf->fifo_slot) {
      // advance FIFO to target slot and CPU to cycles at that slot
      vf->fifo_slot += AdvanceFIFOEntry(vf, pv, slot - vf->fifo_slot);
      cycles = Sl2Cyc(vf, vf->fifo_slot);
      bd = vf->fifo_queue[vf->fifo_qx] & bgdma;
    }
  }
  if (vf->fifo_ql && ((vf->fifo_total > level) | bd))
    cycles = slcpu; // not completed in this scanline
  if (cycles > ocyc)
    burn = cycles - ocyc;

  SetFIFOState(vf, pv);

  return burn;
}

// read VDP data port
static int PicoVideoFIFORead(void)
{
  struct VdpFIFO *vf = &VdpFIFO;
  struct PicoVideo *pv = &Pico.video;
  int lc = SekCyclesDone()-Pico.t.m68c_line_start;
  int burn = 0;

  if (vf->fifo_ql) {
    // advance FIFO and CPU until FIFO is empty
    burn = PicoVideoFIFODrain(0, lc, FQ_BGDMA);
    lc += burn;
  }

  if (vf->fifo_ql)
    pv->status |= PVS_CPURD; // target slot is in later scanline
  else {
    // use next VDP access slot for reading, block 68k until then
    vf->fifo_slot = Cyc2Sl(vf, lc) + 1;
    burn += Sl2Cyc(vf, vf->fifo_slot) - lc;
  }

  return burn;
}
 
// write VDP data port
int PicoVideoFIFOWrite(int count, int flags, unsigned sr_mask,unsigned sr_flags)
{
  struct VdpFIFO *vf = &VdpFIFO;
  struct PicoVideo *pv = &Pico.video;
  int lc = SekCyclesDone()-Pico.t.m68c_line_start;
  int burn = 0, x;

  // sync only needed if queue is too full or background dma might be deferred
  if ((vf->fifo_ql >= 6) | (pv->status & PVS_DMABG))
    PicoVideoFIFOSync(lc);

  // determine last ent, ignoring bg dma (pushed back below if new ent created)
  x = (vf->fifo_qx + vf->fifo_ql - 1 - !!(pv->status & PVS_DMABG)) & 7;

  pv->status = (pv->status & ~sr_mask) | sr_flags;
  vf->fifo_total += count * !(flags & FQ_BGDMA);
  if (!vf->fifo_ql)
    vf->fifo_slot = Cyc2Sl(vf, lc+7); // FIFO latency ~3 vdp slots

  // determine queue position for entry
  count <<= (flags & FQ_BYTE)+3;
  if (vf->fifo_queue[x] && (vf->fifo_queue[x] & 7) == flags) {
    // amalgamate entries if of same type and not empty (in case of bgdma)
    vf->fifo_queue[x] += count;
  } else {
    // create new xfer queue entry
    vf->fifo_ql ++;
    x = (x+1) & 7;
    vf->fifo_queue[(x+1)&7] = vf->fifo_queue[x]; // push back bg dma if exists
    vf->fifo_queue[x] = count | flags;
  }

  // if CPU is waiting for the bus, advance CPU and FIFO until bus is free
  // do this only if it would exhaust the available slots since last sync
  x = (Cyc2Sl(vf,lc) - vf->fifo_slot) / 2; // lower bound of FIFO ents 
  if ((pv->status & PVS_CPUWR) && vf->fifo_total > 4 + x)
    burn = PicoVideoFIFODrain(4, lc, 0);

  return burn;
}

// at HINT, advance FIFO to new scanline
int PicoVideoFIFOHint(void)
{
  struct VdpFIFO *vf = &VdpFIFO;
  struct PicoVideo *pv = &Pico.video;
  int lc = SekCyclesDone()-Pico.t.m68c_line_start;
  int burn = 0;

  // reset slot to start of scanline
  vf->fifo_slot = 0;
  // only need to refresh sprite position if we are synced
  if (Pico.est.DrawScanline == Pico.m.scanline && !(pv->status & SR_VB))
    PicoDrawRefreshSprites();
 
  // if CPU is waiting for the bus, advance CPU and FIFO until bus is free
  if (pv->status & PVS_CPUWR)
    burn = PicoVideoFIFODrain(4, lc, 0);
  else if (pv->status & PVS_CPURD)
    burn = PicoVideoFIFORead();

  return burn;
}

// switch FIFO mode between active/inactive display
void PicoVideoFIFOMode(int active, int h40)
{
  static const unsigned short *vdpcyc2sl[2][2] =
      { {vdpcyc2sl_32_bl, vdpcyc2sl_40_bl},{vdpcyc2sl_32_ac, vdpcyc2sl_40_ac} };
  static const unsigned short *vdpsl2cyc[2][2] =
      { {vdpsl2cyc_32_bl, vdpsl2cyc_40_bl},{vdpsl2cyc_32_ac, vdpsl2cyc_40_ac} };
  static const unsigned char *vdphcounts[2] =
      { hcounts_32, hcounts_40 };

  struct VdpFIFO *vf = &VdpFIFO;
  struct PicoVideo *pv = &Pico.video;
  int lc = SekCyclesDone() - Pico.t.m68c_line_start;
  active = active && !(pv->status & PVS_VB2);

  if (vf->fifo_maxslot)
    PicoVideoFIFOSync(lc);
  else
    lc = 0;

  vf->fifo_cyc2sl = vdpcyc2sl[active][h40];
  vf->fifo_sl2cyc = vdpsl2cyc[active][h40];
  vf->fifo_hcounts = vdphcounts[h40];
  // recalculate FIFO slot for new mode
  vf->fifo_slot = Cyc2Sl(vf, lc);
  vf->fifo_maxslot = Cyc2Sl(vf, slcpu);
}

// VDP memory rd/wr

static __inline void AutoIncrement(void)
{
  struct PicoVideo *pvid = &Pico.video;
  pvid->addr=(unsigned short)(pvid->addr+pvid->reg[0xf]);
  if (pvid->addr < pvid->reg[0xf]) pvid->addr_u ^= 1;
}

static NOINLINE void VideoWriteVRAM128(u32 a, u16 d)
{
  // nasty
  u32 b = ((a & 2) >> 1) | ((a & 0x400) >> 9) | (a & 0x3FC) | ((a & 0x1F800) >> 1);

  ((u8 *)PicoMem.vram)[b] = d;
  if (!(u16)((b^SATaddr) & SATmask))
    Pico.est.rendstatus |= PDRAW_DIRTY_SPRITES;

  if (((a^SATaddr) & SATmask) == 0)
    UpdateSAT(a, d);
}

static void VideoWrite(u16 d)
{
  struct PicoVideo *pvid = &Pico.video;
  unsigned int a = pvid->addr;

  switch (pvid->type)
  {
    case 1: if (a & 1)
              d = (u16)((d << 8) | (d >> 8));
            a |= pvid->addr_u << 16;
            VideoWriteVRAM(a, d);
            break;
    case 3: if (PicoMem.cram [(a >> 1) & 0x3f] != (d & 0xeee)) Pico.m.dirtyPal = 1;
            PicoMem.cram [(a >> 1) & 0x3f] = d & 0xeee; break;
    case 5: PicoMem.vsram[(a >> 1) & 0x3f] = d & 0x7ff; break;
    case 0x81:
            a |= pvid->addr_u << 16;
            VideoWriteVRAM128(a, d);
            break;
    //default:elprintf(EL_ANOMALY, "VDP write %04x with bad type %i", d, pvid->type); break;
  }

  AutoIncrement();
}

static unsigned int VideoRead(int is_from_z80)
{
  struct PicoVideo *pvid = &Pico.video;
  unsigned int a, d = VdpFIFO.fifo_data[(VdpFIFO.fifo_dx+1)&3];

  a=pvid->addr; a>>=1;

  if (!is_from_z80)
    SekCyclesBurnRun(PicoVideoFIFORead());
  switch (pvid->type)
  {
    case 0: d=PicoMem.vram [a & 0x7fff]; break;
    case 8: d=PicoMem.cram [a & 0x003f] | (d & ~0x0eee); break;
    case 4: if ((a & 0x3f) >= 0x28) a = 0;
            d=PicoMem.vsram [a & 0x003f] | (d & ~0x07ff); break;
    case 12:a=PicoMem.vram [a & 0x7fff]; if (pvid->addr&1) a >>= 8;
            d=(a & 0x00ff) | (d & ~0x00ff); break;
    default:elprintf(EL_ANOMALY, "VDP read with bad type %i", pvid->type); break;
  }

  AutoIncrement();
  return d;
}

// VDP DMA

static int GetDmaLength(void)
{
  struct PicoVideo *pvid=&Pico.video;
  int len=0;
  // 16-bit words to transfer:
  len =pvid->reg[0x13];
  len|=pvid->reg[0x14]<<8;
  len = ((len - 1) & 0xffff) + 1;
  return len;
}

static void DmaSlow(int len, u32 source)
{
  struct PicoVideo *pvid=&Pico.video;
  u32 inc = pvid->reg[0xf];
  u32 a = pvid->addr | (pvid->addr_u << 16), e;
  u16 *r, *base = NULL;
  u32 mask = 0x1ffff;
  int lc = SekCyclesDone()-Pico.t.m68c_line_start;

  elprintf(EL_VDPDMA, "DmaSlow[%i] %06x->%04x len %i inc=%i blank %i [%u] @ %06x",
    pvid->type, source, a, len, inc, (pvid->status&SR_VB)||!(pvid->reg[1]&0x40),
    SekCyclesDone(), SekPc);

  SekCyclesBurnRun(PicoVideoFIFOWrite(len, FQ_FGDMA | (pvid->type == 1),
                              PVS_DMABG, SR_DMA | PVS_CPUWR));
  // short transfers might have been completely conveyed to FIFO, adjust state
  if ((pvid->status & SR_DMA) && VdpFIFO.fifo_total <= 4)
    SetFIFOState(&VdpFIFO, pvid);

  if ((source & 0xe00000) == 0xe00000) { // Ram
    base = (u16 *)PicoMem.ram;
    mask = 0xffff;
  }
  else if (PicoIn.AHW & PAHW_MCD)
  {
    u8 r3 = Pico_mcd->s68k_regs[3];
    elprintf(EL_VDPDMA, "DmaSlow CD, r3=%02x", r3);
    if ((source & 0xfc0000) == pcd_base_address) { // Bios area
      base = (u16 *)(Pico_mcd->bios + (source & 0xfe0000));
    } else if ((source & 0xfc0000) == pcd_base_address+0x200000) { // Word Ram
      if (!(r3 & 4)) { // 2M mode
        base = (u16 *)(Pico_mcd->word_ram2M + (source & 0x20000));
      } else {
        if ((source & 0xfe0000) < pcd_base_address+0x220000) { // 1M mode
          int bank = r3 & 1;
          base = (u16 *)(Pico_mcd->word_ram1M[bank]);
        } else {
          DmaSlowCell(source - 2, a, len, inc);
          return;
        }
      }
      source -= 2;
    } else if ((source & 0xfe0000) == pcd_base_address+0x020000) { // Prg Ram
      base = (u16 *)Pico_mcd->prg_ram_b[r3 >> 6];
      source -= 2; // XXX: test
    } else // Rom
      base = m68k_dma_source(source);
  }
  else
  {
    // if we have DmaHook, let it handle ROM because of possible DMA delay
    u32 source2;
    if (PicoDmaHook && (source2 = PicoDmaHook(source, len, &base, &mask)))
      source = source2;
    else // Rom
      base = m68k_dma_source(source);
  }
  if (!base) {
    elprintf(EL_VDPDMA|EL_ANOMALY, "DmaSlow[%i] %06x->%04x: invalid src", pvid->type, source, a);
    return;
  }

  // operate in words
  source >>= 1;
  mask >>= 1;

  switch (pvid->type)
  {
    case 1: // vram
      e = a + len*2-1;
      r = PicoMem.vram;
      if (inc == 2 && !(a & 1) && !((a ^ e) >> 16) &&
          ((a >= SATaddr + 0x280) | (e < SATaddr)) &&
          !((source ^ (source + len-1)) & ~mask))
      {
        // most used DMA mode
        memcpy((char *)r + a, base + (source & mask), len * 2);
        a += len * 2;
        break;
      }
      for(; len; len--)
      {
        u16 d = base[source++ & mask];
        if(a & 1) d=(d<<8)|(d>>8);
        VideoWriteVRAM(a, d);
        // AutoIncrement
        a = (a+inc) & ~0x20000;
      }
      break;

    case 3: // cram
      Pico.m.dirtyPal = 1;
      r = PicoMem.cram;
      if (inc == 0 && !(pvid->reg[1] & 0x40) &&
            (pvid->reg[7] & 0x3f) == ((a/2) & 0x3f)) { // bg color DMA
        PicoVideoSync(1);
        int sl = VdpFIFO.fifo_hcounts[lc/clkdiv];
        if (sl > VdpFIFO.fifo_hcounts[0]-5) // hint delay is 5 slots
          sl = (s8)sl;
        // TODO this is needed to cover timing inaccuracies
        if (sl <= 12) sl = -3;
        else if (sl <= 40) sl = 30;
        PicoDrawBgcDMA(base, source, mask, len, sl);
        // do last DMA cycle since it's all going to the same cram location
        source = source+len-1;
        len = 1;
      }
      for (; len; len--)
      {
        r[(a / 2) & 0x3f] = base[source++ & mask] & 0xeee;
        // AutoIncrement
        a = (a+inc) & ~0x20000;
      }
      break;

    case 5: // vsram
      r = PicoMem.vsram;
      for (; len; len--)
      {
        r[(a / 2) & 0x3f] = base[source++ & mask] & 0x7ff;
        // AutoIncrement
        a = (a+inc) & ~0x20000;
      }
      break;

    case 0x81: // vram 128k
      for(; len; len--)
      {
        u16 d = base[source++ & mask];
        VideoWriteVRAM128(a, d);
        // AutoIncrement
        a = (a+inc) & ~0x20000;
      }
      break;

    default:
      if (pvid->type != 0 || (EL_LOGMASK & EL_VDPDMA))
        elprintf(EL_VDPDMA|EL_ANOMALY, "DMA with bad type %i", pvid->type);
      break;
  }
  // remember addr
  pvid->addr = a;
  pvid->addr_u = a >> 16;
}

static void DmaCopy(int len)
{
  struct PicoVideo *pvid=&Pico.video;
  u32 a = pvid->addr | (pvid->addr_u << 16);
  u8 *vr = (u8 *)PicoMem.vram;
  u8 inc = pvid->reg[0xf];
  int source;
  elprintf(EL_VDPDMA, "DmaCopy len %i [%u]", len, SekCyclesDone());

  // XXX implement VRAM 128k? Is this even working? xfer/count still in bytes?
  SekCyclesBurnRun(PicoVideoFIFOWrite(2*len, FQ_BGDMA, // 2 slots each (rd+wr)
                              PVS_CPUWR, SR_DMA | PVS_DMABG));

  source =pvid->reg[0x15];
  source|=pvid->reg[0x16]<<8;

  for (; len; len--)
  {
    vr[(u16)a] = vr[(u16)(source++)];
    if (((a^SATaddr) & SATmask) == 0)
      UpdateSAT(a, ((u16 *)vr)[(u16)a >> 1]);
    // AutoIncrement
    a = (a+inc) & ~0x20000;
  }
  // remember addr
  pvid->addr = a;
  pvid->addr_u = a >> 16;
}

static NOINLINE void DmaFill(int data)
{
  struct PicoVideo *pvid=&Pico.video;
  u32 a = pvid->addr | (pvid->addr_u << 16), e;
  u8 *vr = (u8 *)PicoMem.vram;
  u8 high = (u8)(data >> 8);
  u8 inc = pvid->reg[0xf];
  int source;
  int len, l;

  len = GetDmaLength();
  elprintf(EL_VDPDMA, "DmaFill len %i inc %i [%u]", len, inc, SekCyclesDone());

  SekCyclesBurnRun(PicoVideoFIFOWrite(len, FQ_BGDMA, // 1 slot each (wr)
                              PVS_CPUWR | PVS_DMAFILL, SR_DMA | PVS_DMABG));

  switch (pvid->type)
  {
    case 1: // vram
      e = a + len-1;
      if (inc == 1 && !((a ^ e) >> 16) &&
          ((a >= SATaddr + 0x280) | (e < SATaddr)))
      {
        // most used DMA mode
        memset(vr + (u16)a, high, len);
        a += len;
        break;
      }
      for (l = len; l; l--) {
        // Write upper byte to adjacent address
        // (here we are byteswapped, so address is already 'adjacent')
        vr[(u16)a] = high;
        if (((a^SATaddr) & SATmask) == 0)
          UpdateSAT(a, ((u16 *)vr)[(u16)a >> 1]);

        // Increment address register
        a = (a+inc) & ~0x20000;
      }
      break;
    case 3:   // cram
      Pico.m.dirtyPal = 1;
      data &= 0xeee;
      for (l = len; l; l--) {
        PicoMem.cram[(a/2) & 0x3f] = data;

        // Increment address register
        a = (a+inc) & ~0x20000;
      }
      break;
    case 5: { // vsram
      data &= 0x7ff;
      for (l = len; l; l--) {
        PicoMem.vsram[(a/2) & 0x3f] = data;

        // Increment address register
        a = (a+inc) & ~0x20000;
      }
      break;
    }
    case 0x81: // vram 128k
      for (l = len; l; l--) {
        VideoWriteVRAM128(a, data);

        // Increment address register
        a = (a+inc) & ~0x20000;
      }
      break;
    default:
      a += len * inc;
      break;
  }

  // remember addr
  pvid->addr = a;
  pvid->addr_u = a >> 16;
  // register update
  pvid->reg[0x13] = pvid->reg[0x14] = 0;
  source  = pvid->reg[0x15];
  source |= pvid->reg[0x16] << 8;
  source += len;
  pvid->reg[0x15] = source;
  pvid->reg[0x16] = source >> 8;
}

// VDP command handling

static NOINLINE void CommandDma(void)
{
  struct PicoVideo *pvid = &Pico.video;
  u32 len, method;
  u32 source;

  PicoVideoFIFOSync(SekCyclesDone()-Pico.t.m68c_line_start);
  if (pvid->status & SR_DMA) {
    elprintf(EL_VDPDMA, "Dma overlap, left=%d @ %06x",
             VdpFIFO.fifo_total, SekPc);
    VdpFIFO.fifo_total = VdpFIFO.fifo_ql = 0;
    pvid->status &= ~PVS_DMAFILL;
  }

  len = GetDmaLength();
  source  = pvid->reg[0x15];
  source |= pvid->reg[0x16] << 8;
  source |= pvid->reg[0x17] << 16;

  method=pvid->reg[0x17]>>6;
  if (method < 2)
    DmaSlow(len, source << 1); // 68000 to VDP
  else if (method == 3)
    DmaCopy(len); // VRAM Copy
  else {
    pvid->status |= SR_DMA|PVS_DMAFILL;
    return;
  }
  source += len;
  pvid->reg[0x13] = pvid->reg[0x14] = 0;
  pvid->reg[0x15] = source;
  pvid->reg[0x16] = source >> 8;
}

static NOINLINE void CommandChange(struct PicoVideo *pvid)
{
  unsigned int cmd, addr;

  cmd = pvid->command;

  // Get type of transfer 0xc0000030 (v/c/vsram read/write)
  pvid->type = (u8)(((cmd >> 2) & 0xc) | (cmd >> 30));
  if (pvid->type == 1) // vram
    pvid->type |= pvid->reg[1] & 0x80; // 128k

  // Get address 0x3fff0003
  addr  = (cmd >> 16) & 0x3fff;
  addr |= (cmd << 14) & 0xc000;
  pvid->addr = (u16)addr;
  pvid->addr_u = (u8)((cmd >> 2) & 1);
}

// VDP interface
 
static inline int InHblank(int offs)
{
  // check if in left border (14 pixels) or HBLANK (86 pixels), 116 68k cycles
  return SekCyclesDone() - Pico.t.m68c_line_start <= offs;
}

void PicoVideoSync(int skip)
{
  struct VdpFIFO *vf = &VdpFIFO;
  int lines = Pico.video.reg[1]&0x08 ? 240 : 224;
  int last = Pico.m.scanline - (skip > 0);

  if (!(PicoIn.opt & POPT_ALT_RENDERER) && !PicoIn.skipFrame) {
    if (last >= lines)
      last = lines-1;
    else // in active display, need to sync next frame as well
      Pico.est.rendstatus |= PDRAW_SYNC_NEXT;

    //elprintf(EL_ANOMALY, "sync");
    if (unlikely(linedisabled >= 0 && linedisabled <= last)) {
      if (Pico.est.DrawScanline <= linedisabled) {
        int sl = vf->fifo_hcounts[lineoffset/clkdiv];
        PicoDrawSync(linedisabled, sl ? sl : 1, 0);
      }
      linedisabled = -1;
    }
    if (unlikely(lineenabled >= 0 && lineenabled <= last)) {
      if (Pico.est.DrawScanline <= lineenabled) {
        int sl = vf->fifo_hcounts[lineoffset/clkdiv];
        PicoDrawSync(lineenabled, 0, sl ? sl : 1);
      }
      lineenabled = -1;
    }
    if (Pico.est.DrawScanline <= last)
      PicoDrawSync(last, 0, 0);
  }
  if (skip >= 0)
    Pico.est.rendstatus |= PDRAW_SYNC_NEEDED;
}

PICO_INTERNAL_ASM void PicoVideoWrite(u32 a,unsigned short d)
{
  struct PicoVideo *pvid=&Pico.video;

  //elprintf(EL_STATUS, "PicoVideoWrite [%06x] %04x [%u] @ %06x",
  //  a, d, SekCyclesDone(), SekPc);

  a &= 0x1c;
  switch (a)
  {
  case 0x00: // Data port 0 or 2
    if (pvid->pending) {
      CommandChange(pvid);
      pvid->pending=0;
    }

    // try avoiding the sync if the data doesn't change.
    // Writes to the SAT in VRAM are special since they update the SAT cache.
    if ((pvid->reg[1]&0x40) &&
        !(pvid->type == 1 && !(pvid->addr&1) && ((pvid->addr^SATaddr)&SATmask) && PicoMem.vram[pvid->addr>>1] == d) &&
        !(pvid->type == 3 && PicoMem.cram[(pvid->addr>>1) & 0x3f] == (d & 0xeee)) &&
        !(pvid->type == 5 && PicoMem.vsram[(pvid->addr>>1) & 0x3f] == (d & 0x7ff)))
      // the vertical scroll value for this line must be read from VSRAM early,
      // since the A/B tile row to be read depends on it. E.g. Skitchin, OD2
      // in contrast, CRAM writes would have an immediate effect on the current
      // pixel, so sync can be closer to start of actual image data
      PicoVideoSync(InHblank(pvid->type == 3 ? 103 : 30)); // cram in Toy Story

    if (!(PicoIn.opt&POPT_DIS_VDP_FIFO))
    {
      VdpFIFO.fifo_data[++VdpFIFO.fifo_dx&3] = d;
      SekCyclesBurnRun(PicoVideoFIFOWrite(1, pvid->type == 1, 0, PVS_CPUWR));

      elprintf(EL_ASVDP, "VDP data write: [%04x] %04x [%u] {%i} @ %06x",
        pvid->addr, d, SekCyclesDone(), pvid->type, SekPc);
    }
    VideoWrite(d);

    // start DMA fill on write. NB VSRAM and CRAM fills use wrong FIFO data.
    if (pvid->status & PVS_DMAFILL)
      DmaFill(VdpFIFO.fifo_data[(VdpFIFO.fifo_dx + !!(pvid->type&~0x81))&3]);

    break;

  case 0x04: // Control (command) port 4 or 6
    if (pvid->status & SR_DMA)
      SekCyclesBurnRun(PicoVideoFIFORead()); // kludge, flush out running DMA
    if (pvid->pending)
    {
      // Low word of command:
      if (!(pvid->reg[1]&0x10))
        d = (d&~0x80)|(pvid->command&0x80);
      pvid->command &= 0xffff0000;
      pvid->command |= d;
      pvid->pending = 0;
      CommandChange(pvid);
      // Check for dma:
      if (d & 0x80) {
        PicoVideoSync(InHblank(93));
        CommandDma();
      }
    }
    else
    {
      if ((d&0xc000)==0x8000)
      {
        // Register write:
        int num=(d>>8)&0x1f;
        int dold=pvid->reg[num];
        pvid->type=0; // register writes clear command (else no Sega logo in Golden Axe II)
        if (num > 0x0a && !(pvid->reg[1]&4)) {
          elprintf(EL_ANOMALY, "%02x written to reg %02x in SMS mode @ %06x", d, num, SekPc);
          return;
        }

        d &= 0xff;

        if (num == 1 && ((pvid->reg[1]^d)&0x40)) {
          // handle line blanking before line rendering. Only the last switch
          // before the 1st sync for other reasons is honoured. Switching after
          // active area is on next line
          int skip = InHblank(470); // Deadly Moves
          PicoVideoSync(skip);
          lineenabled = (d&0x40) ? Pico.m.scanline + !skip: -1;
          linedisabled = (d&0x40) ? -1 : Pico.m.scanline + !skip;
          lineoffset = (skip ? SekCyclesDone() - Pico.t.m68c_line_start : 0);
        } else if (((1<<num) & 0x738ff) && pvid->reg[num] != d)
          // VDP regs 0-7,11-13,16-18 influence rendering, ignore all others
          PicoVideoSync(InHblank(93)); // Toy Story
        pvid->reg[num] = d;

        switch (num)
        {
          case 0x00:
            if ((~dold&d)&2) {
              unsigned c = SekCyclesDone() - Pico.t.m68c_line_start;
              pvid->hv_latch = VdpFIFO.fifo_hcounts[c/clkdiv] | (pvid->v_counter << 8);
            }
            elprintf(EL_INTSW, "hint_onoff: %i->%i [%u] pend=%i @ %06x", (dold&0x10)>>4,
                    (d&0x10)>>4, SekCyclesDone(), (pvid->pending_ints&0x10)>>4, SekPc);
            goto update_irq;
          case 0x01:
            if ((d^dold)&0x40)
              PicoVideoFIFOMode(d & 0x40, pvid->reg[12]&1);
            if (!(pvid->status & PVS_VB2))
              pvid->status &= ~SR_VB;
            pvid->status |= ((d >> 3) ^ SR_VB) & SR_VB; // forced blanking
            elprintf(EL_INTSW, "vint_onoff: %i->%i [%u] pend=%i @ %06x", (dold&0x20)>>5,
                    (d&0x20)>>5, SekCyclesDone(), (pvid->pending_ints&0x20)>>5, SekPc);
            goto update_irq;
          case 0x05:
          case 0x06:
            if (d^dold) Pico.est.rendstatus |= PDRAW_DIRTY_SPRITES;
            break;
          case 0x0c:
            // renderers should update their palettes if sh/hi mode is changed
            if ((d^dold)&8) Pico.m.dirtyPal = 1;
            if ((d^dold)&1) {
              PicoVideoFIFOMode(pvid->reg[1]&0x40, d & 1);
              Pico.est.rendstatus |= PDRAW_DIRTY_SPRITES;
            }
            break;
          default:
            return;
        }
        if (Pico.est.rendstatus & PDRAW_DIRTY_SPRITES) {
          SATaddr = ((pvid->reg[5]&0x7f) << 9) | ((pvid->reg[6]&0x20) << 11);
          SATmask = ~0x1ff;
          if (pvid->reg[12]&1)
            SATaddr &= ~0x200, SATmask &= ~0x200; // H40, zero lowest SAT bit
          //elprintf(EL_STATUS, "spritep moved to %04x", SATaddr);
        }
        return;

update_irq:
#ifndef EMU_CORE_DEBUG
        // update IRQ level; TODO hack, still fire irq if disabling now
        if (!SekShouldInterrupt() || SekIrqLevel < pvid->hint_irq)
        {
          int lines, pints, irq = 0;
          lines = (pvid->reg[1] & 0x20) | (pvid->reg[0] & 0x10);
          pints = pvid->pending_ints & lines;
               if (pints & 0x20) irq = 6;
          else if (pints & 0x10) irq = pvid->hint_irq;

          if (irq) {
            // VDP irqs have highest prio, just overwrite old level
            SekInterrupt(irq); // update line

            // TODO this is broken because cost of current insn isn't known here
            SekEndRun(21); // make it delayed
          } else if (SekIrqLevel >= pvid->hint_irq) {
            // no VDP irq, query lower irqs
            SekInterrupt(PicoIn.AHW & PAHW_PICO ? PicoPicoIrqAck(0) : 0);
          }
        }
#endif
      }
      else
      {
        // High word of command:
        pvid->command&=0x0000ffff;
        pvid->command|=d<<16;
        pvid->pending=1;
      }
    }
    break;

  // case 0x08: // 08 0a - HV counter - lock up
  // case 0x0c: // 0c 0e - HV counter - lock up
  // case 0x10: // 10 12 - PSG - handled by caller
  // case 0x14: // 14 16 - PSG - handled by caller
  // case 0x18: // 18 1a - no effect?
  case 0x1c: // 1c 1e - debug
    pvid->debug = d;
    pvid->debug_p = 0;
    if (d & (1 << 6)) {
      pvid->debug_p |= PVD_KILL_A | PVD_KILL_B;
      pvid->debug_p |= PVD_KILL_S_LO | PVD_KILL_S_HI;
    }
    switch ((d >> 7) & 3) {
      case 1:
        pvid->debug_p &= ~(PVD_KILL_S_LO | PVD_KILL_S_HI);
        pvid->debug_p |= PVD_FORCE_S;
        break;
      case 2:
        pvid->debug_p &= ~PVD_KILL_A;
        pvid->debug_p |= PVD_FORCE_A;
        break;
      case 3:
        pvid->debug_p &= ~PVD_KILL_B;
        pvid->debug_p |= PVD_FORCE_B;
        break;
    }
    break;
  }
}

static u32 VideoSr(const struct PicoVideo *pv)
{
  unsigned int hp = pv->reg[12]&1 ? hboff40*488.5/slots40 : hboff32*488.5/slots32;
  unsigned int hl = pv->reg[12]&1 ? hblen40*488.5/slots40 : hblen32*488.5/slots32;
  unsigned int c = SekCyclesDone() - Pico.t.m68c_line_start;
  u32 d;

  PicoVideoFIFOSync(c);
  d = (u16)pv->status;

  if (c - hp < hl)
    d |= SR_HB;

  if (VdpFIFO.fifo_total >= 4)
    d |= SR_FULL;
  else if (!VdpFIFO.fifo_total)
    d |= SR_EMPT;
  return d;
}

PICO_INTERNAL_ASM u32 PicoVideoRead(u32 a)
{
  struct PicoVideo *pv = &Pico.video;
  a &= 0x1c;

  if (a == 0x04) // control port
  {
    u32 d = VideoSr(pv);
    if (pv->pending) {
      CommandChange(pv);
      pv->pending = 0;
    }
    elprintf(EL_SR, "SR read: %04x [%u] @ %06x", d, SekCyclesDone(), SekPc);
    return d;
  }

  if (a == 0x08)
  {
    unsigned int c;
    u32 d;

    c = SekCyclesDone() - Pico.t.m68c_line_start;
    if (pv->reg[0]&2)
         d = pv->hv_latch;
    else d = VdpFIFO.fifo_hcounts[c/clkdiv] | (pv->v_counter << 8);

    elprintf(EL_HVCNT, "hv: %02x %02x [%u] @ %06x", d, pv->v_counter, SekCyclesDone(), SekPc);
    return d;
  }

  if (a==0x00) // data port
  {
    return VideoRead(0);
  }

  return PicoRead16_floating(a | 0xc00000);
}

unsigned char PicoVideoRead8DataH(int is_from_z80)
{
  return VideoRead(is_from_z80) >> 8;
}

unsigned char PicoVideoRead8DataL(int is_from_z80)
{
  return VideoRead(is_from_z80);
}

unsigned char PicoVideoRead8CtlH(int is_from_z80)
{
  struct PicoVideo *pv = &Pico.video;
  u8 d = VideoSr(pv) >> 8;
  if (pv->pending) {
    CommandChange(pv);
    pv->pending = 0;
  }
  elprintf(EL_SR, "SR read (h): %02x @ %06x", d, SekPc);
  return d;
}

unsigned char PicoVideoRead8CtlL(int is_from_z80)
{
  struct PicoVideo *pv = &Pico.video;
  u8 d = VideoSr(pv);
  if (pv->pending) {
    CommandChange(pv);
    pv->pending = 0;
  }
  elprintf(EL_SR, "SR read (l): %02x @ %06x", d, SekPc);
  return d;
}

unsigned char PicoVideoRead8HV_H(int is_from_z80)
{
  u32 d = Pico.video.v_counter;
  if (Pico.video.reg[0]&2)
    d = Pico.video.hv_latch >> 8;
  elprintf(EL_HVCNT, "vcounter: %02x [%u] @ %06x", d, SekCyclesDone(), SekPc);
  return d;
}

// FIXME: broken
unsigned char PicoVideoRead8HV_L(int is_from_z80)
{
  u32 d = SekCyclesDone() - Pico.t.m68c_line_start;
  if (Pico.video.reg[0]&2)
       d = Pico.video.hv_latch;
  else d = VdpFIFO.fifo_hcounts[d/clkdiv];
  elprintf(EL_HVCNT, "hcounter: %02x [%u] @ %06x", d, SekCyclesDone(), SekPc);
  return d;
}

void PicoVideoReset(void)
{
  Pico.video.pending_ints=0;
  Pico.video.reg[1] &= ~0x40; // TODO verify display disabled after reset
  Pico.video.reg[10] = 0xff; // HINT is turned off after reset
  Pico.video.status = 0x3428 | Pico.m.pal; // 'always set' bits | vblank | collision | pal

  memset(&VdpFIFO, 0, sizeof(VdpFIFO));
  Pico.m.dirtyPal = 1;

  PicoDrawBgcDMA(NULL, 0, 0, 0, 0);
  PicoVideoFIFOMode(Pico.video.reg[1]&0x40, Pico.video.reg[12]&1);
}

void PicoVideoCacheSAT(int load)
{
  struct PicoVideo *pv = &Pico.video;
  int l;

  SATaddr = ((pv->reg[5]&0x7f) << 9) | ((pv->reg[6]&0x20) << 11);
  SATmask = ~0x1ff;
  if (pv->reg[12]&1)
    SATaddr &= ~0x200, SATmask &= ~0x200; // H40, zero lowest SAT bit

  // rebuild SAT cache XXX wrong since cache and memory can differ
  for (l = 0; load && l < 2*80; l ++) {
    u16 addr = SATaddr + l*4;
    ((u16 *)VdpSATCache)[l*2    ] = PicoMem.vram[(addr>>1)    ];
    ((u16 *)VdpSATCache)[l*2 + 1] = PicoMem.vram[(addr>>1) + 1];
  }

  Pico.est.rendstatus |= PDRAW_DIRTY_SPRITES;
}

void PicoVideoSave(void)
{
  struct VdpFIFO *vf = &VdpFIFO;
  struct PicoVideo *pv = &Pico.video;
  int l, x;

  // account for all outstanding xfers XXX kludge, entry attr's not saved
  pv->fifo_cnt = pv->fifo_bgcnt = 0;
  for (l = vf->fifo_ql, x = vf->fifo_qx + l-1; l > 0; l--, x--) {
    int cnt = (vf->fifo_queue[x&7] >> 3);
    if (vf->fifo_queue[x&7] & FQ_BGDMA)
      pv->fifo_bgcnt += cnt;
    else
      pv->fifo_cnt += cnt;
  }
}

void PicoVideoLoad(void)
{
  struct VdpFIFO *vf = &VdpFIFO;
  struct PicoVideo *pv = &Pico.video;
  int b = pv->type == 1;

  // convert former dma_xfers (why was this in PicoMisc anyway?)
  if (Pico.m.dma_xfers) {
    pv->fifo_cnt = Pico.m.dma_xfers << b;
    Pico.m.dma_xfers = 0;
  }

  // fake entries in the FIFO if there are outstanding transfers
  vf->fifo_ql = vf->fifo_qx = vf->fifo_total = 0;
  if (pv->fifo_cnt) {
    int wc = pv->fifo_cnt;
    vf->fifo_total = (wc+b) >> b;
    vf->fifo_queue[vf->fifo_qx + vf->fifo_ql] = (wc << 3) | b | FQ_FGDMA;
    vf->fifo_ql ++;
    if (vf->fifo_total > 4 && !(pv->status & (PVS_CPUWR|PVS_CPURD)))
      pv->status |= PVS_CPUWR;
  }
  if (pv->fifo_bgcnt) {
    int wc = pv->fifo_bgcnt;
    if (!vf->fifo_ql)
      pv->status |= PVS_DMABG;
    vf->fifo_queue[vf->fifo_qx + vf->fifo_ql] = (wc << 3)     | FQ_BGDMA;
    vf->fifo_ql ++;
  }
  PicoVideoCacheSAT(1);
  vf->fifo_maxslot = 0;
}
// vim:shiftwidth=2:ts=2:expandtab
