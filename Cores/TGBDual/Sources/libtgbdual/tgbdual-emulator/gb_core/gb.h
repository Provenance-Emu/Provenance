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
// GB クラス定義部,その他

#include <list>

#include "gb_types.h"
#include "renderer.h"
#include "serializer.h"

#define INT_VBLANK 1
#define INT_LCDC 2
#define INT_TIMER 4
#define INT_SERIAL 8
#define INT_PAD 16

class gb;
class cpu;
class lcd;
class apu;
class apu_snd;
class rom;
class mbc;
class cheat;

struct ext_hook{
	byte (*send)(byte);
	bool (*led)(void);
};

struct cheat_dat{
	bool enable;
	byte code;
	word adr;
	byte dat;
	char name[255];
	cheat_dat *next;
};

struct gb_regs {
	byte P1,SB,SC,DIV,TIMA,TMA,TAC,IF,LCDC,STAT,SCY,SCX,LY,LYC,DMA,BGP,OBP1,OBP2,WY,WX,IE;
};

struct gbc_regs {
	byte KEY1,VBK,HDMA1,HDMA2,HDMA3,HDMA4,HDMA5,RP,BCPS,BCPD,OCPS,OCPD,SVBK;
};

union pare_reg {
	word w;
	struct{byte l,h;}b;
};

struct cpu_regs {
	pare_reg AF;
	pare_reg BC;
	pare_reg DE;
	pare_reg HL;
	word SP;
	word PC;
	byte I;
};

struct apu_stat{
	bool sq1_playing;
	int sq1_sw_time;
	int sq1_sw_dir;
	int sq1_sw_shift;

	int sq1_len;
	int sq1_init_len;
	int sq1_type;

	int sq1_vol;
	int sq1_init_vol;
	int sq1_env_dir;
	int sq1_env_speed;

	int sq1_freq;
	int sq1_init_freq;

	int sq1_hold;


	bool sq2_playing;

	int sq2_len;
	int sq2_init_len;
	int sq2_type;

	int sq2_vol;
	int sq2_init_vol;
	int sq2_env_dir;
	int sq2_env_speed;

	int sq2_freq;
	int sq2_init_freq;

	int sq2_hold;


	bool wav_playing;
	int wav_vol;
	int wav_freq;
	int wav_init_freq;
	int wav_init_len;
	int wav_len;
	int wav_hold;


	bool noi_playing;
	int noi_len;
	int noi_init_len;

	int noi_vol;
	int noi_init_vol;
	int noi_env_dir;
	int noi_env_speed;

	int noi_freq;
	int noi_init_freq;
	int noi_hold;
	int noi_step;

	int master_enable;
	int ch_enable[4][2];
	int master_vol[2];
	int ch_on[4];
	int wav_enable;
};

struct apu_que {
	word adr;
	byte dat;
	int clock;
};

struct rom_info {
	char cart_name[18];
	int cart_type;
	byte rom_size;
	byte ram_size;

	bool check_sum;
	int gb_type;
};

class gb
{
friend class cpu;
public:
	gb(renderer *ref,bool b_lcd,bool b_apu);
	~gb();

	cpu *get_cpu() { return m_cpu; }
	lcd *get_lcd() { return m_lcd; }
	apu *get_apu() { return m_apu; }
	rom *get_rom() { return m_rom; }
	mbc *get_mbc() { return m_mbc; }
	renderer *get_renderer() { return m_renderer; }
	cheat *get_cheat() { return m_cheat; }
	gb *get_target() { return target; }
	gb_regs *get_regs() { return &regs; }
	gbc_regs *get_cregs() { return &c_regs; }

	void run();
	void reset();
	void set_skip(int frame);
	void set_use_gba(bool use) { use_gba=use; }
	bool load_rom(byte *buf,int size,byte *ram,int ram_size, bool persistent);

	void serialize(serializer &s);
	void serialize_firstrev(serializer &s);
	void serialize_legacy(serializer &s);

	size_t get_state_size(void);
	void save_state_mem(void *buf);
	void restore_state_mem(void *buf);

	void refresh_pal();

	void set_target(gb *tar) { target=tar; }

	void hook_extport(ext_hook *ext);
	void unhook_extport();

private:
	cpu *m_cpu;
	lcd *m_lcd;
	apu *m_apu;
	rom *m_rom;
	mbc *m_mbc;
	renderer *m_renderer;

