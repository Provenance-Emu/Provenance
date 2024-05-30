/*--------------------------------------------------
   TGB Dual - Gameboy Emulator -
   Copyright (C) 2001  Hii

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
*/

//------------------------------------------------
// CPU ニーモニック以外実装部 (I/O､IRQ 等)
// CPU emulation unit (I/O, IRQ, etc.)

#include "gb.h"
#include <string.h>

#define Z_FLAG 0x40
#define H_FLAG 0x10
#define N_FLAG 0x02
#define C_FLAG 0x01

cpu::cpu(gb *ref)
{
	ref_gb=ref;
	b_trace=false;

	for (int i=0;i<256;i++){
		z802gb[i]=((i&0x40)?0x80:0)|((i&0x10)?0x20:0)|((i&0x02)?0x40:0)|((i&0x01)?0x10:0);
		gb2z80[i]=((i&0x80)?0x40:0)|((i&0x40)?0x02:0)|((i&0x20)?0x10:0)|((i&0x10)?0x01:0);
	}

	reset();
}

cpu::~cpu()
{
}

void cpu::reset()
{
	regs.AF.w=(ref_gb->get_rom()->get_info()->gb_type>=3)?0x11b0:0x01b0;
	regs.BC.w=(ref_gb->get_rom()->get_info()->gb_type>=4)?0x0113:0x0013;
	regs.DE.w=0x00D8;
	regs.HL.w=0x014D;
	regs.I=0;
	regs.SP=0xFFFE;
	regs.PC=0x100;

	vram_bank=vram;
	ram_bank=ram+0x1000;

	rest_clock=0;
	total_clock=sys_clock=div_clock=0;
	seri_occer=0x7fffffff;
	halt=false;
	speed=false;
	speed_change=false;
	dma_executing=false;
	b_dma_first=false;
	gdma_rest=0;

	last_int=0;
	int_desable=false;

	memset(ram,0,sizeof(ram));
	memset(vram,0,sizeof(vram));
	memset(stack,0,sizeof(stack));
	memset(oam,0,sizeof(oam));
	memset(spare_oam,0,sizeof(spare_oam));

	rp_que[0]=0x000001cc;
	rp_que[1]=0x00000000;
	que_cur=1;
}

void cpu::save_state(int *dat)
{
	dat[0]=(ram_bank-ram)/0x1000;
	dat[1]=(vram_bank-vram)/0x2000;

	dat[2]=(speed?1:0);
	dat[3]=(dma_executing?1:0);
	dat[4]=dma_src;
	dat[5]=dma_dest;
	dat[6]=dma_rest;
	dat[7]=(speed_change?1:0);
}

void cpu::save_state_ex(int *dat)
{
	dat[0]=div_clock;
	dat[1]=rest_clock;
	dat[2]=sys_clock;
	dat[3]=total_clock;
}

void cpu::restore_state(int *dat)
{
	ram_bank=ram+dat[0]*0x1000;
	vram_bank=vram+dat[1]*0x2000;

	speed=(dat[2]?true:false);
	dma_executing=(dat[3]?true:false);
	dma_src=dat[4];
	dma_dest=dat[5];
	dma_rest=dat[6];
	speed_change=(dat[7]?true:false);
}

void cpu::restore_state_ex(int *dat)
{
	div_clock=dat[0];
	rest_clock=dat[1];
	sys_clock=dat[2];
	total_clock=dat[3];
}

byte cpu::read_direct(word adr)
{
	switch(adr>>13){
	case 0:
	case 1:
		return ref_gb->get_rom()->get_rom()[adr];//ROM領域 // ROM area
	case 2:
	case 3:
		return ref_gb->get_mbc()->get_rom()[adr];//バンク可能ROM // ROM bank
	case 4:
		return vram_bank[adr&0x1FFF];//8KBVRAM
	case 5:
		if (ref_gb->get_mbc()->is_ext_ram())
			return ref_gb->get_mbc()->get_sram()[adr&0x1FFF];//カートリッジRAM // cartridge RAM
		else
			return ref_gb->get_mbc()->ext_read(adr);
	case 6:
		if (adr&0x1000)
			return ram_bank[adr&0x0fff];
		else
			return ram[adr&0x0fff];
	case 7:
		if (adr<0xFE00){
			if (adr&0x1000)
				return ram_bank[adr&0x0fff];
			else
				return ram[adr&0x0fff];
		}
		else if (adr<0xFEA0)
			return oam[adr-0xFE00];//object attribute memory
		else if (adr<0xFF00)
			return spare_oam[(((adr-0xFFA0)>>5)<<3)|(adr&7)];
		else if (adr<0xFF80)
			return io_read(adr);//I/O
		else if (adr<0xFFFF)
			return stack[adr-0xFF80];//stack
		else
			return io_read(adr);//I/O
	}
	return 0;
}

void cpu::write(word adr,byte dat)
{
	switch(adr>>13){
	case 0:
	case 1:
	case 2:
	case 3:
		ref_gb->get_mbc()->write(adr,dat);
		break;
	case 4:
		vram_bank[adr&0x1FFF]=dat;
		break;
	case 5:
		if (ref_gb->get_mbc()->is_ext_ram())
			ref_gb->get_mbc()->get_sram()[adr&0x1FFF]=dat;//カートリッジRAM // cartridge RAM
		else
			ref_gb->get_mbc()->ext_write(adr,dat);
		break;
	case 6:
		if (adr&0x1000)
			ram_bank[adr&0x0fff]=dat;
		else
			ram[adr&0x0fff]=dat;
		break;
	case 7:
		if (adr<0xFE00){
			if (adr&0x1000)
				ram_bank[adr&0x0fff]=dat;
			else
				ram[adr&0x0fff]=dat;
		}
		else if (adr<0xFEA0)
			oam[adr-0xFE00]=dat;
		else if (adr<0xFF00)
			spare_oam[(((adr-0xFFA0)>>5)<<3)|(adr&7)]=dat;
		else if (adr<0xFF80)
			io_write(adr,dat);//I/O
		else if (adr<0xFFFF)
			stack[adr-0xFF80]=dat;//stack
		else
			io_write(adr,dat);//I/O
		break;
	}
}

