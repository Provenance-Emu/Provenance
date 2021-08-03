/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

#ifndef _CPUMACRO_H_
#define _CPUMACRO_H_

#define rOP8(OP, ADDR, WRAP, FUNC) \
static void Op##OP (void) \
{ \
	uint8	val = OpenBus = S9xGetByte(ADDR(READ)); \
	FUNC(val); \
}

#define rOP16(OP, ADDR, WRAP, FUNC) \
static void Op##OP (void) \
{ \
	uint16	val = S9xGetWord(ADDR(READ), WRAP); \
	OpenBus = (uint8) (val >> 8); \
	FUNC(val); \
}

#define rOPC(OP, COND, ADDR, WRAP, FUNC) \
static void Op##OP (void) \
{ \
	if (Check##COND()) \
	{ \
		uint8	val = OpenBus = S9xGetByte(ADDR(READ)); \
		FUNC(val); \
	} \
	else \
	{ \
		uint16	val = S9xGetWord(ADDR(READ), WRAP); \
		OpenBus = (uint8) (val >> 8); \
		FUNC(val); \
	} \
}

#define rOPM(OP, ADDR, WRAP, FUNC) \
rOPC(OP, Memory, ADDR, WRAP, FUNC)

#define rOPX(OP, ADDR, WRAP, FUNC) \
rOPC(OP, Index, ADDR, WRAP, FUNC)

#define wOP8(OP, ADDR, WRAP, FUNC) \
static void Op##OP (void) \
{ \
	FUNC##8(ADDR(WRITE)); \
}

#define wOP16(OP, ADDR, WRAP, FUNC) \
static void Op##OP (void) \
{ \
	FUNC##16(ADDR(WRITE), WRAP); \
}

#define wOPC(OP, COND, ADDR, WRAP, FUNC) \
static void Op##OP (void) \
{ \
	if (Check##COND()) \
		FUNC##8(ADDR(WRITE)); \
	else \
		FUNC##16(ADDR(WRITE), WRAP); \
}

#define wOPM(OP, ADDR, WRAP, FUNC) \
wOPC(OP, Memory, ADDR, WRAP, FUNC)

#define wOPX(OP, ADDR, WRAP, FUNC) \
wOPC(OP, Index, ADDR, WRAP, FUNC)

#define mOP8(OP, ADDR, WRAP, FUNC) \
static void Op##OP (void) \
{ \
	FUNC##8(ADDR(MODIFY)); \
}

#define mOP16(OP, ADDR, WRAP, FUNC) \
static void Op##OP (void) \
{ \
	FUNC##16(ADDR(MODIFY), WRAP); \
}

#define mOPC(OP, COND, ADDR, WRAP, FUNC) \
static void Op##OP (void) \
{ \
	if (Check##COND()) \
		FUNC##8(ADDR(MODIFY)); \
	else \
		FUNC##16(ADDR(MODIFY), WRAP); \
}

#define mOPM(OP, ADDR, WRAP, FUNC) \
mOPC(OP, Memory, ADDR, WRAP, FUNC)

#define bOP(OP, REL, COND, CHK, E) \
static void Op##OP (void) \
{ \
	pair	newPC; \
	newPC.W = REL(JUMP); \
	if (COND) \
	{ \
		AddCycles(ONE_CYCLE); \
		if (E && Registers.PCh != newPC.B.h) \
			AddCycles(ONE_CYCLE); \
		if ((Registers.PCw & ~MEMMAP_MASK) != (newPC.W & ~MEMMAP_MASK)) \
			S9xSetPCBase(ICPU.ShiftedPB + newPC.W); \
		else \
			Registers.PCw = newPC.W; \
	} \
}


static inline void SetZN (uint16 Work16)
{
	ICPU._Zero = Work16 != 0;
	ICPU._Negative = (uint8) (Work16 >> 8);
}

static inline void SetZN (uint8 Work8)
{
	ICPU._Zero = Work8;
	ICPU._Negative = Work8;
}

static inline void ADC (uint16 Work16)
{
	if (CheckDecimal())
	{
		uint32 result;
		uint32 carry = CheckCarry();

		result = (Registers.A.W & 0x000F) + (Work16 & 0x000F) + carry;
		if (result > 0x0009)
			result += 0x0006;
		carry = (result > 0x000F);

		result = (Registers.A.W & 0x00F0) + (Work16 & 0x00F0) + (result & 0x000F) + carry * 0x10;
		if (result > 0x009F)
			result += 0x0060;
		carry = (result > 0x00FF);

		result = (Registers.A.W & 0x0F00) + (Work16 & 0x0F00) + (result & 0x00FF) + carry * 0x100;
		if (result > 0x09FF)
			result += 0x0600;
		carry = (result > 0x0FFF);

		result = (Registers.A.W & 0xF000) + (Work16 & 0xF000) + (result & 0x0FFF) + carry * 0x1000;

		if ((Registers.A.W & 0x8000) == (Work16 & 0x8000) && (Registers.A.W & 0x8000) != (result & 0x8000))
			SetOverflow();
		else
			ClearOverflow();

		if (result > 0x9FFF)
			result += 0x6000;

		if (result > 0xFFFF)
			SetCarry();
		else
			ClearCarry();

		Registers.A.W = result & 0xFFFF;
		SetZN(Registers.A.W);
	}
	else
	{
		uint32	Ans32 = Registers.A.W + Work16 + CheckCarry();

		ICPU._Carry = Ans32 >= 0x10000;

		if (~(Registers.A.W ^ Work16) & (Work16 ^ (uint16) Ans32) & 0x8000)
			SetOverflow();
		else
			ClearOverflow();

		Registers.A.W = (uint16) Ans32;
		SetZN(Registers.A.W);
	}
}

static inline void ADC (uint8 Work8)
{
	if (CheckDecimal())
	{
		uint32 result;
		uint32 carry = CheckCarry();

		result = (Registers.AL & 0x0F) + (Work8 & 0x0F) + carry;
		if ( result > 0x09 )
			result += 0x06;
		carry = (result > 0x0F);

		result = (Registers.AL & 0xF0) + (Work8 & 0xF0) + (result & 0x0F) + (carry * 0x10);

		if ((Registers.AL & 0x80) == (Work8 & 0x80) && (Registers.AL & 0x80) != (result & 0x80))
			SetOverflow();
		else
			ClearOverflow();

		if (result > 0x9F)
			result += 0x60;

		if (result > 0xFF)
			SetCarry();
		else
			ClearCarry();

		Registers.AL = result & 0xFF;
		SetZN(Registers.AL);
	}
	else
	{
		uint16	Ans16 = Registers.AL + Work8 + CheckCarry();

		ICPU._Carry = Ans16 >= 0x100;

		if (~(Registers.AL ^ Work8) & (Work8 ^ (uint8) Ans16) & 0x80)
			SetOverflow();
		else
			ClearOverflow();

		Registers.AL = (uint8) Ans16;
		SetZN(Registers.AL);
	}
}

static inline void AND (uint16 Work16)
{
	Registers.A.W &= Work16;
	SetZN(Registers.A.W);
}

static inline void AND (uint8 Work8)
{
	Registers.AL &= Work8;
	SetZN(Registers.AL);
}

static inline void ASL16 (uint32 OpAddress, s9xwrap_t w)
{
	uint16	Work16 = S9xGetWord(OpAddress, w);
	ICPU._Carry = (Work16 & 0x8000) != 0;
	Work16 <<= 1;
	AddCycles(ONE_CYCLE);
	S9xSetWord(Work16, OpAddress, w, WRITE_10);
	OpenBus = Work16 & 0xff;
	SetZN(Work16);
}

static inline void ASL8 (uint32 OpAddress)
{
	uint8	Work8 = S9xGetByte(OpAddress);
	ICPU._Carry = (Work8 & 0x80) != 0;
	Work8 <<= 1;
	AddCycles(ONE_CYCLE);
	S9xSetByte(Work8, OpAddress);
	OpenBus = Work8;
	SetZN(Work8);
}

static inline void BIT (uint16 Work16)
{
	ICPU._Overflow = (Work16 & 0x4000) != 0;
	ICPU._Negative = (uint8) (Work16 >> 8);
	ICPU._Zero = (Work16 & Registers.A.W) != 0;
}

static inline void BIT (uint8 Work8)
{
	ICPU._Overflow = (Work8 & 0x40) != 0;
	ICPU._Negative = Work8;
	ICPU._Zero = Work8 & Registers.AL;
}

static inline void CMP (uint16 val)
{
	int32	Int32 = (int32) Registers.A.W - (int32) val;
	ICPU._Carry = Int32 >= 0;
	SetZN((uint16) Int32);
}

static inline void CMP (uint8 val)
{
	int16	Int16 = (int16) Registers.AL - (int16) val;
	ICPU._Carry = Int16 >= 0;
	SetZN((uint8) Int16);
}

static inline void CPX (uint16 val)
{
	int32	Int32 = (int32) Registers.X.W - (int32) val;
	ICPU._Carry = Int32 >= 0;
	SetZN((uint16) Int32);
}

static inline void CPX (uint8 val)
{
	int16	Int16 = (int16) Registers.XL - (int16) val;
	ICPU._Carry = Int16 >= 0;
	SetZN((uint8) Int16);
}

static inline void CPY (uint16 val)
{
	int32	Int32 = (int32) Registers.Y.W - (int32) val;
	ICPU._Carry = Int32 >= 0;
	SetZN((uint16) Int32);
}

static inline void CPY (uint8 val)
{
	int16	Int16 = (int16) Registers.YL - (int16) val;
	ICPU._Carry = Int16 >= 0;
	SetZN((uint8) Int16);
}

static inline void DEC16 (uint32 OpAddress, s9xwrap_t w)
{
	uint16	Work16 = S9xGetWord(OpAddress, w) - 1;
	AddCycles(ONE_CYCLE);
	S9xSetWord(Work16, OpAddress, w, WRITE_10);
	OpenBus = Work16 & 0xff;
	SetZN(Work16);
}

static inline void DEC8 (uint32 OpAddress)
{
	uint8	Work8 = S9xGetByte(OpAddress) - 1;
	AddCycles(ONE_CYCLE);
	S9xSetByte(Work8, OpAddress);
	OpenBus = Work8;
	SetZN(Work8);
}

static inline void EOR (uint16 val)
{
	Registers.A.W ^= val;
	SetZN(Registers.A.W);
}

static inline void EOR (uint8 val)
{
	Registers.AL ^= val;
	SetZN(Registers.AL);
}

static inline void INC16 (uint32 OpAddress, s9xwrap_t w)
{
	uint16	Work16 = S9xGetWord(OpAddress, w) + 1;
	AddCycles(ONE_CYCLE);
	S9xSetWord(Work16, OpAddress, w, WRITE_10);
	OpenBus = Work16 & 0xff;
	SetZN(Work16);
}

static inline void INC8 (uint32 OpAddress)
{
	uint8	Work8 = S9xGetByte(OpAddress) + 1;
	AddCycles(ONE_CYCLE);
	S9xSetByte(Work8, OpAddress);
	OpenBus = Work8;
	SetZN(Work8);
}

static inline void LDA (uint16 val)
{
	Registers.A.W = val;
	SetZN(Registers.A.W);
}

static inline void LDA (uint8 val)
{
	Registers.AL = val;
	SetZN(Registers.AL);
}

static inline void LDX (uint16 val)
{
	Registers.X.W = val;
	SetZN(Registers.X.W);
}

static inline void LDX (uint8 val)
{
	Registers.XL = val;
	SetZN(Registers.XL);
}

static inline void LDY (uint16 val)
{
	Registers.Y.W = val;
	SetZN(Registers.Y.W);
}

static inline void LDY (uint8 val)
{
	Registers.YL = val;
	SetZN(Registers.YL);
}

static inline void LSR16 (uint32 OpAddress, s9xwrap_t w)
{
	uint16	Work16 = S9xGetWord(OpAddress, w);
	ICPU._Carry = Work16 & 1;
	Work16 >>= 1;
	AddCycles(ONE_CYCLE);
	S9xSetWord(Work16, OpAddress, w, WRITE_10);
	OpenBus = Work16 & 0xff;
	SetZN(Work16);
}

static inline void LSR8 (uint32 OpAddress)
{
	uint8	Work8 = S9xGetByte(OpAddress);
	ICPU._Carry = Work8 & 1;
	Work8 >>= 1;
	AddCycles(ONE_CYCLE);
	S9xSetByte(Work8, OpAddress);
	OpenBus = Work8;
	SetZN(Work8);
}

static inline void ORA (uint16 val)
{
	Registers.A.W |= val;
	SetZN(Registers.A.W);
}

static inline void ORA (uint8 val)
{
	Registers.AL |= val;
	SetZN(Registers.AL);
}

static inline void ROL16 (uint32 OpAddress, s9xwrap_t w)
{
	uint32	Work32 = (((uint32) S9xGetWord(OpAddress, w)) << 1) | CheckCarry();
	ICPU._Carry = Work32 >= 0x10000;
	AddCycles(ONE_CYCLE);
	S9xSetWord((uint16) Work32, OpAddress, w, WRITE_10);
	OpenBus = Work32 & 0xff;
	SetZN((uint16) Work32);
}

static inline void ROL8 (uint32 OpAddress)
{
	uint16	Work16 = (((uint16) S9xGetByte(OpAddress)) << 1) | CheckCarry();
	ICPU._Carry = Work16 >= 0x100;
	AddCycles(ONE_CYCLE);
	S9xSetByte((uint8) Work16, OpAddress);
	OpenBus = Work16 & 0xff;
	SetZN((uint8) Work16);
}

static inline void ROR16 (uint32 OpAddress, s9xwrap_t w)
{
	uint32	Work32 = ((uint32) S9xGetWord(OpAddress, w)) | (((uint32) CheckCarry()) << 16);
	ICPU._Carry = Work32 & 1;
	Work32 >>= 1;
	AddCycles(ONE_CYCLE);
	S9xSetWord((uint16) Work32, OpAddress, w, WRITE_10);
	OpenBus = Work32 & 0xff;
	SetZN((uint16) Work32);
}

static inline void ROR8 (uint32 OpAddress)
{
	uint16	Work16 = ((uint16) S9xGetByte(OpAddress)) | (((uint16) CheckCarry()) << 8);
	ICPU._Carry = Work16 & 1;
	Work16 >>= 1;
	AddCycles(ONE_CYCLE);
	S9xSetByte((uint8) Work16, OpAddress);
	OpenBus = Work16 & 0xff;
	SetZN((uint8) Work16);
}

static inline void SBC (uint16 Work16)
{
	if (CheckDecimal())
	{
		int result;
		int carry = CheckCarry();

		Work16 ^= 0xFFFF;

		result = (Registers.A.W & 0x000F) + (Work16 & 0x000F) + carry;
		if (result < 0x0010)
			result -= 0x0006;
		carry = (result > 0x000F);

		result = (Registers.A.W & 0x00F0) + (Work16 & 0x00F0) + (result & 0x000F) + carry * 0x10;
		if (result < 0x0100)
			result -= 0x0060;
		carry = (result > 0x00FF);

		result = (Registers.A.W & 0x0F00) + (Work16 & 0x0F00) + (result & 0x00FF) + carry * 0x100;
		if (result < 0x1000)
			result -= 0x0600;
		carry = (result > 0x0FFF);

		result = (Registers.A.W & 0xF000) + (Work16 & 0xF000) + (result & 0x0FFF) + carry * 0x1000;

		if (((Registers.A.W ^ Work16) & 0x8000) == 0 && ((Registers.A.W ^ result) & 0x8000))
			SetOverflow();
		else
			ClearOverflow();

		if (result < 0x10000)
			result -= 0x6000;

		if (result > 0xFFFF)
			SetCarry();
		else
			ClearCarry();

		Registers.A.W = result & 0xFFFF;
		SetZN(Registers.A.W);
	}
	else
	{
		int32	Int32 = (int32) Registers.A.W - (int32) Work16 + (int32) CheckCarry() - 1;

		ICPU._Carry = Int32 >= 0;

		if ((Registers.A.W ^ Work16) & (Registers.A.W ^ (uint16) Int32) & 0x8000)
			SetOverflow();
		else
			ClearOverflow();

		Registers.A.W = (uint16) Int32;
		SetZN(Registers.A.W);
	}
}

static inline void SBC (uint8 Work8)
{
	if (CheckDecimal())
	{
		int result;
		int carry = CheckCarry();

		Work8 ^= 0xFF;

		result = (Registers.AL & 0x0F) + (Work8 & 0x0F) + carry;
		if (result < 0x10)
			result -= 0x06;
		carry = (result > 0x0F);

		result = (Registers.AL & 0xF0) + (Work8 & 0xF0) + (result & 0x0F) + carry * 0x10;

		if ((Registers.AL & 0x80) == (Work8 & 0x80) && (Registers.AL & 0x80) != (result & 0x80))
			SetOverflow();
		else
			ClearOverflow();

		if (result < 0x100 )
			result -= 0x60;

		if (result > 0xFF)
			SetCarry();
		else
			ClearCarry();

		Registers.AL = result & 0xFF;
		SetZN(Registers.AL);
	}
	else
	{
		int16	Int16 = (int16) Registers.AL - (int16) Work8 + (int16) CheckCarry() - 1;

		ICPU._Carry = Int16 >= 0;

		if ((Registers.AL ^ Work8) & (Registers.AL ^ (uint8) Int16) & 0x80)
			SetOverflow();
		else
			ClearOverflow();

		Registers.AL = (uint8) Int16;
		SetZN(Registers.AL);
	}
}

static inline void STA16 (uint32 OpAddress, enum s9xwrap_t w)
{
	S9xSetWord(Registers.A.W, OpAddress, w);
	OpenBus = Registers.AH;
}

static inline void STA8 (uint32 OpAddress)
{
	S9xSetByte(Registers.AL, OpAddress);
	OpenBus = Registers.AL;
}

static inline void STX16 (uint32 OpAddress, enum s9xwrap_t w)
{
	S9xSetWord(Registers.X.W, OpAddress, w);
	OpenBus = Registers.XH;
}

static inline void STX8 (uint32 OpAddress)
{
	S9xSetByte(Registers.XL, OpAddress);
	OpenBus = Registers.XL;
}

static inline void STY16 (uint32 OpAddress, enum s9xwrap_t w)
{
	S9xSetWord(Registers.Y.W, OpAddress, w);
	OpenBus = Registers.YH;
}

static inline void STY8 (uint32 OpAddress)
{
	S9xSetByte(Registers.YL, OpAddress);
	OpenBus = Registers.YL;
}

static inline void STZ16 (uint32 OpAddress, enum s9xwrap_t w)
{
	S9xSetWord(0, OpAddress, w);
	OpenBus = 0;
}

static inline void STZ8 (uint32 OpAddress)
{
	S9xSetByte(0, OpAddress);
	OpenBus = 0;
}

static inline void TSB16 (uint32 OpAddress, enum s9xwrap_t w)
{
	uint16	Work16 = S9xGetWord(OpAddress, w);
	ICPU._Zero = (Work16 & Registers.A.W) != 0;
	Work16 |= Registers.A.W;
	AddCycles(ONE_CYCLE);
	S9xSetWord(Work16, OpAddress, w, WRITE_10);
	OpenBus = Work16 & 0xff;
}

static inline void TSB8 (uint32 OpAddress)
{
	uint8	Work8 = S9xGetByte(OpAddress);
	ICPU._Zero = Work8 & Registers.AL;
	Work8 |= Registers.AL;
	AddCycles(ONE_CYCLE);
	S9xSetByte(Work8, OpAddress);
	OpenBus = Work8;
}

static inline void TRB16 (uint32 OpAddress, enum s9xwrap_t w)
{
	uint16	Work16 = S9xGetWord(OpAddress, w);
	ICPU._Zero = (Work16 & Registers.A.W) != 0;
	Work16 &= ~Registers.A.W;
	AddCycles(ONE_CYCLE);
	S9xSetWord(Work16, OpAddress, w, WRITE_10);
	OpenBus = Work16 & 0xff;
}

static inline void TRB8 (uint32 OpAddress)
{
	uint8	Work8 = S9xGetByte(OpAddress);
	ICPU._Zero = Work8 & Registers.AL;
	Work8 &= ~Registers.AL;
	AddCycles(ONE_CYCLE);
	S9xSetByte(Work8, OpAddress);
	OpenBus = Work8;
}

#endif
