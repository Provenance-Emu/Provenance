static uint32 PPU_UpdateLineIRQ(uint32 timestamp) MDFN_HOT;
static uint32 PPU_Update(uint32 timestamp) MDFN_HOT;

static DEFWRITE(Write_ScreenMode)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 ScreenMode = V;
 //
 PPU_MTRENDER::MTIF_Write(A, V);
}

static DEFWRITE(Write_2100)
{
 CPUM.timestamp += MEMCYC_FAST;

 if((INIDisp ^ V) & 0x80 & ~V)
  OAM_Addr = (OAMADDL | ((OAMADDH & 0x1) << 8)) << 1;

 INIDisp = V;

 //printf("INIDisp = %02x --- scanline=%u\n", V, scanline);
 //
 PPU_MTRENDER::MTIF_Write(A, V);
}

static DEFWRITE(Write_OBSEL)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 OBSEL = V;
 //
 PPU_MTRENDER::MTIF_Write(A, V);
}

static DEFWRITE(Write_OAMADDL)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 OAMADDL = V;
 OAM_Addr = (OAMADDL | ((OAMADDH & 0x1) << 8)) << 1;
 //
 PPU_MTRENDER::MTIF_Write(A, V);
}

static DEFWRITE(Write_OAMADDH)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 OAMADDH = V;
 OAM_Addr = (OAMADDL | ((OAMADDH & 0x1) << 8)) << 1;
 //
 PPU_MTRENDER::MTIF_Write(A, V);
}

static DEFWRITE(Write_OAMDATA)
{
 CPUM.timestamp += MEMCYC_FAST;

 //fprintf(stderr, "OAMDATA Write: 0x%04x 0x%02x, %d %d\n", OAM_Addr, V, scanline, (CPUM.timestamp - LineStartTS) >> 2);
 //
 // Uniracers test fix
 if(MDFN_UNLIKELY(scanline == 112) && MDFN_UNLIKELY(!(INIDisp & 0x80)))
 {
  OAMHI[0x18] = V;
  //
  PPU_MTRENDER::MTIF_Write(0x3F, V);	// HAX
  return;
 }

 if(OAM_Addr & 0x200)
  OAMHI[OAM_Addr & 0x1F] = V;
 else if(OAM_Addr & 1)
 {
  OAM[(size_t)OAM_Addr - 1] = OAM_Buffer;
  OAM[(size_t)OAM_Addr + 0] = V;
 }

 if(!(OAM_Addr & 1))
  OAM_Buffer = V;

 OAM_Addr = (OAM_Addr + 1) & 0x3FF;
 //
 PPU_MTRENDER::MTIF_Write(A, V);
}

static DEFREAD(Read_PPU1_BL)
{
 if(MDFN_UNLIKELY(DBG_InHLRead))
 {
  return BusLatch[0];
 }

 CPUM.timestamp += MEMCYC_FAST;
 //
 return BusLatch[0];
}

// PPU1
static DEFREAD(Read_OAMDATAREAD)
{
 if(MDFN_UNLIKELY(DBG_InHLRead))
 {
  return (OAM_Addr & 0x200) ? OAMHI[OAM_Addr & 0x1F] : OAM[OAM_Addr];
 }

 CPUM.timestamp += MEMCYC_FAST;
 //
 if(OAM_Addr & 0x200)
  BusLatch[0] = OAMHI[OAM_Addr & 0x1F];
 else
  BusLatch[0] = OAM[OAM_Addr];

 OAM_Addr = (OAM_Addr + 1) & 0x3FF;

 PPU_MTRENDER::MTIF_Read(A);

 return BusLatch[0];
}

static DEFWRITE(Write_2105)
{
 CPUM.timestamp += MEMCYC_FAST;

 BGMode = V;
 //
 PPU_MTRENDER::MTIF_Write(A, V);
}

static DEFWRITE(Write_2106)
{
 CPUM.timestamp += MEMCYC_FAST;

 if((Mosaic ^ V) & 0xF0)
  MosaicYOffset = 0;

 Mosaic = V;
 //
 PPU_MTRENDER::MTIF_Write(A, V);
}

static DEFWRITE(Write_BGSC)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 BGSC[(size_t)(uint8)A - 0x07] = V;
 //
 PPU_MTRENDER::MTIF_Write(A, V);
}

static DEFWRITE(Write_BGNBA)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 BGNBA[(size_t)(uint8)A - 0x0B] = V;
 //
 PPU_MTRENDER::MTIF_Write(A, V);
}

template<bool bg0>
static DEFWRITE(Write_BGHOFS)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 //printf("BG%dHOFS Write; Prev=0x%02x, V=0x%02x, InHDMA=0x%08x, scanline=%u\n", 1 + ((uint8)A >> 1) - (0x0D >> 1), BGOFSPrev, V, InHDMA, scanline);
 //
 uint16* const t = &BGHOFS[((size_t)(uint8)A >> 1) - (0x0D >> 1)];
 *t = BGOFSPrev | ((V & 0x3) << 8);
 BGOFSPrev = V;

 if(bg0)
 {
  //printf("M7HOFS: %u, %02x\n", scanline, V);
  M7HOFS = sign_13_to_s16(M7Prev | ((V & 0x1F) << 8));
  M7Prev = V;
 }
 //
 PPU_MTRENDER::MTIF_Write(A, V);
}

template<bool bg0>
static DEFWRITE(Write_BGVOFS)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 //printf("BG%dVOFS Write; Prev=0x%02x, V=0x%02x, InHDMA=0x%08x, scanline=%u\n", 1 + ((uint8)A >> 1) - (0x0E >> 1), BGOFSPrev, V, InHDMA, scanline);
 //
 BGVOFS[((size_t)(uint8)A >> 1) - (0x0E >> 1)] = BGOFSPrev | ((V & 0x3) << 8);
 BGOFSPrev = V;

 if(bg0)
 {
  //printf("M7VOFS: %u, %02x\n", scanline, V);
  M7VOFS = sign_13_to_s16(M7Prev | ((V & 0x1F) << 8));
  M7Prev = V;
 }
 //
 PPU_MTRENDER::MTIF_Write(A, V);
}

static MDFN_HOT uint16 GetVAddr(void)
{
 return (VRAM_Addr & VMAIN_AddrTransMaskA) | ((VRAM_Addr >> VMAIN_AddrTransShiftB) & 0x7) | ((VRAM_Addr << 3) & VMAIN_AddrTransMaskC);
}