byte cpu::io_read(word adr)
{
	byte ret;
	switch(adr){
	case 0xFF00://P1(パッド制御) //P1 (control pad)
		int tmp;
		tmp=ref_gb->get_renderer()->check_pad();
		if (ref_gb->get_regs()->P1==0x03)
			return 0xff;
		switch((ref_gb->get_regs()->P1>>4)&0x3){
		case 0:
			return 0xC0|((tmp&0x81?0:1)|(tmp&0x42?0:2)|(tmp&0x24?0:4)|(tmp&0x18?0:8));
		case 1:
			return 0xD0|((tmp&0x01?0:1)|(tmp&0x02?0:2)|(tmp&0x04?0:4)|(tmp&0x08?0:8));
		case 2:
			return 0xE0|((tmp&0x80?0:1)|(tmp&0x40?0:2)|(tmp&0x20?0:4)|(tmp&0x10?0:8));
		case 3:
			return 0xFF;
		}
		return 0x00;
	case 0xFF01://SB(シリアル通信送受信) // SB (sending and receiving serial communication)
//		fprintf(file,"Read SB %02X\n",ref_gb->get_regs()->SB);
		return ref_gb->get_regs()->SB;
	case 0xFF02://SC(シリアルコントロール) // SC (serial control)
//		fprintf(file,"Read SC %02X\n",ref_gb->get_regs()->SC);
		return (ref_gb->get_regs()->SC&0x83)|0x7C;
	case 0xFF04://DIV(ディバイダー?) // DIV (divider?)
		return ref_gb->get_regs()->DIV;
	case 0xFF05://TIMA(タイマカウンタ) // TIMA (timer counter)
		return ref_gb->get_regs()->TIMA;
	case 0xFF06://TMA(タイマ調整) // TMA (adjustment timer)
		return ref_gb->get_regs()->TMA;
	case 0xFF07://TAC(タイマコントロール) // TAC (timer control)
		return ref_gb->get_regs()->TAC;
	case 0xFF0F://IF(割りこみフラグ) // IF (Interrupt flag)
		return ref_gb->get_regs()->IF;
	case 0xFF40://LCDC(LCDコントロール) // LCDC (LCD control)
		return ref_gb->get_regs()->LCDC;
	case 0xFF41://STAT(LCDステータス) // STAT (LCD status)
		return ref_gb->get_regs()->STAT|0x80;
	case 0xFF42://SCY(スクロールY) // SCY (scroll Y)
		return ref_gb->get_regs()->SCY;
	case 0xFF43://SCX(スクロールX) // SCX (scroll X)
		return ref_gb->get_regs()->SCX;
	case 0xFF44://LY(LCDC Y座標) // LY (LCDC Y coordinate)
		return ref_gb->get_regs()->LY;
	case 0xFF45://LYC(LY比較) // LYC (compare LY)
		return ref_gb->get_regs()->LYC;
	case 0xFF46://DMA(DMA転送) // DMA (DMA transfer)
		return 0;
	case 0xFF47://BGP(背景パレット) BGP (background palette)
		return ref_gb->get_regs()->BGP;
	case 0xFF48://OBP1(オブジェクトパレット1) // OBP1 (object palette 1)
		return ref_gb->get_regs()->OBP1;
	case 0xFF49://OBP2(オブジェクトパレット2) // OBP2 (object palette 2)
		return ref_gb->get_regs()->OBP2;
	case 0xFF4A://WY(ウインドウY座標) // WY (window coordinates Y)
		return ref_gb->get_regs()->WY;
	case 0xFF4B://WX(ウインドウX座標) // WX (window coordinates X)
		return ref_gb->get_regs()->WX;

		//以下カラーでの追加 // Adding color below // TODO: continue translation
	case 0xFF4D://KEY1システムクロック変更 // KEY1 change system clock
		return (speed?0x80:(ref_gb->get_cregs()->KEY1&1)?1:0x7E);
	case 0xFF4F://VBK(内部VRAMバンク切り替え) // VBK (Internal bank switching VRAM)
		return ref_gb->get_cregs()->VBK;
	case 0xFF51://HDMA1(転送元上位) // HDMA (upper source)
		return dma_src>>8;
	case 0xFF52://HDMA2(転送元下位) // HDMA (lower source)
		return dma_src&0xff;
	case 0xFF53://HDMA3(転送先上位) // HDMA3 (upper destination)
		return dma_dest>>8;
	case 0xFF54://HDMA4(転送先下位) // HDMA4 (lower destination)
		return dma_dest&0xff;
	case 0xFF55://HDMA5(転送実行) // HDMA5 (run forward)
		return (dma_executing?((dma_rest-1)&0x7f):0xFF);
	case 0xFF56://RP(赤外線) // RP (infrared)
		if (ref_gb->get_target()){
			if ((ref_gb->get_cregs()->RP&0xC0)==0xC0){
				dword *que=ref_gb->get_target()->get_cpu()->rp_que;
				int que_cnt=0;
				int cur;
				while((que[que_cnt]&0xffff)>rest_clock)	cur=que[que_cnt++]>>16;
//				fprintf(file,"read RP %02X\n",(ref_gb->get_cregs()->RP&1)|((cur&1)<<1)|0xC0);
				return (ref_gb->get_cregs()->RP&1)|((cur&1)<<1)|0xC0;

//				fprintf(file,"read RP %02X\n",(ref_gb->get_cregs()->RP&1)|((ref_gb->get_target()->get_cregs()->RP&1)<<1)|0xC0);
//				return (ref_gb->get_cregs()->RP&1)|((ref_gb->get_target()->get_cregs()->RP&1)<<1)|0xC0;
			}
			else{
//				fprintf(file,"read RP %02X\n",(ref_gb->get_cregs()->RP&1));
				return (ref_gb->get_cregs()->RP&1);
			}
		}
		else{
			if (ref_gb->hook_ext){ // フックします // Hook
				if ((ref_gb->get_cregs()->RP&0xC0)==0xC0)
					return (ref_gb->get_cregs()->RP&1)|(ref_gb->hook_proc.led()?2:0)|0xC0;
				else
					return (ref_gb->get_cregs()->RP&0xC1);
			}
			else
				return (ref_gb->get_cregs()->RP&0xC1);
		}
	case 0xFF68://BCPS(BGパレット書き込み指定) // BG write palette
		return ref_gb->get_cregs()->BCPS;
	case 0xFF69://BCPD(BGパレット書きこみデータ) // BG palette data written
		if (ref_gb->get_cregs()->BCPS&1)
			ret=ref_gb->get_lcd()->get_pal((ref_gb->get_cregs()->BCPS>>3)&7)[(ref_gb->get_cregs()->BCPS>>1)&3]>>8;
		else
			ret=ref_gb->get_lcd()->get_pal((ref_gb->get_cregs()->BCPS>>3)&7)[(ref_gb->get_cregs()->BCPS>>1)&3]&0xff;
/*		if (ref_gb->get_cregs()->BCPS&1)
			ret=ref_gb->get_renderer()->unmap_color(ref_gb->get_lcd()->get_pal((ref_gb->get_cregs()->BCPS>>3)&7)[(ref_gb->get_cregs()->BCPS>>1)&3])>>8;
		else
			ret=ref_gb->get_renderer()->unmap_color(ref_gb->get_lcd()->get_pal((ref_gb->get_cregs()->BCPS>>3)&7)[(ref_gb->get_cregs()->BCPS>>1)&3])&0xff;
*/		//ポインタはインクリメントされない(おじゃる丸) // pointer is not incremented (Round Ojaru)
		return ret;
	case 0xFF6A://OCPS(OBJパレット書きこみ指定) // OBJ palette specified written
		return ref_gb->get_cregs()->OCPS;
	case 0xFF6B://OCPD(OBJパレット書きこみデータ) // Write data OBJ palette
		if (ref_gb->get_cregs()->OCPS&1)
			ret=ref_gb->get_lcd()->get_pal(((ref_gb->get_cregs()->OCPS>>3)&7)+8)[(ref_gb->get_cregs()->OCPS>>1)&3]>>8;
		else
			ret=ref_gb->get_lcd()->get_pal(((ref_gb->get_cregs()->OCPS>>3)&7)+8)[(ref_gb->get_cregs()->OCPS>>1)&3]&0xff;
/*		if (ref_gb->get_cregs()->OCPS&1)
			ret=ref_gb->get_renderer()->unmap_color(ref_gb->get_lcd()->get_pal(((ref_gb->get_cregs()->OCPS>>3)&7)+8)[(ref_gb->get_cregs()->OCPS>>1)&3])>>8;
		else
			ret=ref_gb->get_renderer()->unmap_color(ref_gb->get_lcd()->get_pal(((ref_gb->get_cregs()->OCPS>>3)&7)+8)[(ref_gb->get_cregs()->OCPS>>1)&3])&0xff;
*/		return ret;
	case 0xFF70://SVBK(内部RAMバンク切り替え) // Internal RAM bank switching
		return ref_gb->get_cregs()->SVBK;

	case 0xFFFF://IE(割りこみマスク) // Interrupt Mask
		return ref_gb->get_regs()->IE;

	// undocumented register
	case 0xFF6C:
		return _ff6c&1;
	case 0xFF72:
		return _ff72;
	case 0xFF73:
		return _ff73;
	case 0xFF74:
		return _ff74;
	case 0xFF75:
		return _ff75&0x70;
	case 0xFF76:
		return 0;
	case 0xFF77:
		return 0;
	default:
		if (adr>0xFF0F&&adr<0xFF40){
			return ref_gb->get_apu()->read(adr);
		}
		else if ((adr>0xff70)&&(adr<0xff80))
			return ext_mem[adr-0xff71];
		else
			return 0;
	}
}

