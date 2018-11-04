/*
 *	registers.h
 *
 *		ARMv7-A system register(s).
 */
#pragma once

namespace ARM
{

/*************************************************************************************************
 *	CP15 Registers for VMSA Implementation.	[ref.DDI0406B B3.12]
 *************************************************************************************************/
	/*
		<CRn>	<opc1>	<CRm>		<opc2>			[NAME,]	Description											[Flags]
		c0	{
				0		c0	{
									0				MIDR,	Main ID												RO
									1				CTR,	Cache Type											RO
									2				TCMTR,	TCM Type											RO, IMPL.DEFINED
									3				TLBTR,	TLB Type											RO, IMPL.DEFINED
									5				MPIDR,	Multiprocessor Affinity								RO
									{4,6,7}			MIDR$,	Main ID Aliases										RO
							}

				0		c[1-7]		[0-7]			CPUID	ID_{PFRn,DFRn,AFR0,MMFRn,ISARn}						RO

				1		c0			0				CCSIDR,	Cache Size ID										RO
				1		c0			1				CLIDR,	Cache Level ID										RO
				1		c0			7				AIDR,	Aux ID												RO,	IMPL.DEFINED

				2		c0			0				CSSELR,	Cache Size Selection								RW
		}

		c1		0		c0			[0-2]			System Control												RW
		c1		0		c1			[0-2]			Security Extension											RW, IMPL.OPTIONAL

		c2		0		c0			[0-2]			Translation Table Base										RW

		c3		0		c0			0				DACR, Domain Access Control									RW

		c5		0		c{0,1}		{0,1}			Fault Status												RW

		c6		0		c0			{0,2]			Fault Address												RW

		c7		0	{
						c0			4				NOP															WO
						c1			{0,6}			Cache Maintenance operations, Multiprocessing Extensions	WO
						c4			0				PAR, Physical Address										RW
						c5			{0,1,6,7}		Cache and branch predictor maintenance operations			WO
						c5			4				CP15ISB, Instruction barrier operation						WO, USER
						c6			{1,2}			Cache Maintenance operations								WO
						c8			[0-7]			VA to PA translation ops.									WO
						c10			{1,2}			Cache management ops.										WO
						c10			{4,5}			Data barrier ops.											WO, USER
						c11			1				DCCMVAU, Cache barrier ops.									WO
						c13			1				NOP															WO
						c14			{1,2}			Cache management ops.										WO
					}

		c8		0		c{3,5,6,7}	[0-3]			TLB maintenance ops. *										WO
		
		c9		[0-7]	c{0,2,5,8}	[0-7]			Reserved for Branch Predictor, Cache and TCM ops.			RSVD, OP.ACCESS
		c9		[0-7]	c[12-15]	[0-7]			Reserved for Performance monitors.							RSVD, OP.ACCESS

		c10		0		c{0,1,4,8}	[0-7]			Reserved for TLB lockdown ops.								RSVD, OP.ACCESS
		c10		0		c2			{0,1}			PRRR, NMRRR,	TEX Remap									RW
		
		c11		[0-7]	c{0,8,15}	[0-7]			Reserved for DMA ops. TCM access.							RSVD, OP.ACCESS

		c12		0		c0			{0,1}			Security Extensions											RW, IMPL.OPTIONAL
		c12		0		c1			0				ISR, Security Extensions									RO, IMPL.OPTIONAL

		c13		0		c0			0				FCSEIDR, FCSE PID											RO-if-FCSE-!IMPL / RW?
		c13		0		c0			[1-4]			Software Thread and Context ID								RW

		c15		*		*			*				IMPLEMENTATION DEFINED										IMPL.DEFINED
	*/


	
/*************************************************************************************************
 *	CP15 c0:  ID codes registers
 *************************************************************************************************/


	/*
	 *	MIDR: Main ID Register
	 */
	struct MIDR
	{
		u32 Revision		: 4;
		u32 PriPartNum		: 12;	// IF Impl:ARM && PriPartNo top 4bits are 0 || 7: arch&variant encoding differs
		u32 Architecture	: 4;
		u32 Variant			: 4;
		u32 Implementer		: 8;
	};

	enum MIDR_Implementer
	{
		ARM_Ltd						= 0x41,		// 'A'
		DigitalEquipment_Corp		= 0x44,		// 'D'
		Motorola_FreescaleSemi_Inc	= 0x4D,		// 'M'
		QUALCOMM_Inc				= 0x51,		// 'Q'
		MarvellSemi_Inc				= 0x56,		// 'V'
		Intel_Corp					= 0x69,		// 'i'

		TexasInstruments_Inc		= 0xFF		// 'T' ???
	};

	enum MIDR_Arch
	{
		ARMv4		= 1,
		ARMv4T		= 2,
		ARMv5		= 3,	// obselete
		ARMv5T		= 4,
		ARMv5TE		= 5,
		ARMv5TEJ	= 6,
		ARMv6		= 7,
		CPUID_Defined = 15
	};




