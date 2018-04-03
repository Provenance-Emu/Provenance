#ifndef __MDFN_NES_UNIF_H
#define __MDFN_NES_UNIF_H

int BioMiracleA_Init(CartInfo *info) MDFN_COLD;

int TCU01_Init(CartInfo *info) MDFN_COLD;
int S8259B_Init(CartInfo *info) MDFN_COLD;
int S8259A_Init(CartInfo *info) MDFN_COLD;
int S74LS374N_Init(CartInfo *info) MDFN_COLD;
int SA0161M_Init(CartInfo *info) MDFN_COLD;

int SA72007_Init(CartInfo *info) MDFN_COLD;
int SA72008_Init(CartInfo *info) MDFN_COLD;
int SA0036_Init(CartInfo *info) MDFN_COLD;
int SA0037_Init(CartInfo *info) MDFN_COLD;

int H2288_Init(CartInfo *info) MDFN_COLD;
int UNL8237_Init(CartInfo *info) MDFN_COLD;

namespace MDFN_IEN_NES
{

int ETROM_Init(CartInfo *info) MDFN_COLD;
int EKROM_Init(CartInfo *info) MDFN_COLD;
int ELROM_Init(CartInfo *info) MDFN_COLD;
int EWROM_Init(CartInfo *info) MDFN_COLD;

int SAROM_Init(CartInfo *info) MDFN_COLD;
int SBROM_Init(CartInfo *info) MDFN_COLD;
int SCROM_Init(CartInfo *info) MDFN_COLD;
int SEROM_Init(CartInfo *info) MDFN_COLD;
int SGROM_Init(CartInfo *info) MDFN_COLD;
int SKROM_Init(CartInfo *info) MDFN_COLD;
int SLROM_Init(CartInfo *info) MDFN_COLD;
int SL1ROM_Init(CartInfo *info) MDFN_COLD;
int SNROM_Init(CartInfo *info) MDFN_COLD;
int SOROM_Init(CartInfo *info) MDFN_COLD;

int TEROM_Init(CartInfo *info) MDFN_COLD;
int TFROM_Init(CartInfo *info) MDFN_COLD;
int TGROM_Init(CartInfo *info) MDFN_COLD;
int TKROM_Init(CartInfo *info) MDFN_COLD;
int TSROM_Init(CartInfo *info) MDFN_COLD;
int TLROM_Init(CartInfo *info) MDFN_COLD;
int TLSROM_Init(CartInfo *info) MDFN_COLD;
int TKSROM_Init(CartInfo *info) MDFN_COLD;
int TQROM_Init(CartInfo *info) MDFN_COLD;
int TQROM_Init(CartInfo *info) MDFN_COLD;

int NROM_Init(CartInfo *info) MDFN_COLD;
int NROM256_Init(CartInfo *info) MDFN_COLD;
int NROM128_Init(CartInfo *info) MDFN_COLD;
int MHROM_Init(CartInfo *info) MDFN_COLD;
int UNROM_Init(CartInfo *info) MDFN_COLD;
int CNROM_Init(CartInfo *info) MDFN_COLD;
int CPROM_Init(CartInfo *info) MDFN_COLD;
int GNROM_Init(CartInfo *info) MDFN_COLD;
int AOROM_Init(CartInfo *info) MDFN_COLD;
int BTR_Init(CartInfo *info) MDFN_COLD;
int HKROM_Init(CartInfo *info) MDFN_COLD;
int UNL6035052_Init(CartInfo *info) MDFN_COLD;

int MMC4_Init(CartInfo *info) MDFN_COLD;
int PNROM_Init(CartInfo *info) MDFN_COLD;

int AGCI50282_Init(CartInfo *info) MDFN_COLD;

int BIC48_Init(CartInfo *info) MDFN_COLD;
int BIC62_Init(CartInfo *info) MDFN_COLD;

int NINA06_Init(CartInfo *info) MDFN_COLD;

}

int MALEE_Init(CartInfo *info) MDFN_COLD;
int Supervision16_Init(CartInfo *info) MDFN_COLD;
int Super24_Init(CartInfo *info) MDFN_COLD;
int Novel_Init(CartInfo *info) MDFN_COLD;

namespace MDFN_IEN_NES
{
extern uint8 *UNIFchrrama;	// Meh.  So I can stop CHR RAM 
	 			// bank switcherooing with certain boards...
}

#endif
