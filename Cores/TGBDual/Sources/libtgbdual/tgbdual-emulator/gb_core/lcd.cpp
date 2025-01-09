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

//-------------------------------------------------------
// LCD エミュレーション部
// inline assembler あり 適宜変更せよ

#include "gb.h"

#define ROL_BYTE(var, bits) (var = ((var) & (-1U << 8)) \
                             | (((var)<<(bits))&0xff) \
                             | ((var) >> (8-(bits))))

lcd::lcd(gb *ref)
{
	ref_gb=ref;

	byte dat[]={31,21,11,0};

	for (int i=0;i<4;i++){
		m_pal16[i]=ref_gb->get_renderer()->map_color(dat[i]|(dat[i]<<5)|(dat[i]<<10));
		m_pal32[i]=((dat[i]<<16)|(dat[i]<<8)|dat[i]);
	}

	reset();
}

lcd::~lcd()
{
}

void lcd::set_enable(int layer,bool enable)
{
	layer_enable[layer]=enable;
}

bool lcd::get_enable(int layer)
{
	return layer_enable[layer];
}

void lcd::reset()
{
	now_win_line=0;
	layer_enable[0]=layer_enable[1]=layer_enable[2]=true;
	sprite_count=0;
}

void lcd::bg_render(void *buf,int scanline)
{
	int i,x,y;
   int start, y_div_8, prefix = 0;
   byte *trans, *now_tile;
	dword tmp_dat, calc1, calc2;
   word back, pat, *dat;
   word *now_share, *now_pat;
   byte *vrams[2];
	word share  = 0x0000;//prefix
	word pal[4];
	byte tile;

	if (!(ref_gb->get_regs()->LCDC&0x80)||!(ref_gb->get_regs()->LCDC&0x01)||
		(ref_gb->get_regs()->WY<=(dword)scanline&&ref_gb->get_regs()->WX<8&&(ref_gb->get_regs()->LCDC&0x20)))
   {
		if (!(ref_gb->get_regs()->LCDC&0x80)||!(ref_gb->get_regs()->LCDC&0x01))
      {
         word *tmp_w=(word*)buf+160*scanline;
         word tmp_dat=ref_gb->get_renderer()->map_color(0x7fff);
         for (int t=0;t<160;t++)
            *(tmp_w++)=tmp_dat;
      }
		return;
	}

	back      = (ref_gb->get_regs()->LCDC&0x08)?0x1C00:0x1800;
	pat       = (ref_gb->get_regs()->LCDC&0x10)?0x0000:0x1000;
	vrams[0]  = ref_gb->get_cpu()->get_vram();
   vrams[1]  = ref_gb->get_cpu()->get_vram() +0x2000;

	pal[0]    = m_pal16[ref_gb->get_regs()->BGP&0x3];
	pal[1]    = m_pal16[(ref_gb->get_regs()->BGP>>2)&0x3];
	pal[2]    = m_pal16[(ref_gb->get_regs()->BGP>>4)&0x3];
	pal[3]    = m_pal16[(ref_gb->get_regs()->BGP>>6)&0x3];

	y         = scanline+ref_gb->get_regs()->SCY;
	if (y >= 256)
		y     -= 256;
	x         = ref_gb->get_regs()->SCX;

	dat       = ((word*)buf)+scanline*160;


	start=ref_gb->get_regs()->SCX>>3;
	y_div_8=y>>3;


	trans=trans_tbl;
	now_tile=vrams[0]+back+((y_div_8)<<5)+start;
	now_share=(word*)(vrams[0]+share+((y&7)<<1));
	now_pat=(word*)(vrams[0]+pat+((y&7)<<1));

	tile=*(now_tile++);
	tmp_dat=(tile&0x80)?*(now_share+(tile<<3)):*(now_pat+(tile<<3));
	calc1=tmp_dat;
	calc2=tmp_dat>>7;
	calc1&=0x55;
	calc2&=0xAA;
	calc1|=calc2;
	calc2=tmp_dat>>1;
	tmp_dat>>=8;
	calc2&=0x55;
	tmp_dat&=0xAA;
	calc2|=tmp_dat;

	*(dat++)=pal[calc2>>6];
	*(dat++)=pal[calc1>>6];
	*(dat++)=pal[(calc2>>4)&3];
	*(dat++)=pal[(calc1>>4)&3];
	*(dat++)=pal[(calc2>>2)&3];
	*(dat++)=pal[(calc1>>2)&3];
	*(dat++)=pal[calc2&3];
	*(dat++)=pal[calc1&3];

	*(trans++)=(calc2>>6);
	*(trans++)=(calc1>>6);
	*(trans++)=(calc2>>4)&3;
	*(trans++)=(calc1>>4)&3;
	*(trans++)=(calc2>>2)&3;
	*(trans++)=(calc1>>2)&3;
	*(trans++)=calc2&3;
	*(trans++)=calc1&3;

	dat   -= 8;
	trans -= 8;

	for (i=0;i<8-(x&7);i++){ // スクロール補正 // Scroll correction
		*(dat)=*(dat+(x&7));
		*(trans)=*(dat+(x&7));
		dat++; trans++;
	}

	for (i=0;i<20;i++){
		if ((x/8*8+i*8)-prefix>=248){
			now_tile=ref_gb->get_cpu()->get_vram()+back+((y/8)<<5);
			prefix=256;
		}
		tile=*(now_tile++);
		tmp_dat=(tile&0x80)?*(now_share+(tile<<3)):*(now_pat+(tile<<3));
		calc1=tmp_dat;
		calc2=tmp_dat>>7;
		calc1&=0x55;
		calc2&=0xAA;
		calc1|=calc2;
		calc2=tmp_dat>>1;
		tmp_dat>>=8;
		calc2&=0x55;
		tmp_dat&=0xAA;
		calc2|=tmp_dat;

		*(dat++)=pal[calc2>>6];
		*(dat++)=pal[calc1>>6];
		*(dat++)=pal[(calc2>>4)&3];
		*(dat++)=pal[(calc1>>4)&3];
		*(dat++)=pal[(calc2>>2)&3];
		*(dat++)=pal[(calc1>>2)&3];
		*(dat++)=pal[calc2&3];
		*(dat++)=pal[calc1&3];

		*(trans++)=(calc2>>6);
		*(trans++)=(calc1>>6);
		*(trans++)=(calc2>>4)&3;
		*(trans++)=(calc1>>4)&3;
		*(trans++)=(calc2>>2)&3;
		*(trans++)=(calc1>>2)&3;
		*(trans++)=calc2&3;
		*(trans++)=calc1&3;
	}
}

