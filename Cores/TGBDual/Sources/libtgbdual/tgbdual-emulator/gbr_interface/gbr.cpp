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

#include "gbr.h"
#include <memory.h>

gbr_sound::gbr_sound(gbr_procs *ref_procs)
{
	procs=ref_procs;
	change=false;
	rest=0;
	now=0;
}

gbr_sound::~gbr_sound()
{
}

void gbr_sound::render(short *buf,int samples)
{
	procs->render(buf,samples);
	rest=(samples<1600)?samples:1600;
	memcpy(bef_buf,buf,rest*4);
	change=true;
	now=0;
}

short *gbr_sound::get_bef()
{
	rest-=160;
	now+=160;
	if (rest<0)
		return 0;
	return bef_buf+now;
}

//-----------------------------------------------

char playing_num[11][80]={
	"0111110011000001111001100110110110001100111100000011000110000000000000000000000",
	"0110011011000011001101100110110110001101100110000011000110000000000000000000000",
	"0110011011000011001101100110110111001101100110000011100110000000000000000000011",
	"0110011011000011001101100110110111001101100110000011100110000000000000000000011",
	"0110011011000011001101100110110111101101100110000011110110000000000000000000000",
	"0110011011000011001101100110110110101101100110000011010110011100000000000000000",
	"0110011011000011001101100110110110111101100000000011011110110110000000000000000",
	"0111110011000011111100111100110110011101101110000011001110110110000000000000011",
	"0110000011000011001100011000110110011101100110000011001110110110000000000000011",
	"0110000011000011001100011000110110001101100110000011000110110110110000000000000",
	"0110000011111011001100011000110110001100111110000011000110011100110000000000000"
};

char playing_time[11][80]={
	"0111110011000001111001100110110110001100111100000011111101101100011011111000000",
	"0110011011000011001101100110110110001101100110000000110001101100011011000000000",
	"0110011011000011001101100110110111001101100110000000110001101110111011000000011",
	"0110011011000011001101100110110111001101100110000000110001101110111011000000011",
	"0110011011000011001101100110110111101101100110000000110001101111111011000000000",
	"0110011011000011001101100110110110101101100110000000110001101111111011000000000",
	"0110011011000011001101100110110110111101100000000000110001101101011011111000000",
	"0111110011000011111100111100110110011101101110000000110001101101011011000000011",
	"0110000011000011001100011000110110011101100110000000110001101100011011000000011",
	"0110000011000011001100011000110110001101100110000000110001101100011011000000000",
	"0110000011111011001100011000110110001100111110000000110001101100011011111000000"
};

char num_pat[10][11][7]={
{
"011110",
"110011",
"110011",
"110111",
"110111",
"111111",
"111011",
"111011",
"110011",
"110011",
"011110"
},
{
"001100",
"011100",
"111100",
"101100",
"001100",
"001100",
"001100",
"001100",
"001100",
"001100",
"111111"
},
{
"011110",
"110011",
"110011",
"110011",
"110011",
"110011",
"000111",
"011110",
"111000",
"110000",
"111111"
},
{
"011110",
"110011",
"110011",
"110011",
"110011",
"110011",
"000110",
"110011",
"110011",
"110011",
"011110"
},
{
"110011",
"110011",
"110011",
"110011",
"110011",
"110011",
"110011",
"111111",
"000011",
"000011",
"000011"
},
{
"111111",
"110000",
"110000",
"110000",
"110000",
"111110",
"110011",
"000011",
"110011",
"110011",
"011110"
},
{
"011110",
"110011",
"110011",
"110011",
"110011",
"110000",
"111110",
"110011",
"110011",
"110011",
"011110"
},
{
"111111",
"000011",
"000011",
"000011",
"000011",
"000011",
"000011",
"000011",
"000011",
"000011",
"000011"
},
{
"011110",
"110011",
"110011",
"110011",
"110011",
"110011",
"011110",
"110011",
"110011",
"110011",
"011110"
},
{
"011110",
"110011",
"110011",
"110011",
"110011",
"110011",
"110011",
"011111",
"000011",
"000011",
"111110"
}
};

char colon[11][3]={
	"00",
	"00",
	"11",
	"11",
	"00",
	"00",
	"00",
	"11",
	"11",
	"00",
	"00"
};

gbr::gbr(renderer *ref,gbr_procs *ref_procs)
{
	m_renderer=ref;
	procs=ref_procs;

	gbr_snd=new gbr_sound(procs);
	
	m_renderer->set_sound_renderer(gbr_snd);
	reset();
}

gbr::~gbr()
{
}

void gbr::reset()
{
	cur_num=0;
	m_renderer->reset();
	procs->select(0);
	frames=0;

	memset(vframe,0,160*144*2);

	int i,j;

	for (i=0;i<11;i++)
		for (j=0;j<79;j++)
			vframe[(i+1)*160+j]=(playing_num[i][j]=='0')?0x0000:0xffff;

	for (i=0;i<11;i++)
		for (j=0;j<79;j++)
			vframe[(i+18)*160+j]=(playing_time[i][j]=='0')?0x0000:0xffff;

	for (i=0;i<11;i++)
		for (j=0;j<2;j++)
			vframe[(i+18)*160+j+97]=(colon[i][j]=='0')?0x0000:0xffff;

	for (i=0;i<11;i++)
		for (j=0;j<2;j++)
			vframe[(i+18)*160+j+114]=(colon[i][j]=='0')?0x0000:0xffff;
}

