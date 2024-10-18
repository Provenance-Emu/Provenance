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

//---------------------------------------
// MBC エミュレーション部 (MBC1/2/3/5/7,HuC-1,MMM01,Rumble,RTC,Motion-Sensor,etc...)
// MBC emulation unit (MBC1/2/3/5/7,HuC-1,MMM01,Rumble,RTC,Motion-Sensor,etc...)

#include "gb.h"

mbc::mbc(gb *ref)
{
	ref_gb=ref;

	reset();
}

mbc::~mbc()
{

}

void mbc::reset()
{
	ref_gb->get_rom()->set_first(0);
	rom_page=ref_gb->get_rom()->get_rom();
	sram_page=ref_gb->get_rom()->get_sram();

	mbc1_16_8=true;
	mbc1_dat=0;
	ext_is_ram=true;

	mbc7_adr=0;
	mbc7_dat=0;
	mbc7_write_enable=false;
	mbc7_idle=false;
	mbc7_cs=0;
	mbc7_sk=0;
	mbc7_state=0;
	mbc7_buf=0;
	mbc7_count=0;
	mbc7_ret=0;

	huc1_16_8=true;
	huc1_dat=0;

	if (ref_gb->get_rom()->get_info()->cart_type==0xFD){
		ext_is_ram=false;
	}
}

byte mbc::read(word adr)
{
	return 0;
}

void mbc::write(word adr,byte dat)
{
	switch(ref_gb->get_rom()->get_info()->cart_type){
	case 1:
	case 2:
	case 3:
		mbc1_write(adr,dat);
		break;
	case 5:
	case 6:
		mbc2_write(adr,dat);
		break;
	case 0x0F:
	case 0x10:
	case 0x11:
	case 0x12:
	case 0x13:
		mbc3_write(adr,dat);
		break;
	case 0x19:
	case 0x1A:
	case 0x1B:
	case 0x1C:
	case 0x1D:
	case 0x1E:
		mbc5_write(adr,dat);
		break;
	case 0x22:
		mbc7_write(adr,dat);
		break;
	case 0xFD:
		tama5_write(adr,dat);
		break;
	case 0xFE:
		huc3_write(adr,dat);
		break;
	case 0xFF:
		huc1_write(adr,dat);
		break;
	case 0x100:
		mmm01_write(adr,dat);
		break;
	}
}

byte mbc::ext_read(word adr)
{
	switch(ref_gb->get_rom()->get_info()->cart_type){
	case 1:
	case 2:
	case 3:
	case 5:
	case 6:
		return 0;
	case 0x0F:
	case 0x10:
	case 0x11:
	case 0x12:
	case 0x13:
//		extern FILE *file;
//		fprintf(file,"external read [%04X]\n",adr);
		if (mbc3_latch){
			switch(mbc3_timer){
			case 8: return mbc3_sec;
			case 9: return mbc3_min;
			case 10: return mbc3_hour;
			case 11: return mbc3_dayl;
			case 12: return mbc3_dayh;
			}
		}
		return ref_gb->get_renderer()->get_time(mbc3_timer);
	case 0x19:
	case 0x1A:
	case 0x1B:
	case 0x1C:
	case 0x1D:
	case 0x1E:
		return 0;
	case 0x22: // コロコロカービィ // Korokoro Kirby
		switch(adr&0xa0f0)
		{
		case 0xA000:
			return 0;
		case 0xA010:
			return 0;
		case 0xA020:
			return ref_gb->get_renderer()->get_sensor(true)&0xff;
		case 0xA030:
			return (ref_gb->get_renderer()->get_sensor(true)>>8)&0xf;
		case 0xA040:
			return ref_gb->get_renderer()->get_sensor(false)&0xff;
		case 0xA050:
			return (ref_gb->get_renderer()->get_sensor(false)>>8)&0xf;
		case 0xA060:
			return 0;
		case 0xA070:
			return 0;
		case 0xA080:
			return mbc7_ret;
		}
		return 0xff;
	case 0xFD:
//		extern FILE *file;
//		fprintf(file,"%04X : TAMA5 ext_read %04X \n",ref_gb->get_cpu()->get_regs()->PC,adr);
		return 1;
	case 0xFE:
//		extern FILE *file;
//		fprintf(file,"%04X : HuC-3 ext_read %04X \n",ref_gb->get_cpu()->get_regs()->PC,adr);
		return 1;
	case 0xFF:
		return 0;
	}
	return 0;
}

