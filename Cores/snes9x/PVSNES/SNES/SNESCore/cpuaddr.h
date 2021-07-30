/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

#ifndef _CPUADDR_H_
#define _CPUADDR_H_

typedef enum
{
	NONE   = 0,
	READ   = 1,
	WRITE  = 2,
	MODIFY = 3,
	JUMP   = 5,
	JSR    = 8
}	AccessMode;

static inline uint8 Immediate8Slow (AccessMode a)
{
	uint8	val = S9xGetByte(Registers.PBPC);
	if (a & READ)
		OpenBus = val;
	Registers.PCw++;

	return (val);
}

static inline uint8 Immediate8 (AccessMode a)
{
	uint8	val = CPU.PCBase[Registers.PCw];
	if (a & READ)
		OpenBus = val;
	AddCycles(CPU.MemSpeed);
	Registers.PCw++;

	return (val);
}

static inline uint16 Immediate16Slow (AccessMode a)
{
	uint16	val = S9xGetWord(Registers.PBPC, WRAP_BANK);
	if (a & READ)
		OpenBus = (uint8) (val >> 8);
	Registers.PCw += 2;

	return (val);
}

static inline uint16 Immediate16 (AccessMode a)
{
	uint16	val = READ_WORD(CPU.PCBase + Registers.PCw);
	if (a & READ)
		OpenBus = (uint8) (val >> 8);
	AddCycles(CPU.MemSpeedx2);
	Registers.PCw += 2;

	return (val);
}

static inline uint32 RelativeSlow (AccessMode a)						// branch $xx
{
	int8	offset = Immediate8Slow(a);

	return ((int16) Registers.PCw + offset) & 0xffff;
}

static inline uint32 Relative (AccessMode a)							// branch $xx
{
	int8	offset = Immediate8(a);

	return ((int16) Registers.PCw + offset) & 0xffff;
}

static inline uint32 RelativeLongSlow (AccessMode a)					// BRL $xxxx
{
	int16	offset = Immediate16Slow(a);

	return ((int32) Registers.PCw + offset) & 0xffff;
}

static inline uint32 RelativeLong (AccessMode a)						// BRL $xxxx
{
	int16	offset = Immediate16(a);

	return ((int32) Registers.PCw + offset) & 0xffff;
}

static inline uint32 AbsoluteIndexedIndirectSlow (AccessMode a)			// (a,X)
{
	uint16	addr;

	if (a & JSR)
	{
		// JSR (a,X) pushes the old address in the middle of loading the new.
		// OpenBus needs to be set to account for this.
		addr = Immediate8Slow(READ);
		if (a == JSR)
			OpenBus = Registers.PCl;
		addr |= Immediate8Slow(READ) << 8;
	}
	else
		addr = Immediate16Slow(READ);

	AddCycles(ONE_CYCLE);
	addr += Registers.X.W;

	// Address load wraps within the bank
	uint16	addr2 = S9xGetWord(ICPU.ShiftedPB | addr, WRAP_BANK);
	OpenBus = addr2 >> 8;

	return (addr2);
}

static inline uint32 AbsoluteIndexedIndirect (AccessMode a)				// (a,X)
{
	uint16	addr = Immediate16Slow(READ);

	AddCycles(ONE_CYCLE);
	addr += Registers.X.W;

	// Address load wraps within the bank
	uint16	addr2 = S9xGetWord(ICPU.ShiftedPB | addr, WRAP_BANK);
	OpenBus = addr2 >> 8;

	return (addr2);
}

static inline uint32 AbsoluteIndirectLongSlow (AccessMode a)			// [a]
{
	uint16	addr = Immediate16Slow(READ);

	// No info on wrapping, but it doesn't matter anyway due to mirroring
	uint32	addr2 = S9xGetWord(addr);
	OpenBus = addr2 >> 8;
	addr2 |= (OpenBus = S9xGetByte(addr + 2)) << 16;

	return (addr2);
}

