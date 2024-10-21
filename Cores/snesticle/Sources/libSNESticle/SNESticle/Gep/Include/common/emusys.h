

/*!

    \File    emusys.h

    \Description
        Description

    \Notes
        None.

    \Copyright
        (c) 2004 Icer Addis

*/


#ifndef _emusys_h
#define _emusys_h

/*-- Include files -------------------------------------------------------------------------------*/

#include <stdlib.h>
#include "emuinput.h"

class CRenderSurface;
class CMixBuffer; 

namespace Emu {
/*-- Preprocessor Definitions --------------------------------------------------------------------*/

/*-- Type Definitions ----------------------------------------------------------------------------*/

class System
{
public:
    enum ModeE
    {
        MODE_INACCURATEDETERMINISTIC,
        MODE_ACCURATENONDETERMINISTIC,
        MODE_ACCURATEDETERMINISTIC,
    };

    enum StringE
    {
        STRING_SHORTNAME,
        STRING_FULLNAME,
        STRING_SRAMEXT,
        STRING_STATEEXT,
    };

public:
                                System();
    virtual                     ~System();

	Uint32	                    GetLine()									{return m_uLine;}
	Uint32	                    GetFrame()									{return m_uFrame;}

	virtual void 				SetRom(class Rom *pRom) = 0;
    virtual void 				Reset() = 0;
    virtual void 				SoftReset() = 0;

	virtual void				ExecuteFrame(SysInputT *pInput, CRenderSurface *pTarget, CMixBuffer *pMixBuf, ModeE eMode) = 0;
																											   
	virtual Int32				GetStateSize()=0;
	virtual void				SaveState(void *pState, Int32 nStateBytes) = 0;
	virtual void				RestoreState(void *pState, Int32 nStateBytes) = 0;

    virtual Int32				GetSRAMBytes()								{return 0;}
    virtual Uint8 *				GetSRAMData()								{return NULL;}

	virtual char *				GetString(StringE eString)					{return "";}
	virtual Uint32				GetSampleRate()								{return 0;}

protected:
    Uint32						m_uLine;
    Uint32						m_uFrame;		// current frame
};



/*-- Variables -----------------------------------------------------------------------------------*/

/*-- Functions -----------------------------------------------------------------------------------*/

} // namespace
#endif // _emusys_h


