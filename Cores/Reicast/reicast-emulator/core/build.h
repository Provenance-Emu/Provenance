/*
	reicast build options

		Reicast can support a lot of stuff, and this is an attempt
		to organize the build time options

		Option categories

			BUILD_* - BUILD_COMPILER, etc...
				definitions about the build machine

			HOST_*	
				definitions about the host machine

			FEAT_*
				definitions about the features that this build targets
				This is higly related to HOST_*, but it's for options that might
				or might not be avaiable depending on the target host, or that 
				features that are irrelevant of	the host

				Eg, Alsa, Pulse Audio and OSS might sense as HOST dedinitions
				but it usually makes more sense to detect them as runtime. In
				that context, HOST_ALSA makes no sense because the host might
				or might not have alsa installed/ running

				MMU makes no sense as a HOST definition at all, so it should
				be FEAT_HAS_MMU

			TARGET_*
				A preconfigured default. Eg TARGET_WIN86. 

		Naming of options, option values, and how to use them
			
			for options that makes sense to have a list of values
				{CATEGORY}_{OPTION} 
				{OPTION}_{VALUE}

				eg.
				BUILD_COMPILER == COMPILER_GCC, HOST_CPU != CPU_X64, ...

			for options that are boolean
				{CATEGORY}_IS_{OPTION} or {CATEGORY}_HAS_{OPTION} 
				
				Evaluates to 0 or 1

			If an configuration cannot be neatly split into a set of
			of orthogonal options, then it makes sense to break things
			to "sets" or have a hierarchy of options. 

			Example
			-------
			
			In the beggining it made sense to have an audio backend
			per operating system. It made sense to have it depend 
			on HOST_OS and seleect DirectSound or alsa. 

				// no option needed

			Then, as android was introduced, which also uses OS_LINUX
			atm, the audio could have been made an option. It could be
			a HOST_* option, or FEAT_* one. I'd prefer FEAT_*. 
			FEAT_* makes more sense as future wise we might want
			to support multiple backends.
				
				FEAT_AUDIO_BACKEND
					AUDIO_BACKEND_NONE
					AUDIO_BACKEND_DS
					AUDIO_BACKEND_ALSA
					AUDIO_BACKEND_ANDROID

				Used like
					#if FEAT_AUDIO_BACKEND == AUDIO_BACKEND_DS ....
			
			At some point, we might have multiple audio backends that
			can be compiled in and autodetected/selected at runtime.
			In that case, it might make sense to have the options like

					FEAT_HAS_ALSA
					FEAT_HAS_DIRECTSOUND
					FEAT_HAS_ANDROID_AUDIO

				or 
					FEAT_HAS_AUDIO_ALSA
					FEAT_HAS_AUDIO_DS
					FEAT_HAS_AUDIO_ANDROID

				The none option might or might not make sense. In this
				case it can be removed, as it should always be avaiable.

			Guidelines
			----------

			General rule of thumb, don't overcomplicate things. Start
			with a simple option, and then make it more complicated
			as new uses apply (see the example above)

			Don't use too long names, don't use too cryptic names. 
			Most team developers should be able to understand or
			figure out most of the acronyms used. 

			Try to be consistent on the acronyms across all definitions

			Code shouldn't depend on build level options whenever possible

			Generally, the file should compile even if the option/module is
			disabled. This makes makefiles etc much easier to write

			TARGET_* options should generally only be used in this file

			The current source is *not* good example of these guidelines

		We'll try to be smart and figure out some options/defaults on this file
		but this shouldn't get too complicated


*/

#define NO_MMU

#define DC_PLATFORM_MASK        7
#define DC_PLATFORM_DREAMCAST   0   /* Works, for the most part */
#define DC_PLATFORM_DEV_UNIT    1   /* This is missing hardware */
#define DC_PLATFORM_NAOMI       2   /* Works, for the most part */ 
#define DC_PLATFORM_NAOMI2      3   /* Needs to be done, 2xsh4 + 2xpvr + custom TNL */
#define DC_PLATFORM_ATOMISWAVE  4   /* Needs to be done, DC-like hardware with possibly more ram */
#define DC_PLATFORM_HIKARU      5   /* Needs to be done, 2xsh4, 2x aica , custom vpu */
#define DC_PLATFORM_AURORA      6   /* Needs to be done, Uses newer 300 mhz sh4 + 150 mhz pvr mbx SoC */


//HOST_OS
#define OS_WINDOWS   0x10000001
#define OS_LINUX     0x10000002
#define OS_DARWIN    0x10000003

//HOST_CPU
#define CPU_X86      0x20000001
#define CPU_ARM      0x20000002
#define CPU_MIPS     0x20000003
#define CPU_X64      0x20000004
#define CPU_GENERIC  0x20000005 //used for pnacl, emscripten, etc

//BUILD_COMPILER
#define COMPILER_VC  0x30000001
#define COMPILER_GCC 0x30000002

//FEAT_SHREC, FEAT_AREC, FEAT_DSPREC
#define DYNAREC_NONE	0x40000001
#define DYNAREC_JIT		0x40000002
#define DYNAREC_CPP		0x40000003