static DEFWRITE(Write_2115)
{
 static const uint8 inctab[4] = { 1, 32, 128, 128 };
 static const uint32 ttab[4][3] =
 {
  { 0x7FFF, 0, 0 },
  { 0x7F00, 5, 0x0F8 },
  { 0x7E00, 6, 0x1F8 },
  { 0x7C00, 7, 0x3F8 },
 };
 CPUM.timestamp += MEMCYC_FAST;


 VMAIN_IncMode = V & 0x80;
 VMAIN_AddrInc = inctab[V & 0x3];

 VMAIN_AddrTransMaskA = ttab[(V >> 2) & 0x3][0];
 VMAIN_AddrTransShiftB = ttab[(V >> 2) & 0x3][1];
 VMAIN_AddrTransMaskC = ttab[(V >> 2) & 0x3][2];
 //
 PPU_MTRENDER::MTIF_Write(A, V);
}

static DEFWRITE(Write_2116)
{
 CPUM.timestamp += MEMCYC_FAST;

 VRAM_Addr &= 0xFF00;
 VRAM_Addr |= V << 0;

 VRAM_ReadBuffer = VRAM[GetVAddr()];
 //
 PPU_MTRENDER::MTIF_Write(A, V);
}

static DEFWRITE(Write_2117)
{
 CPUM.timestamp += MEMCYC_FAST;

 VRAM_Addr &= 0x00FF;
 VRAM_Addr |= V << 8;

 VRAM_ReadBuffer = VRAM[GetVAddr()];
 //
 PPU_MTRENDER::MTIF_Write(A, V);
}

static DEFWRITE(Write_2118)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 // TODO: Block all VRAM writes during active display, not just those from HDMA(just doing the latter
 // for now in case small timing errors might break legitimate write attempts).
 if(MDFN_UNLIKELY(InHDMA != 0x80000000U && !(INIDisp & 0x80)))
  return;
 //
 //
 const unsigned va = GetVAddr();

 //if(va >= 0x2000 && va < 0x3000)
 // fprintf(stderr, "Low: %04x %04x, %02x\n", va, VRAM_Addr, V);

 VRAM[va] &= 0xFF00;
 VRAM[va] |= V << 0;

 if(!VMAIN_IncMode)
  VRAM_Addr += VMAIN_AddrInc;
 //
 PPU_MTRENDER::MTIF_Write(A, V);
}

static DEFWRITE(Write_2119)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 // TODO: Block all VRAM writes during active display, not just those from HDMA(just doing the latter
 // for now in case small timing errors might break legitimate write attempts).
 if(MDFN_UNLIKELY(InHDMA != 0x80000000U && !(INIDisp & 0x80)))
  return;
 //
 //
 const unsigned va = GetVAddr();

 //if(va >= 0x2000 && va < 0x3000)
 // fprintf(stderr, "High: %04x %04x, %02x\n", va, VRAM_Addr, V);

 VRAM[va] &= 0x00FF;
 VRAM[va] |= V << 8;

 if(VMAIN_IncMode)
  VRAM_Addr += VMAIN_AddrInc;
 //
 PPU_MTRENDER::MTIF_Write(A, V);
}

// PPU1
static DEFREAD(Read_2139)
{
 if(MDFN_UNLIKELY(DBG_InHLRead))
 {
  return VRAM_ReadBuffer;
 }

 CPUM.timestamp += MEMCYC_FAST;
 //
 BusLatch[0] = VRAM_ReadBuffer;

 if(!VMAIN_IncMode)
 {
  VRAM_ReadBuffer = VRAM[GetVAddr()];
  VRAM_Addr += VMAIN_AddrInc;

  PPU_MTRENDER::MTIF_Read(A);	// Don't move outside this if() block
 }

 return BusLatch[0];
}

// PPU1
static DEFREAD(Read_213A)
{
 if(MDFN_UNLIKELY(DBG_InHLRead))
 {
  return VRAM_ReadBuffer >> 8;
 }

 CPUM.timestamp += MEMCYC_FAST;
 //
 BusLatch[0] = VRAM_ReadBuffer >> 8;

 if(VMAIN_IncMode)
 {
  VRAM_ReadBuffer = VRAM[GetVAddr()];
  VRAM_Addr += VMAIN_AddrInc;

  PPU_MTRENDER::MTIF_Read(A);	// Don't move outside this if() block
 }

 return BusLatch[0];
}

static DEFWRITE(Write_211A)
{
 CPUM.timestamp += MEMCYC_FAST;
 //

 M7SEL = V & 0xC3;
 //
 PPU_MTRENDER::MTIF_Write(A, V);
}

static DEFWRITE(Write_M7Matrix)		// $1b-$1e
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 M7Matrix[(size_t)(uint8)A - 0x1B] = M7Prev | (V << 8);
 M7Prev = V;
 //
 PPU_MTRENDER::MTIF_Write(A, V);
}

// PPU1
template<unsigned shift>
static DEFREAD(Read_M7Multiplier)
{
 if(MDFN_UNLIKELY(DBG_InHLRead))
 {
  return (uint32)((int16)M7Matrix[0] * (int8)(M7Matrix[1] >> 8)) >> shift;
 }

 CPUM.timestamp += MEMCYC_FAST;
 //
 BusLatch[0] = (uint32)((int16)M7Matrix[0] * (int8)(M7Matrix[1] >> 8)) >> shift;

 return BusLatch[0];
}

static DEFWRITE(Write_M7Center)
{
 CPUM.timestamp += MEMCYC_FAST;
 //

 M7Center[(size_t)(uint8)A - 0x1F] = sign_13_to_s16(M7Prev | ((V & 0x1F) << 8));
 M7Prev = V;
 //
 PPU_MTRENDER::MTIF_Write(A, V);
}

static DEFWRITE(Write_CGADD)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 CGRAM_Addr = V;
 CGRAM_Toggle = false;
 //
 PPU_MTRENDER::MTIF_Write(A, V);
}