void lcd::win_render(void *buf,int scanline)
{
	if (!(ref_gb->get_regs()->LCDC&0x80)||!(ref_gb->get_regs()->LCDC&0x20)||ref_gb->get_regs()->WY>=(scanline+1)||ref_gb->get_regs()->WX>166){
//		if ((ref_gb->get_regs()->WY>=(scanline+1))&&((ref_gb->get_regs()->LCDC&0x21)!=0x21))
//			memset(((word*)buf)+160*scanline,0,160*2);
		return;
	}

	int y=now_win_line-1/*scanline-res->system_reg.WY*/;
	now_win_line++;
	byte *trans=trans_tbl;

	word back=(ref_gb->get_regs()->LCDC&0x40)?0x1C00:0x1800;
	word pat=(ref_gb->get_regs()->LCDC&0x10)?0x0000:0x1000;
	word share=0x0000;//prefix
	word pal[4];
	word *dat=(word*)buf;
	byte tile;
	int i;

	pal[0]=m_pal16[ref_gb->get_regs()->BGP&0x3];
	pal[1]=m_pal16[(ref_gb->get_regs()->BGP>>2)&0x3];
	pal[2]=m_pal16[(ref_gb->get_regs()->BGP>>4)&0x3];
	pal[3]=m_pal16[(ref_gb->get_regs()->BGP>>6)&0x3];
	dat+=160*scanline+ref_gb->get_regs()->WX-7;
	trans+=ref_gb->get_regs()->WX-7;
	byte *now_tile=ref_gb->get_cpu()->get_vram()+back+(((y>>3)-1)<<5);
	word *now_share=(word*)(ref_gb->get_cpu()->get_vram()+share+((y&7)<<1));
	word *now_pat=(word*)(ref_gb->get_cpu()->get_vram()+pat+((y&7)<<1));
	dword tmp_dat;
	dword calc1,calc2;

	for (i=ref_gb->get_regs()->WX>>3;i<21;i++){
		tile=*(now_tile++);
		tmp_dat=(tile&0x80)?*(now_share+(tile<<3)):*(now_pat+(tile<<3));
		calc1=tmp_dat;
		calc2=tmp_dat>>7;
		calc1&=0x55;
		calc2&=0xAA;
		calc1|=calc2;
		calc2=tmp_dat>>1;
		tmp_dat>>=8;
		calc2&=0x55;
		tmp_dat&=0xAA;
		calc2|=tmp_dat;

		*(dat++)=pal[calc2>>6];
		*(dat++)=pal[calc1>>6];
		*(dat++)=pal[(calc2>>4)&3];
		*(dat++)=pal[(calc1>>4)&3];
		*(dat++)=pal[(calc2>>2)&3];
		*(dat++)=pal[(calc1>>2)&3];
		*(dat++)=pal[calc2&3];
		*(dat++)=pal[calc1&3];

		*(trans++)=(calc2>>6);
		*(trans++)=(calc1>>6);
		*(trans++)=(calc2>>4)&3;
		*(trans++)=(calc1>>4)&3;
		*(trans++)=(calc2>>2)&3;
		*(trans++)=(calc1>>2)&3;
		*(trans++)=calc2&3;
		*(trans++)=calc1&3;
	}
}

