

/*!

    \File    emumovie.h

    \Description
	    Description

    \Notes
	    None.

    \Copyright
	    (c) 2004 Icer Addis

*/


#ifndef _emumovie_h
#define _emumovie_h

/*-- Include files -------------------------------------------------------------------------------*/

#include "emusys.h"

namespace Emu {
/*-- Preprocessor Definitions --------------------------------------------------------------------*/

/*-- Type Definitions ----------------------------------------------------------------------------*/

class MovieClip
{
public:
						MovieClip(Uint32 uStateSize, Uint32 uMaxFrames);
						~MovieClip();

    void            	RecordBegin(System *pSystem);
    void            	RecordEnd();
    Bool            	RecordFrame(SysInputT &input);
    Bool            	IsRecording() const									{return m_bRecording;}
    Uint32          	GetRecordPosition() const							{return m_nRecordedFrames;}

    void            	PlayBegin(System *pSystem);
    void            	PlayEnd();
    Bool            	PlayFrame(SysInputT &input);
    Bool            	IsPlaying() const									{return m_bPlaying;}
    Uint32          	GetPlayPosition() const								{return m_uPlayFrame;}

private:
    // state data at start of movie clip
    void *              m_pStateData;
    Uint32              m_uMaxStateSize;
    Uint32              m_uStateSize;

    // frames
    SysInputT *			m_pFrames;      
    Uint32              m_uMaxFrames;

    Bool                m_bRecording;
    Bool                m_bPlaying;

    Uint32              m_nRecordedFrames;
    Uint32              m_uPlayFrame;
};

/*-- Variables -----------------------------------------------------------------------------------*/

/*-- Functions -----------------------------------------------------------------------------------*/

} // namespace
#endif // _emumovie_h