static DEFWRITE(Write_CGDATA)
{
 CPUM.timestamp += MEMCYC_FAST;

 //
 if(CGRAM_Toggle)
 {
  CGRAM[CGRAM_Addr] = ((V & 0x7F) << 8) | CGRAM_Buffer;
  CGRAM_Addr++;
 }
 else
  CGRAM_Buffer = V;

 CGRAM_Toggle = !CGRAM_Toggle;
 //
 PPU_MTRENDER::MTIF_Write(A, V);
}

// PPU2
static DEFREAD(Read_CGDATAREAD)
{
 if(MDFN_UNLIKELY(DBG_InHLRead))
 {
  return CGRAM_Toggle ? ((BusLatch[1] & 0x80) | (CGRAM[CGRAM_Addr] >> 8)) : (CGRAM[CGRAM_Addr] >> 0);
 }

 CPUM.timestamp += MEMCYC_FAST;
 //
 if(CGRAM_Toggle)
 {
  BusLatch[1] = (BusLatch[1] & 0x80) | (CGRAM[CGRAM_Addr] >> 8);
  CGRAM_Addr++;
 }
 else
  BusLatch[1] = CGRAM[CGRAM_Addr] >> 0;

 CGRAM_Toggle = !CGRAM_Toggle;

 return BusLatch[1];
}

static DEFWRITE(Write_MSEnable)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 MSEnable = V & 0x1F;
 //
 PPU_MTRENDER::MTIF_Write(A, V);
}

static DEFWRITE(Write_SSEnable)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 SSEnable = V & 0x1F;
 //
 PPU_MTRENDER::MTIF_Write(A, V);
}

static DEFWRITE(Write_WMMainEnable)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 WMMainEnable = V;
 //
 PPU_MTRENDER::MTIF_Write(A, V);
}

static DEFWRITE(Write_WMSubEnable)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 WMSubEnable = V;
 //
 PPU_MTRENDER::MTIF_Write(A, V);
}

template<bool msb>
static DEFWRITE(Write_WMLogic)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 if(msb)
  WMLogic = (WMLogic & 0x00FF) | ((V & 0xF) << 8);
 else
  WMLogic = (WMLogic & 0xFF00) | (V << 0);
 //
 PPU_MTRENDER::MTIF_Write(A, V);
}

static DEFWRITE(Write_WMSettings)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 WMSettings[(size_t)(uint8)A - 0x23] = V;
 //
 PPU_MTRENDER::MTIF_Write(A, V);
}


static DEFWRITE(Write_WindowPos)	// $26-$29
{
 CPUM.timestamp += MEMCYC_FAST;
 //

 ((uint8*)WindowPos)[(size_t)(uint8)A - 0x26] = V;

 //printf("%04x %02x\n", A, V);
 //
 PPU_MTRENDER::MTIF_Write(A, V);
}


static DEFWRITE(Write_CGWSEL)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 CGWSEL = V;
 //
 PPU_MTRENDER::MTIF_Write(A, V);
}

static DEFWRITE(Write_CGADSUB)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 CGADSUB = V;
 //
 PPU_MTRENDER::MTIF_Write(A, V);
}

static DEFWRITE(Write_COLDATA)
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 unsigned cc = V & 0x1F;

 if(V & 0x20)
  FixedColor = (FixedColor &~ (0x1F <<  0)) | (cc <<  0);

 if(V & 0x40)
  FixedColor = (FixedColor &~ (0x1F <<  5)) | (cc <<  5);

 if(V & 0x80)
  FixedColor = (FixedColor &~ (0x1F << 10)) | (cc << 10);
 //
 PPU_MTRENDER::MTIF_Write(A, V);
}

static DEFREAD(Read_HVLatchTrigger)
{
 if(MDFN_UNLIKELY(DBG_InHLRead))
 {
  return CPUM.mdr;
 }

 CPUM.timestamp += MEMCYC_FAST;
 //

 //printf("Read HVLatchTrigger\n");

 if(1)
 {
  // Maximum horribleness.
  //PPU_Update(CPUM.timestamp);

  HLatch = (uint32)(CPUM.timestamp - LineStartTS) >> 2;
  VLatch = scanline;

  if(HLatch >= 340)
  {
   if(HLatch == 340)
    HLatch = 339;
   else
   {
    HLatch -= 341;
    VLatch = (VLatch + 1) % (LinesPerFrame + ((~Status[1] >> 7) & ScreenMode & 1));	// FIXME
   }
  }

  //printf("VL: %d, HL: %d\n", VLatch, HLatch);

  Status[1] |= 0x40;
 }

 return CPUM.mdr;
}

// PPU2
static DEFREAD(Read_HLatch)
{
 if(MDFN_UNLIKELY(DBG_InHLRead))
 {
  return (HLatch | ((BusLatch[1] & 0xFE) << 8)) >> HLatchReadShift;
 }

 CPUM.timestamp += MEMCYC_FAST;
 //
 BusLatch[1] = (HLatch | ((BusLatch[1] & 0xFE) << 8)) >> HLatchReadShift;

 HLatchReadShift ^= 8;

 return BusLatch[1];
}

// PPU2
static DEFREAD(Read_VLatch)
{
 if(MDFN_UNLIKELY(DBG_InHLRead))
 {
  return (VLatch | ((BusLatch[1] & 0xFE) << 8)) >> VLatchReadShift;
 }

 CPUM.timestamp += MEMCYC_FAST;
 //
 BusLatch[1] = (VLatch | ((BusLatch[1] & 0xFE) << 8)) >> VLatchReadShift;

 VLatchReadShift ^= 8;

 return BusLatch[1];
}

// PPU1
static DEFREAD(Read_PPU1_Status)
{
 if(MDFN_UNLIKELY(DBG_InHLRead))
 {
  return (BusLatch[0] & 0x10) | Status[0];
 }

 CPUM.timestamp += MEMCYC_FAST;
 //
 BusLatch[0] = (BusLatch[0] & 0x10) | Status[0];

 return BusLatch[0];
}

// PPU2
static DEFREAD(Read_PPU2_Status)
{
 if(MDFN_UNLIKELY(DBG_InHLRead))
 {
  return (BusLatch[1] & 0x20) | Status[1];
 }

 CPUM.timestamp += MEMCYC_FAST;
 //
 BusLatch[1] = (BusLatch[1] & 0x20) | Status[1];

 if(1)
  Status[1] &= ~0x40;

 HLatchReadShift = 0;
 VLatchReadShift = 0;

 return BusLatch[1];
}