void lcd::sprite_render(void *buf,int scanline)
{
	if (!(ref_gb->get_regs()->LCDC&0x80)||!(ref_gb->get_regs()->LCDC&0x02))
		return;

	word *sdat=((word*)buf)+(scanline)*160,*now_pos;
	int x,y,tile,atr,i,now;
	word l1,l2,tmp_dat;
	word pal[2][4],*cur_p;
	byte *oam=ref_gb->get_cpu()->get_oam(),*vram=ref_gb->get_cpu()->get_vram();

	bool sp_size=(ref_gb->get_regs()->LCDC&0x04)?true:false;
	int palnum;

	pal[0][0]=m_pal16[ref_gb->get_regs()->OBP1&0x3];
	pal[0][1]=m_pal16[(ref_gb->get_regs()->OBP1>>2)&0x3];
	pal[0][2]=m_pal16[(ref_gb->get_regs()->OBP1>>4)&0x3];
	pal[0][3]=m_pal16[(ref_gb->get_regs()->OBP1>>6)&0x3];

	pal[1][0]=m_pal16[ref_gb->get_regs()->OBP2&0x3];
	pal[1][1]=m_pal16[(ref_gb->get_regs()->OBP2>>2)&0x3];
	pal[1][2]=m_pal16[(ref_gb->get_regs()->OBP2>>4)&0x3];
	pal[1][3]=m_pal16[(ref_gb->get_regs()->OBP2>>6)&0x3];

	for (i=39;i>=0;i--){
		tile=oam[i*4+2];
		atr=oam[i*4+3];
		palnum=(atr>>4)&1;
		cur_p=pal[palnum];

		if (sp_size){ // 8*16
			y=oam[i*4]-1;
			x=oam[i*4+1]-8;
			if ((x==-8&&y==-16)||x>160||y>144+15||(y<scanline)||(y>scanline+15))
				continue;
			if (scanline-y+15<8)
         {
				now= (atr & 0x40) ? ((y-scanline) & 7) : ((7 - (y - scanline)) & 7);
				tmp_dat=*(word*)(vram+(tile&0xfe)*16+now*2+((atr&0x40)?16:0));
			}
			else{
				now= (atr & 0x40) ? ((y-scanline) & 7) : ((7-(y-scanline)) & 7);
				tmp_dat=*(word*)(vram+(tile&0xfe)*16+now*2+((atr&0x40)?0:16));
			}
		}
		else{
			y=oam[i*4]-9;
			x=oam[i*4+1]-8;
			if ((x==-8&&y==-16)||(x>160)||(y>144+7)||(y<scanline)||(y>scanline+7))
				continue;
			now=(atr&0x40)?((y-scanline)&7):((7-(y-scanline)) & 7);
			tmp_dat=*(word*)(vram+tile*16+now*2);
		}
		sprite_count++;
		now_pos=sdat+x;

		l1=tmp_dat;
		l2=tmp_dat>>7;
		l1&=0x55;
		l2&=0xAA;
		l1|=l2;
		l2=tmp_dat>>1;
		tmp_dat>>=8;
		tmp_dat&=0xAA;
		l2&=0x55;
		l2|=tmp_dat;

		if (atr&0x20){ // 反転する
			byte tmp_p=l2;
			l2=((l1>>2)&0x33)|((l1<<2)&0xcc);
			ROL_BYTE(l2,4);
			l1=((tmp_p>>2)&0x33)|((tmp_p<<2)&0xcc);
			ROL_BYTE(l1,4);
		}

		if (x<0){ // クリッピング処理
			if (atr&0x80){ // プライオリティ(背面に)
				if ((-x)<=1) if (!trans_tbl[x+1]) if (l1>>6) *(now_pos+1)=cur_p[l1>>6];
				if ((-x)<=2) if (!trans_tbl[x+2]) if ((l2>>4)&3) *(now_pos+2)=cur_p[(l2>>4)&3];
				if ((-x)<=3) if (!trans_tbl[x+3]) if ((l1>>4)&3) *(now_pos+3)=cur_p[(l1>>4)&3];
				if ((-x)<=4) if (!trans_tbl[x+4]) if ((l2>>2)&3) *(now_pos+4)=cur_p[(l2>>2)&3];
				if ((-x)<=5) if (!trans_tbl[x+5]) if ((l1>>2)&3) *(now_pos+5)=cur_p[(l1>>2)&3];
				if ((-x)<=6) if (!trans_tbl[x+6]) if (l2&3) *(now_pos+6)=cur_p[l2&3];
				if ((-x)<=7) if (!trans_tbl[x+7]) if (l1&3) *(now_pos+7)=cur_p[l1&3];
			}
			else{
				if ((-x)<=1) if (l1>>6) *(now_pos+1)=cur_p[l1>>6];
				if ((-x)<=2) if ((l2>>4)&3) *(now_pos+2)=cur_p[(l2>>4)&3];
				if ((-x)<=3) if ((l1>>4)&3) *(now_pos+3)=cur_p[(l1>>4)&3];
				if ((-x)<=4) if ((l2>>2)&3) *(now_pos+4)=cur_p[(l2>>2)&3];
				if ((-x)<=5) if ((l1>>2)&3) *(now_pos+5)=cur_p[(l1>>2)&3];
				if ((-x)<=6) if (l2&3) *(now_pos+6)=cur_p[l2&3];
				if ((-x)<=7) if (l1&3) *(now_pos+7)=cur_p[l1&3];
			}
		}
		else{
			if (atr&0x80){
				if (!trans_tbl[x+0]) if (l2>>6) *(now_pos)=cur_p[l2>>6];
				if (!trans_tbl[x+1]) if (l1>>6) *(now_pos+1)=cur_p[l1>>6];
				if (!trans_tbl[x+2]) if ((l2>>4)&3) *(now_pos+2)=cur_p[(l2>>4)&3];
				if (!trans_tbl[x+3]) if ((l1>>4)&3) *(now_pos+3)=cur_p[(l1>>4)&3];
				if (!trans_tbl[x+4]) if ((l2>>2)&3) *(now_pos+4)=cur_p[(l2>>2)&3];
				if (!trans_tbl[x+5]) if ((l1>>2)&3) *(now_pos+5)=cur_p[(l1>>2)&3];
				if (!trans_tbl[x+6]) if (l2&3) *(now_pos+6)=cur_p[l2&3];
				if (!trans_tbl[x+7]) if (l1&3) *(now_pos+7)=cur_p[l1&3];
			}
			else{
				if (l2>>6) *(now_pos)=cur_p[l2>>6];
				if (l1>>6) *(now_pos+1)=cur_p[l1>>6];
				if ((l2>>4)&3) *(now_pos+2)=cur_p[(l2>>4)&3];
				if ((l1>>4)&3) *(now_pos+3)=cur_p[(l1>>4)&3];
				if ((l2>>2)&3) *(now_pos+4)=cur_p[(l2>>2)&3];
				if ((l1>>2)&3) *(now_pos+5)=cur_p[(l1>>2)&3];
				if (l2&3) *(now_pos+6)=cur_p[l2&3];
				if (l1&3) *(now_pos+7)=cur_p[l1&3];
			}
		}
	}
}

