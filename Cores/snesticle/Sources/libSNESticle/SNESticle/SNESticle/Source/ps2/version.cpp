
#include "version.h"





static const VersionInfoT _Version_Info = 
{
	// application name
	"SNESticlePS2",

	// version
	{0,3,4},

	// build type
	""
	#if CODE_DEBUG
	"Debug"
	#endif
	#if CODE_PROFILE
	"Profile"
	#endif
	,

	// elf name
	 "SLPS_999.99",

	// copy right
	"Copyright (c) 1997-2004 Icer Addis",

	// build date
	__DATE__,

	// build time
	__TIME__,	

	// compiler
	"GCC",
	
	// compiler version
	{ 
		(__GNUC__) , 
		(__GNUC_MINOR__) 
	},
};		  

const VersionInfoT *VersionGetInfo()
{
	return &_Version_Info;
}


char * VersionGetElfName()
{
	return _Version_Info.ElfName;
}