//
//
//
//
//
//
//
//
static DEFWRITE(Write_NMITIMEEN)	// $4200
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 SNES_DBG("[SNES] Write NMITIMEEN: 0x%02x --- scanline=%u, %u\n", V, scanline, (CPUM.timestamp - LineStartTS) >> 2);

 if(NMITIMEEN != V)
 {
  // Mortal Kombat II kludge
  if(MDFN_UNLIKELY(CPUM.timestamp >= events[SNES_EVENT_PPU].event_time) && !CPUM.InDMABusAccess)
   CPUM.EventHandler();
  //
  NMITIMEEN = V;

  if(!(NMITIMEEN & 0x30))
   IRQFlag = 0x00;

  CPU_SetNMI(NMIFlag & NMITIMEEN & 0x80);
  CPU_SetIRQ(IRQFlag);

  SNES_SetEventNT(SNES_EVENT_PPU_LINEIRQ, PPU_UpdateLineIRQ((InHDMA != 0x80000000U) ? InHDMA : CPUM.timestamp));
 }
}

static DEFWRITE(Write_HTIME)	// $4207 and $4208
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 const unsigned shift = (~A & 1) << 3;
 const unsigned Old_HTime = HTime;

 HTime &= 0xFF00 >> shift;
 HTime |= V << shift;
 HTime &= 0x1FF;

 if(HTime != Old_HTime)
 {
  SNES_DBG("[SNES] HTIME Changed: new=0x%04x(old=0x%04x) --- scanline=%u, LineCounter=%u, LinePhase=%u -- %u\n", HTime, Old_HTime, scanline, LineCounter, LinePhase, (CPUM.timestamp - LineStartTS) >> 2);

  SNES_SetEventNT(SNES_EVENT_PPU_LINEIRQ, PPU_UpdateLineIRQ((InHDMA != 0x80000000U) ? InHDMA : CPUM.timestamp));
 }
}

static DEFWRITE(Write_VTIME)	// $4209 and $420A
{
 CPUM.timestamp += MEMCYC_FAST;
 //
 const unsigned shift = (~A & 1) << 3;
 const unsigned Old_VTime = VTime;

 VTime &= 0xFF00 >> shift;
 VTime |= V << shift;
 VTime &= 0x1FF;

 if(VTime != Old_VTime)
 {
  SNES_DBG("[SNES] VTIME Changed: new=0x%04x(old=0x%04x) --- HTIME=0x%04x, scanline=%u, LineCounter=%u, LinePhase=%u -- %u\n", VTime, Old_VTime, HTime, scanline, LineCounter, LinePhase, (CPUM.timestamp - LineStartTS) >> 2);

  SNES_SetEventNT(SNES_EVENT_PPU_LINEIRQ, PPU_UpdateLineIRQ((InHDMA != 0x80000000U) ? InHDMA : CPUM.timestamp));
 }
}

static DEFREAD(Read_4210)
{
 if(MDFN_UNLIKELY(DBG_InHLRead))
 {
  return NMIFlag | 0x01 | (CPUM.mdr & 0x70);
 }

 CPUM.timestamp += MEMCYC_FAST;
 //
 // Kludge of doooooom~
 if(MDFN_UNLIKELY(CPUM.timestamp >= events[SNES_EVENT_PPU].event_time) && !CPUM.InDMABusAccess)
  CPUM.EventHandler();
 //
 uint8 ret = NMIFlag | 0x01 | (CPUM.mdr & 0x70);

 NMIFlag = 0x00;
 CPU_SetNMI(false);

 return ret;
}

static DEFREAD(Read_4211)
{
 if(MDFN_UNLIKELY(DBG_InHLRead))
 {
  return IRQFlag | (CPUM.mdr & 0x7F);
 }

 CPUM.timestamp += MEMCYC_FAST;
 //
 uint8 ret = IRQFlag | (CPUM.mdr & 0x7F);

 //printf("Read: %04x\n", A);

 IRQFlag = 0x00;
 CPU_SetIRQ(false);

 return ret;
}

static DEFREAD(Read_4212)
{
 if(MDFN_UNLIKELY(DBG_InHLRead))
 {
  return HVBJOY;
 }

 CPUM.timestamp += MEMCYC_FAST;
 //
 return HVBJOY;
}

static DEFREAD(Read_4213)
{
 if(MDFN_UNLIKELY(DBG_InHLRead))
 {
  return 0;
 }

 CPUM.timestamp += MEMCYC_FAST;
 //
 SNES_DBG("[PPU] Read 4213\n");

 return 0;
}


//
//
//
//
//
//
//
//
//

/*
static uint32 PPU_UpdateLineIRQ(uint32 timestamp)
{
 uint32 ret = SNES_EVENT_MAXTS;
 bool NewIRQThing = false;

 if(NMITIMEEN & 0x30)
 {
  if((scanline == VTime) || !(NMITIMEEN & 0x20))
  {
   if(!(NMITIMEEN & 0x10))
    NewIRQThing = true;
   else if(HTime < 340)
   {
    const int32 td = (timestamp - LineStartTS) - (HTime << 2);

    if(td < 0)
     ret = timestamp - td;
    else if(td < 4)
    {
     NewIRQThing = true;
     ret = timestamp + 4;
    }
   }
  }
 }

 if(NewIRQThing && !IRQThing && !IRQFlag)
 {
  SNES_DBG("[SNES] IRQ: %d\n", scanline);
  IRQFlag = 0x80;
  CPU_SetIRQ(IRQFlag);
 }

 IRQThing = NewIRQThing;

 return ret;
}
*/

static uint32 PPU_UpdateLineIRQ(uint32 timestamp)
{
 uint32 ret = SNES_EVENT_MAXTS;
 bool NewIRQThing = false;

 if(NMITIMEEN & 0x30)
 {
  if((scanline == VTime) || !(NMITIMEEN & 0x20))
  {
   if(!(NMITIMEEN & 0x10))
    NewIRQThing = true;
   else if(HTime < 340)
   {
    const int32 td = (timestamp - LineStartTS) - (HTime << 2);

    if(td < 0)
     ret = timestamp - td;
    else if(td < 4)
    {
     NewIRQThing = true;
     ret = timestamp + 4;
    }
   }
  }
 }

 if(NewIRQThing && !IRQThing && !IRQFlag)
 {
  SNES_DBG("[SNES] IRQ: %d, %u\n", scanline, (timestamp - LineStartTS) >> 2);
  IRQFlag = 0x80;
  CPU_SetIRQ(IRQFlag);
 }

 IRQThing = NewIRQThing;

 return ret;
}