void lcd::bg_render_color(void *buf,int scanline)
{
	byte tile;
	int i,x,y;
   word back, pat, *pal, *dat;
   byte *vrams[2];
   word share=0x0000;//prefix
	trans_count=0;

	// カラーではOFF機能が働かない?(僕のキャンプ場､モンコレナイト)
	// OFF function does not work in color? (my campsite, Moncolle Night)
	if (!(ref_gb->get_regs()->LCDC&0x80)/*||!(ref_gb->get_regs()->LCDC&0x01)*/||
		(ref_gb->get_regs()->WY<=(dword)scanline&&ref_gb->get_regs()->WX<8&&(ref_gb->get_regs()->LCDC&0x20))){
		if (!(ref_gb->get_regs()->LCDC&0x80)/*||!(ref_gb->get_regs()->LCDC&0x01)*/){
			word *tmp_w=(word*)buf+160*scanline;
			word tmp_dat=ref_gb->get_renderer()->map_color(0x7fff);
			for (int t=0;t<160;t++)
				*(tmp_w++)=tmp_dat;
//			memset(()+160*scanline,0xff,160*2);
		}
		return;
	}

	back=(ref_gb->get_regs()->LCDC&0x08)?0x1C00:0x1800;
	pat=(ref_gb->get_regs()->LCDC&0x10)?0x0000:0x1000;
	vrams[0] = ref_gb->get_cpu()->get_vram();
   vrams[1] = ref_gb->get_cpu()->get_vram()+0x2000;

	y=scanline+ref_gb->get_regs()->SCY;
	if (y>=256)
		y-=256;
	x=ref_gb->get_regs()->SCX;

	dat=((word*)buf)+scanline*160;

	int start=ref_gb->get_regs()->SCX>>3;
	int y_div_8=y>>3;
	int prefix=0;
	byte *now_tile=vrams[0]+back+((y_div_8)<<5)+start;
	byte *now_atr=vrams[0]+back+((y_div_8)<<5)+start+0x2000;
	word *now_share=(word*)(vrams[0]+share+((y&7)<<1));
	word *now_pat=(word*)(vrams[0]+pat+((y&7)<<1));
	word *now_share2=(word*)(vrams[0]+share+14-((y&7)<<1));
	word *now_pat2=(word*)(vrams[0]+pat+14-((y&7)<<1));
	dword tmp_dat;
	dword calc1,calc2;
	byte atr;
	word bank;
	byte *trans=trans_tbl;
	byte *priority=priority_tbl;

	tile=*(now_tile++);
	atr=*(now_atr++);

	pal=mapped_pal[atr&7];
	bank=(atr<<9)&0x1000;
	tmp_dat=(tile&0x80)?*(((atr&0x40)?now_share2:now_share)+(tile<<3)+bank):*(((atr&0x40)?now_pat2:now_pat)+(tile<<3)+bank);
	calc1=tmp_dat;
	calc2=tmp_dat>>7;
	calc1&=0x55;
	calc2&=0xAA;
	calc1|=calc2;
	calc2=tmp_dat>>1;
	tmp_dat>>=8;
	calc2&=0x55;
	tmp_dat&=0xAA;
	calc2|=tmp_dat;

	if (atr&0x20){ // 反転する
		byte tmp_p=calc2;
		calc2=((calc1>>2)&0x33)|((calc1<<2)&0xcc);
		ROL_BYTE(calc2,4);
		calc1=((tmp_p>>2)&0x33)|((tmp_p<<2)&0xcc);
		ROL_BYTE(calc1,4);
	}

	*(dat++)=pal[calc2>>6];
	*(dat++)=pal[calc1>>6];
	*(dat++)=pal[(calc2>>4)&3];
	*(dat++)=pal[(calc1>>4)&3];
	*(dat++)=pal[(calc2>>2)&3];
	*(dat++)=pal[(calc1>>2)&3];
	*(dat++)=pal[calc2&3];
	*(dat++)=pal[calc1&3];

	*(trans++)=(calc2>>6);
	*(trans++)=(calc1>>6);
	*(trans++)=(calc2>>4)&3;
	*(trans++)=(calc1>>4)&3;
	*(trans++)=(calc2>>2)&3;
	*(trans++)=(calc1>>2)&3;
	*(trans++)=calc2&3;
	*(trans++)=calc1&3;

	memset(priority,(atr&0x80),8);
	priority+=8;

	dat-=8;
	trans-=8;
	priority-=8;

	for (i=0;i<8-(x&7);i++){ // スクロール補正 // Scroll correction
		*(dat)=*(dat+(x&7));
		*(trans)=*(trans+(x&7));
		*(priority)=*(priority+(x&7));
		dat++; trans++; priority++;
	}

	for (i=0;i<20;i++){
		if ((x/8*8+i*8)-prefix>=248){
			now_tile=ref_gb->get_cpu()->get_vram()+back+((y/8)<<5);
			now_atr=ref_gb->get_cpu()->get_vram()+back+((y/8)<<5)+0x2000;
			prefix=256;
		}

		tile=*(now_tile++);
		atr=*(now_atr++);

		pal=mapped_pal[atr&7];
		bank=(atr<<9)&0x1000;
		tmp_dat=(tile&0x80)?*(((atr&0x40)?now_share2:now_share)+(tile<<3)+bank):*(((atr&0x40)?now_pat2:now_pat)+(tile<<3)+bank);

		calc1=tmp_dat;
		calc2=tmp_dat>>7;
		calc1&=0x55;
		calc2&=0xAA;
		calc1|=calc2;
		calc2=tmp_dat>>1;
		tmp_dat>>=8;
		calc2&=0x55;
		tmp_dat&=0xAA;
		calc2|=tmp_dat;

		if (atr&0x20){ // 反転する
			byte tmp_p=calc2;
			calc2=((calc1>>2)&0x33)|((calc1<<2)&0xcc);
			ROL_BYTE(calc2,4);
			calc1=((tmp_p>>2)&0x33)|((tmp_p<<2)&0xcc);
			ROL_BYTE(calc1,4);
		}

		*(dat++)=pal[calc2>>6];
		*(dat++)=pal[calc1>>6];
		*(dat++)=pal[(calc2>>4)&3];
		*(dat++)=pal[(calc1>>4)&3];
		*(dat++)=pal[(calc2>>2)&3];
		*(dat++)=pal[(calc1>>2)&3];
		*(dat++)=pal[calc2&3];
		*(dat++)=pal[calc1&3];

		*(trans++)=(calc2>>6);
		*(trans++)=(calc1>>6);
		*(trans++)=(calc2>>4)&3;
		*(trans++)=(calc1>>4)&3;
		*(trans++)=(calc2>>2)&3;
		*(trans++)=(calc1>>2)&3;
		*(trans++)=calc2&3;
		*(trans++)=calc1&3;

		memset(priority,(atr&0x80),8);
		priority+=8;
	}

	// 多分こういうこと(僕のキャンプ場)
	if (!(ref_gb->get_regs()->LCDC&0x01))
		memset(trans_tbl,0,160);
}

