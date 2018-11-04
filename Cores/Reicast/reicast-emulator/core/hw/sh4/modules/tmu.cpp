/*
	Lovely timers, its amazing how many times this module was bugged
*/

#include "types.h"
#include "../sh4_sched.h"
#include "tmu.h"
#include "hw/sh4/sh4_interrupts.h"
#include "hw/sh4/sh4_mmr.h"


#define tmu_underflow 0x0100
#define tmu_UNIE      0x0020
/*
u32 tmu_prescaler[3];
u32 tmu_prescaler_shift[3];
u32 tmu_prescaler_mask[3];
*/

u32 tmu_shift[3];
u32 tmu_mask[3];
u64 tmu_mask64[3];

const u32 tmu_ch_bit[3]={1,2,4};

u32 old_mode[3] = {0xFFFF,0xFFFF,0xFFFF};

const InterruptID tmu_intID[3]={sh4_TMU0_TUNI0,sh4_TMU1_TUNI1,sh4_TMU2_TUNI2};
int tmu_sched[3];

#if 0
//Accurate counts for the channel ch
template<u32 ch>
void UpdateTMU_chan(u32 clc)
{
	//if channel is on
	//if ((TMU_TSTR & tmu_ch_bit[ch])!=0)
	//{
		//count :D
		tmu_prescaler[ch]+=clc;
		u32 steps=tmu_prescaler[ch]>>tmu_prescaler_shift[ch];
		
		//remove the full steps from the prescaler counter
		tmu_prescaler[ch]&=tmu_prescaler_mask[ch];

		if (unlikely(steps>TMU_TCNT(ch)))
		{
			//remove the 'extra' steps to overflow
			steps-=TMU_TCNT(ch);
			//refill the counter
			TMU_TCNT(ch) = TMU_TCOR(ch);
			//raise the interrupt
			TMU_TCR(ch) |= tmu_underflow;
			InterruptPend(tmu_intID[ch],1);
			
			//remove the full underflows (possible because we only check every 448 cycles)
			//this can be done with a div, but its very very very rare so this is probably faster
			//THIS can probably be replaced with a verify check on counter setup (haven't seen any game do this)
			while(steps>TMU_TCOR(ch))
				steps-=TMU_TCOR(ch);

			//steps now has the partial steps needed for update, guaranteed it won't cause an overflow
		}
		//count down
		TMU_TCNT(ch)-=steps;
	//}
}

template<u32 chans>
void UpdateTMU_i(u32 Cycles)
{
	if (chans & 1) UpdateTMU_chan<0>(Cycles);
	if (chans & 2) UpdateTMU_chan<1>(Cycles);
	if (chans & 4) UpdateTMU_chan<2>(Cycles);
}
#endif

u32 tmu_ch_base[3];
u64 tmu_ch_base64[3];

u32 read_TMU_TCNTch(u32 ch)
{
	return tmu_ch_base[ch] - ((sh4_sched_now64() >> tmu_shift[ch])&tmu_mask[ch]);
}

s64 read_TMU_TCNTch64(u32 ch)
{
	return tmu_ch_base64[ch] - ((sh4_sched_now64() >> tmu_shift[ch])&tmu_mask64[ch]);
}

void sched_chan_tick(int ch)
{
	//schedule next interrupt
	//return TMU_TCOR(ch) << tmu_shift[ch];

	u32 togo = read_TMU_TCNTch(ch);

	if (togo > SH4_MAIN_CLOCK)
		togo = SH4_MAIN_CLOCK;

	u32 cycles = togo << tmu_shift[ch];

	if (cycles > SH4_MAIN_CLOCK)
		cycles = SH4_MAIN_CLOCK;

	if (tmu_mask[ch])
		sh4_sched_request(tmu_sched[ch], cycles );
	else
		sh4_sched_request(tmu_sched[ch], -1);
	//sched_tmu_cb
}

void write_TMU_TCNTch(u32 ch, u32 data)
{
	//u32 TCNT=read_TMU_TCNTch(ch);
	tmu_ch_base[ch]=data+((sh4_sched_now64()>>tmu_shift[ch])&tmu_mask[ch]);
	tmu_ch_base64[ch] = data + ((sh4_sched_now64() >> tmu_shift[ch])&tmu_mask64[ch]);

	sched_chan_tick(ch);
}