//
//
//
//
//
//
//
//
//

//
//
//
//
//
//
//
//
//

static const int RenderLineDelay = 512; //64;

static uint32 PPU_Update(uint32 timestamp)
{
 if(timestamp < lastts)
 {
  SNES_DBG("[PPU] timestamp goof: timestamp=%u, lastts=%u\n", timestamp, lastts);
  assert(timestamp >= lastts);
 }

 LineCounter -= (timestamp - lastts);

 if(LineCounter <= 0)
 {
  LinePhase = (LinePhase + 1) % 4;

  if(LinePhase == 0) // HBlank end
  {
   scanline = (scanline + 1) % (LinesPerFrame + ((~Status[1] >> 7) & ScreenMode & 1));
   //
   LineStartTS = timestamp;
   //
   //
   HVBJOY &= ~0x40;

   SNES_SetEventNT(SNES_EVENT_PPU_LINEIRQ, PPU_UpdateLineIRQ(timestamp));

   if(JPReadCounter > 0)
   {
    if(JPReadCounter == 3)
     INPUT_AutoRead();

    JPReadCounter--;
    if(!JPReadCounter)
     HVBJOY &= ~0x01;
   }

   //
   //

   if(scanline == 0)	// VBlank end
   {
    VBlank = false;
    Status[0] &= ~0xC0;	// Reset Time Over and Range Over flags.
    Status[1] ^= 0x80;
    InterlaceOnSample = ScreenMode & 0x1;
    //
    //
    //
    //
    //
    HVBJOY &= ~0x80;
    NMIFlag = 0x00;
    CPU_SetNMI(false);

    DMA_InitHDMA();
    //
    //
    //
    if(!FrameBeginVBlank)
    {
     CPUM.running_mask = 0;
    }
    //
    //
    //
    //printf("%02x, %d\n", ScreenMode, es->DisplayRect.y);
   }
/*
   else if(scanline == 1)
   {
    //CPUM.running_mask = 0;
   }
*/
   else if(!VBlank && scanline >= ((ScreenMode & 0x04) ? 0xF0 : 0xE1))
   {
    VBlank = true;

    PPU_MTRENDER::MTIF_EnterVBlank(PAL, SkipFrame);
    //
    //
    MDFNMP_ApplyPeriodicCheats();

    if(FrameBeginVBlank)
    {
     CPUM.running_mask = 0;
    }
    else
    {
     MDFN_MidSync(es, MIDSYNC_FLAG_UPDATE_INPUT);
     INPUT_UpdatePhysicalState();
    }
    //
    //
    //
    HVBJOY |= 0x80;
    NMIFlag = 0x80;

    SNES_DBG("NMI: %u %u\n", scanline, timestamp);

    CPU_SetNMI(NMIFlag & NMITIMEEN & 0x80);

    if(NMITIMEEN & 0x01)
    {
     JPReadCounter = 3;
     HVBJOY |= 0x01;
    }
    //
    //
    //
    if(!(INIDisp & 0x80))
     OAM_Addr = (OAMADDL | ((OAMADDH & 0x1) << 8)) << 1;
   }
   //
   LineCounter += RenderLineDelay;
  }
  else if(LinePhase == 1)
  {
   if(scanline == 1)
   {
    SkipFrame = ((bool)es->skip & !InterlaceOnSample) | (es->skip < 0);
    // FIXME: Should technically sample Status[1] earlier, in vblank?
    if(!SkipFrame)
     PPU_MTRENDER::MTIF_ResetLineTarget(PAL, InterlaceOnSample, (bool)(Status[1] & 0x80));
   }

   if(MDFN_LIKELY(!VBlank))
   {
    if(scanline > 0 && scanline < 240 && !SkipFrame)
    {
     PPU_MTRENDER::MTIF_RenderLine(scanline);
    }
   }

   LineCounter += 534 - RenderLineDelay;
  }
  else if(LinePhase == 2)
  {
   CPUM.timestamp += 40;
   LineCounter += 1096 - 534;
  }
  else if(LinePhase == 3)	// HBlank begin
  {
   //
   //
   HVBJOY |= 0x40;
   //
   //

   if(!VBlank)
   {
    InHDMA = timestamp;
    DMA_RunHDMA();
    InHDMA = 0x80000000U;
#ifndef MDFN_SNES_FAUST_SKETCHYPPUOPT
    FetchSpriteData(scanline);
#endif
    if(!SkipFrame)
     PPU_MTRENDER::MTIF_FetchSpriteData(scanline);
   }

   //
   LineCounter += 1364 - 1096;
  }
 }

 lastts = timestamp;

 return timestamp + LineCounter;
}

void PPU_ResetTS(void)
{
 LineStartTS -= lastts;
 lastts = 0;
}