void mbc::ext_write(word adr,byte dat)
{
	int i;

	switch(ref_gb->get_rom()->get_info()->cart_type){
	case 1:
	case 2:
	case 3:
	case 5:
	case 6:
	case 0x19:
	case 0x1A:
	case 0x1B:
	case 0x1C:
	case 0x1D:
	case 0x1E:
	case 0xFF:
		break;
	case 0x0F:
	case 0x10:
	case 0x11:
	case 0x12:
	case 0x13:
		ref_gb->get_renderer()->set_time(mbc3_timer,dat);
		break;
	case 0xFE: //HuC-3
//		extern FILE *file;
//		fprintf(file,"%04X : HuC-3 ext_write %04X <= %02X\n",ref_gb->get_cpu()->get_regs()->PC,adr,dat);
		break;
	case 0xFD: //TAMA5
//		extern FILE *file;
//		fprintf(file,"%04X : TAMA5 ext_write %04X <= %02X\n",ref_gb->get_cpu()->get_regs()->PC,adr,dat);
		break;
	case 0x22: // コロコロカービィ // Korokoro Kirby
		if (adr==0xA080){
			int bef_cs=mbc7_cs,bef_sk=mbc7_sk;

			mbc7_cs=dat>>7;
			mbc7_sk=(dat>>6)&1;

			if (!bef_cs&&mbc7_cs){
				if (mbc7_state==5){
					if (mbc7_write_enable){
						*(ref_gb->get_rom()->get_sram()+mbc7_adr*2)=mbc7_buf>>8;
						*(ref_gb->get_rom()->get_sram()+mbc7_adr*2+1)=mbc7_buf&0xff;
////						fprintf(file,"書き込み完了\n");
//						fprintf(file,"Write complete\n");
					}
					mbc7_state=0;
					mbc7_ret=1;
////					fprintf(file,"書き込み受理 ステート:なし\n");
//					fprintf(file,"State writing acceptance: no\n");
				}
				else{
					mbc7_idle=true; // アイドル状態突入
					mbc7_state=0;
////					fprintf(file,"アイドル状態突入 ステート:アイドル状態\n");
//					fprintf(file,"Idle: idle state rush\n");
				}
			}

			if (!bef_sk&&mbc7_sk){ // クロック立ち上がり // Rising edge of the clock
				if (mbc7_idle){ // アイドル状態であれば // If idle
					if (dat&0x02){
						mbc7_idle=false; // アイドル状態解除 // Idle state release
						mbc7_count=0;
						mbc7_state=1;
////						fprintf(file,"アイドル状態解除 ステート:コマンド認識\n");
//						fprintf(file,"Command recognition: release idle state\n");
					}
				}
				else{
					switch(mbc7_state){
					case 1: // コマンド受付 // Command reception
						mbc7_buf<<=1;
						mbc7_buf|=(dat&0x02)?1:0;
						mbc7_count++;
						if (mbc7_count==2){ // 受付終了 // Exit Reception
							mbc7_state=2;
							mbc7_count=0;
							mbc7_op_code=mbc7_buf&3;
						}
						break;
					case 2: // アドレス受信 // Address received
						mbc7_buf<<=1;
						mbc7_buf|=(dat&0x02)?1:0;
						mbc7_count++;
						if (mbc7_count==8){ // 受付終了 // Exit Reception
							mbc7_state=3;
							mbc7_count=0;
							mbc7_adr=mbc7_buf&0xff;
							if (mbc7_op_code==0){
								if ((mbc7_adr>>6)==0){
////									fprintf(file,"書き込み消去禁止 ステート:なし\n");
//									fprintf(file,"erasing state prohibited : No\n");
									mbc7_write_enable=false;
									mbc7_state=0;
								}
								else if ((mbc7_adr>>6)==3){
////									fprintf(file,"書き込み消去許可 ステート:なし\n");
//									fprintf(file,"erasing the authorized state : No\n");
									mbc7_write_enable=true;
									mbc7_state=0;
								}
							}
							else{
////								fprintf(file,"アドレス:%02X ステート:データ受信\n",mbc7_adr);
//								fprintf(file,"Address: %02X State: Data reception\n",mbc7_adr);
							}
						}
						break;
					case 3: // データ // Data
						mbc7_buf<<=1;
						mbc7_buf|=(dat&0x02)?1:0;
						mbc7_count++;

						switch(mbc7_op_code){
						case 0:
							if (mbc7_count==16){
								if ((mbc7_adr>>6)==0){
////									fprintf(file,"書き込み消去禁止 ステート:なし\n");
//									fprintf(file,"erasing state prohibited : No\n");
									mbc7_write_enable=false;
									mbc7_state=0;
								}
								else if ((mbc7_adr>>6)==1){
									if (mbc7_write_enable){
										for (i=0;i<256;i++){
											*(ref_gb->get_rom()->get_sram()+i*2)=mbc7_buf>>8;
											*(ref_gb->get_rom()->get_sram()+i*2)=mbc7_buf&0xff;
										}
									}
////									fprintf(file,"全アドレス書き込み %04X ステート:なし\n",mbc7_buf);
//									fprintf(file,"Write all addresses %04X State: No\n",mbc7_buf);
									mbc7_state=5;
								}
								else if ((mbc7_adr>>6)==2){
									if (mbc7_write_enable){
										for (i=0;i<256;i++)
											*(word*)(ref_gb->get_rom()->get_sram()+i*2)=0xffff;
									}
////									fprintf(file,"全アドレス消去 ステート:なし\n");
//									fprintf(file,"erased state all addresses : None\n");
									mbc7_state=5;
								}
								else if ((mbc7_adr>>6)==3){
////									fprintf(file,"書き込み消去許可 ステート:なし\n");
//									fprintf(file,"erasing the authorized state : No\n");
									mbc7_write_enable=true;
									mbc7_state=0;
								}
								mbc7_count=0;
							}
							break;
						case 1:
							if (mbc7_count==16){
////								fprintf(file,"書き込み [%02X]<-%04X ステート:書き込み待ちフレーム\n",mbc7_adr,mbc7_buf);
//								fprintf(file,"Writing [%02X]<-%04X State: Frame waiting to be written\n",mbc7_adr,mbc7_buf);
								mbc7_count=0;
								mbc7_state=5;
								mbc7_ret=0;
							}
							break;
						case 2:
							if (mbc7_count==1){
////								fprintf(file,"ダミー受信完了 ステート:読み出し可\n");
//								fprintf(file,"Readable: State reception complete dummy\n");
								mbc7_state=4;
								mbc7_count=0;
								mbc7_buf=(ref_gb->get_rom()->get_sram()[mbc7_adr*2]<<8)|(ref_gb->get_rom()->get_sram()[mbc7_adr*2+1]);
////								fprintf(file,"受信データ %04X\n",mbc7_buf);
//								fprintf(file,"Received data %04X\n",mbc7_buf);
							}
							break;
						case 3:
							if (mbc7_count==16){
////								fprintf(file,"消去 [%02X] ステート:書き込み待ちフレーム\n",mbc7_adr,mbc7_buf);
//								fprintf(file,"Elimination [%02X] State: Frame waiting to be written\n",mbc7_adr,mbc7_buf);
								mbc7_count=0;
								mbc7_state=5;
								mbc7_ret=0;
								mbc7_buf=0xffff;
							}
							break;
						}
						break;
					}
				}
			}

			if (bef_sk&&!mbc7_sk){ // クロック立ち下り // Falling clock
				if (mbc7_state==4){ // 読み出し中 // While reading
					mbc7_ret=(mbc7_buf&0x8000)?1:0;
					mbc7_buf<<=1;
					mbc7_count++;
////					fprintf(file,"読み出し中 %d ビット目\n",mbc7_count);
//					fprintf(file,"While reading %dth bit\n",mbc7_count);
					if (mbc7_count==16){
						mbc7_count=0;
						mbc7_state=0;
////						fprintf(file,"読み出し完了 ステート:なし\n");
//						fprintf(file,"Read state complete: No\n");
					}
				}
			}
		}

		break;
	}
}

