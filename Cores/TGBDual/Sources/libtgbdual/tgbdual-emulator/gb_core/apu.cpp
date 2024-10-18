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

//--------------------------------------------------
// APU(PSG?)エミュレーション部 (レジスタ/波形生成)
// APU unit (PSG?) Emulation (waveform generation register)

#define UPDATE_INTERVAL 172 // 1/256秒あたりのサンプル数 // Number of samples per second / 256
#define CLOKS_PER_INTERVAL 16384 // 1/256秒あたりのクロック数 (4MHz時) // Number of clock ticks per second / 256 (at 4MHz)

#include "gb.h"
#include <stdlib.h>

static dword sq1_cur_pos=0;
static dword sq2_cur_pos=0;
static dword wav_cur_pos=0;
static dword noi_cur_pos=0;

apu::apu(gb *ref)
{
	ref_gb=ref;
	snd=new apu_snd(this);
	reset();
}

apu::~apu()
{
}

void apu::reset()
{
	//
	snd->reset();
}

byte apu::read(word adr)
{
	if (adr==0xff26)
		return (!snd->stat.master_enable)?0x00:
				(0x80|(((snd->stat.sq1_playing&&snd->stat.wav_vol)?1:0)|
					((snd->stat.sq2_playing&&snd->stat.wav_vol)?2:0)|
					((snd->stat.wav_enable&&snd->stat.wav_playing&&snd->stat.wav_vol)?4:0)|
					((snd->stat.noi_playing&&snd->stat.noi_vol)?8:0)));
	else
		return snd->mem[adr-0xff10];
}

void apu::write(word adr,byte dat,int clock)
{
	static int bef_clock=clock;
	static int clocks=0;

	snd->mem[adr-0xFF10]=dat;

	snd->write_que[snd->que_count].adr=adr;
	snd->write_que[snd->que_count].dat=dat;
	snd->write_que[snd->que_count++].clock=clock;

	if (snd->que_count>=0x10000)
		snd->que_count=0xffff;

	snd->process(adr,dat);

	if (bef_clock>clock)
		bef_clock=clock;

	clocks+=clock-bef_clock;

	while (clocks>CLOKS_PER_INTERVAL*(ref_gb->get_cpu()->get_speed()?2:1)){
		snd->update();
		clocks-=CLOKS_PER_INTERVAL*(ref_gb->get_cpu()->get_speed()?2:1);
	}

	bef_clock=clock;
}

void apu::update()
{
}

apu_stat *apu::get_stat()
{
	return &snd->stat;
}

apu_stat *apu::get_stat_cpy()
{
	return &snd->stat_cpy;
}

byte *apu::get_mem()
{
	return snd->mem;
}

//---------------------------------------------------------------------

apu_snd::apu_snd(apu *papu)
{
	ref_apu=papu;
	b_enable[0]=b_enable[1]=b_enable[2]=b_enable[3]=true;
	b_echo=false;
	b_lowpass=false;
}

apu_snd::~apu_snd()
{
}

void apu_snd::reset()
{
	que_count=0;
	bef_clock=0;
	memset(&stat,0,sizeof(stat));
	stat.sq1_playing=false;
	stat.sq2_playing=false;
	stat.wav_playing=false;
	stat.noi_playing=false;
	stat.ch_enable[0][0]=stat.ch_enable[0][1]=stat.ch_enable[1][0]=stat.ch_enable[1][1]=
		stat.ch_enable[2][0]=stat.ch_enable[2][1]=stat.ch_enable[3][0]=stat.ch_enable[3][1]=1;
	stat.ch_on[0]=stat.ch_on[1]=stat.ch_on[2]=stat.ch_on[3]=1;
	stat.master_enable=1;
	stat.master_vol[0]=stat.master_vol[1]=7;

	memcpy(&stat_cpy,&stat,sizeof(stat));

	byte gb_init_wav[]={0x06,0xFE,0x0E,0x7F,0x00,0xFF,0x58,0xDF,0x00,0xEC,0x00,0xBF,0x0C,0xED,0x03,0xF7};
	byte gbc_init_wav[]={0x00,0xFF,0x00,0xFF,0x00,0xFF,0x00,0xFF,0x00,0xFF,0x00,0xFF,0x00,0xFF,0x00,0xFF};

	if (ref_apu->ref_gb->get_rom()->get_info()->gb_type==1) // 初期型GB // GB early type
		memcpy(mem+20,gb_init_wav,16);
	else if (ref_apu->ref_gb->get_rom()->get_info()->gb_type>=3) // GBC
		memcpy(mem+20,gbc_init_wav,16);
}

