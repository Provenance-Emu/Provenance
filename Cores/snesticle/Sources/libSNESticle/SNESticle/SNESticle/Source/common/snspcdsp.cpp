
#include <string.h>
#include "types.h"
#include "prof.h"
#include "snspcdsp.h"
#include "console.h"

#define SNSPCDSP_DETERMINISMSAFE (0)
#define SNSPCDSP_DEBUGPRINT (CODE_DEBUG && FALSE)


//
//
//


SNSpcDsp::SNSpcDsp()
{
}

void SNSpcDsp::Reset()
{
	memset(m_Regs, 0, sizeof(m_Regs));
	m_Regs[SNSPCDSP_REG_FLG] = 0x40;
	m_Queue.Reset();
}

void SNSpcDsp::Write8(Uint32 uAddr, Uint8 uData)
{
	Int32 iChannel;

	uAddr &= 0x7F;

//	if (uAddr==SNSPCDSP_REG_FLG) // && uData != m_Regs[uAddr])
//		ConDebug("flg %02X\n", uData);

#if SNSPCDSP_DEBUGPRINT
	if (m_Regs[uAddr] != uData)
		ConDebug("dsp[%02X] %02X\n", uAddr, uData);
#endif

	m_Regs[uAddr] = uData;

	switch (uAddr)
	{
	case SNSPCDSP_REG_FLG:
		if (uData & 0x80)
		{
			// soft reset
			m_Regs[SNSPCDSP_REG_FLG] |= 0x40 | 0x20; // enable mute, disable echo
			m_Regs[SNSPCDSP_REG_KOFF] = 0;
			m_Regs[SNSPCDSP_REG_KON] = 0;
	    	m_Regs[SNSPCDSP_REG_ENDX] = 0;
		}
		break;
    case SNSPCDSP_REG_KON:
		// if a channel has keyoff set, it can't be keyed on

		//uData &=  ~m_Regs[SNSPCDSP_REG_KOFF];
		if (uData != 0)
		{
#if SNSPCDSP_DEBUGPRINT
			ConDebug("kon: %02X\n", uData);
#endif

			for (iChannel=0; iChannel < SNSPCDSP_CHANNEL_NUM; iChannel++)
			{
				if ((uData>>iChannel)&1)
					KeyOn(iChannel);
			}
		}
		break;
    case SNSPCDSP_REG_ENDX:
        // reset endx
    	m_Regs[SNSPCDSP_REG_ENDX] = 0;
        break;
	case SNSPCDSP_REG_KOFF:
		//ConDebug("koff: %02X\n", uData);
		if (uData != 0)
		{
			for (iChannel=0; iChannel < SNSPCDSP_CHANNEL_NUM; iChannel++)
			{
				if ((uData>>iChannel)&1)
					KeyOff(iChannel);
			}
		}
		break;
	default:
		#if SNSPCDSP_DEBUGPRINT
		ConDebug("dsp[%02X] %02X\n", uAddr, uData);
		#endif
		break;
	}

}


Uint8 SNSpcDsp::Read8(Uint32 uAddr)
{
#if SNSPCDSP_DEBUGPRINT
	ConDebug("read_dsp[%02X]\n", uAddr);
#endif

	uAddr &= 0x7F;

#if SNSPCDSP_DETERMINISMSAFE
	// short-circuit registers that will violate determinism
	switch (uAddr)
	{
	case 0x00 + SNSPCDSP_REG_ENVX:
	case 0x10 + SNSPCDSP_REG_ENVX:
	case 0x20 + SNSPCDSP_REG_ENVX:
	case 0x30 + SNSPCDSP_REG_ENVX:
	case 0x40 + SNSPCDSP_REG_ENVX:
	case 0x50 + SNSPCDSP_REG_ENVX:
	case 0x60 + SNSPCDSP_REG_ENVX:
	case 0x70 + SNSPCDSP_REG_ENVX:
		return 0;

	case 0x00 + SNSPCDSP_REG_OUTX:
	case 0x10 + SNSPCDSP_REG_OUTX:
	case 0x20 + SNSPCDSP_REG_OUTX:
	case 0x30 + SNSPCDSP_REG_OUTX:
	case 0x40 + SNSPCDSP_REG_OUTX:
	case 0x50 + SNSPCDSP_REG_OUTX:
	case 0x60 + SNSPCDSP_REG_OUTX:
	case 0x70 + SNSPCDSP_REG_OUTX:
		return 0;

		// this violates determinism
    case SNSPCDSP_REG_KON:
	case SNSPCDSP_REG_KOFF:
		return 0;

		// this violates determinism
    case SNSPCDSP_REG_ENDX:
		return 0x0;
	}
#endif

	return m_Regs[uAddr];
}