int mbc::get_state()
{
	switch(ref_gb->get_rom()->get_info()->cart_type){
	case 1:
	case 2:
	case 3:
		return mbc1_dat|(mbc1_16_8?0x100:0);
	case 5:
	case 6:
		return 0;
	case 0x0F:
	case 0x10:
	case 0x11:
	case 0x12:
	case 0x13:
		return (mbc3_timer&0xf)|((mbc3_latch&1)<<4)|((mbc3_sec&0x3f)<<5)|((mbc3_min&0x3f)<<11)|
			((mbc3_hour&0x1f)<<17)|(mbc3_dayl<<22)|((mbc3_dayh&1)<<30);
	case 0x19:
	case 0x1A:
	case 0x1B:
	case 0x1C:
	case 0x1D:
	case 0x1E:
		return mbc5_dat;
	case 0xFF:
		return huc1_dat|(huc1_16_8?0x100:0);
	default:
		return 0;
	}
}

void mbc::set_state(int dat)
{
	switch(ref_gb->get_rom()->get_info()->cart_type){
	case 1:
	case 2:
	case 3:
		mbc1_dat=dat&0xFF;
		mbc1_16_8=((dat>>8)&1?true:false);
		break;
	case 5:
	case 6:
		break;
	case 0x0F:
	case 0x10:
	case 0x11:
	case 0x12:
	case 0x13:
		mbc3_timer=dat&0x0F;
		dat>>=4;
		mbc3_latch=dat&1;
		dat>>=1;
		mbc3_sec=dat&0x3f;
		dat>>=6;
		mbc3_min=dat&0x3f;
		dat>>=6;
		mbc3_hour=dat&0x1f;
		dat>>=5;
		mbc3_dayl=dat&0xff;
		dat>>=8;
		mbc3_dayh=dat&1;
		break;
	case 0x19:
	case 0x1A:
	case 0x1B:
	case 0x1C:
	case 0x1D:
	case 0x1E:
		mbc5_dat=dat&0xFFFF;
		break;
	case 0xFF:
		huc1_dat=dat&0xFF;
		huc1_16_8=((dat>>8)&1?true:false);
		break;
	}
}

