/*
 *	H_fp.h
 *
 *		ARMv7 floating point help routines.
 */
#pragma once


			/// WIP ///



namespace ARM
{

#if defined(_DEVEL)


	/*
	 *	vfpVersion():	Returns VFP Arch. Version, or -1 if not supported
	 */
	int vfpVersion()
	{
		//	FPSID bits [22:16] contain version

		return 0;
	}

	int neonVersion()
	{
		//	??

		return 0;
	}


#define VFP_SINGLE		(1<<0)
#define VFP_DOUBLE		(1<<1)
#define NEON_INTEGER	(1<<2)
#define NEON_SINGLE		(1<<3)
#define VFP_TRAPS		(1<<8)	// VFPv3U
#define FPEXT_HALF		(1<<16)	// Half precision extension

	u32 fpFeatures()
	{


		return 0;
	}


#endif	// _DEVEL





#if 0

Version 1 of the Common VFP subarchitecture has special behavior when the FPSCR.IXE bit is set to 1.
	The Common VFP subarchitecture version can be identified by checking FPSID bits [22:16]. This field is
	0b0000001 for version 1. In version 1 of the Common VFP subarchitecture the FPEXC.DEX bit is RAZ/WI.


Detecting which VFP Common subarchitecture registers are implemented
	An implementation can choose not to implement FPINST and FPINST2, if these registers are not required.

Set FPEXC.EX=1 and FPEXC.FP2V=1
Read back the FPEXC register
if FPEXC.EX == 0 then
	Neither FPINST nor FPINST2 are implemented
else
	if FPEXC.FP2V == 0 then
		FPINST is implemented, FPINST2 is not implemented.
	else
		Both FPINST and FPINST2 are implemented.
Clean up

#endif




}


