	cheat *m_cheat;

	gb *target;

	gb_regs regs;
	gbc_regs c_regs;

	word dmy[160*5]; // vframe はみ出した時用
	word vframe[160*(144+100)];

	ext_hook hook_proc;

	int skip,skip_buf;
	int now_frame;
	int re_render;

	bool hook_ext;
	bool use_gba;
};

class cheat
{
public:
	cheat(gb *ref);
	~cheat();

	byte cheat_read(word adr);
	void cheat_write(word adr,byte dat);

	bool cheak_cheat(word adr);
	void create_cheat_map();

	void add_cheat(cheat_dat *dat);
	void delete_cheat(char *name);
	std::list<cheat_dat>::iterator find_cheat(char *name);
	void create_unique_name(char *buf);

	void clear();

	std::list<cheat_dat>::iterator get_first() { return cheat_list.begin(); }
	std::list<cheat_dat>::iterator get_end() { return cheat_list.end(); }

	int *get_cheat_map() { return cheat_map; }

private:
	std::list<cheat_dat> cheat_list;
	int cheat_map[0x10000];

	gb *ref_gb;
};

class lcd
{
public:
	lcd(gb *ref);
	~lcd();

	void render(void *buf,int scanline);
	void reset();
	void clear_win_count() { now_win_line=9; }
	word *get_pal(int num) { return col_pal[num]; }
	word *get_mapped_pal(int num) { return mapped_pal[num]; }

	void set_enable(int layer,bool enable);
	bool get_enable(int layer);

	int get_sprite_count() { return sprite_count; };

	void serialize(serializer &s);
private:
	void bg_render(void *buf,int scanline);
	void win_render(void *buf,int scanline);
	void sprite_render(void *buf,int scanline);
	void bg_render_color(void *buf,int scanline);
	void win_render_color(void *buf,int scanline);
	void sprite_render_color(void *buf,int scanline);

	word m_pal16[4];
	dword m_pal32[4];
	word col_pal[16][4];
	word mapped_pal[16][4];

	int trans_count;
	byte trans_tbl[160+160],priority_tbl[320];

	int now_win_line;
	int mul;
	int sprite_count;

	bool layer_enable[3];

	gb *ref_gb;
};

class apu
{
friend class apu_snd;
public:
	apu(gb *ref);
	~apu();

	apu_snd *get_renderer() { return snd; }
	apu_stat *get_stat();
	apu_stat *get_stat_cpy();
	byte *get_mem();

	byte read(word adr);
	void write(word adr,byte dat,int clock);

	void update();
	void reset();

	void serialize(serializer &s);
private:
	gb *ref_gb;
	apu_snd *snd;
};

class apu_snd : public sound_renderer
{
friend class apu;
public:
	apu_snd(apu *papu);
	~apu_snd();

	void set_enable(int ch,bool enable);
	bool get_enable(int ch);
	void set_echo(bool echo){ b_echo=echo; };
	void set_lowpass(bool lowpass){ b_lowpass=lowpass; };
	bool get_echo(){ return b_echo; };
	bool get_lowpass(){ return b_lowpass; };


	void render(short *buf,int sample);
	void reset();

	void serialize(serializer &s);
private:
	void process(word adr,byte dat);
	void update();
	short sq1_produce(int freq);
	short sq2_produce(int freq);
	short wav_produce(int freq,bool interpolation);
	short noi_produce(int freq);

	apu_stat stat;
	apu_stat stat_cpy,stat_tmp;
	apu_que write_que[0x10000];
	int que_count;
	int bef_clock;
	apu *ref_apu;

	bool b_echo;
	bool b_lowpass;

	byte mem[0x100];
	bool b_enable[4];
};

class mbc
{
public:
	mbc(gb *ref);
	~mbc();

	byte *get_rom() { return rom_page; }
	byte *get_sram() { return sram_page; }
	bool is_ext_ram() { return ext_is_ram; }
	void set_ext_is(bool ext) { ext_is_ram=ext; }

	int get_state();
	void set_state(int dat);
	void set_page(int rom,int sram);

	byte read(word adr);
	void write(word adr,byte dat);
	byte ext_read(word adr);
	void ext_write(word adr,byte dat);
	void reset();