void mbc::set_page(int rom,int sram)
{
	rom_page=ref_gb->get_rom()->get_rom()+rom*0x4000;
	sram_page=ref_gb->get_rom()->get_sram()+sram*0x2000;
}

static int rom_size_tbl[]={2,4,8,16,32,64,128,256,512};
static int ram_size_tbl[]={0,1,1,4,16,8};

void mbc::mbc1_write(word adr,byte dat)
{
	if (mbc1_16_8){//16/8モード
		switch(adr>>13){
		case 0:
			break;
		case 1:
			mbc1_dat=(mbc1_dat&0x60)+(dat&0x1F);
			rom_page=ref_gb->get_rom()->get_rom()+0x4000*((mbc1_dat==0?1:mbc1_dat)&(rom_size_tbl[ref_gb->get_rom()->get_info()->rom_size]-1))-0x4000;
			break;
		case 2:
			mbc1_dat=((dat<<5)&0x60)+(mbc1_dat&0x1F);
			rom_page=ref_gb->get_rom()->get_rom()+0x4000*((mbc1_dat==0?1:mbc1_dat)&(rom_size_tbl[ref_gb->get_rom()->get_info()->rom_size]-1))-0x4000;
			break;
		case 3:
			if (dat&1)
				mbc1_16_8=false;
			else
				mbc1_16_8=true;
//			mbc1_dat=0;
			break;
		}
	}
	else{//4/32モード
		switch(adr>>13){
		case 0:
			break;
		case 1:
			rom_page=ref_gb->get_rom()->get_rom()+0x4000*((dat==0?1:dat)&0x1F&(rom_size_tbl[ref_gb->get_rom()->get_info()->rom_size]-1))-0x4000;
			break;
		case 2:
			sram_page=ref_gb->get_rom()->get_sram()+0x2000*(dat&3);
			break;
		case 3:
			if (dat&1)
				mbc1_16_8=false;
			else
				mbc1_16_8=true;
//			mbc1_dat=0;
			break;
		}
	}
}

