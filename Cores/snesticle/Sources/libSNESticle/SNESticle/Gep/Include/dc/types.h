
/*H********************************************************************

	types.h

	Description:

		Standard data type definitions

	Notes:
		None


********************************************************************H*/

#ifndef _TYPES_H
#define _TYPES_H

#include "assert.h"

#ifndef ASSERT
#define ASSERT assert
#endif 

#ifndef FALSE
#define FALSE 0
#endif

#ifndef TRUE
#define TRUE  (!FALSE)
#endif

// standard data types

typedef unsigned char	Uint8;
typedef signed char		Int8;
typedef unsigned short	Uint16;
typedef signed short	Int16;
typedef unsigned int	Uint32;
typedef signed int		Int32;
typedef char			Char;
typedef unsigned char   Bool;
typedef float			Float32;
typedef double			Float64;

#endif