void lcd::win_render_color(void *buf,int scanline)
{
	if (!(ref_gb->get_regs()->LCDC&0x80)||!(ref_gb->get_regs()->LCDC&0x20)||ref_gb->get_regs()->WY>=(scanline+1)||ref_gb->get_regs()->WX>166){
//		if ((ref_gb->get_regs()->WY>=(scanline+1))&&((ref_gb->get_regs()->LCDC&0x21)!=0x21))
//			memset(((word*)buf)+160*scanline,0,160*2);
		return;
	}

	int y=now_win_line-1/*scanline-res->system_reg.WY*/;
	now_win_line++;

	byte *vrams[2]={ref_gb->get_cpu()->get_vram(),ref_gb->get_cpu()->get_vram()+0x2000};

	word back=(ref_gb->get_regs()->LCDC&0x40)?0x1C00:0x1800;
	word pat=(ref_gb->get_regs()->LCDC&0x10)?0x0000:0x1000;
	word share=0x0000;//prefix
	word *pal;
	word *dat=(word*)buf;
	byte *trans=trans_tbl;
	byte *priority=priority_tbl;
	byte tile;
	int i;

	dat+=160*scanline+ref_gb->get_regs()->WX-7;
	trans+=ref_gb->get_regs()->WX-7;
	priority+=ref_gb->get_regs()->WX-7;
	byte *now_tile=ref_gb->get_cpu()->get_vram()+back+(((y>>3)-1)<<5);
	byte *now_atr=ref_gb->get_cpu()->get_vram()+back+(((y>>3)-1)<<5)+0x2000;
	word *now_share=(word*)(ref_gb->get_cpu()->get_vram()+share+((y&7)<<1));
	word *now_pat=(word*)(ref_gb->get_cpu()->get_vram()+pat+((y&7)<<1));
	word *now_share2=(word*)(vrams[0]+share+14-((y&7)<<1));
	word *now_pat2=(word*)(vrams[0]+pat+14-((y&7)<<1));
	dword tmp_dat;
	dword calc1,calc2;
	byte atr;
	word bank;

	for (i=ref_gb->get_regs()->WX>>3;i<21;i++){
		tile=*(now_tile++);
		atr=*(now_atr++);
		bank=(atr<<9)&0x1000;
		pal=mapped_pal[atr&7];
		tmp_dat=(tile&0x80)?*(((atr&0x40)?now_share2:now_share)+(tile<<3)+bank):*(((atr&0x40)?now_pat2:now_pat)+(tile<<3)+bank);
		calc1=tmp_dat;
		calc2=tmp_dat>>7;
		calc1&=0x55;
		calc2&=0xAA;
		calc1|=calc2;
		calc2=tmp_dat>>1;
		tmp_dat>>=8;
		calc2&=0x55;
		tmp_dat&=0xAA;
		calc2|=tmp_dat;

		if (atr&0x20){ // 反転する
			byte tmp_p=calc2;
			calc2=((calc1>>2)&0x33)|((calc1<<2)&0xcc);
			ROL_BYTE(calc2,4);
			calc1=((tmp_p>>2)&0x33)|((tmp_p<<2)&0xcc);
			ROL_BYTE(calc1,4);
		}

		*(dat++)=pal[calc2>>6];
		*(dat++)=pal[calc1>>6];
		*(dat++)=pal[(calc2>>4)&3];
		*(dat++)=pal[(calc1>>4)&3];
		*(dat++)=pal[(calc2>>2)&3];
		*(dat++)=pal[(calc1>>2)&3];
		*(dat++)=pal[calc2&3];
		*(dat++)=pal[calc1&3];

		*(trans++)=(calc2>>6);
		*(trans++)=(calc1>>6);
		*(trans++)=(calc2>>4)&3;
		*(trans++)=(calc1>>4)&3;
		*(trans++)=(calc2>>2)&3;
		*(trans++)=(calc1>>2)&3;
		*(trans++)=calc2&3;
		*(trans++)=calc1&3;

		memset(priority,(atr&0x80),8);
		priority+=8;
	}
}

