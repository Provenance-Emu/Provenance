#include "spg.h"
#include "Renderer_if.h"
#include "pvr_regs.h"
#include "hw/holly/holly_intc.h"
#include "oslib/oslib.h"
#include "hw/sh4/sh4_sched.h"

//SPG emulation; Scanline/Raster beam registers & interrupts
//Time to emulate that stuff correctly ;)

u32 in_vblank=0;
u32 clc_pvr_scanline;
u32 pvr_numscanlines=512;
u32 prv_cur_scanline=-1;
u32 vblk_cnt=0;

float last_fps=0;

//54 mhz pixel clock :)
#define PIXEL_CLOCK (54*1000*1000/2)
u32 Line_Cycles=0;
u32 Frame_Cycles=0;
int render_end_schid;
int vblank_schid;
int time_sync;

void CalculateSync()
{
	u32 pixel_clock;
	float scale_x=1,scale_y=1;

	pixel_clock=PIXEL_CLOCK / (FB_R_CTRL.vclk_div?1:2);

	//We need to calculate the pixel clock

	u32 sync_cycles=(SPG_LOAD.hcount+1)*(SPG_LOAD.vcount+1);
	pvr_numscanlines=SPG_LOAD.vcount+1;
	
	Line_Cycles=(u32)((u64)SH4_MAIN_CLOCK*(u64)(SPG_LOAD.hcount+1)/(u64)pixel_clock);
	
	if (SPG_CONTROL.interlace)
	{
		//this is a temp hack
		Line_Cycles/=2;
		u32 interl_mode=VO_CONTROL.field_mode;
		
		//if (interl_mode==2)//3 will be funny =P
		//  scale_y=0.5f;//single interlace
		//else
			scale_y=1;
	}
	else
	{
		if (FB_R_CTRL.vclk_div)
		{
			scale_y = 1.0f;//non interlaced VGA mode has full resolution :)
		}
		else
		{
			scale_y = 0.5f;//non interlaced modes have half resolution
		}
	}

	rend_set_fb_scale(scale_x,scale_y);
	
	//Frame_Cycles=(u64)DCclock*(u64)sync_cycles/(u64)pixel_clock;
	
	Frame_Cycles=pvr_numscanlines*Line_Cycles;
	prv_cur_scanline=0;

	sh4_sched_request(vblank_schid,Line_Cycles);
}

void os_wait_cycl(u32 c);

int elapse_time(int tag, int cycl, int jit)
{
#if HOST_OS==OS_WINDOWS
	//os_wait_cycl(cycl);
#endif
	return min(max(Frame_Cycles,(u32)1*1000*1000),(u32)8*1000*1000);
}
#if HOST_OS==OS_WINDOWS
extern double speed_load_mspdf;
#else
double speed_load_mspdf;
#endif

int mips_counter;

double full_rps;

