
#ifndef _SNDMA_H
#define _SNDMA_H

struct SNCpu_t;
class SnesPPU;

#define SNESDMAC_CHANNEL_NUM 8

struct SnesDMAChT
{
	Uint8	dmapx;
	Uint8	bbadx;
	Uint16	a1tx;
	Uint16	dasx;
	Uint8	a1bx;
	Uint8	dasbx;
	Uint16	a2ax;
	Uint8	ntlrx;
	Uint8	unknown;
};

class SnesDMAC
{
public:
	void                        SetCPU(SNCpu_t *pCPU) {m_pCPU = pCPU;}
	void                        SetPPU(SnesPPU *pPPU) {m_pPPU = pPPU;}

	void                        Reset();
	void                        SaveState(struct SNStateDMACT *pState);
	void                        RestoreState(struct SNStateDMACT *pState);

	void                        ProcessMDMA();
	void                        BeginHDMA();
	void                        ProcessHDMA();

	Uint8                       Read8(Uint32 uChan, Uint32 uAddr);
	void                        Write8(Uint32 uChan, Uint32 uAddr, Uint8 uData);
	void                        SetMDMAEnable(Uint8 uData);
	void                        SetHDMAEnable(Uint8 uData);
	Uint8                       GetMDMAEnable() {return m_MDMAEnable;}
	Uint8                       GetHDMAEnable() {return m_HDMAEnable;}

private:
	SnesDMAChT	                m_Channels[SNESDMAC_CHANNEL_NUM];
	Uint8		                m_MDMAEnable;
	Uint8		                m_HDMAEnable;		// hdma channel enable

	SNCpu_t	*                   m_pCPU;
	SnesPPU	*                   m_pPPU;

	void                        TransferData(SnesDMAChT *pChan, Uint8 *pData, Int32 nBytes);
	void                        ProcessMDMAChRead(Uint32 uChan);
	void                        ProcessMDMAChFast(Uint32 uChan);
	Uint32                      ProcessHDMACh(Uint32 uChan);

    //Uint32 ProcessMDMACh(Uint32 uChan);
};



#endif
