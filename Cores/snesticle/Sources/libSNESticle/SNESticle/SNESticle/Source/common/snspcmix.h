

#ifndef _SNSPCMIX_H
#define _SNSPCMIX_H

#if CODE_PLATFORM == CODE_PS2
//#define SNSPCDSP_MAXSAMPLES 400
//#define SNSPCDSP_BUFFERSIZE 400
#define SNSPCDSP_MAXSAMPLES 544/8
#define SNSPCDSP_BUFFERSIZE 544
//#define SNSPCDSP_MAXSAMPLES 800
//#define SNSPCDSP_BUFFERSIZE 800

#else
//#define SNSPCDSP_MAXSAMPLES 800*4
#define SNSPCDSP_MAXSAMPLES 544/8
#define SNSPCDSP_BUFFERSIZE (SNSPCDSP_MAXSAMPLES)
#endif


class    SNSpcDspMix : public ISNSpcDspMix
{
	SNSpcChannelT	m_Channels[SNSPCDSP_CHANNEL_NUM];

protected:
	// envelope parameters
	Uint32			m_nSampleRate;
	Uint32			m_AttackTicks[16];
	Uint32			m_DecayTicks[8];
	Uint32			m_SustainTicks[32];
	Uint32			m_LinearTicks[32];
	Uint32			m_BentLineTicks[32];

protected:
	SNSpcChannelT  *GetChannel(Int32 iChannel) {return &m_Channels[iChannel]; }
	void	BuildLookupTables(Uint32 nSampleRate);
	Int32	OutputEnvelope(Int32 iChannel, Uint8 *pOut, Int32 nSamples);

public:
	virtual Bool	GetChannelState(Int32 iChannel, Uint8 *pEnvX, Uint8 *pOutX);
	virtual void	KeyOn(Int32 iChannel);
	virtual void	KeyOff(Int32 iChannel);

	void	Reset();
	void	SaveState(struct SNStateSPCDSPT *pState);
	void	RestoreState(struct SNStateSPCDSPT *pState);
};


class SNSpcDspMixSilent : public SNSpcDspMix
{
	void	FetchBlock(Int32 iChannel);
	Int32	OutputSample(Int32 iChannel, Int32 nSamples, Int32 nSampleRate);
public:

	void	Mix(class CMixBuffer *pOutBuffer);
};

class    SNSpcDspMixFull : public SNSpcDspMix
{
	SNSpcEchoT		m_Echo;
	Int16			m_EchoBuffer[SNSPCDSP_ECHOBUFFER_SIZE];

	Int32			m_iNoisePhase;
	Uint32			m_uNoiseGen;
	Int16			m_iNoiseSample[SNSPCDSP_BUFFERSIZE*2];
	Uint16			m_iNoiseFrac[SNSPCDSP_BUFFERSIZE];

	void	FetchBlock(Int32 iChannel);
	void	RefreshBlock(Int32 iChannel);
	Int32	OutputSample(Int32 iChannel, Int16 *pOut, Uint16 *pFrac, Int32 nSamples, Int32 nSampleRate);
	Int32   OutputNoise(Int16 *pOut, Uint16 *pFrac, Int32 nSamples, Int32 nSampleRate);
	void	FilterEcho(Int16 *pLeftEcho, Int16 *pRightEcho, Int32 nSamples, Int32 nSampleRate, Bool bEchoSPCMem);
public:
	void	Reset();
	void	Mix(class CMixBuffer *pOutBuffer);
};



#endif