void apu_snd::set_enable(int ch,bool enable)
{
	b_enable[ch]=enable;
}

bool apu_snd::get_enable(int ch)
{
	return b_enable[ch];
}

void apu_snd::process(word adr,byte dat)
{
	int tb[]={0,4,2,1};
	int mul_t[]={2,1,1,1,1,1,1,1};
	int div_t[]={1,1,2,3,4,5,6,7};
	int div_t2[]={2,4,8,16,32,64,128,256,512,1024,2048,4096,8192,16384,1,1};

	mem[adr-0xFF10]=dat;

	switch(adr){
	case 0xFF10:
		stat.sq1_sw_time=(dat>>4)&7;
		stat.sq1_sw_dir=(dat>>3)&1;
		stat.sq1_sw_shift=dat&7;
		break;
	case 0xFF11:
		stat.sq1_type=(dat>>6)&3;
		stat.sq1_init_len=64-(dat&0x3F);
		stat.sq1_len=stat.sq1_init_len;
		break;
	case 0xFF12:
		stat.sq1_init_vol=(dat>>4)&0xF;
		stat.sq1_vol=stat.sq1_init_vol;
		stat.sq1_env_dir=(dat>>3)&1;
		stat.sq1_env_speed=dat&7;
		break;
	case 0xFF13:
		stat.sq1_init_freq&=0x700;
		stat.sq1_init_freq|=dat;
		stat.sq1_freq=stat.sq1_init_freq;
		break;
	case 0xFF14:
		stat.sq1_init_freq&=0xFF;
		stat.sq1_init_freq|=((dat&7)<<8);
		stat.sq1_freq=stat.sq1_init_freq;
		stat.sq1_hold=(dat>>6)&1;
		if (dat&0x80){
			stat.sq1_playing=true;
			stat.sq1_vol=stat.sq1_init_vol;
			stat.sq1_len=stat.sq1_init_len;
			if ((!stat.sq1_playing)||(!stat.sq1_vol)) sq1_cur_pos=0;
		}
		break;
	case 0xFF16:
		stat.sq2_type=(dat>>6)&3;
		stat.sq2_init_len=64-(dat&0x3F);
		stat.sq2_len=stat.sq2_init_len;
		break;
	case 0xFF17:
		stat.sq2_init_vol=(dat>>4)&0xF;
		stat.sq2_vol=stat.sq2_init_vol;
		stat.sq2_env_dir=(dat>>3)&1;
		stat.sq2_env_speed=dat&7;
		break;
	case 0xFF18:
		stat.sq2_init_freq&=0x700;
		stat.sq2_init_freq|=dat;
		stat.sq2_freq=stat.sq2_init_freq;
		break;
	case 0xFF19:
		stat.sq2_init_freq&=0xFF;
		stat.sq2_init_freq|=((dat&7)<<8);
		stat.sq2_freq=stat.sq2_init_freq;
		stat.sq2_hold=(dat>>6)&1;
		if (dat&0x80){
			if ((!stat.sq2_playing)||(!stat.sq2_vol)) sq2_cur_pos=0;
			stat.sq2_playing=true;
			stat.sq2_vol=stat.sq2_init_vol;
			stat.sq2_len=stat.sq2_init_len;
		}
		break;
	case 0xFF1A:
		stat.wav_enable=(dat&0x80)?1:0;
		break;
	case 0xFF1B:
		stat.wav_init_len=(256-dat);
		stat.wav_len=stat.wav_init_len;
		if ((stat.wav_len&&dat)||!stat.wav_hold)
			stat.wav_playing=true;
		else
			stat.wav_playing=false;
		break;
	case 0xFF1C:
		stat.wav_vol=tb[(dat>>5)&3];
//		byte tmp;
//		tmp=stat.wav_vol*128/4;
//		voice_kind_count++;
		break;
	case 0xFF1D:
		stat.wav_freq&=0x700;
		stat.wav_freq|=dat;
		break;
	case 0xFF1E:
		stat.wav_freq&=0xFF;
		stat.wav_freq|=((dat&7)<<8);
		stat.wav_hold=(dat>>6)&1;
		if (dat&0x80){
			stat.wav_len=stat.wav_init_len;
			stat.wav_playing=true;
			if (!stat.wav_playing) wav_cur_pos=0;
		}
		break;
	case 0xFF20://noi len
		stat.noi_init_len=64-(dat&0x3F);
		stat.noi_len=stat.noi_init_len;
		if (stat.noi_len==0)
			stat.noi_playing=false;
		break;
	case 0xFF21://noi env
		stat.noi_init_vol=(dat>>4)&0x0F;
		stat.noi_vol=stat.noi_init_vol;
		stat.noi_env_dir=(dat>>3)&1;
		stat.noi_env_speed=dat&7;
		if (stat.noi_vol==0)
			stat.noi_playing=false;
		break;
	case 0xFF22://noi freq
		stat.noi_init_freq=4194304*mul_t[dat&7]/div_t[dat&7]/div_t2[(dat>>4)&15]/8;
		stat.noi_freq=stat.noi_init_freq;
		stat.noi_step=(dat&8)?7:15;

		if ((dat>>6)==3)
			stat.noi_playing=false;
		break;
	case 0xFF23://noi kick
		stat.noi_hold=(dat>>6)&1;
		if (dat&0x80){
			stat.noi_playing=true;
			stat.noi_len=stat.noi_init_len;
			stat.noi_vol=stat.noi_init_vol;
			if ((!stat.noi_playing)||(!stat.noi_vol)) noi_cur_pos=0;
		}
		break;
	case 0xFF24:
		stat.master_vol[0]=(dat&7);
		stat.master_vol[1]=((dat>>4)&7);
//		voice_kind_count++;
		break;
	case 0xFF25:

		stat.ch_enable[0][0]=((dat>>0)&1);
		stat.ch_enable[0][1]=((dat>>4)&1);
		stat.ch_enable[1][0]=((dat>>1)&1);
		stat.ch_enable[1][1]=((dat>>5)&1);
		stat.ch_enable[2][0]=((dat>>2)&1);
		stat.ch_enable[2][1]=((dat>>6)&1);
		stat.ch_enable[3][0]=((dat>>3)&1);
		stat.ch_enable[3][1]=((dat>>7)&1);

//		voice_kind_count++;
		break;
	case 0xFF26:
		stat.master_enable=(dat&0x80)?1:0;

		stat.ch_on[0]=dat&1;
		stat.ch_on[1]=(dat>>1)&1;
		stat.ch_on[2]=(dat>>2)&1;
		stat.ch_on[3]=(dat>>3)&1;
		break;
	}
}

