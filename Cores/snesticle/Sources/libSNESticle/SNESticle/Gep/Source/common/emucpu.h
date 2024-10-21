
#ifndef _EMUCPU_H
#define _EMUCPU_H




class CEmuCpu	: public CEmuThread
{


public:
	virtual Int32 Execute(Int32 nExecCycles);

	virtual void DumpRegs(Char *pStr)=0;
	virtual Int32 Disassemble(Uint32 Addr, Char *pStr, Uint8 *pFlags=NULL)=0;
	virtual Uint32 GetPC();
	
	virtual Uint8 Peek8(Uint32 Addr)=0;
	virtual void PeekMem(Uint32 uAddr, Uint8 *pBuffer, Uint32 nBytes)=0;		
};






#endif