void cpu::io_write(word adr,byte dat)
{
		switch(adr){
		case 0xFF00://P1(パッド制御) // P1 (control pad)
			ref_gb->get_regs()->P1=dat;
			return;
		case 0xFF01://SB(シリアルシリアル通信送受信) // SB (sending and receiving serial communication)
			ref_gb->get_regs()->SB=dat;
			return;
		case 0xFF02://SC(コントロール) // SC (control)
			if (ref_gb->get_rom()->get_info()->gb_type==1){
				ref_gb->get_regs()->SC=dat&0x81;
				if ((dat&0x80)&&(dat&1)) // 送信開始 // Transmission start
					seri_occer=total_clock+512;
			}
			else{ // GBCでの拡張 // Enhancements in GBC
				ref_gb->get_regs()->SC = dat & 0x83;
				if ((dat & 0x80) && (dat & 1)) // 送信開始 // Transmission start
            {
					if (dat & 2)
						seri_occer = total_clock + 512 * 8 / 32; // 転送速度通常の32倍 // 32 times the normal transfer rate
					else
						seri_occer = total_clock + 512 * 8;
            }
			}
			return;
		case 0xFF04://DIV(ディバイダー) // DIV (divider)
			ref_gb->get_regs()->DIV=0;
			return;
		case 0xFF05://TIMA(タイマカウンタ) // TIMA (timer counter)
			ref_gb->get_regs()->TIMA=dat;
//			sys_clock=0;
			return;
		case 0xFF06://TMA(タイマ調整) // TMA (adjustment timer)
			ref_gb->get_regs()->TMA=dat;
//			sys_clock=0;
			return;
		case 0xFF07://TAC(タイマコントロール) // TAC (timer control)
			if ((dat&0x04)&&!(ref_gb->get_regs()->TAC&0x04))
				sys_clock=0;
			ref_gb->get_regs()->TAC=dat;
			return;
		case 0xFF0F://IF(割りこみフラグ) // IF (Interrupt flag)
			ref_gb->get_regs()->IF=dat;
			return;
		case 0xFF40://LCDC(LCDコントロール) // LCDC (LCD control)
			if ((dat&0x80)&&(!(ref_gb->get_regs()->LCDC&0x80))){
				ref_gb->get_regs()->LY=0;
				ref_gb->get_lcd()->clear_win_count();
			}
			ref_gb->get_regs()->LCDC=dat;
//			fprintf(file,"LCDC=%02X at line %d\n",dat,ref_gb->get_regs()->LY);
			return;
		case 0xFF41://STAT(LCDステータス) // STAT (LCD status)
			if (ref_gb->get_rom()->get_info()->gb_type==1)
				// オリジナルGBにおいてこのような現象が起こるらしい
				// This phenomenon seems to occur in the original GB
				if (!(ref_gb->get_regs()->STAT&0x02))
					ref_gb->get_regs()->IF|=INT_LCDC;

			ref_gb->get_regs()->STAT=(ref_gb->get_regs()->STAT&0x7)|(dat&0x78);
			return;
		case 0xFF42://SCY(スクロールY) // SCY (scroll Y)
			ref_gb->get_regs()->SCY=dat;
			return;
		case 0xFF43://SCX(スクロールX) // SCX (scroll X)
			ref_gb->get_regs()->SCX=dat;
			return;
		case 0xFF44://LY(LCDC Y座標) // LY (LCDC Y coordinate)
//			ref_gb->get_regs()->LY=0;
			ref_gb->get_lcd()->clear_win_count();
			return;
		case 0xFF45://LYC(LY比較) // LYC (compare LY)
			ref_gb->get_regs()->LYC=dat;
			return;
		case 0xFF46://DMA(DMA転送) // DMA (DMA transfer)
			switch(dat>>5){
			case 0:
			case 1:
				memcpy(oam,ref_gb->get_rom()->get_rom()+dat*256,0xA0);
				break;
			case 2:
			case 3:
				memcpy(oam,ref_gb->get_mbc()->get_rom()+dat*256,0xA0);
				break;
			case 4:
				memcpy(oam,vram_bank+(dat&0x1F)*256,0xA0);
				break;
			case 5:
				memcpy(oam,ref_gb->get_mbc()->get_sram()+(dat&0x1F)*256,0xA0);
				break;
			case 6:
				if (dat&0x10)
					memcpy(oam,ram_bank+(dat&0x0F)*256,0xA0);
				else
					memcpy(oam,ram+(dat&0x0F)*256,0xA0);
				break;
			case 7:
				if (dat<0xF2){
					if (dat&0x10)
						memcpy(oam,ram_bank+(dat&0x0F)*256,0xA0);
					else
						memcpy(oam,ram+(dat&0x0F)*256,0xA0);
				}
				break;
			}
			return;
		case 0xFF47://BGP(背景パレット) // BGP (background palette)
			ref_gb->get_regs()->BGP=dat;
			return;
		case 0xFF48://OBP1(オブジェクトパレット1) // OBP1 (object palette 1)
			ref_gb->get_regs()->OBP1=dat;
			return;
		case 0xFF49://OBP2(オブジェクトパレット2) // OBP2 (object palette 2)
			ref_gb->get_regs()->OBP2=dat;
			return;
		case 0xFF4A://WY(ウインドウY座標) // WY (window coordinates Y)
			ref_gb->get_regs()->WY=dat;
			return;
		case 0xFF4B://WX(ウインドウX座標) // WX (window coordinates X)
			ref_gb->get_regs()->WX=dat;
			return;

			//以下カラーでの追加 // Add color below
		case 0xFF4D://KEY1システムクロック変更 // KEY1 change system clock
//			speed=dat&1;
			ref_gb->get_cregs()->KEY1=dat&1;
			speed_change=dat&1;
			return;
		case 0xFF4F://VBK(内部VRAMバンク切り替え) // VBK (VRAM internal bank switching)
			if (dma_executing)
				return;
			vram_bank=vram+0x2000*(dat&0x01);
			ref_gb->get_cregs()->VBK=dat;//&0x01;
			return;
		case 0xFF51://HDMA1(転送元上位) // HDMA1 (upper source)
			dma_src&=0x00F0;
			dma_src|=(dat<<8);
			return;
		case 0xFF52://HDMA2(転送元下位) // HDMA2 (lower source)
			dma_src&=0xFF00;
			dma_src|=(dat&0xF0);
			return;
		case 0xFF53://HDMA3(転送先上位) // HDMA3 (upper destination)
			dma_dest&=0x00F0;
			dma_dest|=((dat&0xFF)<<8);
			return;
		case 0xFF54://HDMA4(転送先下位) // HDMA4 (lower destination)
			dma_dest&=0xFF00;
			dma_dest|=(dat&0xF0);
			return;
		case 0xFF55://HDMA5(転送実行) // HDMA5 (run forward)
			word tmp_adr;
			tmp_adr=0x8000+(dma_dest&0x1ff0);
//			fprintf(file,"%03d : %04X -> %04X  %d byte %s\n",ref_gb->get_regs()->LY,dma_src,dma_dest,((dat&0x7f)+1)*16,(dat&0x80)?"delay":"immidiately");
			if ((dma_src>=0x8000&&dma_src<0xA000)||(dma_src>=0xE000)||(!(tmp_adr>=0x8000&&tmp_adr<0xA000))){
				ref_gb->get_cregs()->HDMA5=0;
				return;
			}
			if (dat&0x80){ //HBlank毎 // Every HBlank
				if (dma_executing){
					dma_executing=false;
					dma_rest=0;
					ref_gb->get_cregs()->HDMA5=0xFF;
					return;
				}
				dma_executing=true;
				b_dma_first=true;
				dma_rest=(dat&0x7F)+1;
				ref_gb->get_cregs()->HDMA5=0;
/*				dma_dest_bank=vram_bank;
				if (dma_src<0x4000)
					dma_src_bank=ref_gb->get_rom()->get_rom();
				else if (dma_src<0x8000)
					dma_src_bank=ref_gb->get_mbc()->get_rom()-0x4000;
				else if (dma_src>=0xA000&&dma_src<0xC000)
					dma_src_bank=ref_gb->get_mbc()->get_sram()-0xA000;
				else if (dma_src>=0xC000&&dma_src<0xD000)
					dma_src_bank=ram-0xC000;
				else if (dma_src>=0xD000&&dma_src<0xE000)
					dma_src_bank=ram_bank-0xD000;
				else dma_src_bank=NULL;
*/			}
			else{ //通常DMA // Normal DMA
				if (dma_executing){
					dma_executing=false;
					dma_rest=0;
					ref_gb->get_cregs()->HDMA5=0xFF;
//					fprintf(file,"dma stopped\n");
					return;
				}
				// どうやら､HBlank以外ならいつでもOKみたいだ
				// Apparently, it seems OK except HBlank anytime
//				if (!(((ref_gb->get_regs()->STAT&3)==1)||(!(ref_gb->get_regs()->LCDC&0x80)))){
//					ref_gb->get_cregs()->HDMA5=0;
//					return;
//				}

				dma_executing=false;
				dma_rest=0;
				ref_gb->get_cregs()->HDMA5=0xFF;

				switch(dma_src>>13){
				case 0:
				case 1:
					memcpy(vram_bank+(dma_dest&0x1ff0),ref_gb->get_rom()->get_rom()+(dma_src),16*(dat&0x7F)+16);
					break;
				case 2:
				case 3:
					memcpy(vram_bank+(dma_dest&0x1ff0),ref_gb->get_mbc()->get_rom()+(dma_src),16*(dat&0x7F)+16);
					break;
				case 4:
					break;
				case 5:
					memcpy(vram_bank+(dma_dest&0x1ff0),ref_gb->get_mbc()->get_sram()+(dma_src&0x1FFF),16*(dat&0x7F)+16);
					break;
				case 6:
					if (dma_src&0x1000)
						memcpy(vram_bank+(dma_dest&0x1ff0),ram_bank+(dma_src&0x0FFF),16*(dat&0x7F)+16);
					else
						memcpy(vram_bank+(dma_dest&0x1ff0),ram+(dma_src&0x0FFF),16*(dat&0x7F)+16);
					break;
				case 7:
					break;
				}
				dma_src+=((dat&0x7F)+1)*16;
				dma_dest+=((dat&0x7F)+1)*16;

				gdma_rest=456*2+((dat&0x7f)+1)*32*(speed?2:1); // CPU パワーを占領 // Occupied the CPU power
			}
			return;
		case 0xFF56://RP(赤外線) // RP (infrared)
//			fprintf(file,"RP=%02X\n",dat);
			rp_que[que_cur++]=(((dword)dat)<<16)|((word)rest_clock);
			rp_que[que_cur]=0x00000000;
			ref_gb->get_cregs()->RP=dat;
			return;
		case 0xFF68://BCPS(BGパレット書き込み指定) // BCPS (write BG palette)
			ref_gb->get_cregs()->BCPS=dat;
			return;
		case 0xFF69://BCPD(BGパレット書きこみデータ xBBBBBGG GGGRRRRR) // (write BG palette data xBBBBBGG GGGRRRR)
			if (ref_gb->get_cregs()->BCPS&1){
				ref_gb->get_lcd()->get_pal((ref_gb->get_cregs()->BCPS>>3)&7)[(ref_gb->get_cregs()->BCPS>>1)&3]=
				(ref_gb->get_lcd()->get_pal((ref_gb->get_cregs()->BCPS>>3)&7)[(ref_gb->get_cregs()->BCPS>>1)&3]&0xff)|(dat<<8);
			}
			else{
				ref_gb->get_lcd()->get_pal((ref_gb->get_cregs()->BCPS>>3)&7)[(ref_gb->get_cregs()->BCPS>>1)&3]=
				(ref_gb->get_lcd()->get_pal((ref_gb->get_cregs()->BCPS>>3)&7)[(ref_gb->get_cregs()->BCPS>>1)&3]&0xff00)|dat;
			}
			ref_gb->get_lcd()->get_mapped_pal((ref_gb->get_cregs()->BCPS>>3)&7)[(ref_gb->get_cregs()->BCPS>>1)&3]=
				ref_gb->get_renderer()->map_color(ref_gb->get_lcd()->get_pal((ref_gb->get_cregs()->BCPS>>3)&7)[(ref_gb->get_cregs()->BCPS>>1)&3]);
/*			if (ref_gb->get_cregs()->BCPS&1){
				ref_gb->get_lcd()->get_pal((ref_gb->get_cregs()->BCPS>>3)&7)[(ref_gb->get_cregs()->BCPS>>1)&3]=
					ref_gb->get_renderer()->map_color(((ref_gb->get_renderer()->unmap_color(ref_gb->get_lcd()->get_pal((ref_gb->get_cregs()->BCPS>>3)&7)[(ref_gb->get_cregs()->BCPS>>1)&3])&0xff)|(dat<<8)));
			}
			else{
				ref_gb->get_lcd()->get_pal((ref_gb->get_cregs()->BCPS>>3)&7)[(ref_gb->get_cregs()->BCPS>>1)&3]=
					ref_gb->get_renderer()->map_color(((ref_gb->get_renderer()->unmap_color(ref_gb->get_lcd()->get_pal((ref_gb->get_cregs()->BCPS>>3)&7)[(ref_gb->get_cregs()->BCPS>>1)&3])&0xff00)|(dat)));
			}*/
			ref_gb->get_cregs()->BCPD=dat;
			if (ref_gb->get_cregs()->BCPS&0x80)
				ref_gb->get_cregs()->BCPS=0x80|((ref_gb->get_cregs()->BCPS+1)&0x3f);
//			fprintf(file,"%d :BCPS = %02X\n",ref_gb->get_regs()->LY,dat);
			return;
		case 0xFF6A://OCPS(OBJパレット書きこみ指定) // OCPS (Specify write OBJ palette)
			ref_gb->get_cregs()->OCPS=dat;
			return;
		case 0xFF6B://OCPD(OBJパレット書きこみデータ) // OCPD (Write data OBJ palette)
			if (ref_gb->get_cregs()->OCPS&1){
				ref_gb->get_lcd()->get_pal(((ref_gb->get_cregs()->OCPS>>3)&7)+8)[(ref_gb->get_cregs()->OCPS>>1)&3]=
				(ref_gb->get_lcd()->get_pal(((ref_gb->get_cregs()->OCPS>>3)&7)+8)[(ref_gb->get_cregs()->OCPS>>1)&3]&0xff)|(dat<<8);
			}
			else{
				ref_gb->get_lcd()->get_pal(((ref_gb->get_cregs()->OCPS>>3)&7)+8)[(ref_gb->get_cregs()->OCPS>>1)&3]=
				(ref_gb->get_lcd()->get_pal(((ref_gb->get_cregs()->OCPS>>3)&7)+8)[(ref_gb->get_cregs()->OCPS>>1)&3]&0xff00)|dat;
			}
			ref_gb->get_lcd()->get_mapped_pal(((ref_gb->get_cregs()->OCPS>>3)&7)+8)[(ref_gb->get_cregs()->OCPS>>1)&3]=
				ref_gb->get_renderer()->map_color(ref_gb->get_lcd()->get_pal(((ref_gb->get_cregs()->OCPS>>3)&7)+8)[(ref_gb->get_cregs()->OCPS>>1)&3]);
/*			if (ref_gb->get_cregs()->OCPS&1){
				ref_gb->get_lcd()->get_pal(((ref_gb->get_cregs()->OCPS>>3)&7)+8)[(ref_gb->get_cregs()->OCPS>>1)&3]=
					ref_gb->get_renderer()->map_color(((ref_gb->get_renderer()->unmap_color(ref_gb->get_lcd()->get_pal(((ref_gb->get_cregs()->OCPS>>3)&7)+8)[(ref_gb->get_cregs()->OCPS>>1)&3])&0xff)|(dat<<8)));
			}
			else{
				ref_gb->get_lcd()->get_pal(((ref_gb->get_cregs()->OCPS>>3)&7)+8)[(ref_gb->get_cregs()->OCPS>>1)&3]=
					ref_gb->get_renderer()->map_color(((ref_gb->get_renderer()->unmap_color(ref_gb->get_lcd()->get_pal(((ref_gb->get_cregs()->OCPS>>3)&7)+8)[(ref_gb->get_cregs()->OCPS>>1)&3])&0xff00)|(dat)));
			}*/
			ref_gb->get_cregs()->OCPD=dat;
			if (ref_gb->get_cregs()->OCPS&0x80)
				ref_gb->get_cregs()->OCPS=0x80|((ref_gb->get_cregs()->OCPS+1)&0x3f);
			return;
		case 0xFF70://SVBK(内部RAMバンク切り替え) // SVBK (RAM internal bank switching)
//			if (dma_executing)
//				return;

			dat=(!(dat&7))?1:(dat&7);
			ref_gb->get_cregs()->SVBK=dat;
			ram_bank=ram+0x1000*dat;
			return;

		case 0xFFFF://IE(割りこみマスク) // IE (Interrupt mask)
			ref_gb->get_regs()->IE=dat;
//			ref_gb->get_regs()->IF=0;
//			fprintf(file,"IE = %02X\n",dat);
			return;

		// undocumented register
		case 0xFF6C:
			_ff6c=dat&1;
			return;
		case 0xFF72:
			_ff72=dat;
			return;
		case 0xFF73:
			_ff73=dat;
			return;
		case 0xFF74:
			_ff74=dat;
			return;
		case 0xff75:
			_ff75=dat&0x70;
			return;

		default:
			if (adr>0xFF0F&&adr<0xFF40){
				ref_gb->get_apu()->write(adr,dat,total_clock);
				return;
			}
			else if ((adr>0xff70)&&(adr<0xff80))
				ext_mem[adr-0xff71]=dat;
		}
}
/*
static int cycles[256] =
{
	4,12,8,8,4,4,8,4,4,12,8,8,4,4,8,4,
	8,12,8,8,4,4,8,4,8,12,8,8,4,4,8,4,
	8,12,8,8,4,4,8,4,8,12,8,8,4,4,8,4,
	8,12,8,8,12,12,12,4,8,12,8,8,4,4,8,4,
	4,4,4,4,4,4,8,4,4,4,4,4,4,4,8,4,
	4,4,4,4,4,4,8,4,4,4,4,4,4,4,8,4,
	4,4,4,4,4,4,8,4,4,4,4,4,4,4,8,4,
	8,8,8,8,8,8,4,8,4,4,4,4,4,4,8,4,
	4,4,4,4,4,4,8,4,4,4,4,4,4,4,8,4,
	4,4,4,4,4,4,8,4,4,4,4,4,4,4,8,4,
	4,4,4,4,4,4,8,4,4,4,4,4,4,4,8,4,
	4,4,4,4,4,4,8,4,4,4,4,4,4,4,8,4,
	8,12,16,16,12,16,8,16,8,16,16,0,12,24,8,16,
	8,12,16,16,12,16,8,16,8,16,16,16,12,24,8,16,
	12,12,8,12,12,16,8,16,16,4,16,12,12,12,8,16,
	12,12,8,4,12,16,8,16,12,8,16,4,12,12,8,16
};
*/