Uint16 SNSpcDsp::GetSampleDir(Uint8 uSrcN, Uint32 uOffset)
{
	Uint16 uSampleDir;
	Uint16 uData;

	// get sample dir address
	uSampleDir =  m_Regs[SNSPCDSP_REG_DIR] * 0x100 + uSrcN * 0x04;
	uSampleDir+= uOffset;

	// read word from sample directory
	uData = m_pMem[uSampleDir + 0] << 0;
	uData|= m_pMem[uSampleDir + 1] << 8;
	return uData;
}


void SNSpcDsp::KeyOn(Int32 iChannel)
{
	// clear endx
	m_Regs[SNSPCDSP_REG_ENDX] &=  ~(1 << iChannel);

	// tell mixer(s) to key on
	if (m_pMixer[0])
		m_pMixer[0]->KeyOn(iChannel);
	if (m_pMixer[1])
		m_pMixer[1]->KeyOn(iChannel);
}


void SNSpcDsp::KeyOff(Int32 iChannel)
{
	// tell mixer(s) to key off
	if (m_pMixer[0])
		m_pMixer[0]->KeyOff(iChannel);
	if (m_pMixer[1])
		m_pMixer[1]->KeyOff(iChannel);
}


Bool SNSpcDsp::EnqueueWrite(Uint32 uCycle, Uint32 uAddr, Uint8 uData)
{
	return m_Queue.Enqueue(uCycle, uAddr, uData);
}

void SNSpcDsp::Sync(Uint32 uCycle)
{
	SNQueueElementT *pElement;

	// dequeue all pending writes  up to cycle time
	while ( (pElement=m_Queue.Dequeue(uCycle)) != NULL)
	{
		// perform write
		Write8(pElement->uAddr, pElement->uData);
	}
}

void SNSpcDsp::Sync(void)
{
	SNQueueElementT *pElement;

	// dequeue all pending writes
	while ( (pElement=m_Queue.Dequeue()) != NULL)
	{
		// perform write
		Write8(pElement->uAddr, pElement->uData);
	}

	// empty queue
	m_Queue.Reset();
}

void SNSpcDsp::UpdateFlags(ISNSpcDspMix *pMixer)
{
	Int32 iChannel;
	
	for (iChannel=0; iChannel < SNSPCDSP_CHANNEL_NUM; iChannel++)
	{
		SNSpcVoiceRegsT *pRegs = (SNSpcVoiceRegsT *)GetVoiceRegs(iChannel);

		if (pMixer)
		{
			// query mixer to get state of channel
			// the mixer provides feedback to the DSP so it can be a source of determinism problems
			if (pMixer->GetChannelState(iChannel, &pRegs->envx, &pRegs->outx))
			{
				// channel just turned off
				m_Regs[SNSPCDSP_REG_ENDX] |=   1 << iChannel;
				// clear key on/off for channel
				m_Regs[SNSPCDSP_REG_KON]  &= ~(1 << iChannel);
				m_Regs[SNSPCDSP_REG_KOFF] &= ~(1 << iChannel);
			}
			
		} else
		{
			pRegs->envx = 0;
			pRegs->outx = 0;
		}
	}
}