	/*
	 *	CTR, Cache Type Register
	 */
	struct CTR
	{
		u32 IminLine	: 4;
		u32 SBZ			: 10;
		u32 L1Ip		: 2;
		u32 DminLine	: 4;	// 
		u32 ERG			: 4;	// Exclusives Reservation Granule.
		u32 CWG			: 4;	// Cache Writeback Granule.
		u32 RAZ			: 1;
		u32 REGFMT		: 3;	// Set to 0b100 for ARMv7 register format, or 0b000 for <=ARMv6 format
	};



	
	/*
	 *	TCMTR, TCM Type Register
	 */
	// High 3 bits is 0b100, the rest is IMPL.DEFINED
	typedef u32 TCMTR;


	/*
	 *	TLBTR, TLB Type Register
	 */
	// Low bit is nU : SET:1: Not unified ( separate instruction and data TLBs )
	typedef u32 TLBTR;


	/*
	 *	MPIDR, Multiprocessor Affinity Register
	 */

	struct MPIDR
	{
		u32 AffinityLevel0	: 8;
		u32 AffinityLevel1	: 8;
		u32 AffinityLevel2	: 8;
		u32 MT				: 1;
		u32 RAZ				: 5;	// Reserved As Zero
		u32 U				: 1;	// Set: Processor is part of a Uniprocessor system.
		u32 MP_Impl			: 1;	// RAO if MP Extensions are implemented.
	};


	/*
	 *	CCSIDR, Cache Size ID Registers
	 */
	struct CCSIDR
	{
		u32 LineSize		: 3;
		u32 Associativity	: 10;
		u32 NumSets			: 15;
		u32 WA				: 1;
		u32 RA				: 1;
		u32 WB				: 1;
		u32 WT				: 1;
	};


	
	/*
	 *	CLIDR, Cache Level ID Register
	 */
	struct CLIDR
	{
		u32 Ctype1	: 3;
		u32 Ctype2	: 3;
		u32 Ctype3	: 3;
		u32 Ctype4	: 3;
		u32 Ctype5	: 3;
		u32 Ctype6	: 3;
		u32 Ctype7	: 3;
		u32 LoUIS	: 3;
		u32 LoC		: 3;
		u32 LoUU	: 3;
		u32 RAZ		: 2;	// RAZ
	};


	/*
	 *	AIDR, Auxiliary ID Register.
	 */
	typedef u32 AIDR;	// IMPLEMENTATION DEFINED



	/*
	 *	CSSELR, Cache Size Selection Register
	 */
	struct CSSELR
	{
		u32 InD		: 1;
		u32 Level	: 3;
		u32 SBZP	: 28;
	};










	
/*************************************************************************************************
 *	CP15 c1:  System control registers
 *************************************************************************************************/




	// SCTRL, ACTLR	//////////////////////  TODO  ///////////////////////




	/*
	 *	CPACR: Coprocessor Access Control Register.
	 *
	 *		Controls access to all coprocessors other than CP14 & CP15.
	 *		It may be used to check for their presence by testing modification to cpN bits.
	 *
	 *	Notes:
	 *
	 *		D32DIS:1 && ASEDIS:0 is INVALID
	 *		ASEDIS on hw { w. VFP & w.o A.SIMD } is RAO/WI, if bit is not supported it is RAZ/WI.
	 *		
	 *		When Security Extensions are enabled, NSACR controls CP access from non-secure state.
	 *
	 *		VFP uses CP10 && CP11, the values of .cp10 && .cp11 should be the same.
	 */
	union CPACR
	{
		struct {
			u32 cp0  : 2;	// cpN [0-13]:
			u32 cp1  : 2;	//	Defines access rights for individual coprocessors.
			u32 cp2  : 2;	//	See CP_Access enum below for possible values;
			u32 cp3  : 2;	//
			u32 cp4  : 2;	//	To test
			u32 cp5  : 2;
			u32 cp6  : 2;
			u32 cp7  : 2;
			u32 cp8  : 2;
			u32 cp9  : 2;
			u32 cp10 : 2;
			u32 cp11 : 2;
			u32 cp12 : 2;
			u32 cp13 : 2;
			u32 rsvcd: 2;	// SBZP
			u32 D32DIS:1;	// SET: Disables use of D16-D32 of the VFP register file.
			u32 ASEDIS:1;	// SET: Disables all A.SIMD Instructions, VFPv3 shall remain valid.
		};

		u32 R;
	};

	/*
	 *	CP_Access:	Enumerates access rights for CPACR.cpN
	 *
	 */
	enum CP_Access
	{
		A_Deny,			// Deny Access,			Attempts to access cause Exception::Undefined_Instruction
		A_Privileged,	// Privileged Access,	Attempts to access cause Exception::Undefined_Instruction in User mode.
		A_Reserved,		// Reserved Value,		Use of this value is UNPREDICTABLE.
		A_Full			// Full Access,			Access is defined by coprocessor.
	};