static int cycles[256] =
{
//   0  1  2  3  4  5  6  7  8  9  A  B  C  D  E  F
	 4,12, 8, 8, 4, 4, 8, 4,20, 8, 8, 8, 4, 4, 8, 4,//0
	 4,12, 8, 8, 4, 4, 8, 4,12, 8, 8, 8, 4, 4, 8, 4,//1
	 8,12, 8, 8, 4, 4, 8, 4, 8, 8, 8, 8, 4, 4, 8, 4,//2
	 8,12, 8, 8,12,12,12, 4, 8, 8, 8, 8, 4, 4, 8, 4,//3
	 4, 4, 4, 4, 4, 4, 8, 4, 4, 4, 4, 4, 4, 4, 8, 4,//4
	 4, 4, 4, 4, 4, 4, 8, 4, 4, 4, 4, 4, 4, 4, 8, 4,//5
	 4, 4, 4, 4, 4, 4, 8, 4, 4, 4, 4, 4, 4, 4, 8, 4,//6
	 8, 8, 8, 8, 8, 8, 4, 8, 4, 4, 4, 4, 4, 4, 8, 4,//7
	 4, 4, 4, 4, 4, 4, 8, 4, 4, 4, 4, 4, 4, 4, 8, 4,//8
	 4, 4, 4, 4, 4, 4, 8, 4, 4, 4, 4, 4, 4, 4, 8, 4,//9
	 4, 4, 4, 4, 4, 4, 8, 4, 4, 4, 4, 4, 4, 4, 8, 4,//A
	 4, 4, 4, 4, 4, 4, 8, 4, 4, 4, 4, 4, 4, 4, 8, 4,//B
	 8,12,12,16,12,16, 8,16, 8,16,12, 0,12,24, 8,16,//C
	 8,12,12, 0,12,16, 8,16, 8,16,12, 0,12, 0, 8,16,//D
	12,12, 8, 0, 0,16, 8,16,16, 4,16, 0, 0, 0, 8,16,//E
	12,12, 8, 4, 0,16, 8,16,12, 8,16, 4, 0, 0, 8,16 //F
};

