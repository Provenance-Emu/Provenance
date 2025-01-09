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

//-------------------------------------------------
// GB その他エミュレーション部/外部とのインターフェース
// Interface with external / other unit emulation GB

#include "gb.h"
#include <stdlib.h>

gb::gb(renderer *ref,bool b_lcd,bool b_apu)
{
	m_renderer=ref;

	m_lcd=new lcd(this);
	m_rom=new rom();
	m_apu=new apu(this);// ROMより後に作られたし // I was made ​​later than the ROM
	m_mbc=new mbc(this);
	m_cpu=new cpu(this);
	m_cheat=new cheat(this);
	target=NULL;

	m_renderer->reset();
	m_renderer->set_sound_renderer(b_apu?m_apu->get_renderer():NULL);

	reset();

	hook_ext=false;
	use_gba=false;
}

gb::~gb()
{
	m_renderer->set_sound_renderer(NULL);

	delete m_mbc;
	delete m_rom;
	delete m_apu;
	delete m_lcd;
	delete m_cpu;
}

void gb::reset()
{
	regs.SC=0;
	regs.DIV=0;
	regs.TIMA=0;
	regs.TMA=0;
	regs.TAC=0;
	regs.LCDC=0x91;
	regs.STAT=0;
	regs.SCY=0;
	regs.SCX=0;
	regs.LY=153;
	regs.LYC=0;
	regs.BGP=0xFC;
	regs.OBP1=0xFF;
	regs.OBP2=0xFF;
	regs.WY=0;
	regs.WX=0;
	regs.IF=0;
	regs.IE=0;

	memset(&c_regs,0,sizeof(c_regs));

	if (m_rom->get_loaded())
		m_rom->get_info()->gb_type=(m_rom->get_rom()[0x143]&0x80)?(use_gba?4:3):1;

	m_cpu->reset();
	m_lcd->reset();
	m_apu->reset();
	m_mbc->reset();

	now_frame=0;
	skip=skip_buf=0;
	re_render=0;
}

void gb::hook_extport(ext_hook *ext)
{
	hook_proc=*ext;
	hook_ext=true;
}

void gb::unhook_extport()
{
	hook_ext=false;
}

void gb::set_skip(int frame)
{
	skip_buf=frame;
}

bool gb::load_rom(byte *buf,int size,byte *ram,int ram_size, bool persistent)
{
	if (m_rom->load_rom(buf,size,ram,ram_size, persistent))
   {
		reset();
		return true;
	}
   return false;
}

// savestate format matching the original TGB dual, pre-libretro port
void gb::serialize_legacy(serializer &s)
{
	int tbl_ram[]={1,1,1,4,16,8};

	s.process(&m_rom->get_info()->gb_type, sizeof(int));
	bool gbc = m_rom->get_info()->gb_type >= 3; // GB: 1, SGB: 2, GBC: 3...

	int cpu_dat[16]; // only used when gbc is true

	if(gbc) {
		s.process(m_cpu->get_ram(), 0x2000*4);
		s.process(m_cpu->get_vram(), 0x2000*2);
	} else {
		s.process(m_cpu->get_ram(), 0x2000);
		s.process(m_cpu->get_vram(), 0x2000);
	}
	s.process(m_rom->get_sram(), tbl_ram[m_rom->get_info()->ram_size]*0x2000);
	s.process(m_cpu->get_oam(), 0xA0);
	s.process(m_cpu->get_stack(), 0x80);

	int rom_page = (m_mbc->get_rom()-m_rom->get_rom())/0x4000;
	int ram_page = (m_mbc->get_sram()-m_rom->get_sram())/0x2000;
	s.process(&rom_page, sizeof(int));
	s.process(&ram_page, sizeof(int));
	m_mbc->set_page(rom_page, ram_page); // hackish, but should work.
	// basically, if we're serializing to count or save, the set_page
	// should have no effect assuming the calculations above are correct.
	// tl;dr: "if it's good enough for saving, it's good enough for loading"

	if(gbc) {
		m_cpu->save_state(cpu_dat);

		s.process(cpu_dat+0, 2*sizeof(int)); //int_page, vram_page
		/* s.process(cpu_dat+1, sizeof(int)); ^ just serialize both in one go */
	}

	s.process(m_cpu->get_regs(), sizeof(cpu_regs)); // cpu_reg
	s.process(&regs, sizeof(gb_regs)); //sys_reg

	if(gbc) {
		s.process(&c_regs, sizeof(gbc_regs)); //col_reg
		s.process(m_lcd->get_pal(0), sizeof(word)*8*4*2); //palette
	}

	int halt = !! (*m_cpu->get_halt());
	s.process(&halt, sizeof(int));
	(*m_cpu->get_halt()) = !! halt; // same errata as above

	// Originally the number of clocks until serial communication expires
	int dmy = 0;
	s.process(&dmy, sizeof(int));

	int mbc_dat = m_mbc->get_state();
	s.process(&mbc_dat, sizeof(int)); //MBC
	m_mbc->set_state(mbc_dat);

	int ext_is = !! m_mbc->is_ext_ram();
	s.process(&ext_is, sizeof(int));
	m_mbc->set_ext_is(!! ext_is);

	if(gbc) {
		// Many additional specifications
		/* i think this is inefficient...
		s.process(cpu_dat+2, sizeof(int));

		s.process(cpu_dat+3, sizeof(int));
		s.process(cpu_dat+4, sizeof(int));
		s.process(cpu_dat+5, sizeof(int));
		s.process(cpu_dat+6, sizeof(int));

		s.process(cpu_dat+7, sizeof(int));
		*/
		s.process(cpu_dat+2, 6*sizeof(int));
		m_cpu->restore_state(cpu_dat); // same errata as above
	}

	// Added ver 1.1
	s.process(m_apu->get_stat(), sizeof(apu_stat));
	s.process(m_apu->get_mem(), 0x30);
	s.process(m_apu->get_stat_cpy(), sizeof(apu_stat));

	byte resurved[256];
	memset(resurved, 0, 256);
	s.process(resurved, 256); // Reserved for future use
}


