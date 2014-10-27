/*
    genio.c
    I/O controller chip emulation
*/

#include "shared.h"
#include "input/gamepad.h"
#include "input/mouse.h"

namespace MDFN_IEN_MD
{

static bool is_pal;
static bool is_overseas;
static bool is_overseas_reported;
static bool is_pal_reported;

// 3 internal ports
enum port_names {PORT_A = 0, PORT_B, PORT_C, PORT_MAX};
enum device_names {DEVICE_NONE = 0, DEVICE_MS2B, DEVICE_MD3B, DEVICE_MD6B, DEVICE_MM};

static void SetDevice(int i, int type);

static MD_Input_Device *port[PORT_MAX] = { NULL };

static InputDeviceInfoStruct InputDeviceInfo[] =
{
 // None
 {
  "none",
  "none",
  NULL,
  NULL,
  0,
  NULL
 },

 {
  "gamepad2",
  "2-Button Gamepad",
  NULL,
  NULL,
  sizeof(Gamepad2IDII) / sizeof(InputDeviceInputInfoStruct),
  Gamepad2IDII,
 },

 {
  "gamepad",
  "3-Button Gamepad",
  NULL,
  NULL,
  sizeof(GamepadIDII) / sizeof(InputDeviceInputInfoStruct),
  GamepadIDII,
 },

 {
  "gamepad6",
  "6-Button Gamepad",
  NULL,
  NULL,
  sizeof(Gamepad6IDII) / sizeof(InputDeviceInputInfoStruct),
  Gamepad6IDII,
 },

 {
  "megamouse",
  "Sega Mega Mouse",
  NULL,
  NULL,
  sizeof(MegaMouseIDII) / sizeof(InputDeviceInputInfoStruct),
  MegaMouseIDII,
 },

};

static const InputPortInfoStruct PortInfo[] =
{
 { "port1", "Port 1", sizeof(InputDeviceInfo) / sizeof(InputDeviceInfoStruct), InputDeviceInfo, "gamepad" },
 { "port2", "Port 2", sizeof(InputDeviceInfo) / sizeof(InputDeviceInfoStruct), InputDeviceInfo, "gamepad" }
};

InputInfoStruct MDInputInfo =
{
 sizeof(PortInfo) / sizeof(InputPortInfoStruct),
 PortInfo
};

static void UpdateBusThing(const int32 master_timestamp);

void MDIO_Init(bool overseas, bool PAL, bool overseas_reported, bool PAL_reported)
{
 is_overseas = overseas;
 is_pal = PAL;
 is_overseas_reported = overseas_reported;
 is_pal_reported = PAL_reported;

 for(int i = 0; i < PORT_MAX; i++)
  SetDevice(i, DEVICE_NONE);

 UpdateBusThing(md_timestamp);
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

  port[i]->Power();		// Should be called before Write(...)
 }
 PortTxData[2] = 0xFB;

 UpdateBusThing(0);
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


int MD_Input_Device::StateAction(StateMem *sm, int load, int data_only, const char *section_prefix)
{
 return(1);
}


static void SetDevice(int i, int type)
{
 if(port[i])
  delete port[i];

    switch(type)
    {
        case DEVICE_NONE:
	    port[i] = new MD_Input_Device();
            break;

        case DEVICE_MS2B:
	    port[i] = MDInput_MakeMS2B();
            break;

        case DEVICE_MD3B:
	    port[i] = MDInput_MakeMD3B();
            break;

        case DEVICE_MD6B:
	    port[i] = MDInput_MakeMD6B();
            break;

        case DEVICE_MM:
	    port[i] = MDInput_MakeMegaMouse();
            break;
    }

 port[i]->Power();
}

static void *data_ptr[8];

void MDINPUT_Frame(void)
{
 for(int i = 0; i < 2; i++)
 {
  port[i]->UpdatePhysicalState(data_ptr[i]);
 }
}

void MDINPUT_SetInput(int aport, const char *type, void *ptr)
{
 int itype = 0;

 if(!strcasecmp(type, "none"))
 {
  itype = DEVICE_NONE;
 }
 if(!strcasecmp(type, "gamepad"))
 {
  itype = DEVICE_MD3B;
 }
 else if(!strcasecmp(type, "gamepad6"))
 {
  itype = DEVICE_MD6B;
 }
 else if(!strcasecmp(type, "gamepad2"))
 {
  itype = DEVICE_MS2B;
 }
 else if(!strcasecmp(type, "megamouse"))
 {
  itype = DEVICE_MM;
 }

 data_ptr[aport] = ptr;
 SetDevice(aport, itype);

 UpdateBusThing(md_timestamp);
}

int MDINPUT_StateAction(StateMem *sm, int load, int data_only)
{
 SFORMAT StateRegs[] =
 {
  SFARRAY(PortData, 3),
  SFARRAY(PortCtrl, 3),
  SFARRAY(PortTxData, 3),
  SFARRAY(PortSCtrl, 3),

  SFARRAY(PortDataBus, 3),
  SFEND
 };

 int ret = MDFNSS_StateAction(sm, load, data_only, StateRegs, "IO");

 ret &= port[0]->StateAction(sm, load, data_only, "PRTA");
 ret &= port[1]->StateAction(sm, load, data_only, "PRTB");
 ret &= port[2]->StateAction(sm, load, data_only, "PRTC");

 if(load)
 {

 }
 return(ret);
}


}