static int sq_wav_dat[4][8]={
	{0,1,0,0,0,0,0,0},
	{1,1,0,0,0,0,0,0},
	{1,1,1,1,0,0,0,0},
	{0,0,1,1,1,1,1,1}
};

inline short apu_snd::sq1_produce(int freq)
{
	static dword cur_sample=0;
	dword cur_freq;
	short ret;

	if (freq>65000)
		return 15000;

	if (freq){
		ret=sq_wav_dat[stat.sq1_type&3][cur_sample]*20000-10000;
		cur_freq=((freq*8)>0x10000)?0xffff:freq*8;
		sq1_cur_pos+=(cur_freq<<16)/44100;
		if (sq1_cur_pos&0xffff0000){
			cur_sample=(cur_sample+(sq1_cur_pos>>16))&7;
			sq1_cur_pos&=0xffff;
		}
	}
	else
		ret=0;

	return ret;
}

inline short apu_snd::sq2_produce(int freq)
{
	static dword cur_sample=0;
	dword cur_freq;
	short ret;

	if (freq>65000)
		return 15000;

	if (freq){
		ret=sq_wav_dat[stat.sq2_type&3][cur_sample]*20000-10000;
		cur_freq=((freq*8)>0x10000)?0xffff:freq*8;
		sq2_cur_pos+=(cur_freq<<16)/44100;
		if (sq2_cur_pos&0xffff0000){
			cur_sample=(cur_sample+(sq2_cur_pos>>16))&7;
			sq2_cur_pos&=0xffff;
		}
	}
	else
		ret=0;

	return ret;
}