void gbr::load_rom(unsigned char *buf,int size)
{
	procs->load(buf,size);
	reset();
}

void gbr::run()
{
	procs->run();
	m_renderer->refresh();

	static int tmp,bef=0; // (a,b,select,start,down,up,left,right の順)
	tmp=m_renderer->check_pad();

	if ((!(bef&0x80))&&(tmp&0x80)){
		cur_num++;
		cur_num&=0xff;
		select(cur_num);
		frames=0;
	}
	if ((!(bef&0x40))&&(tmp&0x40)){
		cur_num--;
		cur_num&=0xff;
		select(cur_num);
		frames=0;
	}
	if ((!(bef&0x20))&&(tmp&0x20)){
		cur_num+=10;
		cur_num&=0xff;
		select(cur_num);
		frames=0;
	}
	if ((!(bef&0x10))&&(tmp&0x10)){
		cur_num-=10;
		cur_num&=0xff;
		select(cur_num);
		frames=0;
	}

	int number,i,j;

	number=cur_num/100;
	for (i=0;i<11;i++)
		for (j=0;j<6;j++)
			vframe[(i+1)*160+j+83]=(num_pat[number][i][j]=='0')?0x0000:0xffff;

	number=(cur_num/10)%10;
	for (i=0;i<11;i++)
		for (j=0;j<6;j++)
			vframe[(i+1)*160+j+90]=(num_pat[number][i][j]=='0')?0x0000:0xffff;

	number=cur_num%10;
	for (i=0;i<11;i++)
		for (j=0;j<6;j++)
			vframe[(i+1)*160+j+97]=(num_pat[number][i][j]=='0')?0x0000:0xffff;


	number=(frames/60/60/10)%10; // 十分
	for (i=0;i<11;i++)
		for (j=0;j<6;j++)
			vframe[(i+18)*160+j+83]=(num_pat[number][i][j]=='0')?0x0000:0xffff;

	number=(frames/60/60)%10; // 一分
	for (i=0;i<11;i++)
		for (j=0;j<6;j++)
			vframe[(i+18)*160+j+90]=(num_pat[number][i][j]=='0')?0x0000:0xffff;

	number=(frames/60/10)%6; // 十秒
	for (i=0;i<11;i++)
		for (j=0;j<6;j++)
			vframe[(i+18)*160+j+100]=(num_pat[number][i][j]=='0')?0x0000:0xffff;

	number=(frames/60)%10; // 一秒
	for (i=0;i<11;i++)
		for (j=0;j<6;j++)
			vframe[(i+18)*160+j+107]=(num_pat[number][i][j]=='0')?0x0000:0xffff;

	number=(int)((float)(frames%60)*1.6666666666f)/10; // 1/10秒
	for (i=0;i<11;i++)
		for (j=0;j<6;j++)
			vframe[(i+18)*160+j+117]=(num_pat[number][i][j]=='0')?0x0000:0xffff;

	number=(int)((float)(frames%60)*1.6666666666f)%10; // 1/100秒
	for (i=0;i<11;i++)
		for (j=0;j<6;j++)
			vframe[(i+18)*160+j+124]=(num_pat[number][i][j]=='0')?0x0000:0xffff;


	r=m_renderer->map_color(0x001f);
	g=m_renderer->map_color(0x03e0);

	short *dat;
	if (dat=gbr_snd->get_bef()){
		int bef=30+(dat[0]+32768)/1150,bef_2=87+(dat[1]+32768)/1150,cur,next;
		memset(vframe+30*160,0,114*160*2);
		for (i=0;i<160;i++){
//			cur=30+((dat[i*2]+dat[i*2+1])/2+32768)/575;
//			next=30+((dat[i*2+2]+dat[i*2+3])/2+32768)/575;
			cur=30+(dat[i*2]+32768)/1150;
			next=30+(dat[i*2+2]+32768)/1150;
			if (bef<cur)
				for (j=bef-(bef-cur)/2;j<cur;j++)
					vframe[j*160+i]=r;
			else
				for (j=bef-(bef-cur)/2;j>cur;j--)
					vframe[j*160+i]=r;
			if (cur<next)
				for (j=cur;j<=cur+(next-cur)/2;j++)
					vframe[j*160+i]=r;
			else
				for (j=cur;j>=cur+(next-cur)/2;j--)
					vframe[j*160+i]=r;
			bef=cur;
		}
		for (i=0;i<160;i++){
//			cur=30+((dat[i*2]+dat[i*2+1])/2+32768)/575;
//			next=30+((dat[i*2+2]+dat[i*2+3])/2+32768)/575;
			cur=87+(dat[i*2+1]+32768)/1150;
			next=87+(dat[i*2+3]+32768)/1150;
			if (bef_2<cur)
				for (j=bef_2-(bef_2-cur)/2;j<cur;j++)
					vframe[j*160+i]=g;
			else
				for (j=bef_2-(bef_2-cur)/2;j>cur;j--)
					vframe[j*160+i]=g;
			if (cur<next)
				for (j=cur;j<=cur+(next-cur)/2;j++)
					vframe[j*160+i]=g;
			else
				for (j=cur;j>=cur+(next-cur)/2;j--)
					vframe[j*160+i]=g;
			bef_2=cur;
		}
	}

	m_renderer->render_screen((unsigned char*)vframe,160,144,16);
	bef=tmp;
	frames++;
}