void mbc::mbc2_write(word adr,byte dat)
{
	if ((adr>=0x2000)&&(adr<=0x3FFF))
		rom_page=ref_gb->get_rom()->get_rom()+0x4000*(((dat&0x0F)==0?1:dat&0x0F)-1);
}

void mbc::mbc3_write(word adr,byte dat)
{
	switch(adr>>13){
	case 0:
		if (dat==0x0a)
			ext_is_ram=true;
		else{
			ext_is_ram=false;
			mbc3_timer=0;
		}
		break;
	case 1:
		rom_page=ref_gb->get_rom()->get_rom()+0x4000*((dat==0?1:dat)&0x7F&(rom_size_tbl[ref_gb->get_rom()->get_info()->rom_size]-1))-0x4000;
		break;
	case 2:
		if (dat<8){
			sram_page=ref_gb->get_rom()->get_sram()+0x2000*(dat&7&(ram_size_tbl[ref_gb->get_rom()->get_info()->ram_size]-1));
			ext_is_ram=true;
		}
		else{
			ext_is_ram=false;
			mbc3_timer=dat&0x0F;
		}
		break;
	case 3://RTCラッチ // RTC latch
		if (dat==0){ // Latchはずす // Disconnect latch
			mbc3_latch=0;
		}
		else if (dat==1){ // データをLatchする // Latch the data to
			if (!mbc3_latch){
				mbc3_sec=ref_gb->get_renderer()->get_time(8);
				mbc3_min=ref_gb->get_renderer()->get_time(9);
				mbc3_hour=ref_gb->get_renderer()->get_time(10);
				mbc3_dayl=ref_gb->get_renderer()->get_time(11);
				mbc3_dayh=ref_gb->get_renderer()->get_time(12);
			}
			mbc3_latch=1;
		}

		break;
	}
}

void mbc::mbc5_write(word adr,byte dat)
{
	switch(adr>>12){
	case 0:
	case 1:
		break;
	case 2:
		mbc5_dat&=0x0100;
		mbc5_dat|=dat;
		rom_page=ref_gb->get_rom()->get_rom()+0x4000*(mbc5_dat&(rom_size_tbl[ref_gb->get_rom()->get_info()->rom_size]-1))-0x4000;
		break;
	case 3:
		mbc5_dat&=0x00FF;
		mbc5_dat|=(dat&1)<<8;
		rom_page=ref_gb->get_rom()->get_rom()+0x4000*(mbc5_dat&(rom_size_tbl[ref_gb->get_rom()->get_info()->rom_size]-1))-0x4000;
		break;
	case 4:
	case 5:
		if (ref_gb->get_rom()->get_info()->cart_type==0x1C||ref_gb->get_rom()->get_info()->cart_type==0x1D||ref_gb->get_rom()->get_info()->cart_type==0x1E){//Rumble カートリッジ
			sram_page=ref_gb->get_rom()->get_sram()+0x2000*(dat&0x07&(ram_size_tbl[ref_gb->get_rom()->get_info()->ram_size]-1));
			if (dat&0x8)
				ref_gb->get_renderer()->set_bibrate(true);
			else
				ref_gb->get_renderer()->set_bibrate(false);
		}
		else
			sram_page=ref_gb->get_rom()->get_sram()+0x2000*(dat&0x0f&(ram_size_tbl[ref_gb->get_rom()->get_info()->ram_size]-1));
		break;
	}
}

