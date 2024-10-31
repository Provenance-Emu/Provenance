

/*!

    \File    emurom.h

    \Description
        Description

    \Notes
        None.

    \Copyright
        (c) 2004 Icer Addis

*/


#ifndef _emurom_h
#define _emurom_h

/*-- Include files -------------------------------------------------------------------------------*/

class CDataIO;

namespace Emu {
/*-- Preprocessor Definitions --------------------------------------------------------------------*/

/*-- Type Definitions ----------------------------------------------------------------------------*/

class Rom
{
public:
    enum LoadErrorE
    {
        LOADERROR_NONE,
        LOADERROR_INVALID,
        LOADERROR_OPENFILE,
        LOADERROR_BADHEADERSIZE,
        LOADERROR_BADROMSIZE,
        LOADERROR_READFILE,
        LOADERROR_NOCARTINFO,
        LOADERROR_OUTOFSPACE,
    };

public:
                                Rom();
    virtual                     ~Rom();

    Bool 	                    IsLoaded()                                                 {return m_bLoaded;}

    virtual LoadErrorE          LoadRom(CDataIO *pFileIO, Uint8 *pBuffer = NULL, Uint32 nBufferBytes = 0) = 0;
    virtual void                Unload() = 0;

    virtual Uint32              GetNumExts() = 0;
    virtual Char *              GetExtName(Uint32 uExt) = 0;
    virtual Uint32	            GetNumRomRegions() = 0;
    virtual Char *              GetRomRegionName(Uint32 uRegion) = 0;
    virtual Uint32              GetRomRegionSize(Uint32 uRegion) = 0;
    virtual Char *              GetMapperName() = 0;
	virtual Char *              GetRomTitle() {return NULL;}
protected:
    Bool		                m_bLoaded;
};

/*-- Variables -----------------------------------------------------------------------------------*/

/*-- Functions -----------------------------------------------------------------------------------*/

} // namespace
#endif // _emurom_h
