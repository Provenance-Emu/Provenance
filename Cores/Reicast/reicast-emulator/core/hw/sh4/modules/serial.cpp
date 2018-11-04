/*
	Dreamcast serial port.
	This is missing most of the functionality, but works for KOS (And thats all that uses it)
*/
#include "types.h"
#include "hw/sh4/sh4_mmr.h"

SCIF_SCFSR2_type SCIF_SCFSR2;
u8 SCIF_SCFRDR2;
SCIF_SCFDR2_type SCIF_SCFDR2;

/*
//SCIF SCSMR2 0xFFE80000 0x1FE80000 16 0x0000 0x0000 Held Held Pclk
SCSMR2_type SCIF_SCSMR2;

//SCIF SCBRR2 0xFFE80004 0x1FE80004 8 0xFF 0xFF Held Held Pclk
u8 SCIF_SCBRR2;

//SCIF SCSCR2 0xFFE80008 0x1FE80008 16 0x0000 0x0000 Held Held Pclk
SCSCR2_type SCIF_SCSCR2;

//SCIF SCFTDR2 0xFFE8000C 0x1FE8000C 8 Undefined Undefined Held Held Pclk
u8 SCIF_SCFTDR2;

//SCIF SCFSR2 0xFFE80010 0x1FE80010 16 0x0060 0x0060 Held Held Pclk
SCSCR2_type SCIF_SCFSR2;

//SCIF SCFRDR2 0xFFE80014 0x1FE80014 8 Undefined Undefined Held Held Pclk
//Read OLNY
u8 SCIF_SCFRDR2;

//SCIF SCFCR2 0xFFE80018 0x1FE80018 16 0x0000 0x0000 Held Held Pclk
SCFCR2_type SCIF_SCFCR2;

//Read OLNY
//SCIF SCFDR2 0xFFE8001C 0x1FE8001C 16 0x0000 0x0000 Held Held Pclk
SCFDR2_type SCIF_SCFDR2;

//SCIF SCSPTR2 0xFFE80020 0x1FE80020 16 0x0000 0x0000 Held Held Pclk
SCSPTR2_type SCIF_SCSPTR2;

//SCIF SCLSR2 0xFFE80024 0x1FE80024 16 0x0000 0x0000 Held Held Pclk
SCLSR2_type SCIF_SCLSR2;
*/

void SerialWrite(u32 addr, u32 data)
{
	if (settings.debug.SerialConsole) {
		putc(data, stdout);
	}
}

//SCIF_SCFSR2 read
u32 ReadSerialStatus(u32 addr)
{
	if (false /*PendingSerialData()*/)
	{
		return 0x60 | 2;
	}
	else
	{
		return 0x60| 0;
	}
	/*
	//TODO : Add status for serial input
	return 0x60;//hackish but works !
	*/
}

void WriteSerialStatus(u32 addr,u32 data)
{
	/*
	//TODO : do something ?
	*/
}

//SCIF_SCFDR2 - 16b
u32 Read_SCFDR2(u32 addr)
{
	return 0;
}
//SCIF_SCFRDR2
u32 ReadSerialData(u32 addr)
{
	s32 rd=0;//ReadSerial();
	return (u8)rd ;
}

//Init term res
void serial_init()
{
	//SCIF SCSMR2 0xFFE80000 0x1FE80000 16 0x0000 0x0000 Held Held Pclk
	sh4_rio_reg(SCIF,SCIF_SCSMR2_addr,RIO_DATA,16);

	//SCIF SCBRR2 0xFFE80004 0x1FE80004 8 0xFF 0xFF Held Held Pclk
	sh4_rio_reg(SCIF,SCIF_SCBRR2_addr,RIO_DATA,8);

	//SCIF SCSCR2 0xFFE80008 0x1FE80008 16 0x0000 0x0000 Held Held Pclk
	sh4_rio_reg(SCIF,SCIF_SCSCR2_addr,RIO_DATA,16);

	//Write only 
	//SCIF SCFTDR2 0xFFE8000C 0x1FE8000C 8 Undefined Undefined Held Held Pclk
	sh4_rio_reg(SCIF,SCIF_SCFTDR2_addr,RIO_WF,8,0,&SerialWrite);

	//SCIF SCFSR2 0xFFE80010 0x1FE80010 16 0x0060 0x0060 Held Held Pclk
	sh4_rio_reg(SCIF,SCIF_SCFSR2_addr,RIO_FUNC,16,&ReadSerialStatus,&WriteSerialStatus);

	//READ only
	//SCIF SCFRDR2 0xFFE80014 0x1FE80014 8 Undefined Undefined Held Held Pclk
	sh4_rio_reg(SCIF,SCIF_SCFRDR2_addr,RIO_RO_FUNC,8,&ReadSerialData);

	//SCIF SCFCR2 0xFFE80018 0x1FE80018 16 0x0000 0x0000 Held Held Pclk
	sh4_rio_reg(SCIF,SCIF_SCFCR2_addr,RIO_DATA,16);

	//Read only
	//SCIF SCFDR2 0xFFE8001C 0x1FE8001C 16 0x0000 0x0000 Held Held Pclk
	sh4_rio_reg(SCIF,SCIF_SCFDR2_addr,RIO_RO_FUNC,16,&Read_SCFDR2);

	//SCIF SCSPTR2 0xFFE80020 0x1FE80020 16 0x0000 0x0000 Held Held Pclk
	sh4_rio_reg(SCIF,SCIF_SCSPTR2_addr,RIO_DATA,16);

	//SCIF SCLSR2 0xFFE80024 0x1FE80024 16 0x0000 0x0000 Held Held Pclk
	sh4_rio_reg(SCIF,SCIF_SCLSR2_addr,RIO_DATA,16);
}
void serial_reset()
{
	/*
	SCIF SCSMR2 H'FFE8 0000 H'1FE8 0000 16 H'0000 H'0000 Held Held Pclk
	SCIF SCBRR2 H'FFE8 0004 H'1FE8 0004 8 H'FF H'FF Held Held Pclk
	SCIF SCSCR2 H'FFE8 0008 H'1FE8 0008 16 H'0000 H'0000 Held Held Pclk
	SCIF SCFTDR2 H'FFE8 000C H'1FE8 000C 8 Undefined Undefined Held Held Pclk
	SCIF SCFSR2 H'FFE8 0010 H'1FE8 0010 16 H'0060 H'0060 Held Held Pclk
	SCIF SCFRDR2 H'FFE8 0014 H'1FE8 0014 8 Undefined Undefined Held Held Pclk
	SCIF SCFCR2 H'FFE8 0018 H'1FE8 0018 16 H'0000 H'0000 Held Held Pclk
	SCIF SCFDR2 H'FFE8 001C H'1FE8 001C 16 H'0000 H'0000 Held Held Pclk
	SCIF SCSPTR2 H'FFE8 0020 H'1FE8 0020 16 H'0000*2 H'0000*2 Held Held Pclk
	SCIF SCLSR2 H'FFE8 0024 H'1FE8 0024 16 H'0000 H'0000 Held Held Pclk
	*/
	SCIF_SCSMR2.full=0x0000;
	SCIF_SCBRR2=0xFF;
	SCIF_SCFSR2.full=0x000;
	SCIF_SCFCR2.full=0x000;
	SCIF_SCFDR2.full=0x000;
	SCIF_SCSPTR2.full=0x000;
	SCIF_SCLSR2.full=0x000;
}

void serial_term()
{
}

