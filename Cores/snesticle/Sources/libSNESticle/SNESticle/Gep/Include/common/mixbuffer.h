

#ifndef _MIXBUFFER_H
#define _MIXBUFFER_H

// 
// stream buffer abstract class
//

class CMixBuffer
{
public:
	virtual void	GetFormat(Uint32 *puSampleRate, Uint32 *pnSampleBits, Uint32 *pnChannels);
	virtual Int32	GetOutputSamples();
	virtual void	OutputSamplesMono(Int16 *pSamples, Int32 nSamples);
	virtual void	OutputSamplesStereo(Int16 *pLeftSamples, Int16 *pRightSamples, Int32 nSamples);
    virtual void    Flush();
};

#endif
