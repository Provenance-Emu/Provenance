/*
    genio.c
    I/O controller chip emulation
*/

#include "shared.h"
#include "input/gamepad.h"
#include "input/megamouse.h"
#include "input/multitap.h"
#include "input/4way.h"

namespace MDFN_IEN_MD
{

static bool is_pal;
static bool is_overseas;
static bool is_overseas_reported;
static bool is_pal_reported;

// 3 internal ports
enum port_names {PORT_A = 0, PORT_B, PORT_C, PORT_MAX};

static MD_Input_Device *port[PORT_MAX] = { NULL };

static uint8* data_ptr[8];
static MD_Input_Device *InputDevice[8] = { NULL };
static MD_Multitap* MultitapDevice[2] = { NULL };
static MD_4Way* Way4Device = NULL;
static unsigned MultitapEnabled;
static MD_Input_Device* DummyDevice = nullptr;

static const std::vector<InputDeviceInfoStruct> InputDeviceInfo =
{
 // None
 {
  "none",
  "none",
  NULL,
  IDII_Empty
 },

 {
  "gamepad2",
  "2-Button Gamepad",
  NULL,
  Gamepad2IDII
 },

 {
  "gamepad",
  "3-Button Gamepad",
  NULL,
  GamepadIDII
 },

 {
  "gamepad6",
  "6-Button Gamepad",
  NULL,
  Gamepad6IDII
 },

 {
  "megamouse",
  "Sega Mega Mouse",
  NULL,
  MegaMouseIDII
 },

};

const std::vector<InputPortInfoStruct> MDPortInfo =
{
 { "port1", "Virtual Port 1", InputDeviceInfo, "gamepad" },
 { "port2", "Virtual Port 2", InputDeviceInfo, "gamepad" },
 { "port3", "Virtual Port 3", InputDeviceInfo, "gamepad" },
 { "port4", "Virtual Port 4", InputDeviceInfo, "gamepad" },
 { "port5", "Virtual Port 5", InputDeviceInfo, "gamepad" },
 { "port6", "Virtual Port 6", InputDeviceInfo, "gamepad" },
 { "port7", "Virtual Port 7", InputDeviceInfo, "gamepad" },
 { "port8", "Virtual Port 8", InputDeviceInfo, "gamepad" }
};

static void UpdateBusThing(const int32 master_timestamp);

static void RebuildPortMap(void)
{
 for(unsigned pp = 0, vp = 0; pp < 2; pp++)
 {
  MD_Input_Device* nd = nullptr;

  if(MultitapEnabled == MTAP_TP_DUAL || (pp == 0 && MultitapEnabled == MTAP_TP_PRT1) || (pp == 1 && MultitapEnabled == MTAP_TP_PRT2))
  {
   nd = MultitapDevice[pp];
   for(unsigned i = 0; i < 4; i++)
   {
    MultitapDevice[pp]->SetSubPort(i, InputDevice[vp] ? InputDevice[vp] : DummyDevice);
    vp++;
   }
  }
  else if(MultitapEnabled == MTAP_4WAY)
  {
   nd = Way4Device->GetShim(pp);

   if(!pp)
   {
    for(unsigned i = 0; i < 4; i++)
    {
     Way4Device->SetSubPort(i, InputDevice[vp] ? InputDevice[vp] : DummyDevice);
     vp++;
    }
   }
  }
  else
  {
   nd = InputDevice[vp] ? InputDevice[vp] : DummyDevice;
   vp++;
  }

  if(port[pp] != nd)
  {
   port[pp] = nd;
   port[pp]->Power();
  }
 }

 port[2] = DummyDevice;
}

void MDIO_Init(bool overseas, bool PAL, bool overseas_reported, bool PAL_reported)
{
 MultitapEnabled = false;

 is_overseas = overseas;
 is_pal = PAL;
 is_overseas_reported = overseas_reported;
 is_pal_reported = PAL_reported;

 DummyDevice = new MD_Input_Device();

 Way4Device = new MD_4Way();

 for(unsigned i = 0; i < 2; i++)
  MultitapDevice[i] = new MD_Multitap();

 for(unsigned i = 0; i < 8; i++)
  InputDevice[i] = nullptr;

 RebuildPortMap();

 UpdateBusThing(md_timestamp);
}

void MDIO_Kill(void)
{
 if(DummyDevice)
 {
  delete DummyDevice;
  DummyDevice = nullptr;
 }

 if(Way4Device)
 {
  delete Way4Device;
  Way4Device = nullptr;
 }

 for(unsigned i = 0; i < 2; i++)
 {
  if(MultitapDevice[i])
  {
   delete MultitapDevice[i];
   MultitapDevice[i] = nullptr;
  }
 }

 for(unsigned i = 0; i < 8; i++)
 {
  if(InputDevice[i])
  {
   delete InputDevice[i];
   InputDevice[i] = nullptr;
  }
 }
}

void MDINPUT_SetMultitap(unsigned type)
{
 MultitapEnabled = type;

 RebuildPortMap();
}

static uint8 PortData[3];
static uint8 PortDataBus[3];
static uint8 PortCtrl[3];
static uint8 PortTxData[3];
static uint8 PortSCtrl[3];

static void UpdateBusThing(const int32 master_timestamp)
{
 for(int i = 0; i < PORT_MAX; i++)
 {
  PortDataBus[i] &= ~PortCtrl[i];
  PortDataBus[i] |= PortData[i] & PortCtrl[i];
  port[i]->UpdateBus(master_timestamp, PortDataBus[i], PortCtrl[i] & 0x7F);
 }
}


void gen_io_reset(void)
{
 for(int i = 0; i < 3; i++)
 {
  PortDataBus[i] = 0x7F;
  PortData[i] = 0x00;
  PortCtrl[i] = 0x00;
  PortTxData[i] = 0xFF;
  PortSCtrl[i] = 0x00;
  port[i]->Power();
 }

 PortTxData[2] = 0xFB;

 UpdateBusThing(0);

 for(int i = 0; i < 3; i++)
 {
  port[i]->Power();	// Power before and after UpdateBusThing()
 }
}

/*--------------------------------------------------------------------------*/
/* I/O chip functions                                                       */
/*--------------------------------------------------------------------------*/

void gen_io_w(int offset, int value)
{
    //printf("I/O Write: %04x:%04x, %d @ %08x\n", offset, value, md_timestamp, C68k_Get_PC(&Main68K));

    switch(offset)
    {
        case 0x01: /* Port A Data */
	case 0x02: /* Port B Data */
	case 0x03: /* Port C Data */
	    {
	     int wp = offset - 0x01;
             PortData[wp] = value;
	    }
	    UpdateBusThing(md_timestamp);
            break;

        case 0x04: /* Port A Ctrl */
        case 0x05: /* Port B Ctrl */
        case 0x06: /* Port C Ctrl */
	    {
	     int wp = offset - 0x04;

	     PortCtrl[wp] = value;
	    }
	    UpdateBusThing(md_timestamp);
            break;

        case 0x07: /* Port A TxData */
        case 0x0A: /* Port B TxData */
        case 0x0D: /* Port C TxData */
	    PortTxData[(offset - 0x07) / 3] = value;
            break;

        case 0x09: /* Port A S-Ctrl */
        case 0x0C: /* Port B S-Ctrl */
        case 0x0F: /* Port C S-Ctrl */
	    PortSCtrl[(offset - 0x09) / 3] = value & 0xF8;
            break;
    }
}

int gen_io_r(int offset)
{
    uint8 ret;
    uint8 temp;
    uint8 has_scd = MD_IsCD ? 0x00 : 0x20;
    uint8 gen_ver = 0x00; /* Version 0 hardware */

    switch(offset)
    {
	default:
	    ret = 0x00;
	    MD_DBG(MD_DBG_WARNING, "[IO] Unmapped I/O Read: %04x\n", offset);
	    break;

        case 0x00: /* Version */
	    temp = 0x00;
	    if(is_overseas_reported)
	     temp |= 0x80;
	    if(is_pal_reported)
	     temp |= 0x40;
            ret = (temp | has_scd | gen_ver);
            break;

        case 0x01: /* Port A Data */
        case 0x02: /* Port B Data */
        case 0x03: /* Port C Data */
	    {
	     int wp = offset - 0x01;

	     UpdateBusThing(md_timestamp);
             ret = (PortDataBus[wp] & 0x7F) | (PortCtrl[wp] & 0x80);
	    }
	    break;

        case 0x04: /* Port A Ctrl */
        case 0x05: /* Port B Ctrl */
        case 0x06: /* Port C Ctrl */
            ret = PortCtrl[offset - 0x04];
	    break;

        case 0x07: /* Port A TxData */
        case 0x0A: /* Port B TxData */
        case 0x0D: /* Port C TxData */
            ret = PortTxData[(offset - 0x07) / 3];
	    break;

        case 0x09: /* Port A S-Ctrl */
        case 0x0C: /* Port B S-Ctrl */
        case 0x0F: /* Port C S-Ctrl */
            ret = PortSCtrl[(offset - 0x09) / 3];
	    break;
    }

 //printf("I/O Read: %04x ret=%02x, %d @ %08x\n", offset, ret, md_timestamp, C68k_Get_PC(&Main68K));

 return(ret);
}


void MDIO_BeginTimePeriod(const int32 timestamp_base)
{
 for(int i = 0; i < 3; i++)
  port[i]->BeginTimePeriod(timestamp_base);
}

void MDIO_EndTimePeriod(const int32 master_timestamp)
{
 for(int i = 0; i < 3; i++)
  port[i]->EndTimePeriod(master_timestamp);
}


/*--------------------------------------------------------------------------*/
/* Null device                                                              */
/*--------------------------------------------------------------------------*/
MD_Input_Device::MD_Input_Device()
{

}

MD_Input_Device::~MD_Input_Device()
{


}

void MD_Input_Device::Power(void)
{

}

void MD_Input_Device::UpdateBus(const int32 master_timestamp, uint8 &bus, const uint8 genesis_asserted)
{
// printf("%02x -- %02x\n", bus, genesis_asserted);
// bus |= 0x3F &~ genesis_asserted;
// bus &= genesis_asserted;
}

void MD_Input_Device::UpdatePhysicalState(const void *data)
{

}

void MD_Input_Device::BeginTimePeriod(const int32 timestamp_base)
{

}

void MD_Input_Device::EndTimePeriod(const int32 master_timestamp)
{

}


void MD_Input_Device::StateAction(StateMem *sm, const unsigned load, const bool data_only, const char *section_prefix)
{

}

void MDINPUT_Frame(void)
{
 MDFNGameInfo->mouse_sensitivity = MDFN_GetSettingF("md.input.mouse_sensitivity");

 for(unsigned vp = 0; vp < 8; vp++)
 {
  if(InputDevice[vp])
   InputDevice[vp]->UpdatePhysicalState(data_ptr[vp]);
 }
}

void MDINPUT_SetInput(unsigned vp, const char *type, uint8 *ptr)
{
 assert(vp < 8);

 data_ptr[vp] = ptr;

 if(InputDevice[vp])
 {
  delete InputDevice[vp];
  InputDevice[vp] = nullptr;
 }

 if(!strcmp(type, "none"))
  InputDevice[vp] = nullptr;
 else if(!strcmp(type, "gamepad"))
  InputDevice[vp] = MDInput_MakeMD3B();
 else if(!strcmp(type, "gamepad6"))
  InputDevice[vp] = MDInput_MakeMD6B();
 else if(!strcmp(type, "gamepad2"))
  InputDevice[vp] = MDInput_MakeMS2B();
 else if(!strcmp(type, "megamouse"))
  InputDevice[vp] = MDInput_MakeMegaMouse();
 else
  abort();

 if(InputDevice[vp])
  InputDevice[vp]->Power();

 RebuildPortMap();
 //
 //
 //
 UpdateBusThing(md_timestamp);
}

void MDINPUT_StateAction(StateMem *sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(PortData),
  SFVAR(PortCtrl),
  SFVAR(PortTxData),
  SFVAR(PortSCtrl),

  SFVAR(PortDataBus),
  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "IO");

 port[0]->StateAction(sm, load, data_only, "PRTA");
 port[1]->StateAction(sm, load, data_only, "PRTB");
 port[2]->StateAction(sm, load, data_only, "PRTC");

 if(load)
 {

 }
}


}