void lcd::sprite_render_color(void *buf,int scanline)
{
	if (!(ref_gb->get_regs()->LCDC&0x80)||!(ref_gb->get_regs()->LCDC&0x02))
		return;

	word *sdat=((word*)buf)+(scanline)*160,*now_pos;
	int x,y,tile,atr,i,now;
	word l1,l2,tmp_dat;
	word *cur_p;
	byte *oam=ref_gb->get_cpu()->get_oam(),*vram=ref_gb->get_cpu()->get_vram();

	bool sp_size=(ref_gb->get_regs()->LCDC&0x04)?true:false;

	word bank;

	for (i=39;i>=0;i--){
		tile=oam[i*4+2];
		atr=oam[i*4+3];
		cur_p=mapped_pal[(atr&7)+8];
		bank=(atr&0x08?0x2000:0);

		if (sp_size){ // 8*16
			y=oam[i*4]-1;
			x=oam[i*4+1]-8;
			if ((x==-8&&y==-16)||x>160||y>144+15||(y<scanline)||(y>scanline+15))
				continue;

			if (scanline-y+15<8){ //上半分
				now=(atr&0x40)?((y-scanline)&7):((7-(y-scanline)) &7);
				tmp_dat=*(word*)(vram+bank+(tile&0xfe)*16+now*2+((atr&0x40)?16:0));
			}
			else{ // 下半分
				now=(atr&0x40)?((y-scanline)&7):((7-(y-scanline)) &7);
				tmp_dat=*(word*)(vram+bank+(tile&0xfe)*16+now*2+((atr&0x40)?0:16));
			}
		}
		else{ // 8*8
			y=oam[i*4]-9;
			x=oam[i*4+1]-8;
			if ((x==-8&&y==-16)||(x>160)||(y>144+7)||(y<scanline)||(y>scanline+7))
				continue;

			now=(atr&0x40)?((y-scanline)&7):((7-(y-scanline)) & 7);
			tmp_dat=*(word*)(vram+tile*16+now*2+bank);
		}
		sprite_count++;
		now_pos=sdat+x; // now_pos=現在地点

		l1=tmp_dat;
		l2=tmp_dat>>7;
		l1&=0x55;
		l2&=0xAA;
		l1|=l2;
		l2=tmp_dat>>1;
		tmp_dat>>=8;
		tmp_dat&=0xAA;
		l2&=0x55;
		l2|=tmp_dat;

		if (atr&0x20){ // 反転する
			byte tmp_p=l2;
			l2=((l1>>2)&0x33)|((l1<<2)&0xcc);
			ROL_BYTE(l2,4);
			l1=((tmp_p>>2)&0x33)|((tmp_p<<2)&0xcc);
			ROL_BYTE(l1,4);
		}

		if (x<0){ // クリッピング処理
			if (atr&0x80){ // プライオリティ(背面に)
				if ((-x)<=1) if (!trans_tbl[x+1]) if (l1>>6) *(now_pos+1)=cur_p[l1>>6];
				if ((-x)<=2) if (!trans_tbl[x+2]) if ((l2>>4)&3) *(now_pos+2)=cur_p[(l2>>4)&3];
				if ((-x)<=3) if (!trans_tbl[x+3]) if ((l1>>4)&3) *(now_pos+3)=cur_p[(l1>>4)&3];
				if ((-x)<=4) if (!trans_tbl[x+4]) if ((l2>>2)&3) *(now_pos+4)=cur_p[(l2>>2)&3];
				if ((-x)<=5) if (!trans_tbl[x+5]) if ((l1>>2)&3) *(now_pos+5)=cur_p[(l1>>2)&3];
				if ((-x)<=6) if (!trans_tbl[x+6]) if (l2&3) *(now_pos+6)=cur_p[l2&3];
				if ((-x)<=7) if (!trans_tbl[x+7]) if (l1&3) *(now_pos+7)=cur_p[l1&3];
			}
			else{
				if ((-x)<=1) if (!(priority_tbl[x+1]&&trans_tbl[x+1])) if (l1>>6) *(now_pos+1)=cur_p[l1>>6];
				if ((-x)<=2) if (!(priority_tbl[x+2]&&trans_tbl[x+2])) if ((l2>>4)&3) *(now_pos+2)=cur_p[(l2>>4)&3];
				if ((-x)<=3) if (!(priority_tbl[x+3]&&trans_tbl[x+3])) if ((l1>>4)&3) *(now_pos+3)=cur_p[(l1>>4)&3];
				if ((-x)<=4) if (!(priority_tbl[x+4]&&trans_tbl[x+4])) if ((l2>>2)&3) *(now_pos+4)=cur_p[(l2>>2)&3];
				if ((-x)<=5) if (!(priority_tbl[x+5]&&trans_tbl[x+5])) if ((l1>>2)&3) *(now_pos+5)=cur_p[(l1>>2)&3];
				if ((-x)<=6) if (!(priority_tbl[x+6]&&trans_tbl[x+6])) if (l2&3) *(now_pos+6)=cur_p[l2&3];
				if ((-x)<=7) if (!(priority_tbl[x+7]&&trans_tbl[x+7])) if (l1&3) *(now_pos+7)=cur_p[l1&3];
			}
		}
		else{
			if (atr&0x80){
				if (!trans_tbl[x+0]) if (l2>>6) *(now_pos)=cur_p[l2>>6];
				if (!trans_tbl[x+1]) if (l1>>6) *(now_pos+1)=cur_p[l1>>6];
				if (!trans_tbl[x+2]) if ((l2>>4)&3) *(now_pos+2)=cur_p[(l2>>4)&3];
				if (!trans_tbl[x+3]) if ((l1>>4)&3) *(now_pos+3)=cur_p[(l1>>4)&3];
				if (!trans_tbl[x+4]) if ((l2>>2)&3) *(now_pos+4)=cur_p[(l2>>2)&3];
				if (!trans_tbl[x+5]) if ((l1>>2)&3) *(now_pos+5)=cur_p[(l1>>2)&3];
				if (!trans_tbl[x+6]) if (l2&3) *(now_pos+6)=cur_p[l2&3];
				if (!trans_tbl[x+7]) if (l1&3) *(now_pos+7)=cur_p[l1&3];
			}
			else{
				if (!(priority_tbl[x]&&trans_tbl[x])) if (l2>>6) *(now_pos)=cur_p[l2>>6];
				if (!(priority_tbl[x+1]&&trans_tbl[x+1])) if (l1>>6) *(now_pos+1)=cur_p[l1>>6];
				if (!(priority_tbl[x+2]&&trans_tbl[x+2])) if ((l2>>4)&3) *(now_pos+2)=cur_p[(l2>>4)&3];
				if (!(priority_tbl[x+3]&&trans_tbl[x+3])) if ((l1>>4)&3) *(now_pos+3)=cur_p[(l1>>4)&3];
				if (!(priority_tbl[x+4]&&trans_tbl[x+4])) if ((l2>>2)&3) *(now_pos+4)=cur_p[(l2>>2)&3];
				if (!(priority_tbl[x+5]&&trans_tbl[x+5])) if ((l1>>2)&3) *(now_pos+5)=cur_p[(l1>>2)&3];
				if (!(priority_tbl[x+6]&&trans_tbl[x+6])) if (l2&3) *(now_pos+6)=cur_p[l2&3];
				if (!(priority_tbl[x+7]&&trans_tbl[x+7])) if (l1&3) *(now_pos+7)=cur_p[l1&3];
			}
		}
	}
}