// TODO: put 'serialize' in other classes (cpu, mbc, ...) and call it from here.
void gb::serialize_firstrev(serializer &s)
{
	int tbl_ram[]={1,1,1,4,16,8};

	s.process(&m_rom->get_info()->gb_type, sizeof(int));
	bool gbc = m_rom->get_info()->gb_type >= 3; // GB: 1, SGB: 2, GBC: 3...

	int cpu_dat[16];

	if(gbc) {
		s.process(m_cpu->get_ram(), 0x2000*4);
		s.process(m_cpu->get_vram(), 0x2000*2);
	} else {
		s.process(m_cpu->get_ram(), 0x2000);
		s.process(m_cpu->get_vram(), 0x2000);
	}
	s.process(m_rom->get_sram(), tbl_ram[m_rom->get_info()->ram_size]*0x2000);
	s.process(m_cpu->get_oam(), 0xA0);
	s.process(m_cpu->get_stack(), 0x80);

	int rom_page = (m_mbc->get_rom() - m_rom->get_rom()) / 0x4000;
	int ram_page = (m_mbc->get_sram() - m_rom->get_sram()) / 0x2000;
	s.process(&rom_page, sizeof(int)); // rom_page
	s.process(&ram_page, sizeof(int)); // ram_page
	m_mbc->set_page(rom_page, ram_page); // hackish, but should work.
	// basically, if we're serializing to count or save, the set_page
	// should have no effect assuming the calculations above are correct.
	// tl;dr: "if it's good enough for saving, it's good enough for loading"

	if(true || gbc) { // why not for normal gb as well?
		m_cpu->save_state(cpu_dat);
		m_cpu->save_state_ex(cpu_dat+8);
		s.process(cpu_dat, 12*sizeof(int));
		m_cpu->restore_state(cpu_dat);      // same errata as above
		m_cpu->restore_state_ex(cpu_dat+8);
	}

	s.process(m_cpu->get_regs(), sizeof(cpu_regs)); // cpu_reg
	s.process(&regs, sizeof(gb_regs)); //sys_reg

	if(gbc) {
		s.process(&c_regs, sizeof(gbc_regs)); //col_reg
		s.process(m_lcd->get_pal(0), sizeof(word)*8*4*2); //palette
	}

	s.process(m_cpu->get_halt(), sizeof(bool));

	int mbc_dat = m_mbc->get_state();
	s.process(&mbc_dat, sizeof(int)); //MBC
	m_mbc->set_state(mbc_dat);

	bool ext_is = m_mbc->is_ext_ram();
	s.process(&ext_is, sizeof(bool));
	m_mbc->set_ext_is(ext_is);

	// Added ver 1.1
	s.process(m_apu->get_stat(), sizeof(apu_stat));
	s.process(m_apu->get_mem(), 0x30);
	s.process(m_apu->get_stat_cpy(), sizeof(apu_stat));
}

void gb::serialize(serializer &s)
{
	s_VAR(regs);
	s_VAR(c_regs);

	m_rom->serialize(s);
	m_cpu->serialize(s);
	m_mbc->serialize(s);
	m_lcd->serialize(s);
	m_apu->serialize(s);
}

size_t gb::get_state_size(void)
{
	size_t ret = 0;
	serializer s(&ret, serializer::COUNT);
	serialize(s);
	return ret;
}

void gb::save_state_mem(void *buf)
{
	serializer s(buf, serializer::SAVE_BUF);
	serialize(s);
}

void gb::restore_state_mem(void *buf)
{
	serializer s(buf, serializer::LOAD_BUF);
	serialize(s);
}

void gb::refresh_pal()
{
	for (int i=0;i<64;i++)
		m_lcd->get_mapped_pal(i>>2)[i&3]=m_renderer->map_color(m_lcd->get_pal(i>>2)[i&3]);
}

