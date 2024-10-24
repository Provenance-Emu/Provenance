
#ifndef _MEMSPACE_H
#define _MEMSPACE_H

#include <stdio.h>

class CMemSpace
{
	Uint32	m_uSize;		// size of memory space
	Uint8	*m_pMem;		// pointer to memory
	Uint8	*m_pMemAlloc;	// pointer to memory that was allocated

	Uint32	m_uBankShift;	// bank size
public:
	CMemSpace();
	~CMemSpace();

	void	SetBankShift(Uint32 uBankShift) {m_uBankShift = uBankShift;}

	Uint32	GetNumBanks() {return m_uSize >> m_uBankShift;}
	Uint8	*GetBank(Uint32 iBank)
	{
		Uint32 Addr = iBank << m_uBankShift;
		return (Addr < m_uSize) ? (m_pMem + Addr) : NULL;
	}

	void	Clear(Uint8 Value);

	Uint8	ReadByte(Uint32 uAddr) {return m_pMem[uAddr];}

	Uint8	*GetMem() {return m_pMem;}
	Uint32	GetSize() {return m_uSize;}

	void	SetMem(Uint8 *pMem, Uint32 uSize);
	void	Alloc(Uint32 uSize);
	void	Free();

	bool	ReadFile(FILE *pFile);
	bool	WriteFile(FILE *pFile);

	bool	ReadFile(class CDataIO *pFile);
	bool	WriteFile(class CDataIO *pFile);

	bool	ReadAllocFile(class CDataIO *pFile, Uint32 nBytes);

	void	SaveState(Uint8 *pData, Uint32 uDataSize);
	void	RestoreState(Uint8 *pData, Uint32 uDataSize);
};


#endif