/*
static int cycles[256] =
{
   4,12, 8, 8, 4, 4, 8, 4,20, 8, 8, 8, 4, 4, 8, 4,
   4,12, 8, 8, 4, 4, 8, 4, 8, 8, 8, 8, 4, 4, 8, 4,
   8,12, 8, 8, 4, 4, 8, 4, 8, 8, 8, 8, 4, 4, 8, 4,
   8,12, 8, 8,12,12,12, 4, 8, 8, 8, 8, 4, 4, 8, 4,
   4, 4, 4, 4, 4, 4, 8, 4, 4, 4, 4, 4, 4, 4, 8, 4,
   4, 4, 4, 4, 4, 4, 8, 4, 4, 4, 4, 4, 4, 4, 8, 4,
   4, 4, 4, 4, 4, 4, 8, 4, 4, 4, 4, 4, 4, 4, 8, 4,
   8, 8, 8, 8, 8, 8, 4, 8, 4, 4, 4, 4, 4, 4, 8, 4,
   4, 4, 4, 4, 4, 4, 8, 4, 4, 4, 4, 4, 4, 4, 8, 4,
   4, 4, 4, 4, 4, 4, 8, 4, 4, 4, 4, 4, 4, 4, 8, 4,
   4, 4, 4, 4, 4, 4, 8, 4, 4, 4, 4, 4, 4, 4, 8, 4,
   4, 4, 4, 4, 4, 4, 8, 4, 4, 4, 4, 4, 4, 4, 8, 4,
   8,12,12,12,12,16, 8,32, 8, 8,12, 0,12,12, 8,32,
   8,12,12, 0,12,16, 8,32, 8, 8,12, 0,12, 0, 8,32,
  12,12, 8, 0, 0,16, 8,32,16, 4,16, 0, 0, 0, 8,32,
  12,12, 8, 4, 0,16, 8,32,12, 8,16, 4, 0, 0, 8,32
};
*/