inline short apu_snd::wav_produce(int freq,bool interpolation)
{
	static dword cur_pos2=0;
	static byte bef_sample=0,cur_sample=0;
	dword cur_freq;
	short ret;

	if (freq>65000)
		return (mem[0x20]>>4)*4000-30000;

	if (freq){
		if (interpolation){
			ret=((cur_sample*2500-15000)*wav_cur_pos+(bef_sample*2500-15000)*(0x10000-wav_cur_pos))/0x10000;
		}
		else{
			ret=cur_sample*2500-15000;
		}
		cur_freq=(freq>0x10000)?0xffff:freq;
		wav_cur_pos+=(cur_freq<<16)/44100;
		if (wav_cur_pos&0xffff0000){
			bef_sample=cur_sample;
			cur_pos2=(cur_pos2+(wav_cur_pos>>16))&31;
			if (cur_pos2&1)
				cur_sample=mem[0x20+cur_pos2/2]&0xf;
			else
				cur_sample=mem[0x20+cur_pos2/2]>>4;
			wav_cur_pos&=0xffff;
		}
	}
	else
		ret=0;

	return ret;
}

static inline unsigned int _mrand(dword degree)
{
	static int shift_reg=0x7f;
	static int bef_degree=0;
	int xor_reg=0;
	int masked;
	
	degree=(degree==7)?0:1;

	if (bef_degree!=degree){
		shift_reg&=(degree?0x7fff:0x7f);
		if (!shift_reg) shift_reg=degree?0x7fff:0x7f;
	}
	bef_degree=degree;

	masked=shift_reg&3;
	while(masked)
	{
		xor_reg^=masked&0x01;
		masked>>=1;
	}

	if(xor_reg)
		shift_reg|=(degree?0x8000:0x80);
	else
		shift_reg&=~(degree?0x8000:0x80);
	shift_reg>>=1;

	return shift_reg;
}
/*
inline short apu_snd::noi_produce(int freq)
{
	static int cur_sample=10000;
	dword cur_freq;
	short ret;

	if (freq){
		ret=cur_sample;
		cur_freq=((freq)>44100)?44100:freq;
		noi_cur_pos+=(cur_freq<<16)/44100;
		if (noi_cur_pos&0xffff0000){
			cur_sample=(_mrand(stat.noi_step)&1)?12000:-10000;
//			cur_sample=(_mrand(stat.noi_step)&0x1f)*1000;
			noi_cur_pos&=0xffff;
		}
	}
	else
		ret=0;

	return ret;
}*/
inline short apu_snd::noi_produce(int freq)
{
 	static int cur_sample=10000;
 	dword cur_freq;
 	short ret;
 	int sc;
 	if (freq){
 		ret=cur_sample;
 		cur_freq=freq;
 		noi_cur_pos+=cur_freq;
 		sc=0;
 		while(noi_cur_pos>44100){
 			if(sc==0)
 				cur_sample=(_mrand(stat.noi_step)&1)?12000:-10000;
			else
 				cur_sample+=(_mrand(stat.noi_step)&1)?12000:-10000;
//			cur_sample=(_mrand(stat.noi_step)&0x1f)*1000;
			noi_cur_pos-=44100;
 			sc++;
 		}
 		
		if(sc > 0)
 			cur_sample /= sc;
 		
		
	}
	else
		ret=0;
 	return ret;
}

