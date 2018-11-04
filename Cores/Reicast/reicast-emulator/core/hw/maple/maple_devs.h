#pragma once
#include "types.h"

enum MapleDeviceType
{
	MDT_SegaController,

	MDT_SegaVMU,
	MDT_Microphone,
	MDT_PurupuruPack,

	MDT_NaomiJamma,

	MDT_None,
	MDT_Count
};

struct IMapleConfigMap;

struct maple_device
{
	u8 maple_port;          //raw maple port
	u8 bus_port;            //0 .. 5
	u8 bus_id;              //0 .. 3
	wchar logical_port[3];  //A0, etc
	IMapleConfigMap* config;

	//fill in the info
	void Setup(u32 prt);

	virtual void OnSetup(){};
	virtual ~maple_device();
	virtual u32 Dma(u32 Command,u32* buffer_in,u32 buffer_in_len,u32* buffer_out,u32& buffer_out_len)=0;
};

maple_device* maple_Create(MapleDeviceType type);
#define SIZE_OF_MIC_DATA	480 //ALSO DEFINED IN SipEmulator.java
#ifndef TARGET_PANDORA
int get_mic_data(u8* buffer); //implemented in Android.cpp
int push_vmu_screen(u8* buffer); //implemented in Android.cpp
#endif
