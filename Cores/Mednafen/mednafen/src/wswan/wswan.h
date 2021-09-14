#ifndef __WSWAN_H
#define __WSWAN_H

#include <mednafen/mednafen.h>
#include <mednafen/state.h>
#include <mednafen/general.h>

using namespace Mednafen;

#include "interrupt.h"

namespace MDFN_IEN_WSWAN
{

#define  mBCD(value) (((value)/10)<<4)|((value)%10)

MDFN_HIDE extern uint16 WSButtonStatus;
MDFN_HIDE extern uint32 WS_InDebug;
MDFN_HIDE extern uint32 rom_size;
MDFN_HIDE extern int wsc;

enum
{
 WSWAN_SEX_MALE = 1,
 WSWAN_SEX_FEMALE = 2
};

enum
{
 WSWAN_BLOOD_A = 1,
 WSWAN_BLOOD_B = 2,
 WSWAN_BLOOD_O = 3,
 WSWAN_BLOOD_AB = 4
};

}

#endif