void apu_snd::update()
{
	static int counter=0;

	if (stat.sq1_playing&&stat.master_enable){
		if (stat.sq1_env_speed&&(counter%(4*stat.sq1_env_speed)==0)){
			stat.sq1_vol+=(stat.sq1_env_dir?1:-1);
			if (stat.sq1_vol<0) stat.sq1_vol=0;
			if (stat.sq1_vol>15) stat.sq1_vol=15;
		}
		if (stat.sq1_sw_time&&stat.sq1_sw_shift&&(counter%(2*stat.sq1_sw_time)==0)){
			if (stat.sq1_sw_dir)
				stat.sq1_freq=stat.sq1_freq-(stat.sq1_freq>>stat.sq1_sw_shift);
			else
				stat.sq1_freq=stat.sq1_freq+(stat.sq1_freq>>stat.sq1_sw_shift);
		}
		if (stat.sq1_hold&&stat.sq1_len){
			stat.sq1_len--;
			if (stat.sq1_len<=0){
				stat.sq1_playing=false;
			}
		}
	}

	if (stat.sq2_playing&&stat.master_enable){
		if (stat.sq2_env_speed&&(counter%(4*stat.sq2_env_speed)==0)){
			stat.sq2_vol+=(stat.sq2_env_dir?1:-1);
			if (stat.sq2_vol<0) stat.sq2_vol=0;
			if (stat.sq2_vol>15) stat.sq2_vol=15;
		}
		if (stat.sq2_hold&&stat.sq2_len){
			stat.sq2_len--;
			if (stat.sq2_len<=0){
				stat.sq2_playing=false;
			}
		}
	}

	if (stat.wav_playing&&stat.master_enable){
		if (stat.wav_hold&&stat.wav_len){
			stat.wav_len--;
			if (stat.wav_len<=0){
				stat.wav_playing=false;
			}
		}
	}

	if (stat.noi_playing&&stat.master_enable){
		if (stat.noi_env_speed&&(counter%(4*stat.noi_env_speed)==0)){
			stat.noi_vol+=(stat.noi_env_dir?1:-1);
			if (stat.noi_vol<0) stat.noi_vol=0;
			if (stat.noi_vol>15) stat.noi_vol=15;
		}
		if (stat.noi_hold&&stat.noi_len){
			stat.noi_len--;
			if (stat.noi_len<=0)
				stat.noi_playing=false;
		}
	}

	counter++;
}