void PPU_Init(const bool IsPAL, const bool IsPALPPUBit, const bool WantFrameBeginVBlank, const uint64 affinity)
{
 //MDFN_printf("%zu %u\n", sizeof(PPU), (unsigned)((unsigned char*)&PPU.VRAM - (unsigned char*)&PPU));
 //
 //
 //
 PPU_MTRENDER::MTIF_Init(affinity);
 //
 //
 //
 lastts = 0;
 LineStartTS = 0;

 PAL = IsPAL;
 FrameBeginVBlank = WantFrameBeginVBlank;
 LinesPerFrame = IsPAL ? 312 : 262;
 InHDMA = 0x80000000U;
 InterlaceOnSample = false;

 Set_B_Handlers(0x00, OBRead_FAST, Write_2100);

 Set_B_Handlers(0x01, OBRead_FAST, Write_OBSEL);
 Set_B_Handlers(0x02, OBRead_FAST, Write_OAMADDL);
 Set_B_Handlers(0x03, OBRead_FAST, Write_OAMADDH);
 Set_B_Handlers(0x04, Read_PPU1_BL, Write_OAMDATA);

 Set_B_Handlers(0x05, Read_PPU1_BL, Write_2105);
 Set_B_Handlers(0x06, Read_PPU1_BL, Write_2106);

 Set_B_Handlers(0x07, OBRead_FAST, Write_BGSC);
 Set_B_Handlers(0x08, Read_PPU1_BL, Write_BGSC);
 Set_B_Handlers(0x09, Read_PPU1_BL, Write_BGSC);
 Set_B_Handlers(0x0A, Read_PPU1_BL, Write_BGSC);

 Set_B_Handlers(0x0B, OBRead_FAST, Write_BGNBA);
 Set_B_Handlers(0x0C, OBRead_FAST, Write_BGNBA);

 Set_B_Handlers(0x0D, OBRead_FAST, Write_BGHOFS<true>);
 Set_B_Handlers(0x0F, OBRead_FAST, Write_BGHOFS<false>);
 Set_B_Handlers(0x11, OBRead_FAST, Write_BGHOFS<false>);
 Set_B_Handlers(0x13, OBRead_FAST, Write_BGHOFS<false>);

 Set_B_Handlers(0x0E, OBRead_FAST, Write_BGVOFS<true>);
 Set_B_Handlers(0x10, OBRead_FAST, Write_BGVOFS<false>);
 Set_B_Handlers(0x12, OBRead_FAST, Write_BGVOFS<false>);
 Set_B_Handlers(0x14, Read_PPU1_BL, Write_BGVOFS<false>);

 Set_B_Handlers(0x15, Read_PPU1_BL, Write_2115);
 Set_B_Handlers(0x16, Read_PPU1_BL, Write_2116);
 Set_B_Handlers(0x17, OBRead_FAST, Write_2117);
 Set_B_Handlers(0x18, Read_PPU1_BL, Write_2118);
 Set_B_Handlers(0x19, Read_PPU1_BL, Write_2119);

 Set_B_Handlers(0x1A, Read_PPU1_BL, Write_211A);
 Set_B_Handlers(0x1B, OBRead_FAST, Write_M7Matrix);
 Set_B_Handlers(0x1C, OBRead_FAST, Write_M7Matrix);
 Set_B_Handlers(0x1D, OBRead_FAST, Write_M7Matrix);
 Set_B_Handlers(0x1E, OBRead_FAST, Write_M7Matrix);

 Set_B_Handlers(0x1F, OBRead_FAST, Write_M7Center);
 Set_B_Handlers(0x20, OBRead_FAST, Write_M7Center);

 Set_B_Handlers(0x21, OBRead_FAST, Write_CGADD);
 Set_B_Handlers(0x22, OBRead_FAST, Write_CGDATA);

 Set_B_Handlers(0x23, OBRead_FAST, Write_WMSettings);
 Set_B_Handlers(0x24, Read_PPU1_BL, Write_WMSettings);
 Set_B_Handlers(0x25, Read_PPU1_BL, Write_WMSettings);

 Set_B_Handlers(0x26, Read_PPU1_BL, Write_WindowPos);
 Set_B_Handlers(0x27, OBRead_FAST, Write_WindowPos);
 Set_B_Handlers(0x28, Read_PPU1_BL, Write_WindowPos);
 Set_B_Handlers(0x29, Read_PPU1_BL, Write_WindowPos);
 Set_B_Handlers(0x2A, Read_PPU1_BL, Write_WMLogic<false>);
 Set_B_Handlers(0x2B, OBRead_FAST, Write_WMLogic<true>);

 Set_B_Handlers(0x2C, OBRead_FAST, Write_MSEnable);
 Set_B_Handlers(0x2D, OBRead_FAST, Write_SSEnable);

 Set_B_Handlers(0x2E, OBRead_FAST, Write_WMMainEnable);
 Set_B_Handlers(0x2F, OBRead_FAST, Write_WMSubEnable);

 Set_B_Handlers(0x30, OBRead_FAST, Write_CGWSEL);
 Set_B_Handlers(0x31, OBRead_FAST, Write_CGADSUB);

 Set_B_Handlers(0x32, OBRead_FAST, Write_COLDATA);

 Set_B_Handlers(0x33, OBRead_FAST, Write_ScreenMode);

 Set_B_Handlers(0x34, Read_M7Multiplier< 0>, OBWrite_FAST);
 Set_B_Handlers(0x35, Read_M7Multiplier< 8>, OBWrite_FAST);
 Set_B_Handlers(0x36, Read_M7Multiplier<16>, OBWrite_FAST);

 Set_B_Handlers(0x37, Read_HVLatchTrigger, OBWrite_FAST);

 Set_B_Handlers(0x38, Read_OAMDATAREAD, OBWrite_FAST);

 Set_B_Handlers(0x39, Read_2139, OBWrite_FAST);
 Set_B_Handlers(0x3A, Read_213A, OBWrite_FAST);

 Set_B_Handlers(0x3B, Read_CGDATAREAD, OBWrite_FAST);

 Set_B_Handlers(0x3C, Read_HLatch, OBWrite_FAST);
 Set_B_Handlers(0x3D, Read_VLatch, OBWrite_FAST);

 Set_B_Handlers(0x3E, Read_PPU1_Status, OBWrite_FAST);
 Set_B_Handlers(0x3F, Read_PPU2_Status, OBWrite_FAST);

 Status[0] = 1;
 Status[1] = (IsPALPPUBit << 4) | 2;

 //
 //
 //
 for(unsigned bank = 0x00; bank < 0x100; bank++)
 {
  if(bank <= 0x3F || (bank >= 0x80 && bank <= 0xBF))
  {
   Set_A_Handlers((bank << 16) | 0x4200, OBRead_FAST, Write_NMITIMEEN);
   Set_A_Handlers((bank << 16) | 0x4207, (bank << 16) | 0x4208, OBRead_FAST, Write_HTIME);
   Set_A_Handlers((bank << 16) | 0x4209, (bank << 16) | 0x420A, OBRead_FAST, Write_VTIME);

   Set_A_Handlers((bank << 16) | 0x4210, Read_4210, OBWrite_FAST);
   Set_A_Handlers((bank << 16) | 0x4211, Read_4211, OBWrite_FAST);
   Set_A_Handlers((bank << 16) | 0x4212, Read_4212, OBWrite_FAST);
   Set_A_Handlers((bank << 16) | 0x4213, Read_4213, OBWrite_FAST);
  }
 }
}