void mbc::mbc7_write(word adr,byte dat)
{
	switch(adr>>13){
	case 0:
		break;
	case 1:
		rom_page=ref_gb->get_rom()->get_rom()+0x4000*((dat==0?1:dat)&0x7F&(rom_size_tbl[ref_gb->get_rom()->get_info()->rom_size]-1))-0x4000;
//		rom_page=ref_gb->get_rom()->get_rom()+0x4000*(dat&0x3f)-0x4000;
		break;
	case 2:
		if (dat<8){
			sram_page=ref_gb->get_rom()->get_sram()+0x2000*(dat&3);
			ext_is_ram=false;
		}
		else
			ext_is_ram=false;
		break;
	case 3: // 0x40 が モーションセンサーにマップだが､他のものがマップされることは無い。
		// But mapped to a motion sensor, but not the other things that will be mapped.
		break;
	}
}

void mbc::huc1_write(word adr,byte dat)
{
	if (huc1_16_8){//16/8モード
		switch(adr>>13){
		case 0:
			break;
		case 1:
			huc1_dat=(huc1_dat&0x60)+(dat&0x3F);
			rom_page=ref_gb->get_rom()->get_rom()+0x4000*((huc1_dat==0?1:huc1_dat)&(rom_size_tbl[ref_gb->get_rom()->get_info()->rom_size]-1))-0x4000;
			break;
		case 2:
			huc1_dat=((dat<<5)&0x60)+(huc1_dat&0x3F);
			rom_page=ref_gb->get_rom()->get_rom()+0x4000*((huc1_dat==0?1:huc1_dat)&(rom_size_tbl[ref_gb->get_rom()->get_info()->rom_size]-1))-0x4000;
			break;
		case 3:
			if (dat&1)
				huc1_16_8=false;
			else
				huc1_16_8=true;
			huc1_dat=0;
			break;
		}
	}
	else{//4/32モード
		switch(adr>>13){
		case 0:
			break;
		case 1:
			rom_page=ref_gb->get_rom()->get_rom()+0x4000*((dat==0?1:dat)&0x3F&(rom_size_tbl[ref_gb->get_rom()->get_info()->rom_size]-1))-0x4000;
			break;
		case 2:
			sram_page=ref_gb->get_rom()->get_sram()+0x2000*(dat&3);
			break;
		case 3:
			if (dat&1)
				huc1_16_8=false;
			else
				huc1_16_8=true;
			huc1_dat=0;
			break;
		}
	}
}

void mbc::huc3_write(word adr,byte dat)
{
//	extern FILE *file;
//	fprintf(file,"%04X : HuC-3 write %04X <= %02X\n",ref_gb->get_cpu()->get_regs()->PC,adr,dat);
	switch(adr>>13){
	case 0:
		if (dat==0xA)
			ext_is_ram=true;
		else if (dat==0x0B){
			ext_is_ram=false;
		}
		else if (dat==0x0C){
			ext_is_ram=false;
		}
		else if (dat==0x0D){
			ext_is_ram=false;
		}
		else {
			ext_is_ram=false;
		}
		break;
	case 1:
		rom_page=ref_gb->get_rom()->get_rom()+0x4000*((dat==0?1:dat)&0x7F&(rom_size_tbl[ref_gb->get_rom()->get_info()->rom_size]-1))-0x4000;
		break;
	case 2:
		if (dat<8){
			sram_page=ref_gb->get_rom()->get_sram()+0x2000*(dat&3);
			ext_is_ram=true;
		}
		else{
//			ext_is_ram=false;
//			mbc3_timer=dat&0x0F;
		}
		break;
	case 3://RTCラッチ
/*		if (dat==0){ // Latchはずす // Disconnect Latch
			mbc3_latch=0;
		}
		else if (dat==1){ // データをLatchする // Latch the data to
			if (!mbc3_latch){
				mbc3_sec=ref_gb->get_renderer()->get_time(8);
				mbc3_min=ref_gb->get_renderer()->get_time(9);
				mbc3_hour=ref_gb->get_renderer()->get_time(10);
				mbc3_dayl=ref_gb->get_renderer()->get_time(11);
				mbc3_dayh=ref_gb->get_renderer()->get_time(12);
			}
			mbc3_latch=1;
		}
*/
		break;
	}
}