//automatic

#if defined(_WIN32) && !defined(TARGET_WIN86) && !defined(TARGET_WIN64)
	#if !defined(_M_AMD64)
		#define TARGET_WIN86
	#else
		#define TARGET_WIN64
	#endif
#endif

#ifdef __GNUC__ 
	#define BUILD_COMPILER COMPILER_GCC
#else
	#define BUILD_COMPILER COMPILER_VC
#endif

//Targets
#if defined(TARGET_WIN86)
	#define HOST_OS OS_WINDOWS
	#define HOST_CPU CPU_X86
#elif defined(TARGET_WIN64)
	#define HOST_OS OS_WINDOWS
	#define HOST_CPU CPU_X64
#elif defined(TARGET_PANDORA)
	#define HOST_OS OS_LINUX
	#define HOST_CPU CPU_ARM
#elif defined(TARGET_LINUX_ARMELv7)
	#define HOST_OS OS_LINUX
	#define HOST_CPU CPU_ARM
#elif defined(TARGET_LINUX_x86)
	#define HOST_OS OS_LINUX
	#define HOST_CPU CPU_X86
#elif defined(TARGET_LINUX_x64)
	#define HOST_OS OS_LINUX
	#define HOST_CPU CPU_X64
#elif defined(TARGET_LINUX_MIPS)
	#define HOST_OS OS_LINUX
	#define HOST_CPU CPU_MIPS
#elif defined(TARGET_GCW0)
	#define HOST_OS OS_LINUX
	#define HOST_CPU CPU_MIPS
#elif defined(TARGET_NACL32) || defined(TARGET_EMSCRIPTEN)
	#define HOST_OS OS_LINUX
	#define HOST_CPU CPU_GENERIC
#elif defined(TARGET_IPHONE)
    #define HOST_OS OS_DARWIN
//    #ifdef __LP64__
        #define HOST_CPU CPU_GENERIC
//    #else
//        #define HOST_CPU CPU_ARM
//    #endif
#elif defined(TARGET_IPHONE_SIMULATOR)
    #define HOST_OS OS_DARWIN
    #define HOST_CPU CPU_GENERIC
#elif defined(TARGET_OSX)
    #define HOST_OS OS_DARWIN
    #define HOST_CPU CPU_GENERIC
#else
	#error Invalid Target: TARGET_* not defined
#endif

#if defined(TARGET_NAOMI)
	#define DC_PLATFORM DC_PLATFORM_NAOMI
	#undef TARGET_NAOMI
#endif

#if defined(TARGET_NO_REC)
#define FEAT_SHREC DYNAREC_NONE
#define FEAT_AREC DYNAREC_NONE
#define FEAT_DSPREC DYNAREC_NONE
#endif

#if defined(TARGET_NO_AREC)
#define FEAT_SHREC DYNAREC_JIT
#define FEAT_AREC DYNAREC_NONE
#define FEAT_DSPREC DYNAREC_NONE
#endif

#if defined(TARGET_NO_JIT)
#define FEAT_SHREC DYNAREC_CPP
#define FEAT_AREC DYNAREC_NONE
#define FEAT_DSPREC DYNAREC_NONE
#endif


#if defined(TARGET_NO_NIXPROF)
#define FEAT_HAS_NIXPROF 0
#endif

#if defined(TARGET_NO_COREIO_HTTP)
#define FEAT_HAS_COREIO_HTTP 0
#endif

#if defined(TARGET_SOFTREND)
	#define FEAT_HAS_SOFTREND 1
#endif

//defaults

#ifndef DC_PLATFORM 
	#define DC_PLATFORM DC_PLATFORM_DREAMCAST
#endif

#ifndef FEAT_SHREC
	#define FEAT_SHREC DYNAREC_JIT
#endif

#ifndef FEAT_AREC
	#if HOST_CPU == CPU_ARM || HOST_CPU == CPU_X86
		#define FEAT_AREC DYNAREC_JIT
	#else
		#define FEAT_AREC DYNAREC_NONE
	#endif
#endif

#ifndef FEAT_DSPREC
	#if HOST_CPU == CPU_X86
		#define FEAT_DSPREC DYNAREC_JIT
	#else
		#define FEAT_DSPREC DYNAREC_NONE
	#endif
#endif

#ifndef FEAT_HAS_NIXPROF
  #if HOST_OS != OS_WINDOWS
    #define FEAT_HAS_NIXPROF 1
  #endif
#endif

#ifndef FEAT_HAS_COREIO_HTTP
	#define FEAT_HAS_COREIO_HTTP 1
#endif

#ifndef FEAT_HAS_SOFTREND
	#define FEAT_HAS_SOFTREND BUILD_COMPILER == COMPILER_VC	//GCC wants us to enable sse4 globaly to enable intrins
#endif

//Depricated build configs
#ifdef HOST_NO_REC
#error Dont use HOST_NO_REC
#endif

#ifdef HOST_NO_AREC
#error Dont use HOST_NO_AREC
#endif