void PPU_SetGetVideoParams(MDFNGI* gi, const unsigned caspect, const unsigned hfilter, const unsigned sls, const unsigned sle)
{
 assert(sls < 239);
 assert(sle < 239);
 assert(sle >= sls);

 HFilter = hfilter;
 SLDRY = (PAL ? 0 : 8) + sls;
 SLDRH = sle + 1 - sls;
 //
 gi->fb_width = 512;
 gi->fb_height = 480;	// Don't change to less than 480

 gi->nominal_height = SLDRH;

 if(caspect == PPU_CASPECT_DISABLED)
  gi->nominal_width = 256;
 else if((caspect == PPU_CASPECT_ENABLED && !PAL) || caspect == PPU_CASPECT_FORCE_NTSC)
  gi->nominal_width = 292;
 else if((caspect == PPU_CASPECT_ENABLED && PAL) || caspect == PPU_CASPECT_FORCE_PAL)
  gi->nominal_width = 354;
 else
 {
  assert(0);
 }

 gi->fps = PAL ? 838977920 : 1008307711;

 gi->lcm_width = 512;
 gi->lcm_height = gi->nominal_height * 2;
 //
 //
 //
 MDFN_printf("CAspect: %u\n", caspect);
 MDFN_printf("HFilter: %u\n", hfilter);
 MDFN_printf("SLS,SLE: [%u,%u]\n", sls, sle);
 MDFN_printf("FPS: %f\n", gi->fps / (65536.0 * 256.0));
}

snes_event_handler PPU_GetEventHandler(void)
{
 return PPU_Update;
}

snes_event_handler PPU_GetLineIRQEventHandler(void)
{
 return PPU_UpdateLineIRQ;
}

void PPU_Kill(void)
{
 PPU_MTRENDER::MTIF_Kill();
}

static INLINE void Common_Reset(bool powering_up)
{
 IRQThing = false;

 HLatch = 0;
 VLatch = 0;
 HLatchReadShift = 0;
 VLatchReadShift = 0;

 BusLatch[0] = 0x00;
 BusLatch[1] = 0x00;

 Status[0] &= ~0xC0;
 Status[1] &= ~0xC0;

 //
 // Be careful:
 scanline = LinesPerFrame - 1;
 LinePhase = 3;
 LineCounter = 1;
 //
 //

 VBlank = false;

 if(powering_up)
  memset(VRAM, 0x00, sizeof(VRAM));

 ScreenMode = 0x00;
 INIDisp = 0x00;
 BGMode = 0x00;
 Mosaic = 0x00;
 MosaicYOffset = 0x00;

 memset(BGSC, 0x00, sizeof(BGSC));
 memset(BGNBA, 0x00, sizeof(BGNBA));

 BGOFSPrev = 0x00;
 memset(BGHOFS, 0x00, sizeof(BGHOFS));
 memset(BGVOFS, 0x00, sizeof(BGVOFS));

 VRAM_Addr = 0x0000;
 VRAM_ReadBuffer = 0x0000;

 VMAIN_IncMode = 0x00;
 VMAIN_AddrInc = 0;
 VMAIN_AddrTransMaskA = 0x7FFF;
 VMAIN_AddrTransShiftB = 0;
 VMAIN_AddrTransMaskC = 0x0000;


 M7Prev = 0x00;
 M7SEL = 0x00;
 memset(M7Matrix, 0x00, sizeof(M7Matrix));
 memset(M7Center, 0x00, sizeof(M7Center));
 M7HOFS = 0x0000;
 M7VOFS = 0x0000;

 CGRAM_Toggle = false;
 CGRAM_Buffer = 0x00;
 CGRAM_Addr = 0x00;
 if(powering_up)
  memset(CGRAM, 0x00, sizeof(CGRAM));

 MSEnable = 0x00;
 SSEnable = 0x00;

 memset(WMSettings, 0x00, sizeof(WMSettings));
 WMMainEnable = 0x00;
 WMSubEnable = 0x00;
 WMLogic = 0x0000;
 memset(WindowPos, 0x00, sizeof(WindowPos));

 CGWSEL = 0x00;
 CGADSUB = 0x00;
 FixedColor = 0x0000;

 OBSEL = 0x00;
 OAMADDL = 0x00;
 OAMADDH = 0x00;

 OAM_Buffer = 0x00;
 OAM_Addr = 0;
 if(powering_up)
 {
  memset(OAM, 0x00, sizeof(OAM));
  memset(OAMHI, 0x00, sizeof(OAMHI));
 }

 //
 //
 //
 if(powering_up)
 {
  HTime = 0x1FF;
  VTime = 0x1FF;
 }

 JPReadCounter = 0;
 HVBJOY = 0x00;
 NMIFlag = 0x00;
 IRQFlag = 0x00;
 NMITIMEEN = 0;
 CPU_SetNMI(false);
 CPU_SetIRQ(false);
}


void PPU_StartFrame(EmulateSpecStruct* espec)
{
 //printf("PPU_StartFrame, scanline=%d\n", scanline);
 es = espec;
 //
 //
 //
 es->InterlaceOn = false;
 es->DisplayRect.x = 0;
 es->DisplayRect.w = 256;
 es->DisplayRect.y = SLDRY;
 es->DisplayRect.h = SLDRH;
 //
 //
 PPU_MTRENDER::MTIF_StartFrame(espec, HFilter);
 //
 INPUT_UpdatePhysicalState();
}