void gb::run()
{
	if (m_rom->get_loaded()){
		if (regs.LCDC&0x80){ // LCDC 起動時 // Startup LCDC
			regs.LY=(regs.LY+1)%154;

			regs.STAT&=0xF8;
			if (regs.LYC==regs.LY){
				regs.STAT|=4;
				if (regs.STAT&0x40)
					m_cpu->irq(INT_LCDC);
			}
			if (regs.LY==0){
				m_renderer->refresh();
				if (now_frame>=skip){
					m_renderer->render_screen((byte*)vframe,160,144,16);
					now_frame=0;
				}
				else
					now_frame++;
				m_lcd->clear_win_count();
				skip=skip_buf;
			}
			if (regs.LY>=144){ // VBlank 期間中 // During VBlank
				regs.STAT|=1;
				if (regs.LY==144){
					m_cpu->exec(72);
					m_cpu->irq(INT_VBLANK);
					if (regs.STAT&0x10)
						m_cpu->irq(INT_LCDC);
					m_cpu->exec(456-80);
				}
				else if (regs.LY==153){
					m_cpu->exec(80);
					regs.LY=0;
					// 前のラインのかなり早目から0になるようだ。
					// It's pretty early to be 0 from the previous line.
					m_cpu->exec(456-80);
					regs.LY=153;
				}
				else
					m_cpu->exec(456);
			}
			else{ // VBlank 期間外 // Period outside VBlank
				regs.STAT|=2;
				if (regs.STAT&0x20)
					m_cpu->irq(INT_LCDC);
				m_cpu->exec(80); // state=2
				regs.STAT|=3;
				m_cpu->exec(169); // state=3

				if (m_cpu->dma_executing){ // HBlank DMA
					if (m_cpu->b_dma_first){
						m_cpu->dma_dest_bank=m_cpu->vram_bank;
						if (m_cpu->dma_src<0x4000)
							m_cpu->dma_src_bank=m_rom->get_rom();
						else if (m_cpu->dma_src<0x8000)
							m_cpu->dma_src_bank=m_mbc->get_rom();
						else if (m_cpu->dma_src>=0xA000&&m_cpu->dma_src<0xC000)
							m_cpu->dma_src_bank=m_mbc->get_sram()-0xA000;
						else if (m_cpu->dma_src>=0xC000&&m_cpu->dma_src<0xD000)
							m_cpu->dma_src_bank=m_cpu->ram-0xC000;
						else if (m_cpu->dma_src>=0xD000&&m_cpu->dma_src<0xE000)
							m_cpu->dma_src_bank=m_cpu->ram_bank-0xD000;
						else m_cpu->dma_src_bank=NULL;
						m_cpu->b_dma_first=false;
					}
					memcpy(m_cpu->dma_dest_bank+(m_cpu->dma_dest&0x1ff0),m_cpu->dma_src_bank+m_cpu->dma_src,16);
//					fprintf(m_cpu->file,"%03d : dma exec %04X -> %04X rest %d\n",regs.LY,m_cpu->dma_src,m_cpu->dma_dest,m_cpu->dma_rest);

					m_cpu->dma_src+=16;
					m_cpu->dma_src&=0xfff0;
					m_cpu->dma_dest+=16;
					m_cpu->dma_dest&=0xfff0;
					m_cpu->dma_rest--;
					if (!m_cpu->dma_rest)
						m_cpu->dma_executing=false;

//					m_cpu->total_clock+=207*(m_cpu->speed?2:1);
//					m_cpu->sys_clock+=207*(m_cpu->speed?2:1);
//					m_cpu->div_clock+=207*(m_cpu->speed?2:1);
//					regs.STAT|=3;

					if (now_frame>=skip)
						m_lcd->render(vframe,regs.LY);

					regs.STAT&=0xfc;
					m_cpu->exec(207); // state=3
				}
				else{
/*					if (m_lcd->get_sprite_count()){
						if (m_lcd->get_sprite_count()>=10){
							m_cpu->exec(129);
							if ((regs.STAT&0x08))
								m_cpu->irq(INT_LCDC);
							regs.STAT&=0xfc;
							if (now_frame>=skip)
								m_lcd->render(vframe,regs.LY);
							m_cpu->exec(78); // state=0
						}
						else{
							m_cpu->exec(129*m_lcd->get_sprite_count()/10);
							if ((regs.STAT&0x08))
								m_cpu->irq(INT_LCDC);
							regs.STAT&=0xfc;
							if (now_frame>=skip)
								m_lcd->render(vframe,regs.LY);
							m_cpu->exec(207-(129*m_lcd->get_sprite_count()/10)); // state=0
						}
					}
					else{
*/						regs.STAT&=0xfc;
						if (now_frame>=skip)
							m_lcd->render(vframe,regs.LY);
						if ((regs.STAT&0x08))
							m_cpu->irq(INT_LCDC);
						m_cpu->exec(207); // state=0
//					}
				}
			}
		}
		else{ // LCDC 停止時 // LCDC is stopped
			regs.LY=0;
//			regs.LY=(regs.LY+1)%154;
			re_render++;
			if (re_render>=154){
				memset(vframe,0xff,160*144*2);
				m_renderer->refresh();
				if (now_frame>=skip){
					m_renderer->render_screen((byte*)vframe,160,144,16);
					now_frame=0;
				}
				else
					now_frame++;
				m_lcd->clear_win_count();
				re_render=0;
			}
			regs.STAT&=0xF8;
			m_cpu->exec(456);
		}
	}
}
