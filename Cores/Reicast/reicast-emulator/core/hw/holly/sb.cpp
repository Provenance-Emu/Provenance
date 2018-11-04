/*
	System bus registers
	This doesn't implement any functionality, only routing
*/

#include "types.h"
#include "sb.h"
#include "hw/holly/holly_intc.h"
#include "hw/pvr/pvr_sb_regs.h"
#include "hw/gdrom/gdrom_if.h"
#include "hw/maple/maple_if.h"
#include "hw/aica/aica_if.h"

#include "hw/naomi/naomi.h"

Array<RegisterStruct> sb_regs(0x540);

//(addr>= 0x005F6800) && (addr<=0x005F7CFF) -> 0x1500 bytes -> 0x540 possible registers , 125 actually exist only
// System Control Reg.   //0x100 bytes
// Maple i/f Control Reg.//0x100 bytes
// GD-ROM                //0x100 bytes
// G1 i/f Control Reg.   //0x100 bytes
// G2 i/f Control Reg.   //0x100 bytes
// PVR i/f Control Reg.  //0x100 bytes
// much empty space

u32 SB_ISTNRM;

u32 sb_ReadMem(u32 addr,u32 sz)
{
	u32 offset = addr-SB_BASE;
#ifdef TRACE
	if (offset & 3/*(size-1)*/) //4 is min align size
	{
		EMUERROR("Unaligned System Bus register read");
	}
#endif

	offset>>=2;

#ifdef TRACE
	if (sb_regs[offset].flags & sz)
	{
#endif
		if (!(sb_regs[offset].flags & REG_RF) )
		{
			if (sz==4)
				return sb_regs[offset].data32;
			else if (sz==2)
				return sb_regs[offset].data16;
			else
				return sb_regs[offset].data8;
		}
		else
		{
			//printf("SB: %08X\n",addr);
			return sb_regs[offset].readFunctionAddr(addr);
		}
#ifdef TRACE
	}
	else
	{
		if (!(sb_regs[offset].flags& REG_NOT_IMPL))
			EMUERROR("ERROR [wrong size read on register]");
	}
#endif
//  if ((sb_regs[offset].flags& REG_NOT_IMPL))
//      EMUERROR2("Read from System Control Regs , not  implemented , addr=%x",addr);
	return 0;
}

void sb_WriteMem(u32 addr,u32 data,u32 sz)
{
	u32 offset = addr-SB_BASE;
#ifdef TRACE
	if (offset & 3/*(size-1)*/) //4 is min align size
	{
		EMUERROR("Unaligned System bus register write");
	}
#endif
offset>>=2;
#ifdef TRACE
	if (sb_regs[offset].flags & sz)
	{
#endif
		if (!(sb_regs[offset].flags & REG_WF) )
		{
			if (sz==4)
				sb_regs[offset].data32=data;
			else if (sz==2)
				sb_regs[offset].data16=(u16)data;
			else
				sb_regs[offset].data8=(u8)data;
			return;
		}
		else
		{
			//printf("SBW: %08X\n",addr);
			sb_regs[offset].writeFunctionAddr(addr,data);
			/*
			if (sb_regs[offset].flags & REG_CONST)
				EMUERROR("Error [Write to read only register , const]");
			else
			{
				if ()
				{
					sb_regs[offset].writeFunction(data);
					return;
				}
				else
				{
					if (!(sb_regs[offset].flags& REG_NOT_IMPL))
						EMUERROR("ERROR [Write to read only register]");
				}
			}*/
			return;
		}
#ifdef TRACE
	}
	else
	{
		if (!(sb_regs[offset].flags& REG_NOT_IMPL))
			EMUERROR4("ERROR :wrong size write on register ; offset=%x , data=%x,sz=%d",offset,data,sz);
	}
	if ((sb_regs[offset].flags& REG_NOT_IMPL))
		EMUERROR3("Write to System Control Regs , not  implemented , addr=%x,data=%x",addr,data);
#endif

}