template<u32 ch>
u32 read_TMU_TCNT(u32 addr)
{
	return read_TMU_TCNTch(ch);
}

template<u32 ch>
void write_TMU_TCNT(u32 addr, u32 data)
{
	write_TMU_TCNTch(ch,data);
}

void turn_on_off_ch(u32 ch, bool on)
{
	u32 TCNT=read_TMU_TCNTch(ch);
	tmu_mask[ch]=on?0xFFFFFFFF:0x00000000;
	tmu_mask64[ch] = on ? 0xFFFFFFFFFFFFFFFF : 0x0000000000000000;
	write_TMU_TCNTch(ch,TCNT);

	sched_chan_tick(ch);
}

//Update internal counter registers
void UpdateTMUCounts(u32 reg)
{
	InterruptPend(tmu_intID[reg],TMU_TCR(reg) & tmu_underflow);
	InterruptMask(tmu_intID[reg],TMU_TCR(reg) & tmu_UNIE);

	if (old_mode[reg]==(TMU_TCR(reg) & 0x7))
		return;
	else
		old_mode[reg]=(TMU_TCR(reg) & 0x7);

	u32 TCNT=read_TMU_TCNTch(reg);
	switch(TMU_TCR(reg) & 0x7)
	{
		case 0: //4
			tmu_shift[reg]=2;
			break;

		case 1: //16
			tmu_shift[reg]=4;
			break;

		case 2: //64
			tmu_shift[reg]=6;
			break;

		case 3: //256
			tmu_shift[reg]=8;
			break;

		case 4: //1024
			tmu_shift[reg]=10;
			break;

		case 5: //reserved
			printf("TMU ch%d - TCR%d mode is reserved (5)",reg,reg);
			break;

		case 6: //RTC
			printf("TMU ch%d - TCR%d mode is RTC (6), can't be used on Dreamcast",reg,reg);
			break;

		case 7: //external
			printf("TMU ch%d - TCR%d mode is External (7), can't be used on Dreamcast",reg,reg);
			break;
	}
	tmu_shift[reg]+=2;
	write_TMU_TCNTch(reg,TCNT);
	sched_chan_tick(reg);
}

//Write to status registers
template<int ch>
void TMU_TCR_write(u32 addr, u32 data)
{
	TMU_TCR(ch)=(u16)data;
	UpdateTMUCounts(ch);
}

//Chan 2 not used functions
u32 TMU_TCPR2_read(u32 addr)
{
	EMUERROR("Read from TMU_TCPR2 - this register should be not used on Dreamcast according to docs");
	return 0;
}

void TMU_TCPR2_write(u32 addr, u32 data)
{
	EMUERROR2("Write to TMU_TCPR2 - this register should be not used on Dreamcast according to docs, data=%d",data);
}

void write_TMU_TSTR(u32 addr, u32 data)
{
	TMU_TSTR=data;
	//?

	for (int i=0;i<3;i++)
		turn_on_off_ch(i,data&(1<<i));
}

int sched_tmu_cb(int ch, int sch_cycl, int jitter)
{
	if (tmu_mask[ch]) {
		
		u32 tcnt = read_TMU_TCNTch(ch);
		
		s64 tcnt64 = (s64)read_TMU_TCNTch64(ch);

		u32 tcor = TMU_TCOR(ch);

		u32 cycles = tcor << tmu_shift[ch];

		//64 bit maths to differentiate big values from overflows
		if (tcnt64 <= jitter) {
			//raise interrupt, timer counted down
			TMU_TCR(ch) |= tmu_underflow;
			InterruptPend(tmu_intID[ch], 1);
			
			//printf("Interrupt for %d, %d cycles\n", ch, sch_cycl);

			//schedule next trigger by writing the TCNT register
			write_TMU_TCNTch(ch, tcor + tcnt);
		}
		else {
			
			//schedule next trigger by writing the TCNT register
			write_TMU_TCNTch(ch, tcnt);
		}

		return 0;	//has already been scheduled by TCNT write
	}
	else {
		return 0;	//this channel is disabled, no need to schedule next event
	}
}

