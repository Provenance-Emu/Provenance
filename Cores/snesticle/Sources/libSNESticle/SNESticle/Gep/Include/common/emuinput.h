

/*!

    \File    emuinput.h

    \Description
        Description

    \Notes
        None.

    \Copyright
        (c) 2004 Icer Addis

*/


#ifndef _emuinput_h
#define _emuinput_h

/*-- Include files -------------------------------------------------------------------------------*/

#include <stdlib.h>

namespace Emu {

/*-- Preprocessor Definitions --------------------------------------------------------------------*/
    
#define EMUSYS_DEVICE_NUM (5)
#define EMUSYS_DEVICE_DISCONNECTED 0xFFFF

/*-- Type Definitions ----------------------------------------------------------------------------*/

struct SysInputT
{
	Uint16	uPad[EMUSYS_DEVICE_NUM];
};

/*-- Variables -----------------------------------------------------------------------------------*/

/*-- Functions -----------------------------------------------------------------------------------*/

} // namespace
#endif // _emuinput_h