	void serialize(serializer &s);
private:
	void mbc1_write(word adr,byte dat);
	void mbc2_write(word adr,byte dat);
	void mbc3_write(word adr,byte dat);
	void mbc5_write(word adr,byte dat);
	void mbc7_write(word adr,byte dat);
	void huc1_write(word adr,byte dat);
	void huc3_write(word adr,byte dat);
	void tama5_write(word adr,byte dat);
	void mmm01_write(word adr,byte dat);

	byte *rom_page;
	byte *sram_page;

	bool mbc1_16_8;
	byte mbc1_dat;

	byte mbc3_latch; // 1 bits
	byte mbc3_sec; // 6
	byte mbc3_min; // 6
	byte mbc3_hour; // 5
	byte mbc3_dayl; // 8
	byte mbc3_dayh; // 1

	byte mbc3_timer; // 4
	bool ext_is_ram; // 1
	// total 32bits

	int mbc5_dat;

	bool mbc7_write_enable;
	bool mbc7_idle;
	byte mbc7_cs;
	byte mbc7_sk;
	byte mbc7_op_code;
	byte mbc7_adr;
	word mbc7_dat;
	byte mbc7_ret;
	byte mbc7_state;
	word mbc7_buf;
	byte mbc7_count;

	bool huc1_16_8;
	byte huc1_dat;

	gb *ref_gb;
};

class rom
{
public:
	rom();
	~rom();

	rom_info *get_info() { return &info; }
	byte *get_rom() { return first_page; }
	byte *get_sram() { return sram; }
	bool get_loaded() { return b_loaded; }

	bool has_battery();
	int get_sram_size(); // byte単位

	void set_first(int page) { first_page=dat+0x4000*page; }

	bool load_rom(byte *buf,int size,byte *ram,int ram_size, bool persistent);

	void serialize(serializer &s);
private:
	rom_info info;

	byte *dat;
	byte *sram;

	byte *first_page;

	bool b_loaded;
   bool b_persistent;
};

class cpu
{
friend class gb;
public:
	cpu(gb *ref);
	~cpu();

	byte read(word adr) { return (ref_gb->get_cheat()->get_cheat_map()[adr])?ref_gb->get_cheat()->cheat_read(adr):read_direct(adr); }

	byte read_direct(word adr);
	void write(word adr,byte dat);
	word inline readw(word adr) { return read(adr)|(read(adr+1)<<8); }
	void inline writew(word adr,word dat) { write(adr,(byte)dat);write(adr+1,dat>>8); }

	void exec(int clocks);
	byte seri_send(byte dat);
	void irq(int irq_type);
	void inline irq_process();
	void reset();
	void set_trace(bool trace) { b_trace=trace; }

	byte *get_vram() { return vram; }
	byte *get_ram() { return ram; }
	byte *get_oam() { return oam; }
	byte *get_stack() { return stack; }

	byte *get_ram_bank() { return ram_bank; }
	void set_ram_bank(int bank) { ram_bank=ram+bank*0x1000; }

	cpu_regs *get_regs() { return &regs; }

	int get_clock() { return total_clock; }
	bool get_speed() { return speed; }

	bool *get_halt() { return &halt; }

	void save_state(int *dat);
	void restore_state(int *dat);
	void save_state_ex(int *dat);
	void restore_state_ex(int *dat);

	void serialize(serializer &s);
private:
	byte inline io_read(word adr);
	void inline io_write(word adr,byte dat);
	byte op_read() { return read(regs.PC++); }
	word op_readw() { regs.PC+=2;return readw(regs.PC-2); }

	int dasm(char *S,byte *A);
	void log();

	gb *ref_gb;
	cpu_regs regs;

	byte ram[0x2000*4];
	byte vram[0x2000*2];
	byte stack[0x80];
	byte oam[0xA0];
	byte spare_oam[0x18];
	byte ext_mem[16];

	byte *vram_bank;
	byte *ram_bank;

	byte z802gb[256],gb2z80[256];
	dword rp_que[256];
	int que_cur;
//	word org_pal[16][4];
	int total_clock,rest_clock,sys_clock,seri_occer,div_clock;
	bool halt,speed,speed_change,dma_executing;
	bool b_trace;
	int dma_src;
	int dma_dest;
	int dma_rest;
	int gdma_rest;
	bool b_dma_first;

	int last_int;
	bool int_desable;

	byte *dma_src_bank;
	byte *dma_dest_bank;

	byte _ff6c,_ff72,_ff73,_ff74,_ff75;
};