static inline uint32 AbsoluteIndirectLong (AccessMode a)				// [a]
{
	uint16	addr = Immediate16(READ);

	// No info on wrapping, but it doesn't matter anyway due to mirroring
	uint32	addr2 = S9xGetWord(addr);
	OpenBus = addr2 >> 8;
	addr2 |= (OpenBus = S9xGetByte(addr + 2)) << 16;

	return (addr2);
}

static inline uint32 AbsoluteIndirectSlow (AccessMode a)				// (a)
{
	// No info on wrapping, but it doesn't matter anyway due to mirroring
	uint16	addr2 = S9xGetWord(Immediate16Slow(READ));
	OpenBus = addr2 >> 8;

	return (addr2);
}

static inline uint32 AbsoluteIndirect (AccessMode a)					// (a)
{
	// No info on wrapping, but it doesn't matter anyway due to mirroring
	uint16	addr2 = S9xGetWord(Immediate16(READ));
	OpenBus = addr2 >> 8;

	return (addr2);
}

static inline uint32 AbsoluteSlow (AccessMode a)						// a
{
	return (ICPU.ShiftedDB | Immediate16Slow(a));
}

static inline uint32 Absolute (AccessMode a)							// a
{
	return (ICPU.ShiftedDB | Immediate16(a));
}

static inline uint32 AbsoluteLongSlow (AccessMode a)					// l
{
	uint32	addr = Immediate16Slow(READ);

	// JSR l pushes the old bank in the middle of loading the new.
	// OpenBus needs to be set to account for this.
	if (a == JSR)
		OpenBus = Registers.PB;

	addr |= Immediate8Slow(a) << 16;

	return (addr);
}

static inline uint32 AbsoluteLong (AccessMode a)						// l
{
	uint32	addr = READ_3WORD(CPU.PCBase + Registers.PCw);
	AddCycles(CPU.MemSpeedx2 + CPU.MemSpeed);
	if (a & READ)
		OpenBus = addr >> 16;
	Registers.PCw += 3;

	return (addr);
}

static inline uint32 DirectSlow (AccessMode a)							// d
{
	uint16	addr = Immediate8Slow(a) + Registers.D.W;
	if (Registers.DL != 0)
		AddCycles(ONE_CYCLE);

	return (addr);
}

static inline uint32 Direct (AccessMode a)								// d
{
	uint16	addr = Immediate8(a) + Registers.D.W;
	if (Registers.DL != 0)
		AddCycles(ONE_CYCLE);

	return (addr);
}

static inline uint32 DirectIndirectSlow (AccessMode a)					// (d)
{
	uint32	addr = S9xGetWord(DirectSlow(READ), (!CheckEmulation() || Registers.DL) ? WRAP_BANK : WRAP_PAGE);
	if (a & READ)
		OpenBus = (uint8) (addr >> 8);
	addr |= ICPU.ShiftedDB;

	return (addr);
}

static inline uint32 DirectIndirectE0 (AccessMode a)					// (d)
{
	uint32	addr = S9xGetWord(Direct(READ));
	if (a & READ)
		OpenBus = (uint8) (addr >> 8);
	addr |= ICPU.ShiftedDB;

	return (addr);
}

static inline uint32 DirectIndirectE1 (AccessMode a)					// (d)
{
	uint32	addr = S9xGetWord(DirectSlow(READ), Registers.DL ? WRAP_BANK : WRAP_PAGE);
	if (a & READ)
		OpenBus = (uint8) (addr >> 8);
	addr |= ICPU.ShiftedDB;

	return (addr);
}

static inline uint32 DirectIndirectIndexedSlow (AccessMode a)			// (d),Y
{
	uint32	addr = DirectIndirectSlow(a);
	if (a & WRITE || !CheckIndex() || (addr & 0xff) + Registers.YL >= 0x100)
		AddCycles(ONE_CYCLE);

	return (addr + Registers.Y.W);
}

static inline uint32 DirectIndirectIndexedE0X0 (AccessMode a)			// (d),Y
{
	uint32	addr = DirectIndirectE0(a);
	AddCycles(ONE_CYCLE);

	return (addr + Registers.Y.W);
}