//Init/Res/Term
void tmu_init()
{
	//TMU TOCR 0xFFD80000 0x1FD80000 8 0x00 0x00 Held Held Pclk
	sh4_rio_reg(TMU,TMU_TOCR_addr,RIO_DATA,8);

	//TMU TSTR 0xFFD80004 0x1FD80004 8 0x00 0x00 Held 0x00 Pclk
	sh4_rio_reg(TMU,TMU_TSTR_addr,RIO_WF,8,0,&write_TMU_TSTR);

	//TMU TCOR0 0xFFD80008 0x1FD80008 32 0xFFFFFFFF 0xFFFFFFFF Held Held Pclk
	sh4_rio_reg(TMU,TMU_TCOR0_addr,RIO_DATA,32);

	//TMU TCNT0 0xFFD8000C 0x1FD8000C 32 0xFFFFFFFF 0xFFFFFFFF Held Held Pclk
	sh4_rio_reg(TMU,TMU_TCNT0_addr,RIO_FUNC,32,&read_TMU_TCNT<0>,&write_TMU_TCNT<0>);

	//TMU TCR0 0xFFD80010 0x1FD80010 16 0x0000 0x0000 Held Held Pclk
	sh4_rio_reg(TMU,TMU_TCR0_addr,RIO_WF,16,0,&TMU_TCR_write<0>);

	//TMU TCOR1 0xFFD80014 0x1FD80014 32 0xFFFFFFFF 0xFFFFFFFF Held Held Pclk
	sh4_rio_reg(TMU,TMU_TCOR1_addr,RIO_DATA,32);

	//TMU TCNT1 0xFFD80018 0x1FD80018 32 0xFFFFFFFF 0xFFFFFFFF Held Held Pclk
	sh4_rio_reg(TMU,TMU_TCNT1_addr,RIO_FUNC,32,&read_TMU_TCNT<1>,&write_TMU_TCNT<1>);

	//TMU TCR1 0xFFD8001C 0x1FD8001C 16 0x0000 0x0000 Held Held Pclk
	sh4_rio_reg(TMU,TMU_TCR1_addr,RIO_WF,16,0,&TMU_TCR_write<1>);

	//TMU TCOR2 0xFFD80020 0x1FD80020 32 0xFFFFFFFF 0xFFFFFFFF Held Held Pclk
	sh4_rio_reg(TMU,TMU_TCOR2_addr,RIO_DATA,32);

	//TMU TCNT2 0xFFD80024 0x1FD80024 32 0xFFFFFFFF 0xFFFFFFFF Held Held Pclk
	sh4_rio_reg(TMU,TMU_TCNT2_addr,RIO_FUNC,32,&read_TMU_TCNT<2>,&write_TMU_TCNT<2>);
	
	//TMU TCR2 0xFFD80028 0x1FD80028 16 0x0000 0x0000 Held Held Pclk
	sh4_rio_reg(TMU,TMU_TCR2_addr,RIO_WF,16,0,&TMU_TCR_write<2>);

	//TMU TCPR2 0xFFD8002C 0x1FD8002C 32 Held Held Held Held Pclk
	sh4_rio_reg(TMU,TMU_TCPR2_addr,RIO_FUNC,32,&TMU_TCPR2_read,&TMU_TCPR2_write);

	for (int i = 0; i < 3; i++) {
		tmu_sched[i] = sh4_sched_register(i, &sched_tmu_cb);
		sh4_sched_request(tmu_sched[i], -1);
	}
}


void tmu_reset()
{
	TMU_TOCR=TMU_TSTR=0;
	TMU_TCOR(0) = TMU_TCOR(1) = TMU_TCOR(2) = 0xffffffff;
//	TMU_TCNT(0) = TMU_TCNT(1) = TMU_TCNT(2) = 0xffffffff;
	TMU_TCR(0) = TMU_TCR(1) = TMU_TCR(2) = 0;

	UpdateTMUCounts(0);
	UpdateTMUCounts(1);
	UpdateTMUCounts(2);

	write_TMU_TSTR(0,0);

	for (int i=0;i<3;i++)
		write_TMU_TCNTch(i,0xffffffff);
}

void tmu_term()
{
}