static INLINE void Common_StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(LineStartTS),
  SFVAR(HLatch),
  SFVAR(VLatch),
  SFVAR(HLatchReadShift),
  SFVAR(VLatchReadShift),

  SFVAR(NMITIMEEN),

  SFVAR(IRQThing),
  SFVAR(HTime),
  SFVAR(VTime),

  SFVAR(HVBJOY),
  SFVAR(NMIFlag),
  SFVAR(IRQFlag),
  SFVAR(JPReadCounter),

  SFVAR(VBlank),
  SFVAR(LineCounter),
  SFVAR(LinePhase),
  SFVAR(scanline),

  SFVAR(BusLatch),
  SFVAR(Status),

  SFVAR(VRAM),

  SFVAR(ScreenMode),
  SFVAR(INIDisp),
  SFVAR(BGMode),
  SFVAR(Mosaic),
  SFVAR(MosaicYOffset),

  SFVAR(BGSC),

  SFVAR(BGNBA),

  SFVAR(BGOFSPrev),
  SFVAR(BGHOFS),
  SFVAR(BGVOFS),

  SFVAR(VRAM_Addr),
  SFVAR(VRAM_ReadBuffer),
  SFVAR(VMAIN_IncMode),
  SFVAR(VMAIN_AddrInc),
  SFVAR(VMAIN_AddrTransMaskA),
  SFVAR(VMAIN_AddrTransShiftB),
  SFVAR(VMAIN_AddrTransMaskC),

  SFVAR(M7Prev),
  SFVAR(M7SEL),
  SFVAR(M7Matrix),
  SFVAR(M7Center),
  SFVAR(M7HOFS),
  SFVAR(M7VOFS),

  SFVAR(CGRAM_Toggle),
  SFVAR(CGRAM_Buffer),
  SFVAR(CGRAM_Addr),
  SFVAR(CGRAM),

  SFVAR(MSEnable),
  SFVAR(SSEnable),

  SFVAR(WMSettings),
  SFVAR(WMMainEnable),
  SFVAR(WMSubEnable),
  SFVAR(WMLogic),
  SFVARN(WindowPos, "&WindowPos[0][0]"),

  SFVAR(CGWSEL),
  SFVAR(CGADSUB),
  SFVAR(FixedColor),

  SFVAR(OBSEL),
  SFVAR(OAMADDL),
  SFVAR(OAMADDH),
  SFVAR(OAM_Buffer),
  SFVAR(OAM_Addr),
  SFVAR(OAM),
  SFVAR(OAMHI),
  //
  //
  SFCONDVAR(!load || load >= 0x001023C1, InterlaceOnSample),
  //
  //
  SFEND
 };

 // TODO: Might want to save sprite fetch state when we add a debugger(for save states in step mode, which may occur outside of vblank).

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "PPU");

 if(load)
 {
  OAM_Addr &= 0x3FF;
  VMAIN_AddrTransMaskA &= 0x7FFF;
  VMAIN_AddrTransMaskC &= 0x7FFF;
 }
}

uint16 PPU_PeekVRAM(uint32 addr)
{
 return VRAM[addr & 0x7FFF];
}

uint16 PPU_PeekCGRAM(uint32 addr)
{
 return CGRAM[addr & 0xFF];
}

uint8 PPU_PeekOAM(uint32 addr)
{
 return OAM[addr & 0x1FF];
}

uint8 PPU_PeekOAMHI(uint32 addr)
{
 return OAMHI[addr & 0x1F];
}

uint32 PPU_GetRegister(const unsigned id, char* const special, const uint32 special_len)
{
 uint32 ret = 0xDEADBEEF;

 switch(id)
 {
  case PPU_GSREG_NMITIMEEN:
	ret = NMITIMEEN;
	break;

  case PPU_GSREG_HTIME:
	ret = HTime;
	break;

  case PPU_GSREG_VTIME:
	ret = VTime;
	break;

  case PPU_GSREG_NMIFLAG:
	ret = NMIFlag;
	break;

  case PPU_GSREG_IRQFLAG:
	ret = IRQFlag;
	break;

  case PPU_GSREG_HVBJOY:
	ret = HVBJOY;
	break;

  case PPU_GSREG_SCANLINE:
	ret = scanline;
	break;
  //
  //
  //

  case PPU_GSREG_BGMODE:
	ret = BGMode;
	break;

  case PPU_GSREG_MOSAIC:
	ret = Mosaic;
	break;

  case PPU_GSREG_W12SEL:
	ret = WMSettings[0];
	break;

  case PPU_GSREG_W34SEL:
	ret = WMSettings[1];
	break;

  case PPU_GSREG_WOBJSEL:
	ret = WMSettings[2];
	break;

  case PPU_GSREG_WH0:
	ret = WindowPos[0][0];
	break;
     
  case PPU_GSREG_WH1:
	ret = WindowPos[0][1];
	break;

  case PPU_GSREG_WH2:
	ret = WindowPos[1][0];
	break;

  case PPU_GSREG_WH3:
	ret = WindowPos[1][1];
	break;

  case PPU_GSREG_WBGLOG:
	ret = WMLogic & 0xFF;
	break;

  case PPU_GSREG_WOBJLOG:
	ret = WMLogic >> 8;
	break;

  case PPU_GSREG_TM:
	ret = WMMainEnable;
	break;

  case PPU_GSREG_TS:
	ret = WMSubEnable;
	break;

  case PPU_GSREG_CGWSEL:
	ret = CGWSEL;
	break;

  case PPU_GSREG_CGADSUB:
	ret = CGADSUB;
	break;

  case PPU_GSREG_BG1HOFS:
	ret = BGHOFS[0];
	break;

  case PPU_GSREG_BG1VOFS:
	ret = BGVOFS[0];
	break;

  case PPU_GSREG_BG2HOFS:
	ret = BGHOFS[1];
	break;

  case PPU_GSREG_BG2VOFS:
	ret = BGVOFS[1];
	break;

  case PPU_GSREG_BG3HOFS:
	ret = BGHOFS[2];
	break;

  case PPU_GSREG_BG3VOFS:
	ret = BGVOFS[2];
	break;

  case PPU_GSREG_BG4HOFS:
	ret = BGHOFS[3];
	break;

  case PPU_GSREG_BG4VOFS:
	ret = BGVOFS[3];
	break;

  //
  //
  //
  case PPU_GSREG_M7SEL:
	ret = M7SEL;
	break;

  case PPU_GSREG_M7A:
	ret = (uint16)M7Matrix[0];
	break;

  case PPU_GSREG_M7B:
	ret = (uint16)M7Matrix[1];
	break;

  case PPU_GSREG_M7C:
	ret = (uint16)M7Matrix[2];
	break;

  case PPU_GSREG_M7D:
	ret = (uint16)M7Matrix[3];
	break;

  case PPU_GSREG_M7X:
	ret = M7Center[0] & 0x1FFF;
	break;

  case PPU_GSREG_M7Y:
	ret = M7Center[1] & 0x1FFF;
	break;

  case PPU_GSREG_M7HOFS:
	ret = M7HOFS & 0x1FFF;
	break;

  case PPU_GSREG_M7VOFS:
	ret = M7VOFS & 0x1FFF;
	break;


  case PPU_GSREG_SCREENMODE:
	ret = ScreenMode;
	break;
 }
 return ret;
}