void mbc::tama5_write(word adr,byte dat)
{
//	extern FILE *file;
//	fprintf(file,"TAMA5 write %04X <= %02X\n",adr,dat);
}

void mbc::mmm01_write(word adr,byte dat)
{
	if (mbc1_16_8){//16/8モード // 16/8 mode
		switch(adr>>13){
		case 0:
			break;
		case 1:
			mbc1_dat=(mbc1_dat&0x60)+(dat&0x1F);
			rom_page=ref_gb->get_rom()->get_rom()+0x4000*((mbc1_dat==0?1:mbc1_dat)&(rom_size_tbl[ref_gb->get_rom()->get_info()->rom_size]-1))-0x4000;
			break;
		case 2:
			mbc1_dat=((dat<<5)&0x60)+(mbc1_dat&0x1F);
			rom_page=ref_gb->get_rom()->get_rom()+0x4000*((mbc1_dat==0?1:mbc1_dat)&(rom_size_tbl[ref_gb->get_rom()->get_info()->rom_size]-1))-0x4000;
			break;
		case 3:
			if (dat&1)
				mbc1_16_8=false;
			else
				mbc1_16_8=true;
			mbc1_dat=0;
			break;
		}
	}
	else{//4/32モード // 4/32 mode
		switch(adr>>13){
		case 0:
			break;
		case 1:
			rom_page=ref_gb->get_rom()->get_rom()+0x4000*(((dat&3)*0x10+(dat==0?1:dat))&0x0f&(rom_size_tbl[ref_gb->get_rom()->get_info()->rom_size]-1))-0x4000;
			break;
		case 2:
			ref_gb->get_rom()->set_first((dat&3)*0x10);
			rom_page=ref_gb->get_rom()->get_rom()+0x4000*((dat&3)*0x10);
			mbc1_dat=dat&3;
//			sram_page=ref_gb->get_rom()->get_sram()+0x2000*(dat&3);
			break;
		case 3:
			if (dat&1)
				mbc1_16_8=false;
			else
				mbc1_16_8=true;
//			mbc1_dat=0;
			break;
		}
	}
}


void mbc::serialize(serializer &s)
{
	byte*  rom = ref_gb->get_rom()->get_rom();
	byte* sram = ref_gb->get_rom()->get_sram();

	int tmp;

	tmp = ( rom_page- rom)/0x4000; s_VAR(tmp);  rom_page =  rom + tmp*0x4000;
	tmp = (sram_page-sram)/0x2000; s_VAR(tmp); sram_page = sram + tmp*0x2000;

	tmp = get_state(); s_VAR(tmp); set_state(tmp);

	s_VAR(ext_is_ram);

	// all of the below were originally not in the save state format.
	s_VAR(mbc1_16_8);  s_VAR(mbc1_dat);

	s_VAR(mbc3_latch); s_VAR(mbc3_sec);  s_VAR(mbc3_min); s_VAR(mbc3_hour);
	s_VAR(mbc3_dayl);  s_VAR(mbc3_dayh); s_VAR(mbc3_timer);

	s_VAR(mbc5_dat);

	s_VAR(mbc7_write_enable);
	s_VAR(mbc7_idle);  s_VAR(mbc7_cs);   s_VAR(mbc7_sk);  s_VAR(mbc7_op_code);
	s_VAR(mbc7_adr);   s_VAR(mbc7_dat);  s_VAR(mbc7_ret); s_VAR(mbc7_state);
	s_VAR(mbc7_buf);   s_VAR(mbc7_count);

	s_VAR(huc1_16_8);  s_VAR(huc1_dat);
}