u32 sbio_read_noacc(u32 addr) { verify(false); return 0; }
void sbio_write_noacc(u32 addr, u32 data) { verify(false); }
void sbio_write_const(u32 addr, u32 data) { verify(false); }

void sb_write_zero(u32 addr, u32 data) { verify(data==0); }
void sb_write_gdrom_unlock(u32 addr, u32 data) { verify(data==0 || data==0x001fffff || data==0x42fe); } /* CS writes 0x42fe*/


void sb_rio_register(u32 reg_addr, RegIO flags, RegReadAddrFP* rf, RegWriteAddrFP* wf)
{
	u32 idx=(reg_addr-SB_BASE)/4;

	verify(idx<sb_regs.Size);

	sb_regs[idx].flags = flags | REG_ACCESS_32;

	if (flags == RIO_NO_ACCESS)
	{
		sb_regs[idx].readFunctionAddr=&sbio_read_noacc;
		sb_regs[idx].writeFunctionAddr=&sbio_write_noacc;
	}
	else if (flags == RIO_CONST)
	{
		sb_regs[idx].writeFunctionAddr=&sbio_write_const;
	}
	else
	{
		sb_regs[idx].data32=0;

		if (flags & REG_RF)
			sb_regs[idx].readFunctionAddr=rf;

		if (flags & REG_WF)
			sb_regs[idx].writeFunctionAddr=wf==0?&sbio_write_noacc:wf;
	}
}

template <u32 reg_addr>
void sb_writeonly(u32 addr, u32 data)
{
	SB_REGN_32(reg_addr)=data;
}

u32 SB_FFST_rc;
u32 SB_FFST;
u32 RegRead_SB_FFST(u32 addr)
{
	SB_FFST_rc++;
	if (SB_FFST_rc & 0x8)
	{
		SB_FFST^=31;
	}
	return 0; //SB_FFST -> does the fifo status has really to be faked ?
}