u32 fskip=0;
//called from sh4 context , should update pvr/ta state and everything else
int spg_line_sched(int tag, int cycl, int jit)
{
	clc_pvr_scanline += cycl;

	while (clc_pvr_scanline >=  Line_Cycles)//60 ~hertz = 200 mhz / 60=3333333.333 cycles per screen refresh
	{
		//ok .. here , after much effort , we did one line
		//now , we must check for raster beam interrupts and vblank
		prv_cur_scanline=(prv_cur_scanline+1)%pvr_numscanlines;
		clc_pvr_scanline -= Line_Cycles;
		//Check for scanline interrupts -- really need to test the scanline values
		
		if (SPG_VBLANK_INT.vblank_in_interrupt_line_number == prv_cur_scanline)
			asic_RaiseInterrupt(holly_SCANINT1);

		if (SPG_VBLANK_INT.vblank_out_interrupt_line_number == prv_cur_scanline)
			asic_RaiseInterrupt(holly_SCANINT2);

		if (SPG_VBLANK.vstart == prv_cur_scanline)
			in_vblank=1;

		if (SPG_VBLANK.vbend == prv_cur_scanline)
			in_vblank=0;

		SPG_STATUS.vsync=in_vblank;
		SPG_STATUS.scanline=prv_cur_scanline;
		
		//Vblank start -- really need to test the scanline values
		if (prv_cur_scanline==0)
		{
			if (SPG_CONTROL.interlace)
				SPG_STATUS.fieldnum=~SPG_STATUS.fieldnum;
			else
				SPG_STATUS.fieldnum=0;

			//Vblank counter
			vblk_cnt++;
			asic_RaiseInterrupt(holly_HBLank);// -> This turned out to be HBlank btw , needs to be emulated ;(
			//TODO : rend_if_VBlank();
			rend_vblank();//notify for vblank :)
			
			if ((os_GetSeconds()-last_fps)>2)
			{
				static int Last_FC;
				double ts=os_GetSeconds()-last_fps;
				double spd_fps=(FrameCount-Last_FC)/ts;
				double spd_vbs=vblk_cnt/ts;
				double spd_cpu=spd_vbs*Frame_Cycles;
				spd_cpu/=1000000;	//mrhz kthx
				double fullvbs=(spd_vbs/spd_cpu)*200;
				double mv=VertexCount/ts/(spd_cpu/200);
				char mv_c=' ';

				Last_FC=FrameCount;

				if (mv>750)
				{
					mv/=1000;	//KV
					mv_c='K';
				}
				if (mv>750)
				{
					mv/=1000;	//
					mv_c='M';
				}
				VertexCount=0;
				vblk_cnt=0;

				char fpsStr[256];
				const char* mode=0;
				const char* res=0;

				res=SPG_CONTROL.interlace?"480i":"240p";

				if (SPG_CONTROL.NTSC==0 && SPG_CONTROL.PAL==1)
					mode="PAL";
				else if (SPG_CONTROL.NTSC==1 && SPG_CONTROL.PAL==0)
					mode="NTSC";
				else
				{
					res=SPG_CONTROL.interlace?"480i":"480p";
					mode="VGA";
				}

				double frames_done=spd_cpu/2;
				double mspdf=1/frames_done*1000;

				full_rps=(spd_fps+fskip/ts);

				#ifdef TARGET_PANDORA
				sprintf(fpsStr,"CPU: %4.2f V: %4.2f (%s%s%4.2f) R: %4.2f+%4.2f", 
					spd_cpu*100/200,spd_vbs,
					mode,res,fullvbs,
					spd_fps,fskip/ts);
				#else
				sprintf(fpsStr,"%s/%c - %4.2f (%4.2f) - %4.2f - V: %4.2f (%.2f, %s%s%4.2f) R: %4.2f+%4.2f VTX: %4.2f%c, MIPS: %.2f", 
					VER_SHORTNAME,'n',mspdf,speed_load_mspdf,spd_cpu*100/200,spd_vbs,
					spd_vbs/full_rps,mode,res,fullvbs,
					spd_fps,fskip/ts
					, mv, mv_c, mips_counter/ 1024.0 / 1024.0);
					mips_counter = 0;
				#endif
				
				fskip=0;
				os_SetWindowText(fpsStr);

				last_fps=os_GetSeconds();
			}
		}
	}

	//interrupts
	//0
	//vblank_in_interrupt_line_number
	//vblank_out_interrupt_line_number
	//vstart
	//vbend
	//pvr_numscanlines
	u32 min_scanline=prv_cur_scanline+1;
	u32 min_active=pvr_numscanlines;

	if (min_scanline<SPG_VBLANK_INT.vblank_in_interrupt_line_number)
		min_active=min(min_active,SPG_VBLANK_INT.vblank_in_interrupt_line_number);

	if (min_scanline<SPG_VBLANK_INT.vblank_out_interrupt_line_number)
		min_active=min(min_active,SPG_VBLANK_INT.vblank_out_interrupt_line_number);

	if (min_scanline<SPG_VBLANK.vstart)
		min_active=min(min_active,SPG_VBLANK.vstart);

	if (min_scanline<SPG_VBLANK.vbend)
		min_active=min(min_active,SPG_VBLANK.vbend);

	if (min_scanline<pvr_numscanlines)
		min_active=min(min_active,pvr_numscanlines);

	min_active=max(min_active,min_scanline);

	return (min_active-prv_cur_scanline)*Line_Cycles;
}

int rend_end_sch(int tag, int cycl, int jitt)
{
	asic_RaiseInterrupt(holly_RENDER_DONE);
	asic_RaiseInterrupt(holly_RENDER_DONE_isp);
	asic_RaiseInterrupt(holly_RENDER_DONE_vd);
	rend_end_render();
	return 0;
}

bool spg_Init()
{
	render_end_schid=sh4_sched_register(0,&rend_end_sch);
	vblank_schid=sh4_sched_register(0,&spg_line_sched);
	time_sync=sh4_sched_register(0,&elapse_time);

	sh4_sched_request(time_sync,8*1000*1000);

	return true;
}

void spg_Term()
{
}

void spg_Reset(bool Manual)
{
	CalculateSync();
}


extern u32 PVR_VTXC;

void SetREP(TA_context* cntx)
{
	if (cntx && !cntx->rend.Overrun)
	{
		VertexCount+= cntx->rend.verts.used();
		PVR_VTXC+= cntx->rend.verts.used();
		int render_end_pending_cycles= cntx->rend.verts.used()*60;
		//if (render_end_pending_cycles<500000)
		render_end_pending_cycles+=500000*3;

		sh4_sched_request(render_end_schid,render_end_pending_cycles);
	}
	else
	{
		sh4_sched_request(render_end_schid, 4096);
	}
}