static int cycles_cb[256] =
{
   8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8,
   8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8,
   8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8,
   8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8,
   8, 8, 8, 8, 8, 8,12, 8, 8, 8, 8, 8, 8, 8,12, 8,
   8, 8, 8, 8, 8, 8,12, 8, 8, 8, 8, 8, 8, 8,12, 8,
   8, 8, 8, 8, 8, 8,12, 8, 8, 8, 8, 8, 8, 8,12, 8,
   8, 8, 8, 8, 8, 8,12, 8, 8, 8, 8, 8, 8, 8,12, 8,
   8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8,
   8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8,
   8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8,
   8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8,
   8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8,
   8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8,
   8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8,
   8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8
};

/*static int cycles_cb[256] =
{
   8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8,
   8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8,
   8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8,
   8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8,
   8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8,
   8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8,
   8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8,
   8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8,
   8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8,
   8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8,
   8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8,
   8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8,
   8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8,
   8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8,
   8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8,
   8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8
};
*/
static const byte ZTable[256] =
{
  Z_FLAG,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
};

byte cpu::seri_send(byte dat)
{
//	if ((!(ref_gb->get_regs()->IE&INT_SERIAL))||(ref_gb->get_regs()->IF&INT_SERIAL))
//		return 0xFF;

	if ((ref_gb->get_regs()->SC&0x81)==0x80){
//		fprintf(file,"seri_recv my:%02X tar:%02X state SC:%02X\n",ref_gb->get_regs()->SB,dat,ref_gb->get_regs()->SC);
		byte ret=ref_gb->get_regs()->SB;
		ref_gb->get_regs()->SB=dat;
		ref_gb->get_regs()->SC&=1;
		irq(INT_SERIAL);
		return ret;
	}
	else
		return 0xFF;
}

