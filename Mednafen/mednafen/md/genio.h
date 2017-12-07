#ifndef __MDFN_MD_GENIO_H
#define __MDFN_MD_GENIO_H

namespace MDFN_IEN_MD
{

/* Function prototypes */
extern void gen_io_reset(void);
extern void gen_io_w(int offset, int value);
extern int gen_io_r(int offset);

extern void gen_io_update(void);
extern void gen_io_set_device(int which, int type);

void MDIO_BeginTimePeriod(const int32 timestamp_base);
void MDIO_EndTimePeriod(const int32 master_timestamp);

void MDIO_Init(bool overseas, bool PAL, bool overseas_reported, bool PAL_reported);
void MDIO_Kill(void);

void MDINPUT_Frame(void);
void MDINPUT_SetInput(unsigned port, const char *type, uint8 *ptr);

enum
{
 MTAP_NONE = 0,
 MTAP_TP_PRT1 = 1,
 MTAP_TP_PRT2 = 2,
 MTAP_TP_DUAL = 3,
 MTAP_4WAY = 4,
};
void MDINPUT_SetMultitap(unsigned type);

extern const std::vector<InputPortInfoStruct> MDPortInfo;

class MD_Input_Device
{
	public:
	MD_Input_Device();
	virtual ~MD_Input_Device();

	virtual void Power(void);

	// genesis_asserted is intended for more accurately emulating a device that has pull-up or pull-down resistors
	// on one or more data lines.
	virtual void UpdateBus(const int32 master_timestamp, uint8 &bus, const uint8 genesis_asserted);	// genesis_asserted should
        virtual void UpdatePhysicalState(const void *data);
	virtual void BeginTimePeriod(const int32 timestamp_base);
	virtual void EndTimePeriod(const int32 master_timestamp);
	virtual void StateAction(StateMem *sm, const unsigned load, const bool data_only, const char *section_prefix);
};

void MDINPUT_StateAction(StateMem *sm, const unsigned load, const bool data_only);

}

#endif

