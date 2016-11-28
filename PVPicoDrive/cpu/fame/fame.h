/*****************************************************************************/
/* FAME Fast and Accurate Motorola 68000 Emulation Core                      */
/* (c) 2005 Oscar Orallo Pelaez                                              */
/* Version: 1.24                                                             */
/* Date: 08-20-2005                                                          */
/* See FAME.HTML for documentation and license information                   */
/*****************************************************************************/

#ifndef __FAME_H__
#define __FAME_H__

#ifdef __cplusplus
extern "C" {
#endif

// PicoDrive hacks
#define FAMEC_FETCHBITS 8
#define M68K_FETCHBANK1 (1 << FAMEC_FETCHBITS)

//#define M68K_RUNNING    0x01
#define FM68K_HALTED     0x80
//#define M68K_WAITING    0x04
//#define M68K_DISABLE    0x20
//#define M68K_FAULTED    0x40
#define FM68K_EMULATE_GROUP_0  0x02
#define FM68K_EMULATE_TRACE    0x08
#define FM68K_DO_TRACE    0x10


/************************************/
/* General library defines          */
/************************************/

#ifndef M68K_OK
    #define M68K_OK 0
#endif
#ifndef M68K_RUNNING
    #define M68K_RUNNING 1
#endif
#ifndef M68K_NO_SUP_ADDR_SPACE
    #define M68K_NO_SUP_ADDR_SPACE 2
#endif
#ifndef M68K_DOUBLE_BUS_FAULT
    #define M68K_DOUBLE_BUS_FAULT -1
#endif
#ifndef M68K_INV_REG
    #define M68K_INV_REG -1
#endif

/* Hardware interrupt state */

#ifndef M68K_IRQ_LEVEL_ERROR
    #define M68K_IRQ_LEVEL_ERROR -1
#endif
#ifndef M68K_IRQ_INV_PARAMS
    #define M68K_IRQ_INV_PARAMS -2
#endif

/* Defines to specify hardware interrupt type */

#ifndef M68K_AUTOVECTORED_IRQ
    #define M68K_AUTOVECTORED_IRQ -1
#endif
#ifndef M68K_SPURIOUS_IRQ
    #define M68K_SPURIOUS_IRQ -2
#endif

#ifndef M68K_AUTO_LOWER_IRQ
	#define M68K_AUTO_LOWER_IRQ 1
#endif
#ifndef M68K_MANUAL_LOWER_IRQ
	#define M68K_MANUAL_LOWER_IRQ 0
#endif

/* Defines to specify address space */

#ifndef M68K_SUP_ADDR_SPACE
    #define M68K_SUP_ADDR_SPACE 0
#endif
#ifndef M68K_USER_ADDR_SPACE
    #define M68K_USER_ADDR_SPACE 2
#endif
#ifndef M68K_PROG_ADDR_SPACE
    #define M68K_PROG_ADDR_SPACE 0
#endif
#ifndef M68K_DATA_ADDR_SPACE
    #define M68K_DATA_ADDR_SPACE 1
#endif


/*******************/
/* Data definition */
/*******************/

typedef union
{
	unsigned char B;
	signed char SB;
	unsigned short W;
	signed short SW;
	unsigned int D;
	signed int SD;
} famec_union32;

/* M68K CPU CONTEXT */
typedef struct
{
	unsigned int   (*read_byte )(unsigned int a);
	unsigned int   (*read_word )(unsigned int a);
	unsigned int   (*read_long )(unsigned int a);
	void           (*write_byte)(unsigned int a,unsigned char  d);
	void           (*write_word)(unsigned int a,unsigned short d);
	void           (*write_long)(unsigned int a,unsigned int   d);
	void           (*reset_handler)(void);
	void           (*iack_handler)(unsigned level);
	famec_union32  dreg[8];
	famec_union32  areg[8];
	unsigned       asp;
	unsigned       pc;
	unsigned char  interrupts[8];
	unsigned short sr;
	unsigned short execinfo;
	// PD extension
	int            io_cycle_counter; // cycles left

	unsigned int   Opcode;
	signed int     cycles_needed;

	unsigned short *PC;
	unsigned long  BasePC;
	unsigned int   flag_C;
	unsigned int   flag_V;
	unsigned int   flag_NotZ;
	unsigned int   flag_N;
	unsigned int   flag_X;
	unsigned int   flag_T;
	unsigned int   flag_S;
	unsigned int   flag_I;

	unsigned char  not_polling;
	unsigned char  pad[3];

	unsigned long  Fetch[M68K_FETCHBANK1];
} M68K_CONTEXT;

extern M68K_CONTEXT *g_m68kcontext;

/************************/
/* Function definition  */
/************************/

/* General purpose functions */
void fm68k_init(void);
int  fm68k_reset(void);
int  fm68k_emulate(int n, int idle_mode);
int  fm68k_would_interrupt(void); // to be called from fm68k_emulate()

unsigned fm68k_get_pc(M68K_CONTEXT *context);


#ifdef __cplusplus
}
#endif

#endif