void cpu::irq(int irq_type)
{
//	fprintf(file,"irq %02X LCDC %02X\n",irq_type,ref_gb->get_regs()->LCDC);
	if (!((irq_type==INT_VBLANK||irq_type==INT_LCDC)&&(!(ref_gb->get_regs()->LCDC&0x80))))
//		if (last_int!=irq_type)
			ref_gb->get_regs()->IF|=(irq_type/*&ref_gb->get_regs()->IE*/);
//	ref_gb->get_regs()->IF|=irq_type;
}

void cpu::irq_process()
{
	if (int_desable){
		int_desable=false;
		return;
	}

	if ((ref_gb->get_regs()->IF&ref_gb->get_regs()->IE)&&(regs.I||halt)){//割りこみがかかる時 // Time-consuming interrupt
		if (halt)
			regs.PC++;
		write(regs.SP-2,regs.PC&0xFF);write(regs.SP-1,(regs.PC>>8));regs.SP-=2;
		if (ref_gb->get_regs()->IF&ref_gb->get_regs()->IE&INT_VBLANK){//VBlank
			regs.PC=0x40;
			ref_gb->get_regs()->IF&=0xFE;
			last_int=INT_VBLANK;
		}
		else if (ref_gb->get_regs()->IF&ref_gb->get_regs()->IE&INT_LCDC){//LCDC
			regs.PC=0x48;
			ref_gb->get_regs()->IF&=0xFD;
			last_int=INT_LCDC;
		}
		else if (ref_gb->get_regs()->IF&ref_gb->get_regs()->IE&INT_TIMER){//Timer
			regs.PC=0x50;
			ref_gb->get_regs()->IF&=0xFB;
			last_int=INT_TIMER;
		}
		else if (ref_gb->get_regs()->IF&ref_gb->get_regs()->IE&INT_SERIAL){//Serial
			regs.PC=0x58;
			ref_gb->get_regs()->IF&=0xF7;
			last_int=INT_SERIAL;
		}
		else if (ref_gb->get_regs()->IF&ref_gb->get_regs()->IE&INT_PAD){//Pad
			regs.PC=0x60;
			ref_gb->get_regs()->IF&=0xEF;
			last_int=INT_PAD;
		}
		else {}

		halt=false;
		regs.I=0;
//		ref_gb->get_regs()->IF=0;
	}
}