void apu_snd::render(short *buf,int sample)
{
	static short filter[8820*2];
	static int counter=0;

	memcpy(&stat_tmp,&stat,sizeof(stat));
	memcpy(&stat,&stat_cpy,sizeof(stat_cpy));

	int tmp_l,tmp_r,tmp;
	int now_clock=ref_apu->ref_gb->get_cpu()->get_clock();
	int cur=0;
	static int tmp_sample=0,now_time,bef_sample_l[5]={0,0,0,0,0},bef_sample_r[5]={0,0,0,0,0};
	int update_count=0;

	memset(buf,0,sample*4);

	for (int i=0;i<sample;i++){
		now_time=bef_clock+(now_clock-bef_clock)*i/sample;

		if ((cur!=0x10000)&&(now_time>write_que[cur].clock)&&(que_count)){
			process(write_que[cur].adr,write_que[cur].dat);
			cur++;
			if (cur>=que_count)
				cur=0x10000;
		}

		tmp_l=tmp_r=0;
		if (stat.master_enable){
			if (b_enable[0]&&stat.sq1_playing/*&&(stat.sq1_freq!=0x7ff)*/){
				tmp=sq1_produce((131072/(2048-(stat.sq1_freq&0x7FF))))*stat.sq1_vol/20;
				if (stat.ch_enable[0][0])
					tmp_l+=tmp*stat.master_vol[0]/8;
				if (stat.ch_enable[0][1])
					tmp_r+=tmp*stat.master_vol[1]/8;
			}
			if (b_enable[1]&&stat.sq2_playing/*&&(stat.sq2_freq!=0x7ff)*/){
				tmp=sq2_produce((131072/(2048-(stat.sq2_freq&0x7FF))))*stat.sq2_vol/20;
				if (stat.ch_enable[1][0])
					tmp_l+=tmp*stat.master_vol[0]/8;
				if (stat.ch_enable[1][1])
					tmp_r+=tmp*stat.master_vol[1]/8;
			}
			if (b_enable[2]&&stat.wav_playing/*&&(stat.wav_freq!=0x7ff)*/){
				tmp=wav_produce((65536/(2048-(stat.wav_freq&0x7FF)))*32,false)*stat.wav_vol/10*stat.wav_enable;
				if (stat.ch_enable[2][0])
					tmp_l+=tmp*stat.master_vol[0]/8;
				if (stat.ch_enable[2][1])
					tmp_r+=tmp*stat.master_vol[1]/8;
			}
			if (b_enable[3]&&stat.noi_playing){
				tmp=noi_produce(stat.noi_freq)*stat.noi_vol/20;
				if (stat.ch_enable[3][0])
					tmp_l+=tmp*stat.master_vol[0]/8;
				if (stat.ch_enable[3][1])
					tmp_r+=tmp*stat.master_vol[1]/8;
			}
		}
		if (b_echo){
			// エコー
//			tmp_l/=2;
//			tmp_r/=2;
			int ttmp_l=tmp_l,ttmp_r=tmp_r;
			ttmp_l*=5;ttmp_r*=5;
			ttmp_l+=filter[counter*2]*2;
			ttmp_r+=filter[counter*2+1]*2;
			ttmp_l/=5;
			ttmp_r/=5;
			tmp_l=ttmp_l;
			tmp_r=ttmp_r;
			filter[counter*2]=tmp_l;
			filter[counter*2+1]=tmp_r;
			counter++;
			if (counter>=2000)
				counter=0;
//			tmp_l/=2;
//			tmp_r/=2;
		}
		if (b_lowpass){
			// 出力をフィルタリング
			// Filtering the output
			bef_sample_l[4]=bef_sample_l[3];
			bef_sample_l[3]=bef_sample_l[2];
			bef_sample_l[2]=bef_sample_l[1];
			bef_sample_l[1]=bef_sample_l[0];
			bef_sample_l[0]=tmp_l;
			bef_sample_r[4]=bef_sample_r[3];
			bef_sample_r[3]=bef_sample_r[2];
			bef_sample_r[2]=bef_sample_r[1];
			bef_sample_r[1]=bef_sample_r[0];
			bef_sample_r[0]=tmp_r;
			tmp_l=(bef_sample_l[4]+bef_sample_l[3]*2+bef_sample_l[2]*8+bef_sample_l[1]*2+bef_sample_l[0])/14;
			tmp_r=(bef_sample_r[4]+bef_sample_r[3]*2+bef_sample_r[2]*8+bef_sample_r[1]*2+bef_sample_r[0])/14;
		}
		tmp_l=(tmp_l>32767)?32767:tmp_l;
		tmp_l=(tmp_l<-32767)?-32767:tmp_l;
		tmp_r=(tmp_r>32767)?32767:tmp_r;
		tmp_r=(tmp_r<-32767)?-32767:tmp_r;

		//どうやらうちの3.5インチベイ内蔵スピーカが出力を逆にしていたみたい…
		// Built-in speaker 3.5-inch bay had to reverse the output apparently...
//		buf[i*2]=tmp_l;
//		buf[i*2+1]=tmp_r;
		buf[i*2]=tmp_r;
		buf[i*2+1]=tmp_l;

		tmp_sample++;

		while(update_count*CLOKS_PER_INTERVAL*(ref_apu->ref_gb->get_cpu()->get_speed()?2:1)<now_time-bef_clock){
			update();
			update_count++;
		}
//		if (tmp_sample>UPDATE_INTERVAL){
//			tmp_sample-=UPDATE_INTERVAL;
//			update();
//		}
	}
	while (cur<que_count){ // 取りこぼし // Lose information
		process(write_que[cur].adr,write_que[cur].dat);
		cur++;
	}

	que_count=0;
	bef_clock=now_clock;

	memcpy(&stat_cpy,&stat,sizeof(stat));
	memcpy(&stat,&stat_tmp,sizeof(stat));
}

void apu::serialize(serializer &s) { snd->serialize(s); }
void apu_snd::serialize(serializer &s)
{
	// originally, the only things saved were stat, stat_cpy,
	// and the first 0x30 bytes of mem.
	s_VAR(stat);
	s_VAR(stat_cpy);
	s_ARRAY(mem);

	s_VAR(bef_clock);
	s_VAR(b_echo);
	s_VAR(b_lowpass);
}