static inline uint32 DirectIndirectIndexedE0X1 (AccessMode a)			// (d),Y
{
	uint32	addr = DirectIndirectE0(a);
	if (a & WRITE || (addr & 0xff) + Registers.YL >= 0x100)
		AddCycles(ONE_CYCLE);

	return (addr + Registers.Y.W);
}

static inline uint32 DirectIndirectIndexedE1 (AccessMode a)				// (d),Y
{
	uint32	addr = DirectIndirectE1(a);
	if (a & WRITE || (addr & 0xff) + Registers.YL >= 0x100)
		AddCycles(ONE_CYCLE);

	return (addr + Registers.Y.W);
}

static inline uint32 DirectIndirectLongSlow (AccessMode a)				// [d]
{
	uint16	addr = DirectSlow(READ);
	uint32	addr2 = S9xGetWord(addr);
	OpenBus = addr2 >> 8;
	addr2 |= (OpenBus = S9xGetByte(addr + 2)) << 16;

	return (addr2);
}

static inline uint32 DirectIndirectLong (AccessMode a)					// [d]
{
	uint16	addr = Direct(READ);
	uint32	addr2 = S9xGetWord(addr);
	OpenBus = addr2 >> 8;
	addr2 |= (OpenBus = S9xGetByte(addr + 2)) << 16;

	return (addr2);
}

static inline uint32 DirectIndirectIndexedLongSlow (AccessMode a)		// [d],Y
{
	return (DirectIndirectLongSlow(a) + Registers.Y.W);
}

static inline uint32 DirectIndirectIndexedLong (AccessMode a)			// [d],Y
{
	return (DirectIndirectLong(a) + Registers.Y.W);
}

static inline uint32 DirectIndexedXSlow (AccessMode a)					// d,X
{
	pair	addr;
	addr.W = DirectSlow(a);
	if (!CheckEmulation() || Registers.DL)
		addr.W += Registers.X.W;
	else
		addr.B.l += Registers.XL;

	AddCycles(ONE_CYCLE);

	return (addr.W);
}

static inline uint32 DirectIndexedXE0 (AccessMode a)					// d,X
{
	uint16	addr = Direct(a) + Registers.X.W;
	AddCycles(ONE_CYCLE);

	return (addr);
}

static inline uint32 DirectIndexedXE1 (AccessMode a)					// d,X
{
	if (Registers.DL)
		return (DirectIndexedXE0(a));
	else
	{
		pair	addr;
		addr.W = Direct(a);
		addr.B.l += Registers.XL;
		AddCycles(ONE_CYCLE);

		return (addr.W);
	}
}

static inline uint32 DirectIndexedYSlow (AccessMode a)					// d,Y
{
	pair	addr;
	addr.W = DirectSlow(a);
	if (!CheckEmulation() || Registers.DL)
		addr.W += Registers.Y.W;
	else
		addr.B.l += Registers.YL;

	AddCycles(ONE_CYCLE);

	return (addr.W);
}

static inline uint32 DirectIndexedYE0 (AccessMode a)					// d,Y
{
	uint16	addr = Direct(a) + Registers.Y.W;
	AddCycles(ONE_CYCLE);

	return (addr);
}

static inline uint32 DirectIndexedYE1 (AccessMode a)					// d,Y
{
	if (Registers.DL)
		return (DirectIndexedYE0(a));
	else
	{
		pair	addr;
		addr.W = Direct(a);
		addr.B.l += Registers.YL;
		AddCycles(ONE_CYCLE);

		return (addr.W);
	}
}

static inline uint32 DirectIndexedIndirectSlow (AccessMode a)			// (d,X)
{
	uint32	addr = S9xGetWord(DirectIndexedXSlow(READ), (!CheckEmulation() || Registers.DL) ? WRAP_BANK : WRAP_PAGE);
	if (a & READ)
		OpenBus = (uint8) (addr >> 8);

	return (ICPU.ShiftedDB | addr);
}

