
#include "types.h"
#include "profctr.h"

// Performance Counter Control register
#define PC_S_CTE    (31)
#define PC_S_EVENT1 (15)
#define PC_S_U1     (14)
#define PC_S_S1     (13)
#define PC_S_K1     (12)
#define PC_S_EXL1   (11)
#define PC_S_EVENT0 (5)
#define PC_S_U0     (4)
#define PC_S_S0     (3)
#define PC_S_K0     (2)
#define PC_S_EXL0   (1)



void ProfCtrStartCounter(Uint32 uType0, Uint32 uType1)
{
    Uint32 pcc = 0;
    
    pcc |= (1<<PC_S_CTE);
    pcc |= (1<<PC_S_U1) | (1<<PC_S_S1) | (1<<PC_S_K1);
    pcc |= (1<<PC_S_U0) | (1<<PC_S_S0) | (1<<PC_S_K0);
    pcc |= (uType1<<PC_S_EVENT1);
    pcc |= (uType0<<PC_S_EVENT0);
    
	__asm__ volatile ("mtc0  %0, $25" : : "r" (pcc) );    

/*
	__asm__ volatile ("mtps  %0, 0" : : "r" (uType0 | 0x80000000) );    
	__asm__ volatile ("mtps  %0, 1" : : "r" (uType1 | 0x80000000) );    
    */
	__asm__ volatile ("sync.p" : : );    
}


void ProfCtrInit()
{
    ProfCtrStartCounter(6, 6);
}

void ProfCtrShutdown()
{
}


void ProfCtrReset()
{
	__asm__ volatile ("mtpc  $0, 0" : : );    
	__asm__ volatile ("mtpc  $0, 1" : : );    
	__asm__ volatile ("sync.p" : : );    
}

