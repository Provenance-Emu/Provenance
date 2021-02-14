/******************************************************************************

	cz80macro.h

	CZ80 ŠeŽíƒ}ƒNƒ

******************************************************************************/

#if CZ80_USE_JUMPTABLE
#define _SSOP(A,B)			A##B
#define OP(A)				_SSOP(OP,A)
#define OPCB(A)				_SSOP(OPCB,A)
#define OPED(A)				_SSOP(OPED,A)
#define OPXY(A)				_SSOP(OPXY,A)
#define OPXYCB(A)			_SSOP(OPXYCB,A)
#else
#define OP(A)				case A
#define OPCB(A)				case A
#define OPED(A)				case A
#define OPXY(A)				case A
#define OPXYCB(A)			case A
#endif

#define USE_CYCLES(A)		CPU->ICount -= (A);
#define ADD_CYCLES(A)		CPU->ICount += (A);

#define RET(A)				{ USE_CYCLES(A) goto Cz80_Exec; }

#if CZ80_ENCRYPTED_ROM

#define SET_PC(A)											\
	CPU->BasePC = CPU->Fetch[(A) >> CZ80_FETCH_SFT];		\
	OPBase = CPU->OPFetch[(A) >> CZ80_FETCH_SFT];			\
	PC = (A) + CPU->BasePC;

#define GET_OP()			(*(UINT8 *)(OPBase + PC))

#else

#define SET_PC(A)											\
	CPU->BasePC = CPU->Fetch[(A) >> CZ80_FETCH_SFT];		\
	PC = (A) + CPU->BasePC;

#define GET_OP()			(*(UINT8 *)PC)

#endif

#define READ_OP()			GET_OP(); PC++

#define READ_ARG()			(*(UINT8 *)PC++)
#if CZ80_LITTLE_ENDIAN
#define READ_ARG16()		(*(UINT8 *)PC | (*(UINT8 *)(PC + 1) << 8)); PC += 2
#else
#define READ_ARG16()		(*(UINT8 *)(PC + 1) | (*(UINT8 *)PC << 8)); PC += 2
#endif

//#ifndef BUILD_CPS1PSP
//#define READ_MEM8(A)		memory_region_cpu2[(A)]
//#else
#if PICODRIVE_HACKS
#define READ_MEM8(A)		picodrive_read(A)
#else
#define READ_MEM8(A)		CPU->Read_Byte(A)
#endif
//#endif
#if CZ80_LITTLE_ENDIAN
#define READ_MEM16(A)		(READ_MEM8(A) | (READ_MEM8((A) + 1) << 8))
#else
#define READ_MEM16(A)		((READ_MEM8(A) << 8) | READ_MEM8((A) + 1))
#endif

#if PICODRIVE_HACKS
#define WRITE_MEM8(A, D) { \
	unsigned short a = A; \
	unsigned char d = D; \
	unsigned long v = z80_write_map[a >> Z80_MEM_SHIFT]; \
	if (map_flag_set(v)) \
		((z80_write_f *)(v << 1))(a, d); \
	else \
		*(unsigned char *)((v << 1) + a) = d; \
}
#else
#define WRITE_MEM8(A, D)	CPU->Write_Byte(A, D);
#endif
#if CZ80_LITTLE_ENDIAN
#define WRITE_MEM16(A, D)	{ WRITE_MEM8(A, D); WRITE_MEM8((A) + 1, (D) >> 8); }
#else
#define WRITE_MEM16(A, D)	{ WRITE_MEM8((A) + 1, D); WRITE_MEM8(A, (D) >> 8); }
#endif

#define PUSH_16(A)			{ UINT32 sp; zSP -= 2; sp = zSP; WRITE_MEM16(sp, A); }
#define POP_16(A)			{ UINT32 sp; sp = zSP; A = READ_MEM16(sp); zSP = sp + 2; }

#define IN(A)				CPU->IN_Port(A)
#define OUT(A, D)			CPU->OUT_Port(A, D)

#define CHECK_INT													\
	if (zIFF1)														\
	{																\
		UINT32 IntVect;												\
																	\
		if (CPU->IRQState == HOLD_LINE)								\
			CPU->IRQState = CLEAR_LINE;								\
																	\
		CPU->HaltState = 0;											\
		zIFF1 = zIFF2 = 0;											\
		IntVect = CPU->Interrupt_Callback(CPU->IRQLine);			\
																	\
		PUSH_16(zRealPC)											\
																	\
		if (zIM == 2)												\
		{															\
			IntVect = (IntVect & 0xff) | (zI << 8);					\
			PC = READ_MEM16(IntVect);								\
			CPU->ExtraCycles += 17;									\
		}															\
		else if (zIM == 1)											\
		{															\
			PC = 0x38;												\
			CPU->ExtraCycles += 13;									\
		}															\
		else														\
		{															\
			PC = IntVect & 0x38;									\
			CPU->ExtraCycles += 13;									\
		}															\
																	\
		SET_PC(PC)													\
	}