	/*
	 *	SCR:	Secure Configuration Register.
	 *
	 *		Requires:	Security Extension.
	 */
	union SCR
	{
		struct {
			u32 NS	: 1;	// 
			u32 IRQ	: 1;	// 
			u32 FIQ	: 1;	// 
			u32 EA	: 1;	// 
			u32 FW	: 1;	// 
			u32 AW	: 1;	// 
			u32 nET	: 1;	// 
			u32 SBZP:25;
		};

		u32 R;
	};




	// SDER, Secure Debug Enable Register

	// NSACR, Non-Secure Access Control Register



	







	
/*************************************************************************************************
 *	CP15 c{2,3}:  Memory protection and control registers
 *************************************************************************************************/


	// TTBR0 TTVR1 TTVCR
	// DACR, Domain Access Control Register

	
	
/*************************************************************************************************
 *	CP15 c4:  Not used
 *************************************************************************************************/

	
	
/*************************************************************************************************
 *	CP15 c{5,6}:  Memory system fault registers
 *************************************************************************************************/

	// DFSR,  Data Fault Status Register
	// IFSR,  Instruction Fault Status Register
	// ADFSR, Aux. DFSR
	// AIFSR, Aux. IFSR
	// DFAR,  Data Fault Address Register
	// IFAR,  Instruction Fault Address Register


	
	
/*************************************************************************************************
 *	CP15 c7:  Cache maintenance / misc
 *************************************************************************************************/




	
	
/*************************************************************************************************
 *************************************************************************************************
 *	A.SIMD and VFP extension system registers
 *************************************************************************************************
 *************************************************************************************************/

	enum FP_SysRegs
	{
		R_FPSID		= 0,	// 0b0000
		R_MVFR1		= 6,	// 0b0110
		R_MVFR0		= 7,	// 0b0111
	};

	
	//	FPSID	Floating Point System ID Register
	//	MVFR1	Media and VFP Feature Register 1
	//	MVFR0	Media and VFP Feature Register 0

	struct FPSID
	{
		u32 Revision	: 4;	// IMPL.DEFINED
		u32 Variant		: 4;	// IMPL.DEFINED
		u32 PartNumber	: 8;	// IMPL.DEFINED
		u32 SubArch		: 7;	// MSB:1 when designed by ARM
		u32 SW			: 1;	// Is a software impl. if set
		u32 Implementer	: 8;	// Same as MIDR.Implementer
	};

	enum FP_SubArch
	{
		VFPv1	= 0,	// Not Permitted in ARMv7
		VFPv2_Cv1,		// Not Permitted in ARMv7
		VFPv3_Cv2,		// 
		VFPv3_Null,		// Full hardware, no trap
		VFPv3_Cv3,		// 
	};



	//	Floating-point status and control register
	//
	struct FPSCR
	{
		u32 IOC		: 1;	// * All * bits are cumulative exception bits
		u32 DZC		: 1;	// *
		u32 OFC		: 1;	// *
		u32 UFC		: 1;	// *
		u32 IXC		: 1;	// *
		u32 SBZP1	: 2;	// 
		u32 IDC		: 1;	// *
		u32 IOE		: 1;	// ** All ** bits are FP trap enable bits
		u32 DZE		: 1;	// ** only supported in VFPv2 && VFPv3U
		u32 OFE		: 1;	// ** - RAZ elsewhere -
		u32 UFE		: 1;	// **
		u32 IXE		: 1;	// **
		u32 SBZP2	: 2;	// 
		u32 IDE		: 1;	// **
		u32 Len		: 3;	// SBZ for ARMv7 VFP, ignored for A.SIMD
		u32 SBZP3	: 1;	// 
		u32 Stride	: 2;	// SBZ for ARMv7 VFP, ignored for A.SIMD
		u32 RMode	: 2;	// Rounding Mode
		u32 FZ		: 1;	// Flush-to-Zero
		u32 DN		: 1;	// Default NaN mode control
		u32 AHP		: 1;	// Alt. Half-precision
		u32 QC		: 1;	// Cumulative saturation, A.SIMD
		u32 V		: 1;	// CC Overflow
		u32 C		: 1;	// CC Carry
		u32 Z		: 1;	// CC Zero
		u32 N		: 1;	// CC Negative
	};

	enum FP_RoundingMode	// A.SIMD Always uses RN !
	{
		RN,	// Round to Nearest
		RP,	// Round towards Plus Infinity
		RM,	// Round towards Minus Infinity
		RZ	// Round towards Zero
	};


	struct MVFR0
	{
		u32 A_SIMD	: 4;
		u32 Single	: 4;
		u32 Double	: 4;
		u32 Trap	: 4;
		u32 Divide	: 4;
		u32 Sqrt	: 4;
		u32 ShortVec: 4;
		u32 Rounding: 4;
	};

	struct MVFR1
	{
		u32 FtZ_mode	: 4;
		u32 D_NaN_mode	: 4;
		u32 NFP_LdStr	: 4;
		u32 NFP_int		: 4;
		u32 NFP_SPFP	: 4;
		u32 NFP_HPFP	: 4;
		u32 VFP_HPFP	: 4;
		u32 RAZ			: 4;

	};
};