void lcd::render(void *buf,int scanline)
{
	sprite_count=0;

	if (ref_gb->get_rom()->get_info()->gb_type>=3){
//		for (int i=0;i<64;i++)
//			mapped_pal[i>>2][i&3]=ref_gb->get_renderer()->map_color(col_pal[i>>2][i&3]);

		if (layer_enable[0]&&layer_enable[1]&&layer_enable[2]){
			bg_render_color(buf,scanline);
			win_render_color(buf,scanline);
			sprite_render_color(buf,scanline);
		}
		else{
			memset(((word*)buf)+160*scanline,0x00,160*2);
			if (layer_enable[0])
				bg_render_color(buf,scanline);
			if (layer_enable[1])
				win_render_color(buf,scanline);
			if (layer_enable[2])
				sprite_render_color(buf,scanline);
		}
	}
	else{
		if (layer_enable[0]&&layer_enable[1]&&layer_enable[2]){
			bg_render(buf,scanline);
			win_render(buf,scanline);
			sprite_render(buf,scanline);
		}
		else{
			memset(((word*)buf)+160*scanline,0x00,160*2);
			if (layer_enable[0])
				bg_render(buf,scanline);
			if (layer_enable[1])
				win_render(buf,scanline);
			if (layer_enable[2])
				sprite_render(buf,scanline);
		}
	}
}

void lcd::serialize(serializer &s)
{
	s_ARRAY(m_pal16);
	s_ARRAY(m_pal32);
	s_ARRAY(col_pal); // the only one that was in the original state format.
	s_ARRAY(mapped_pal);
	s_VAR(trans_count);
	s_ARRAY(trans_tbl);
	s_ARRAY(priority_tbl);
	s_VAR(now_win_line);
	s_VAR(mul);
	s_VAR(sprite_count);
	s_ARRAY(layer_enable);
}

