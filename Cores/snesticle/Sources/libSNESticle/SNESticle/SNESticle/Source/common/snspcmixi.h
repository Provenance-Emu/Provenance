
#ifndef _SNSPCMIXI_H
#define _SNSPCMIXI_H

class SNSpcDsp;

// mixer interface
class ISNSpcDspMix 
{
	protected:
	SNSpcDsp	*m_pDsp;

public:
	void	SetDsp(SNSpcDsp *pDsp) {m_pDsp = pDsp;}
	SNSpcDsp *GetDsp() {return m_pDsp;}

	virtual Bool	GetChannelState(Int32 iChannel, Uint8 *pEnvX, Uint8 *pOutX) = 0;
	virtual void	KeyOn(Int32 iChannel) = 0;
	virtual void	KeyOff(Int32 iChannel) = 0;
	virtual void	Mix(class CMixBuffer *pOutBuffer) = 0;
};



class SNSpcDspMixNull  : public ISNSpcDspMix
{
public:
	virtual Bool	GetChannelState(Int32 iChannel, Uint8 *pEnvX, Uint8 *pOutX) {*pEnvX = 0; *pOutX = 0; return FALSE;}
	virtual void	KeyOn(Int32 iChannel) {};
	virtual void	KeyOff(Int32 iChannel) {};
	virtual void	Mix(class CMixBuffer *pOutBuffer) {};
};

#endif