void cpu::exec(int clocks)
{
	if (speed)
		clocks*=2;

	rp_que[0]=clocks+8;
	rp_que[1]=0x00000000;
	que_cur=1;

	int op_code;
	int tmp_clocks;
	byte tmpb;
	pare_reg tmp;
	static const int timer_clocks[]={1024,16,64,256};

	rest_clock+=clocks;

	if (gdma_rest){
		if (rest_clock<=gdma_rest){
			gdma_rest-=rest_clock;
			sys_clock+=rest_clock;
			div_clock+=rest_clock;
			total_clock+=rest_clock;
			rest_clock=0;
		}
		else{
			rest_clock-=gdma_rest;
			sys_clock+=gdma_rest;
			div_clock+=gdma_rest;
			total_clock+=gdma_rest;
			gdma_rest=0;
		}
	}

	while(rest_clock>0){
		irq_process();

		op_code=op_read();
		tmp_clocks=cycles[op_code];

//		if (b_trace)
//			log();

		switch(op_code)
		{
#include "op_normal.h"
		case 0xCB:
			op_code=op_read();
			tmp_clocks=cycles_cb[op_code];
			switch(op_code){
#include "op_cb.h"
			}
			break;
		}

		rest_clock-=tmp_clocks;
		div_clock+=tmp_clocks;
		total_clock+=tmp_clocks;

		if (ref_gb->get_regs()->TAC&0x04){//タイマ割りこみ // Timer interrupt
			sys_clock+=tmp_clocks;
			if (sys_clock>timer_clocks[ref_gb->get_regs()->TAC&0x03]){
				sys_clock&=timer_clocks[ref_gb->get_regs()->TAC&0x03]-1;
				ref_gb->get_regs()->TIMA++;
				if (!ref_gb->get_regs()->TIMA){
					irq(INT_TIMER);
					ref_gb->get_regs()->TIMA=ref_gb->get_regs()->TMA;
				}
			}
		}

		if (div_clock&0x100){
			ref_gb->get_regs()->DIV-=div_clock>>8;
			div_clock&=0xff;
		}

		if (total_clock>seri_occer){
			seri_occer=0x7fffffff;
			if (ref_gb->get_target()){
				byte ret=ref_gb->get_target()->get_cpu()->seri_send(ref_gb->get_regs()->SB);
				ref_gb->get_regs()->SB=ret;
				ref_gb->get_regs()->SC&=3;
			}
			else{
				if (ref_gb->hook_ext){ // フックします // Hook
					byte ret=ref_gb->hook_proc.send(ref_gb->get_regs()->SB);
					ref_gb->get_regs()->SB=ret;
					ref_gb->get_regs()->SC&=3;
				}
				else{
					ref_gb->get_regs()->SB=0xff;
					ref_gb->get_regs()->SC&=3;
				}
			}
			irq(INT_SERIAL);
		}
	}
}

void cpu::serialize(serializer &s)
{
	int tmp;

	tmp = ( ram_bank- ram)/0x1000; s_VAR(tmp);  ram_bank =  ram + tmp*0x1000;
	tmp = (vram_bank-vram)/0x2000; s_VAR(tmp); vram_bank = vram + tmp*0x2000;

	s_VAR(regs);

	if (ref_gb->get_rom()->get_info()->gb_type >= 3) { // GB: 1, SGB: 2, GBC: 3...
		s_ARRAY(ram);
		s_ARRAY(vram);
	} else {
		s.process(ram, 0x2000);
		s.process(vram,0x2000);
	}
	s_ARRAY(stack);
	s_ARRAY(oam);

	// these next four weren't originally in the save state
	s_ARRAY(spare_oam);
	s_ARRAY(ext_mem);
	s_ARRAY(rp_que);
	s_VAR(que_cur);

	s_VAR(total_clock);
	s_VAR(rest_clock);
	s_VAR(sys_clock);
	s_VAR(div_clock);
	s_VAR(seri_occer); // nor was this

	s_VAR(halt);
	s_VAR(speed);
	s_VAR(speed_change);
	s_VAR(dma_executing);

	s_VAR(dma_src);
	s_VAR(dma_dest);
	s_VAR(dma_rest);
	s_VAR(gdma_rest); // or these
	s_VAR(b_dma_first); // two.

	// undocumented registers:
	s_VAR(_ff6c); s_VAR(_ff72); s_VAR(_ff73); s_VAR(_ff74); s_VAR(_ff75);
}