void SB_SFRES_write32(u32 addr, u32 data)
{
	if ((u16)data==0x7611)
	{
		printf("SB/HOLLY: System reset requested -- but cannot SOFT_RESET\n");
	}
}
void sb_Init()
{
	sb_regs.Zero();

	for (u32 i=0;i<sb_regs.Size;i++)
	{
		sb_rio_register(SB_BASE+i*4,RIO_NO_ACCESS);
		//sb_regs[i].flags=REG_NOT_IMPL;
	}

	//0x005F6800    SB_C2DSTAT  RW  ch2-DMA destination address
	sb_rio_register(SB_C2DSTAT_addr,RIO_DATA);


	//0x005F6804    SB_C2DLEN   RW  ch2-DMA length
	sb_rio_register(SB_C2DLEN_addr,RIO_DATA);


	//0x005F6808    SB_C2DST    RW  ch2-DMA start
	sb_rio_register(SB_C2DST_addr,RIO_DATA);

	//0x005F6810    SB_SDSTAW   RW  Sort-DMA start link table address
	sb_rio_register(SB_SDSTAW_addr,RIO_DATA);

	//0x005F6814    SB_SDBAAW   RW  Sort-DMA link base address
	sb_rio_register(SB_SDBAAW_addr,RIO_DATA);

	//0x005F6818    SB_SDWLT    RW  Sort-DMA link address bit width
	sb_rio_register(SB_SDWLT_addr,RIO_DATA);


	//0x005F681C    SB_SDLAS    RW  Sort-DMA link address shift control
	sb_rio_register(SB_SDLAS_addr,RIO_DATA);


	//0x005F6820    SB_SDST RW  Sort-DMA start
	sb_rio_register(SB_SDST_addr,RIO_DATA);

	//0x005F6860 SB_SDDIV R(?) Sort-DMA LAT index (guess)
	sb_rio_register(SB_SDDIV_addr,RIO_RO);
	//sb_regs[((SB_SDDIV_addr-SB_BASE))>>2].flags=REG_32BIT_READWRITE | REG_READ_DATA;

	//0x005F6840    SB_DBREQM   RW  DBREQ# signal mask control
	sb_rio_register(SB_DBREQM_addr,RIO_DATA);

	//0x005F6844    SB_BAVLWC   RW  BAVL# signal wait count
	sb_rio_register(SB_BAVLWC_addr,RIO_DATA);

	//0x005F6848    SB_C2DPRYC  RW  DMA (TA/Root Bus) priority count
	sb_rio_register(SB_C2DPRYC_addr,RIO_DATA);

	//0x005F684C    SB_C2DMAXL  RW  ch2-DMA maximum burst length
	sb_rio_register(SB_C2DMAXL_addr,RIO_DATA);

	//0x005F6880    SB_TFREM    R   TA FIFO remaining amount
	sb_rio_register(SB_TFREM_addr,RIO_RO);

	//0x005F6884    SB_LMMODE0  RW  Via TA texture memory bus select 0
	sb_rio_register(SB_LMMODE0_addr,RIO_DATA);

	//0x005F6888    SB_LMMODE1  RW  Via TA texture memory bus select 1
	sb_rio_register(SB_LMMODE1_addr,RIO_DATA);

	//0x005F688C    SB_FFST     R   FIFO status
	sb_rio_register(SB_FFST_addr,RIO_RO_FUNC,RegRead_SB_FFST);
	/*
	sb_regs[((SB_FFST_addr-SB_BASE))>>2].flags=REG_32BIT_READWRITE ;
	sb_regs[((SB_FFST_addr-SB_BASE))>>2].readFunction=RegRead_SB_FFST;
	sb_regs[((SB_FFST_addr-SB_BASE))>>2].writeFunction=0;
	sb_regs[((SB_FFST_addr-SB_BASE))>>2].data32=0;*/


	//0x005F6890    SB_SFRES    W   System reset
	sb_rio_register(SB_SFRES_addr,RIO_WO_FUNC,0,SB_SFRES_write32);

	/*
	sb_regs[((SB_SFRES_addr-SB_BASE))>>2].flags=REG_32BIT_READWRITE ;
	sb_regs[((SB_SFRES_addr-SB_BASE))>>2].readFunction=0;
	sb_regs[((SB_SFRES_addr-SB_BASE))>>2].writeFunction=SB_SFRES_write32;
	sb_regs[((SB_SFRES_addr-SB_BASE))>>2].data32=&SB_SFRES;
	*/


	//0x005F689C    SB_SBREV    R   System bus revision number
	sb_rio_register(SB_SBREV_addr,RIO_CONST);
	//sb_regs[((SB_SBREV_addr-SB_BASE))>>2].flags=REG_32BIT_READWRITE | REG_READ_DATA | REG_CONST ;


	//0x005F68A0    SB_RBSPLT   RW  SH4 Root Bus split enable
	sb_rio_register(SB_RBSPLT_addr,RIO_DATA);



	//0x005F6900    SB_ISTNRM   RW  Normal interrupt status
	sb_rio_register(SB_ISTNRM_addr,RIO_DATA);


	//0x005F6904    SB_ISTEXT   R   External interrupt status
	sb_rio_register(SB_ISTEXT_addr,RIO_RO);


	//0x005F6908    SB_ISTERR   RW  Error interrupt status
	sb_rio_register(SB_ISTERR_addr,RIO_DATA);



	//0x005F6910    SB_IML2NRM  RW  Level 2 normal interrupt mask
	sb_rio_register(SB_IML2NRM_addr,RIO_DATA);


	//0x005F6914    SB_IML2EXT  RW  Level 2 external interrupt mask
	sb_rio_register(SB_IML2EXT_addr,RIO_DATA);


	//0x005F6918    SB_IML2ERR  RW  Level 2 error interrupt mask
	sb_rio_register(SB_IML2ERR_addr,RIO_DATA);



	//0x005F6920    SB_IML4NRM  RW  Level 4 normal interrupt mask
	sb_rio_register(SB_IML4NRM_addr,RIO_DATA);


	//0x005F6924    SB_IML4EXT  RW  Level 4 external interrupt mask
	sb_rio_register(SB_IML4EXT_addr,RIO_DATA);


	//0x005F6928    SB_IML4ERR  RW  Level 4 error interrupt mask
	sb_rio_register(SB_IML4ERR_addr,RIO_DATA);



	//0x005F6930    SB_IML6NRM  RW  Level 6 normal interrupt mask
	sb_rio_register(SB_IML6NRM_addr,RIO_DATA);


	//0x005F6934    SB_IML6EXT  RW  Level 6 external interrupt mask
	sb_rio_register(SB_IML6EXT_addr,RIO_DATA);


	//0x005F6938    SB_IML6ERR  RW  Level 6 error interrupt mask
	sb_rio_register(SB_IML6ERR_addr,RIO_DATA);



	//0x005F6940    SB_PDTNRM   RW  Normal interrupt PVR-DMA startup mask
	sb_rio_register(SB_PDTNRM_addr,RIO_DATA);


	//0x005F6944    SB_PDTEXT   RW  External interrupt PVR-DMA startup mask
	sb_rio_register(SB_PDTEXT_addr,RIO_DATA);



	//0x005F6950    SB_G2DTNRM  RW  Normal interrupt G2-DMA startup mask
	sb_rio_register(SB_G2DTNRM_addr,RIO_DATA);


	//0x005F6954    SB_G2DTEXT  RW  External interrupt G2-DMA startup mask
	sb_rio_register(SB_G2DTEXT_addr,RIO_DATA);



	//0x005F6C04    SB_MDSTAR   RW  Maple-DMA command table address
	sb_rio_register(SB_MDSTAR_addr,RIO_DATA);



	//0x005F6C10    SB_MDTSEL   RW  Maple-DMA trigger select
	sb_rio_register(SB_MDTSEL_addr,RIO_DATA);


	//0x005F6C14    SB_MDEN     RW  Maple-DMA enable
	sb_rio_register(SB_MDEN_addr,RIO_DATA);


	//0x005F6C18    SB_MDST     RW  Maple-DMA start
	sb_rio_register(SB_MDST_addr,RIO_DATA);



	//0x005F6C80    SB_MSYS     RW  Maple system control
	sb_rio_register(SB_MSYS_addr,RIO_DATA);


	//0x005F6C84    SB_MST      R   Maple status
	sb_rio_register(SB_MST_addr,RIO_RO);


	//0x005F6C88    SB_MSHTCL   W   Maple-DMA hard trigger clear
	sb_rio_register(SB_MSHTCL_addr,RIO_WO_FUNC,0,sb_writeonly<SB_MSHTCL_addr>);


	//0x005F6C8C    SB_MDAPRO   W   Maple-DMA address range
	sb_rio_register(SB_MDAPRO_addr,RIO_WO_FUNC,0,sb_writeonly<SB_MDAPRO_addr>);



	//0x005F6CE8    SB_MMSEL    RW  Maple MSB selection
	sb_rio_register(SB_MMSEL_addr,RIO_DATA);



	//0x005F6CF4    SB_MTXDAD   R   Maple Txd address counter
	sb_rio_register(SB_MTXDAD_addr,RIO_RO);


	//0x005F6CF8    SB_MRXDAD   R   Maple Rxd address counter
	sb_rio_register(SB_MRXDAD_addr,RIO_RO);


	//0x005F6CFC    SB_MRXDBD   R   Maple Rxd base address
	sb_rio_register(SB_MRXDBD_addr,RIO_RO);

	//0x005F7404    SB_GDSTAR   RW  GD-DMA start address
	sb_rio_register(SB_GDSTAR_addr,RIO_DATA);


	//0x005F7408    SB_GDLEN    RW  GD-DMA length
	sb_rio_register(SB_GDLEN_addr,RIO_DATA);


	//0x005F740C    SB_GDDIR    RW  GD-DMA direction
	sb_rio_register(SB_GDDIR_addr,RIO_DATA);



	//0x005F7414    SB_GDEN     RW  GD-DMA enable
	sb_rio_register(SB_GDEN_addr,RIO_DATA);


	//0x005F7418    SB_GDST     RW  GD-DMA start
	sb_rio_register(SB_GDST_addr,RIO_DATA);



	//0x005F7480    SB_G1RRC    W   System ROM read access timing
	sb_rio_register(SB_G1RRC_addr,RIO_WO_FUNC,0,sb_writeonly<SB_G1RRC_addr>);


	//0x005F7484    SB_G1RWC    W   System ROM write access timing
	sb_rio_register(SB_G1RWC_addr,RIO_WO_FUNC,0,sb_writeonly<SB_G1RWC_addr>);


	//0x005F7488    SB_G1FRC    W   Flash ROM read access timing
	sb_rio_register(SB_G1FRC_addr,RIO_WO_FUNC,0,sb_writeonly<SB_G1FRC_addr>);


	//0x005F748C    SB_G1FWC    W   Flash ROM write access timing
	sb_rio_register(SB_G1FWC_addr,RIO_WO_FUNC,0,sb_writeonly<SB_G1FWC_addr>);


	//0x005F7490    SB_G1CRC    W   GD PIO read access timing
	sb_rio_register(SB_G1CRC_addr,RIO_WO_FUNC,0,sb_writeonly<SB_G1CRC_addr>);


	//0x005F7494    SB_G1CWC    W   GD PIO write access timing
	sb_rio_register(SB_G1CWC_addr,RIO_WO_FUNC,0,sb_writeonly<SB_G1CWC_addr>);



	//0x005F74A0    SB_G1GDRC   W   GD-DMA read access timing
	sb_rio_register(SB_G1GDRC_addr,RIO_WO_FUNC,0,sb_writeonly<SB_G1GDRC_addr>);


	//0x005F74A4    SB_G1GDWC   W   GD-DMA write access timing
	sb_rio_register(SB_G1GDWC_addr,RIO_WO_FUNC,0,sb_writeonly<SB_G1GDWC_addr>);



	//0x005F74B0    SB_G1SYSM   R   System mode
	sb_rio_register(SB_G1SYSM_addr,RIO_RO);


	//0x005F74B4    SB_G1CRDYC  W   G1IORDY signal control
	sb_rio_register(SB_G1CRDYC_addr,RIO_WO_FUNC,0,sb_writeonly<SB_G1CRDYC_addr>);


	//0x005F74B8    SB_GDAPRO   W   GD-DMA address range
	sb_rio_register(SB_GDAPRO_addr,RIO_WO_FUNC,0,sb_writeonly<SB_GDAPRO_addr>);



	//0x005F74F4    SB_GDSTARD  R   GD-DMA address count (on Root Bus)
	sb_rio_register(SB_GDSTARD_addr,RIO_RO);


	//0x005F74F8    SB_GDLEND   R   GD-DMA transfer counter
	sb_rio_register(SB_GDLEND_addr,RIO_RO);



	//0x005F7800    SB_ADSTAG   RW  AICA:G2-DMA G2 start address
	sb_rio_register(SB_ADSTAG_addr,RIO_DATA);


	//0x005F7804    SB_ADSTAR   RW  AICA:G2-DMA system memory start address
	sb_rio_register(SB_ADSTAR_addr,RIO_DATA);


	//0x005F7808    SB_ADLEN    RW  AICA:G2-DMA length
	sb_rio_register(SB_ADLEN_addr,RIO_DATA);


	//0x005F780C    SB_ADDIR    RW  AICA:G2-DMA direction
	sb_rio_register(SB_ADDIR_addr,RIO_DATA);


	//0x005F7810    SB_ADTSEL   RW  AICA:G2-DMA trigger select
	sb_rio_register(SB_ADTSEL_addr,RIO_DATA);


	//0x005F7814    SB_ADEN     RW  AICA:G2-DMA enable
	sb_rio_register(SB_ADEN_addr,RIO_DATA);



	//0x005F7818    SB_ADST     RW  AICA:G2-DMA start
	sb_rio_register(SB_ADST_addr,RIO_DATA);


	//0x005F781C    SB_ADSUSP   RW  AICA:G2-DMA suspend
	sb_rio_register(SB_ADSUSP_addr,RIO_DATA);



	//0x005F7820    SB_E1STAG   RW  Ext1:G2-DMA G2 start address
	sb_rio_register(SB_E1STAG_addr,RIO_DATA);


	//0x005F7824    SB_E1STAR   RW  Ext1:G2-DMA system memory start address
	sb_rio_register(SB_E1STAR_addr,RIO_DATA);


	//0x005F7828    SB_E1LEN    RW  Ext1:G2-DMA length
	sb_rio_register(SB_E1LEN_addr,RIO_DATA);


	//0x005F782C    SB_E1DIR    RW  Ext1:G2-DMA direction
	sb_rio_register(SB_E1DIR_addr,RIO_DATA);


	//0x005F7830    SB_E1TSEL   RW  Ext1:G2-DMA trigger select
	sb_rio_register(SB_E1TSEL_addr,RIO_DATA);


	//0x005F7834    SB_E1EN     RW  Ext1:G2-DMA enable
	sb_rio_register(SB_E1EN_addr,RIO_DATA);


	//0x005F7838    SB_E1ST     RW  Ext1:G2-DMA start
	sb_rio_register(SB_E1ST_addr,RIO_DATA);


	//0x005F783C    SB_E1SUSP   RW  Ext1: G2-DMA suspend
	sb_rio_register(SB_E1SUSP_addr,RIO_DATA);



	//0x005F7840    SB_E2STAG   RW  Ext2:G2-DMA G2 start address
	sb_rio_register(SB_E2STAG_addr,RIO_DATA);


	//0x005F7844    SB_E2STAR   RW  Ext2:G2-DMA system memory start address
	sb_rio_register(SB_E2STAR_addr,RIO_DATA);


	//0x005F7848    SB_E2LEN    RW  Ext2:G2-DMA length
	sb_rio_register(SB_E2LEN_addr,RIO_DATA);


	//0x005F784C    SB_E2DIR    RW  Ext2:G2-DMA direction
	sb_rio_register(SB_E2DIR_addr,RIO_DATA);


	//0x005F7850    SB_E2TSEL   RW  Ext2:G2-DMA trigger select
	sb_rio_register(SB_E2TSEL_addr,RIO_DATA);


	//0x005F7854    SB_E2EN     RW  Ext2:G2-DMA enable
	sb_rio_register(SB_E2EN_addr,RIO_DATA);


	//0x005F7858    SB_E2ST     RW  Ext2:G2-DMA start
	sb_rio_register(SB_E2ST_addr,RIO_DATA);


	//0x005F785C    SB_E2SUSP   RW  Ext2: G2-DMA suspend
	sb_rio_register(SB_E2SUSP_addr,RIO_DATA);



	//0x005F7860    SB_DDSTAG   RW  Dev:G2-DMA G2 start address
	sb_rio_register(SB_DDSTAG_addr,RIO_DATA);


	//0x005F7864    SB_DDSTAR   RW  Dev:G2-DMA system memory start address
	sb_rio_register(SB_DDSTAR_addr,RIO_DATA);


	//0x005F7868    SB_DDLEN    RW  Dev:G2-DMA length
	sb_rio_register(SB_DDLEN_addr,RIO_DATA);


	//0x005F786C    SB_DDDIR    RW  Dev:G2-DMA direction
	sb_rio_register(SB_DDDIR_addr,RIO_DATA);


	//0x005F7870    SB_DDTSEL   RW  Dev:G2-DMA trigger select
	sb_rio_register(SB_DDTSEL_addr,RIO_DATA);


	//0x005F7874    SB_DDEN     RW  Dev:G2-DMA enable
	sb_rio_register(SB_DDEN_addr,RIO_DATA);


	//0x005F7878    SB_DDST     RW  Dev:G2-DMA start
	sb_rio_register(SB_DDST_addr,RIO_DATA);


	//0x005F787C    SB_DDSUSP   RW  Dev: G2-DMA suspend
	sb_rio_register(SB_DDSUSP_addr,RIO_DATA);



	//0x005F7880    SB_G2ID     R   G2 bus version
	sb_rio_register(SB_G2ID_addr,RIO_CONST);



	//0x005F7890    SB_G2DSTO   RW  G2/DS timeout
	sb_rio_register(SB_G2DSTO_addr,RIO_DATA);


	//0x005F7894    SB_G2TRTO   RW  G2/TR timeout
	sb_rio_register(SB_G2TRTO_addr,RIO_DATA);


	//0x005F7898    SB_G2MDMTO  RW  Modem unit wait timeout
	sb_rio_register(SB_G2MDMTO_addr,RIO_DATA);


	//0x005F789C    SB_G2MDMW   RW  Modem unit wait time
	sb_rio_register(SB_G2MDMW_addr,RIO_DATA);



	//0x005F78BC    SB_G2APRO   W   G2-DMA address range
	sb_rio_register(SB_G2APRO_addr,RIO_WO_FUNC,0,sb_writeonly<SB_G2APRO_addr>);



	//0x005F78C0    SB_ADSTAGD  R   AICA-DMA address counter (on AICA)
	sb_rio_register(SB_ADSTAGD_addr,RIO_RO);


	//0x005F78C4    SB_ADSTARD  R   AICA-DMA address counter (on root bus)
	sb_rio_register(SB_ADSTARD_addr,RIO_RO);


	//0x005F78C8    SB_ADLEND   R   AICA-DMA transfer counter
	sb_rio_register(SB_ADLEND_addr,RIO_RO);



	//0x005F78D0    SB_E1STAGD  R   Ext-DMA1 address counter (on Ext)
	sb_rio_register(SB_E1STAGD_addr,RIO_RO);


	//0x005F78D4    SB_E1STARD  R   Ext-DMA1 address counter (on root bus)
	sb_rio_register(SB_E1STARD_addr,RIO_RO);


	//0x005F78D8    SB_E1LEND   R   Ext-DMA1 transfer counter
	sb_rio_register(SB_E1LEND_addr,RIO_RO);



	//0x005F78E0    SB_E2STAGD  R   Ext-DMA2 address counter (on Ext)
	sb_rio_register(SB_E2STAGD_addr,RIO_RO);


	//0x005F78E4    SB_E2STARD  R   Ext-DMA2 address counter (on root bus)
	sb_rio_register(SB_E2STARD_addr,RIO_RO);


	//0x005F78E8    SB_E2LEND   R   Ext-DMA2 transfer counter
	sb_rio_register(SB_E2LEND_addr,RIO_RO);



	//0x005F78F0    SB_DDSTAGD  R   Dev-DMA address counter (on Ext)
	sb_rio_register(SB_DDSTAGD_addr,RIO_RO);


	//0x005F78F4    SB_DDSTARD  R   Dev-DMA address counter (on root bus)
	sb_rio_register(SB_DDSTARD_addr,RIO_RO);


	//0x005F78F8    SB_DDLEND   R   Dev-DMA transfer counter
	sb_rio_register(SB_DDLEND_addr,RIO_RO);



	//0x005F7C00    SB_PDSTAP   RW  PVR-DMA PVR start address
	sb_rio_register(SB_PDSTAP_addr,RIO_DATA);


	//0x005F7C04    SB_PDSTAR   RW  PVR-DMA system memory start address
	sb_rio_register(SB_PDSTAR_addr,RIO_DATA);


	//0x005F7C08    SB_PDLEN    RW  PVR-DMA length
	sb_rio_register(SB_PDLEN_addr,RIO_DATA);


	//0x005F7C0C    SB_PDDIR    RW  PVR-DMA direction
	sb_rio_register(SB_PDDIR_addr,RIO_DATA);


	//0x005F7C10    SB_PDTSEL   RW  PVR-DMA trigger select
	sb_rio_register(SB_PDTSEL_addr,RIO_DATA);


	//0x005F7C14    SB_PDEN     RW  PVR-DMA enable
	sb_rio_register(SB_PDEN_addr,RIO_DATA);


	//0x005F7C18    SB_PDST     RW  PVR-DMA start
	sb_rio_register(SB_PDST_addr,RIO_DATA);



	//0x005F7C80    SB_PDAPRO   W   PVR-DMA address range
	sb_rio_register(SB_PDAPRO_addr,RIO_WO_FUNC,0,sb_writeonly<SB_PDAPRO_addr>);



	//0x005F7CF0    SB_PDSTAPD  R   PVR-DMA address counter (on Ext)
	sb_rio_register(SB_PDSTAPD_addr,RIO_RO);


	//0x005F7CF4    SB_PDSTARD  R   PVR-DMA address counter (on root bus)
	sb_rio_register(SB_PDSTARD_addr,RIO_RO);


	//0x005F7CF8    SB_PDLEND   R   PVR-DMA transfer counter
	sb_rio_register(SB_PDLEND_addr,RIO_RO);


	//GDROM unlock register (bios checksumming, etc)
	//0x005f74e4
	sb_rio_register(0x005f74e4,RIO_WO_FUNC,0,sb_write_gdrom_unlock);

	//0x005f68a4, 0x005f68ac, 0x005f78a0,0x005f78a4, 0x005f78a8, 0x005f78b0, 0x005f78b4, 0x005f78b8
	sb_rio_register(0x005f68a4,RIO_WO_FUNC,0,sb_write_zero);
	sb_rio_register(0x005f68ac,RIO_WO_FUNC,0,sb_write_zero);
	sb_rio_register(0x005f78a0,RIO_WO_FUNC,0,sb_write_zero);
	sb_rio_register(0x005f78a4,RIO_WO_FUNC,0,sb_write_zero);
	sb_rio_register(0x005f78a8,RIO_WO_FUNC,0,sb_write_zero);
	sb_rio_register(0x005f78ac,RIO_WO_FUNC,0,sb_write_zero);
	sb_rio_register(0x005f78b0,RIO_WO_FUNC,0,sb_write_zero);
	sb_rio_register(0x005f78b4,RIO_WO_FUNC,0,sb_write_zero);
	sb_rio_register(0x005f78b8,RIO_WO_FUNC,0,sb_write_zero);


	SB_SBREV=0xB;
	SB_G2ID=0x12;
	SB_G1SYSM=((0x0<<4) | (0x1));

	asic_reg_Init();

#if DC_PLATFORM!=DC_PLATFORM_NAOMI
	gdrom_reg_Init();
#else
	naomi_reg_Init();
#endif

	pvr_sb_Init();
	maple_Init();
	aica_sb_Init();
}

void sb_Reset(bool Manual)
{
	asic_reg_Reset(Manual);
#if DC_PLATFORM!=DC_PLATFORM_NAOMI
	gdrom_reg_Reset(Manual);
#else
	naomi_reg_Reset(Manual);
#endif
	pvr_sb_Reset(Manual);
	maple_Reset(Manual);
	aica_sb_Reset(Manual);
}

void sb_Term()
{
	aica_sb_Term();
	maple_Term();
	pvr_sb_Term();
#if DC_PLATFORM!=DC_PLATFORM_NAOMI
	gdrom_reg_Term();
#else
	naomi_reg_Term();
#endif
	asic_reg_Term();
}