static inline uint32 DirectIndexedIndirectE0 (AccessMode a)				// (d,X)
{
	uint32	addr = S9xGetWord(DirectIndexedXE0(READ));
	if (a & READ)
		OpenBus = (uint8) (addr >> 8);

	return (ICPU.ShiftedDB | addr);
}

static inline uint32 DirectIndexedIndirectE1 (AccessMode a)				// (d,X)
{
	uint32	addr = S9xGetWord(DirectIndexedXE1(READ), Registers.DL ? WRAP_BANK : WRAP_PAGE);
	if (a & READ)
		OpenBus = (uint8) (addr >> 8);

	return (ICPU.ShiftedDB | addr);
}

static inline uint32 AbsoluteIndexedXSlow (AccessMode a)				// a,X
{
	uint32	addr = AbsoluteSlow(a);
	if (a & WRITE || !CheckIndex() || (addr & 0xff) + Registers.XL >= 0x100)
		AddCycles(ONE_CYCLE);

	return (addr + Registers.X.W);
}

static inline uint32 AbsoluteIndexedXX0 (AccessMode a)					// a,X
{
	uint32	addr = Absolute(a);
	AddCycles(ONE_CYCLE);

	return (addr + Registers.X.W);
}

static inline uint32 AbsoluteIndexedXX1 (AccessMode a)					// a,X
{
	uint32	addr = Absolute(a);
	if (a & WRITE || (addr & 0xff) + Registers.XL >= 0x100)
		AddCycles(ONE_CYCLE);

	return (addr + Registers.X.W);
}

static inline uint32 AbsoluteIndexedYSlow (AccessMode a)				// a,Y
{
	uint32	addr = AbsoluteSlow(a);
	if (a & WRITE || !CheckIndex() || (addr & 0xff) + Registers.YL >= 0x100)
		AddCycles(ONE_CYCLE);

	return (addr + Registers.Y.W);
}

static inline uint32 AbsoluteIndexedYX0 (AccessMode a)					// a,Y
{
	uint32	addr = Absolute(a);
	AddCycles(ONE_CYCLE);

	return (addr + Registers.Y.W);
}

static inline uint32 AbsoluteIndexedYX1 (AccessMode a)					// a,Y
{
	uint32	addr = Absolute(a);
	if (a & WRITE || (addr & 0xff) + Registers.YL >= 0x100)
		AddCycles(ONE_CYCLE);

	return (addr + Registers.Y.W);
}

static inline uint32 AbsoluteLongIndexedXSlow (AccessMode a)			// l,X
{
	return (AbsoluteLongSlow(a) + Registers.X.W);
}

static inline uint32 AbsoluteLongIndexedX (AccessMode a)				// l,X
{
	return (AbsoluteLong(a) + Registers.X.W);
}

static inline uint32 StackRelativeSlow (AccessMode a)					// d,S
{
	uint16	addr = Immediate8Slow(a) + Registers.S.W;
	AddCycles(ONE_CYCLE);

	return (addr);
}

static inline uint32 StackRelative (AccessMode a)						// d,S
{
	uint16	addr = Immediate8(a) + Registers.S.W;
	AddCycles(ONE_CYCLE);

	return (addr);
}

static inline uint32 StackRelativeIndirectIndexedSlow (AccessMode a)	// (d,S),Y
{
	uint32	addr = S9xGetWord(StackRelativeSlow(READ));
	if (a & READ)
		OpenBus = (uint8) (addr >> 8);
	addr = (addr + Registers.Y.W + ICPU.ShiftedDB) & 0xffffff;
	AddCycles(ONE_CYCLE);

	return (addr);
}

static inline uint32 StackRelativeIndirectIndexed (AccessMode a)		// (d,S),Y
{
	uint32	addr = S9xGetWord(StackRelative(READ));
	if (a & READ)
		OpenBus = (uint8) (addr >> 8);
	addr = (addr + Registers.Y.W + ICPU.ShiftedDB) & 0xffffff;
	AddCycles(ONE_CYCLE);

	return (addr);
}

#endif
