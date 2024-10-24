#include <stdlib.h>
#include <string.h>

#include "e6809.h"
#include "vecx.h"
#include "osint.h"
#include "e8910.h"

#define einline __inline

#define BS_0 0
#define BS_1 1
#define BS_2 2
#define BS_3 3
#define BS_4 4
#define BS_5 5

enum
{
   VECTREX_PDECAY	 = 30,      /* phosphor decay rate */

   /* number of 6809 cycles before a frame redraw */

   FCYCLES_INIT    = VECTREX_MHZ / VECTREX_PDECAY,

   /* max number of possible vectors that maybe on the screen at one time.
    * one only needs VECTREX_MHZ / VECTREX_PDECAY but we need to also store
    * deleted vectors in a single table
    */

   VECTOR_CNT		 = VECTREX_MHZ / VECTREX_PDECAY,

   VECTOR_HASH     = 65521
};


unsigned char rom[8192];
unsigned char cart[65536];
unsigned char vecx_ram[1024];

unsigned newbankswitchOffset = 0;
unsigned bankswitchOffset    = 0;
char big                     = 0;

unsigned bankswitchstate = BS_0;

/* the via 6522 registers */

static unsigned via_ora;
static unsigned via_orb;
static unsigned via_ddra;
static unsigned via_ddrb;
static unsigned via_t1on;  /* is timer 1 on? */
static unsigned via_t1int; /* are timer 1 interrupts allowed? */
static unsigned via_t1c;
static unsigned via_t1ll;
static unsigned via_t1lh;
static unsigned via_t1pb7; /* timer 1 controlled version of pb7 */
static unsigned via_t2on;  /* is timer 2 on? */
static unsigned via_t2int; /* are timer 2 interrupts allowed? */
static unsigned via_t2c;
static unsigned via_t2ll;
static unsigned via_sr;
static unsigned via_srb;   /* number of bits shifted so far */
static unsigned via_src;   /* shift counter */
static unsigned via_srclk;
static unsigned via_acr;
static unsigned via_pcr;
static unsigned via_ifr;
static unsigned via_ier;
static unsigned via_ca2;
static unsigned via_cb2h;  /* basic handshake version of cb2 */
static unsigned via_cb2s;  /* version of cb2 controlled by the shift register */

/* analog devices */

static unsigned alg_rsh;  /* zero ref sample and hold */
static unsigned alg_xsh;  /* x sample and hold */
static unsigned alg_ysh;  /* y sample and hold */
static unsigned alg_zsh;  /* z sample and hold */
unsigned alg_jch0;		  /* joystick direction channel 0 */
unsigned alg_jch1;		  /* joystick direction channel 1 */
unsigned alg_jch2;		  /* joystick direction channel 2 */
unsigned alg_jch3;		  /* joystick direction channel 3 */
static unsigned alg_jsh;  /* joystick sample and hold */

static unsigned alg_compare;

static long alg_dx;     /* delta x */
static long alg_dy;     /* delta y */
static long alg_curr_x; /* current x position */
static long alg_curr_y; /* current y position */

static unsigned alg_vectoring; /* are we drawing a vector right now? */
static long alg_vector_x0;
static long alg_vector_y0;
static long alg_vector_x1;
static long alg_vector_y1;
static long alg_vector_dx;
static long alg_vector_dy;
static unsigned char alg_vector_color;

long vector_draw_cnt;
long vector_erse_cnt;
static vector_t vectors_set[2 * VECTOR_CNT];
vector_t *vectors_draw;
vector_t *vectors_erse;

static long vector_hash[VECTOR_HASH];

static long fcycles;

static unsigned snd_select;
unsigned snd_regs[16];

unsigned char get_cart(unsigned pos)
{
   return cart[ (pos + bankswitchOffset) % 65536];
}

void set_cart(unsigned pos, unsigned char data)
{
   if(pos == 32768 && data != 0) // 64k carts should have data at this offset
      big = 1;
   cart[(pos)%65536] = data; 
}

int vecx_statesz(void)
{
   return 1025 + (sizeof(unsigned) * 37) + (sizeof(long) * 12) +
      e6809_statesz() + e8910_statesz();
}

/* hide all the ugly at the bottom.
 * usual bit of tedium, should really do htons as well,
 * along with the usual reinventing of C99 stdint */
int vecx_serialize(char* dst, int size)
{
   if (size < vecx_statesz())
      return 0;

   e6809_serialize(dst);
   dst += e6809_statesz();
   e8910_serialize(dst);
   dst += e8910_statesz();

   memcpy(dst, vecx_ram, 1024);
   dst += 1024;

   memcpy(dst, &snd_select, sizeof(int));
   dst += sizeof(int); 
   memcpy(dst, &via_ora,    sizeof(int));
   dst += sizeof(int);
   memcpy(dst, &via_orb,    sizeof(int));
   dst += sizeof(int);
   memcpy(dst, &via_ddra,   sizeof(int));
   dst += sizeof(int);
   memcpy(dst, &via_ddrb,   sizeof(int));
   dst += sizeof(int);
   memcpy(dst, &via_t1on,   sizeof(int));
   dst += sizeof(int);
   memcpy(dst, &via_t1int,  sizeof(int));
   dst += sizeof(int);
   memcpy(dst, &via_t1c,    sizeof(int));
   dst += sizeof(int);
   memcpy(dst, &via_t1ll,   sizeof(int)); dst += sizeof(int);
   memcpy(dst, &via_t1lh,   sizeof(int)); dst += sizeof(int);
   memcpy(dst, &via_t1pb7,  sizeof(int)); dst += sizeof(int);
   memcpy(dst, &via_t2on,   sizeof(int)); dst += sizeof(int);
   memcpy(dst, &via_t2int,  sizeof(int)); dst += sizeof(int);
   memcpy(dst, &via_t2c,    sizeof(int)); dst += sizeof(int);
   memcpy(dst, &via_t2ll,   sizeof(int)); dst += sizeof(int);
   memcpy(dst, &via_t2ll,   sizeof(int)); dst += sizeof(int);
   memcpy(dst, &via_sr,     sizeof(int)); dst += sizeof(int);
   memcpy(dst, &via_srb,    sizeof(int)); dst += sizeof(int);
   memcpy(dst, &via_src,    sizeof(int)); dst += sizeof(int);
   memcpy(dst, &via_srclk,  sizeof(int)); dst += sizeof(int);
   memcpy(dst, &via_acr,    sizeof(int)); dst += sizeof(int);
   memcpy(dst, &via_pcr,    sizeof(int)); dst += sizeof(int);
   memcpy(dst, &via_ifr,    sizeof(int)); dst += sizeof(int);
   memcpy(dst, &via_ier,    sizeof(int)); dst += sizeof(int);
   memcpy(dst, &via_ca2,    sizeof(int)); dst += sizeof(int);
   memcpy(dst, &via_cb2h,   sizeof(int)); dst += sizeof(int);
   memcpy(dst, &via_cb2s,   sizeof(int)); dst += sizeof(int);
   memcpy(dst, &alg_rsh,    sizeof(int)); dst += sizeof(int);
   memcpy(dst, &alg_rsh,    sizeof(int)); dst += sizeof(int);
   memcpy(dst, &alg_xsh,    sizeof(int)); dst += sizeof(int);
   memcpy(dst, &alg_ysh,    sizeof(int)); dst += sizeof(int);
   memcpy(dst, &alg_zsh,    sizeof(int)); dst += sizeof(int);
   memcpy(dst, &alg_jch0,   sizeof(int)); dst += sizeof(int);
   memcpy(dst, &alg_jch1,   sizeof(int)); dst += sizeof(int);
   memcpy(dst, &alg_jch2,   sizeof(int)); dst += sizeof(int);
   memcpy(dst, &alg_jch3,   sizeof(int)); dst += sizeof(int);
   memcpy(dst, &alg_jsh,    sizeof(int)); dst += sizeof(int);
   memcpy(dst, &alg_compare, sizeof(int)); dst += sizeof(int);
   memcpy(dst, &alg_vectoring, sizeof(int)); dst += sizeof(int);
   memcpy(dst, &alg_curr_x,    sizeof(long)); dst += sizeof(long);
   memcpy(dst, &alg_curr_y,    sizeof(long)); dst += sizeof(long);
   memcpy(dst, &alg_vector_x0, sizeof(long)); dst += sizeof(long);
   memcpy(dst, &alg_vector_y0, sizeof(long)); dst += sizeof(long);
   memcpy(dst, &alg_vector_x1, sizeof(long)); dst += sizeof(long);
   memcpy(dst, &alg_vector_y1, sizeof(long)); dst += sizeof(long);
   memcpy(dst, &alg_vector_dx, sizeof(long)); dst += sizeof(long);
   memcpy(dst, &alg_vector_dy, sizeof(long)); dst += sizeof(long);
   memcpy(dst, &vector_draw_cnt, sizeof(long)); dst += sizeof(long);
   memcpy(dst, &vector_erse_cnt, sizeof(long)); dst += sizeof(long);
   *dst = alg_vector_color;

   return 1;
}

int vecx_deserialize(char* dst, int size)
{
   if (size < vecx_statesz())
      return 0;

   e6809_deserialize(dst);
   dst += e6809_statesz();
   e8910_deserialize(dst);
   dst += e8910_statesz();

   memcpy(vecx_ram, dst, 1024);
   dst += 1024;

   memcpy(&snd_select,dst,  sizeof(int));
   dst += sizeof(int);
   memcpy(&via_ora,   dst,  sizeof(int));
   dst += sizeof(int);
   memcpy(&via_orb,   dst,  sizeof(int)); dst += sizeof(int);
   memcpy(&via_ddra,  dst,  sizeof(int)); dst += sizeof(int);
   memcpy(&via_ddrb,  dst,  sizeof(int)); dst += sizeof(int);
   memcpy(&via_t1on,  dst,  sizeof(int)); dst += sizeof(int);
   memcpy(&via_t1int, dst,  sizeof(int)); dst += sizeof(int);
   memcpy(&via_t1c,   dst,  sizeof(int)); dst += sizeof(int);
   memcpy(&via_t1ll,  dst,  sizeof(int)); dst += sizeof(int);
   memcpy(&via_t1lh,  dst,  sizeof(int)); dst += sizeof(int);
   memcpy(&via_t1pb7, dst,  sizeof(int)); dst += sizeof(int);
   memcpy(&via_t2on,  dst,  sizeof(int)); dst += sizeof(int);
   memcpy(&via_t2int, dst,  sizeof(int)); dst += sizeof(int);
   memcpy(&via_t2c,   dst,  sizeof(int)); dst += sizeof(int);
   memcpy(&via_t2ll,  dst,  sizeof(int)); dst += sizeof(int);
   memcpy(&via_t2ll,  dst,  sizeof(int)); dst += sizeof(int);
   memcpy(&via_sr,    dst,  sizeof(int)); dst += sizeof(int);
   memcpy(&via_srb,   dst,  sizeof(int)); dst += sizeof(int);
   memcpy(&via_src,   dst,  sizeof(int)); dst += sizeof(int);
   memcpy(&via_srclk, dst,  sizeof(int)); dst += sizeof(int);
   memcpy(&via_acr,   dst,  sizeof(int)); dst += sizeof(int);
   memcpy(&via_pcr,   dst,  sizeof(int)); dst += sizeof(int);
   memcpy(&via_ifr,   dst,  sizeof(int)); dst += sizeof(int);
   memcpy(&via_ier,   dst,  sizeof(int)); dst += sizeof(int);
   memcpy(&via_ca2,   dst,  sizeof(int)); dst += sizeof(int);
   memcpy(&via_cb2h,  dst,  sizeof(int)); dst += sizeof(int);
   memcpy(&via_cb2s,  dst,  sizeof(int)); dst += sizeof(int);
   memcpy(&alg_rsh,   dst,  sizeof(int)); dst += sizeof(int);
   memcpy(&alg_rsh,   dst,  sizeof(int)); dst += sizeof(int);
   memcpy(&alg_xsh,   dst,  sizeof(int)); dst += sizeof(int);
   memcpy(&alg_ysh,   dst,  sizeof(int)); dst += sizeof(int);
   memcpy(&alg_zsh,   dst,  sizeof(int)); dst += sizeof(int);
   memcpy(&alg_jch0,  dst,  sizeof(int)); dst += sizeof(int);
   memcpy(&alg_jch1,  dst,  sizeof(int)); dst += sizeof(int);
   memcpy(&alg_jch2,  dst,  sizeof(int)); dst += sizeof(int);
   memcpy(&alg_jch3,  dst,  sizeof(int)); dst += sizeof(int);
   memcpy(&alg_jsh,   dst,  sizeof(int)); dst += sizeof(int);
   memcpy(&alg_compare, dst,sizeof(int)); dst += sizeof(int);
   memcpy(&alg_vectoring, dst, sizeof(int)); dst += sizeof(int);
   memcpy(&alg_curr_x, dst, sizeof(long)); dst += sizeof(long);
   memcpy(&alg_curr_y, dst, sizeof(long)); dst += sizeof(long);
   memcpy(&alg_vector_x0, dst, sizeof(long)); dst += sizeof(long);
   memcpy(&alg_vector_y0, dst, sizeof(long)); dst += sizeof(long);
   memcpy(&alg_vector_x1, dst, sizeof(long)); dst += sizeof(long);
   memcpy(&alg_vector_y1, dst, sizeof(long)); dst += sizeof(long);
   memcpy(&alg_vector_dx, dst, sizeof(long)); dst += sizeof(long);
   memcpy(&alg_vector_dy, dst, sizeof(long)); dst += sizeof(long);
   memcpy(&vector_draw_cnt, dst, sizeof(long)); dst += sizeof(long);
   memcpy(&vector_erse_cnt, dst, sizeof(long)); dst += sizeof(long);
   alg_vector_color = *dst;

   return 1;
}

/* update the snd chips internal registers when via_ora/via_orb changes */
static einline void snd_update(void)
{
   switch (via_orb & 0x18)
   {
      case 0x00:
         /* the sound chip is disabled */
         break;
      case 0x08:
         /* the sound chip is sending data */
         break;
      case 0x10:
         /* the sound chip is recieving data */
         if (snd_select != 14)
         {
            snd_regs[snd_select] = via_ora;
            e8910_write(snd_select, via_ora);
         }

         break;
      case 0x18:
         /* the sound chip is latching an address */

         if ((via_ora & 0xf0) == 0x00)
            snd_select = via_ora & 0x0f;

         break;
   }
}

/* update the various analog values when orb is written. */

static einline void alg_update (void)
{
   switch (via_orb & 0x06)
   {
      case 0x00:
         alg_jsh = alg_jch0;

         /* demultiplexor is on */
         if ((via_orb & 0x01) == 0x00)
            alg_ysh = alg_xsh;

         break;
      case 0x02:
         alg_jsh = alg_jch1;

         /* demultiplexor is on */
         if ((via_orb & 0x01) == 0x00)
            alg_rsh = alg_xsh;

         break;
      case 0x04:
         alg_jsh = alg_jch2;

         if ((via_orb & 0x01) == 0x00)
         {
            /* demultiplexor is on */

            if (alg_xsh > 0x80)
               alg_zsh = alg_xsh - 0x80;
            else
               alg_zsh = 0;
         }

         break;
      case 0x06:
         /* sound output line */
         alg_jsh = alg_jch3;
         break;
   }

   /* compare the current joystick direction with a reference */

   if (alg_jsh > alg_xsh)
      alg_compare = 0x20;
   else
      alg_compare = 0;

   /* compute the new "deltas" */

   alg_dx = (long) alg_xsh - (long) alg_rsh;
   alg_dy = (long) alg_rsh - (long) alg_ysh;
}

/* update IRQ and bit-7 of the ifr register after making an adjustment to
 * ifr.
 */

static einline void int_update (void)
{
   if ((via_ifr & 0x7f) & (via_ier & 0x7f))
      via_ifr |= 0x80;
   else
      via_ifr &= 0x7f;
}

unsigned char read8 (unsigned address)
{
   unsigned char data = 0;

   /* rom */
   if ((address & 0xe000) == 0xe000)
      data = rom[address & 0x1fff];
   else if ((address & 0xe000) == 0xc000)
   {
      /* ram */
      if (address & 0x800)
         data = vecx_ram[address & 0x3ff];
      else if (address & 0x1000)
      {
         /* io */

         switch (address & 0xf)
         {
            case 0x0:
               /* compare signal is an input so the value does not come from
                * via_orb.
                */
               /* timer 1 has control of bit 7 */
               if (via_acr & 0x80)
                  data = (unsigned char) ((via_orb & 0x5f) | via_t1pb7 | alg_compare);
               else /* bit 7 is being driven by via_orb */
                  data = (unsigned char) ((via_orb & 0xdf) | alg_compare);

               break;
            case 0x1:
               /* register 1 also performs handshakes if necessary */

               /* if ca2 is in pulse mode or handshake mode, then it
                * goes low whenever ira is read.
                */
               if ((via_pcr & 0x0e) == 0x08)
                  via_ca2 = 0;

               /* fall through */

            case 0xf:
               /* the snd chip is driving port a */
               if ((via_orb & 0x18) == 0x08)
                  data = (unsigned char) snd_regs[snd_select];
               else
                  data = (unsigned char) via_ora;

               break;
            case 0x2:
               data = (unsigned char) via_ddrb;
               break;
            case 0x3:
               data = (unsigned char) via_ddra;
               break;
            case 0x4:
               /* T1 low order counter */

               data      = (unsigned char) via_t1c;
               via_ifr  &= 0xbf; /* remove timer 1 interrupt flag */

               via_t1on  = 0; /* timer 1 is stopped */
               via_t1int = 0;
               via_t1pb7 = 0x80;

               int_update();

               break;
            case 0x5:
               /* T1 high order counter */
               data = (unsigned char) (via_t1c >> 8);
               break;
            case 0x6:
               /* T1 low order latch */
               data = (unsigned char) via_t1ll;
               break;
            case 0x7:
               /* T1 high order latch */
               data = (unsigned char) via_t1lh;
               break;
            case 0x8:
               /* T2 low order counter */
               data      = (unsigned char) via_t2c;
               via_ifr  &= 0xdf; /* remove timer 2 interrupt flag */

               via_t2on  = 0; /* timer 2 is stopped */
               via_t2int = 0;

               int_update ();

               break;
            case 0x9:
               /* T2 high order counter */
               data = (unsigned char) (via_t2c >> 8);
               break;
            case 0xa:
               data      = (unsigned char) via_sr;
               via_ifr  &= 0xfb; /* remove shift register interrupt flag */
               via_srb   = 0;
               via_srclk = 1;

               int_update ();

               break;
            case 0xb:
               data = (unsigned char) via_acr;
               break;
            case 0xc:
               data = (unsigned char) via_pcr;
               break;
            case 0xd:
               /* interrupt flag register */

               data = (unsigned char) via_ifr;
               break;
            case 0xe:
               /* interrupt enable register */

               data = (unsigned char) (via_ier | 0x80);
               break;
         }
      }
   }
   else if (address < 0x8000) /* cartridge */
      data = get_cart(address);
   else
      data = 0xff;

   return data;
}

void write8 (unsigned address, unsigned char data)
{
   /* rom */
	if ((address & 0xe000) == 0xe000) { }
	else if ((address & 0xe000) == 0xc000)
   {
      /* it is possible for both ram and io to be written at the same! */

      if (address & 0x800)
         vecx_ram[address & 0x3ff] = data;

      if (address & 0x1000)
      {
         switch (address & 0xf)
         {
            case 0x0:
               if(bankswitchstate == BS_2)
               {
                  if (data == 1)
                     bankswitchstate = BS_3;
                  else
                     bankswitchstate = BS_0;
               }
               else
                  bankswitchstate = BS_0;
               via_orb = data;

               snd_update ();
               alg_update ();

               /* if cb2 is in pulse mode or handshake mode, then it
                * goes low whenever orb is written.
                */
               if ((via_pcr & 0xe0) == 0x80)
                  via_cb2h = 0;

               break;
            case 0x1:
               /* register 1 also performs handshakes if necessary */

               if(bankswitchstate == BS_3)
               {
                  if (data == 0)
                     bankswitchstate = BS_4;
                  else
                     bankswitchstate = BS_0;
               }
               else
                  bankswitchstate = BS_0;

               /* if ca2 is in pulse mode or handshake mode, then it
                * goes low whenever ora is written.
                */
               if ((via_pcr & 0x0e) == 0x08)
                  via_ca2 = 0;

               /* fall through */

            case 0xf:
               via_ora = data;

               snd_update ();

               /* output of port a feeds directly into the dac which then
                * feeds the x axis sample and hold.
                */

               alg_xsh = data ^ 0x80;

               alg_update ();

               break;
            case 0x2:
               via_ddrb = data;
               bankswitchstate = BS_1;
               if(!big || (data & 0x40))
                  newbankswitchOffset = 0;
               else
                  newbankswitchOffset = 32768;
               break;
            case 0x3:
               via_ddra = data;
               if(bankswitchstate == BS_1)
                  bankswitchstate = BS_2;
               else
                  bankswitchstate = BS_0;
               break;
            case 0x4:
               /* T1 low order counter */

               if(bankswitchstate == BS_5)
               {
                  bankswitchOffset = newbankswitchOffset;
                  bankswitchstate = BS_0;
               }
               via_t1ll = data;

               break;
            case 0x5:
               /* T1 high order counter */

               via_t1lh = data;
               via_t1c = (via_t1lh << 8) | via_t1ll;
               via_ifr &= 0xbf; /* remove timer 1 interrupt flag */

               via_t1on = 1; /* timer 1 starts running */
               via_t1int = 1;
               via_t1pb7 = 0;

               int_update ();

               break;
            case 0x6:
               /* T1 low order latch */

               via_t1ll = data;
               break;
            case 0x7:
               /* T1 high order latch */

               via_t1lh = data;
               break;
            case 0x8:
               /* T2 low order latch */

               via_t2ll = data;
               break;
            case 0x9:
               /* T2 high order latch/counter */

               via_t2c = (data << 8) | via_t2ll;
               via_ifr &= 0xdf;

               via_t2on = 1; /* timer 2 starts running */
               via_t2int = 1;

               int_update ();

               break;
            case 0xa:
               via_sr = data;
               via_ifr &= 0xfb; /* remove shift register interrupt flag */
               via_srb = 0;
               via_srclk = 1;

               int_update ();

               break;
            case 0xb:
               via_acr = data;
               if(bankswitchstate == BS_4)
               {
                  if (data == 0x98)
                     bankswitchstate = BS_5;
                  else
                     bankswitchstate = BS_0;
               }
               else
                  bankswitchstate = BS_0;
               break;
            case 0xc:
               via_pcr = data;

               /* ca2 is outputting low */
               if ((via_pcr & 0x0e) == 0x0c)
                  via_ca2 = 0;
               else
               {
                  /* ca2 is disabled or in pulse mode or is
                   * outputting high.
                   */
                  via_ca2 = 1;
               }

               /* cb2 is outputting low */
               if ((via_pcr & 0xe0) == 0xc0)
                  via_cb2h = 0;
               else
               {
                  /* cb2 is disabled or is in pulse mode or is
                   * outputting high.
                   */
                  via_cb2h = 1;
               }

               break;
            case 0xd:
               /* interrupt flag register */

               via_ifr &= ~(data & 0x7f);
               int_update ();

               break;
            case 0xe:
               /* interrupt enable register */

               if (data & 0x80)
                  via_ier |= data & 0x7f;
               else
                  via_ier &= ~(data & 0x7f);

               int_update ();

               break;
         }
      }
   }
   else if (address < 0x8000) { } /* cartridge */
}

void vecx_reset (void)
{
	unsigned r;

	/* ram */

	for (r = 0; r < 1024; r++)
		vecx_ram[r] = r & 0xff;

	for (r = 0; r < 16; r++)
   {
		snd_regs[r] = 0;
		e8910_write(r, 0);
	}

	/* input buttons */

	snd_regs[14] = 0xff;
	e8910_write(14, 0xff);

	snd_select = 0;

	via_ora = 0;
	via_orb = 0;
	via_ddra = 0;
	via_ddrb = 0;
	via_t1on = 0;
	via_t1int = 0;
	via_t1c = 0;
	via_t1ll = 0;
	via_t1lh = 0;
	via_t1pb7 = 0x80;
	via_t2on = 0;
	via_t2int = 0;
	via_t2c = 0;
	via_t2ll = 0;
	via_sr = 0;
	via_srb = 8;
	via_src = 0;
	via_srclk = 0;
	via_acr = 0;
	via_pcr = 0;
	via_ifr = 0;
	via_ier = 0;
	via_ca2 = 1;
	via_cb2h = 1;
	via_cb2s = 0;

	alg_rsh = 128;
	alg_xsh = 128;
	alg_ysh = 128;
	alg_zsh = 0;
	alg_jch0 = 128;
	alg_jch1 = 128;
	alg_jch2 = 128;
	alg_jch3 = 128;
	alg_jsh = 128;

	alg_compare = 0; /* check this */

	alg_dx = 0;
	alg_dy = 0;
	alg_curr_x = ALG_MAX_X / 2;
	alg_curr_y = ALG_MAX_Y / 2;

	alg_vectoring = 0;

	vector_draw_cnt = 0;
	vector_erse_cnt = 0;
	vectors_draw = vectors_set;
	vectors_erse = vectors_set + VECTOR_CNT;

	fcycles = FCYCLES_INIT;

	e6809_read8 = read8;
	e6809_write8 = write8;

	e6809_reset ();
}

/* perform a single cycle worth of via emulation.
 * via_sstep0 is the first postion of the emulation.
 */

static einline void via_sstep0 (void)
{
	unsigned t2shift;

	if (via_t1on)
   {
      via_t1c--;

      if ((via_t1c & 0xffff) == 0xffff)
      {
         /* counter just rolled over */

         if (via_acr & 0x40)
         {
            /* continuous interrupt mode */

            via_ifr |= 0x40;
            int_update ();
            via_t1pb7 = 0x80 - via_t1pb7;

            /* reload counter */

            via_t1c = (via_t1lh << 8) | via_t1ll;
         }
         else
         {
            /* one shot mode */

            if (via_t1int)
            {
               via_ifr |= 0x40;
               int_update ();
               via_t1pb7 = 0x80;
               via_t1int = 0;
            }
         }
      }
   }

	if (via_t2on && (via_acr & 0x20) == 0x00)
   {
		via_t2c--;

		if ((via_t2c & 0xffff) == 0xffff)
      {
			/* one shot mode */

			if (via_t2int)
         {
				via_ifr |= 0x20;
				int_update ();
				via_t2int = 0;
			}
		}
	}

	/* shift counter */

	via_src--;

	if ((via_src & 0xff) == 0xff) {
		via_src = via_t2ll;

		if (via_srclk) {
			t2shift = 1;
			via_srclk = 0;
		} else {
			t2shift = 0;
			via_srclk = 1;
		}
	} else {
		t2shift = 0;
	}

	if (via_srb < 8) {
		switch (via_acr & 0x1c) {
		case 0x00:
			/* disabled */
			break;
		case 0x04:
			/* shift in under control of t2 */

			if (t2shift) {
				/* shifting in 0s since cb2 is always an output */

				via_sr <<= 1;
				via_srb++;
			}

			break;
		case 0x08:
			/* shift in under system clk control */

			via_sr <<= 1;
			via_srb++;

			break;
		case 0x0c:
			/* shift in under cb1 control */
			break;
		case 0x10:
			/* shift out under t2 control (free run) */

			if (t2shift) {
				via_cb2s = (via_sr >> 7) & 1;

				via_sr <<= 1;
				via_sr |= via_cb2s;
			}

			break;
		case 0x14:
			/* shift out under t2 control */

			if (t2shift) {
				via_cb2s = (via_sr >> 7) & 1;

				via_sr <<= 1;
				via_sr |= via_cb2s;
				via_srb++;
			}

			break;
		case 0x18:
			/* shift out under system clock control */

			via_cb2s = (via_sr >> 7) & 1;

			via_sr <<= 1;
			via_sr |= via_cb2s;
			via_srb++;

			break;
		case 0x1c:
			/* shift out under cb1 control */
			break;
		}

		if (via_srb == 8) {
			via_ifr |= 0x04;
			int_update ();
		}
	}
}

/* perform the second part of the via emulation */

static einline void via_sstep1 (void)
{
   /* if ca2 is in pulse mode, then make sure
    * it gets restored to '1' after the pulse.
    */
   if ((via_pcr & 0x0e) == 0x0a)
      via_ca2 = 1;

   /* if cb2 is in pulse mode, then make sure
    * it gets restored to '1' after the pulse.
    */
   if ((via_pcr & 0xe0) == 0xa0)
      via_cb2h = 1;
}

static einline void alg_addline(
      long x0, long y0,
      long x1, long y1, unsigned char color)
{
   unsigned long key;
   long index;

   key = (unsigned long) x0;
   key = key * 31 + (unsigned long) y0;
   key = key * 31 + (unsigned long) x1;
   key = key * 31 + (unsigned long) y1;
   key %= VECTOR_HASH;

   /* first check if the line to be drawn is in the current draw list.
    * if it is, then it is not added again.
    */

   index = vector_hash[key];

   if (index >= 0 && index < vector_draw_cnt &&
         x0 == vectors_draw[index].x0 &&
         y0 == vectors_draw[index].y0 &&
         x1 == vectors_draw[index].x1 &&
         y1 == vectors_draw[index].y1) {
      vectors_draw[index].color = color;
   } else {
      /* missed on the draw list, now check if the line to be drawn is in
       * the erase list ... if it is, "invalidate" it on the erase list.
       */

      if (index >= 0 && index < vector_erse_cnt &&
            x0 == vectors_erse[index].x0 &&
            y0 == vectors_erse[index].y0 &&
            x1 == vectors_erse[index].x1 &&
            y1 == vectors_erse[index].y1) {
         vectors_erse[index].color = VECTREX_COLORS;
      }

      vectors_draw[vector_draw_cnt].x0 = x0;
      vectors_draw[vector_draw_cnt].y0 = y0;
      vectors_draw[vector_draw_cnt].x1 = x1;
      vectors_draw[vector_draw_cnt].y1 = y1;
      vectors_draw[vector_draw_cnt].color = color;
      vector_hash[key] = vector_draw_cnt;
      vector_draw_cnt++;
   }
}

/* perform a single cycle worth of analog emulation */

static einline void alg_sstep (void)
{
   long sig_dx, sig_dy;
   unsigned sig_ramp;
   unsigned sig_blank;

   if ((via_acr & 0x10) == 0x10)
      sig_blank = via_cb2s;
   else
      sig_blank = via_cb2h;

   if (via_ca2 == 0)
   {
      /* need to force the current point to the 'orgin' so just
       * calculate distance to origin and use that as dx,dy.
       */

      sig_dx = ALG_MAX_X / 2 - alg_curr_x;
      sig_dy = ALG_MAX_Y / 2 - alg_curr_y;
   }
   else
   {
      if (via_acr & 0x80)
         sig_ramp = via_t1pb7;
      else
         sig_ramp = via_orb & 0x80;

      if (sig_ramp == 0)
      {
         sig_dx = alg_dx;
         sig_dy = alg_dy;
      }
      else
      {
         sig_dx = 0;
         sig_dy = 0;
      }
   }

   if (alg_vectoring == 0)
   {
      if (sig_blank == 1 &&
            alg_curr_x >= 0 && alg_curr_x < ALG_MAX_X &&
            alg_curr_y >= 0 && alg_curr_y < ALG_MAX_Y) {

         /* start a new vector */

         alg_vectoring = 1;
         alg_vector_x0 = alg_curr_x;
         alg_vector_y0 = alg_curr_y;
         alg_vector_x1 = alg_curr_x;
         alg_vector_y1 = alg_curr_y;
         alg_vector_dx = sig_dx;
         alg_vector_dy = sig_dy;
         alg_vector_color = (unsigned char) alg_zsh;
      }
   }
   else
   {
      /* already drawing a vector ... check if we need to turn it off */

      if (sig_blank == 0)
      {
         /* blank just went on, vectoring turns off, and we've got a
          * new line.
          */

         alg_vectoring = 0;

         alg_addline (alg_vector_x0, alg_vector_y0,
               alg_vector_x1, alg_vector_y1,
               alg_vector_color);
      }
      else if (sig_dx != alg_vector_dx ||
            sig_dy != alg_vector_dy ||
            (unsigned char) alg_zsh != alg_vector_color)
      {
         /* the parameters of the vectoring processing has changed.
          * so end the current line.
          */

         alg_addline (alg_vector_x0, alg_vector_y0,
               alg_vector_x1, alg_vector_y1,
               alg_vector_color);

         /* we continue vectoring with a new set of parameters if the
          * current point is not out of limits.
          */

         if (alg_curr_x >= 0 && alg_curr_x < ALG_MAX_X &&
               alg_curr_y >= 0 && alg_curr_y < ALG_MAX_Y)
         {
            alg_vector_x0 = alg_curr_x;
            alg_vector_y0 = alg_curr_y;
            alg_vector_x1 = alg_curr_x;
            alg_vector_y1 = alg_curr_y;
            alg_vector_dx = sig_dx;
            alg_vector_dy = sig_dy;
            alg_vector_color = (unsigned char) alg_zsh;
         }
         else
            alg_vectoring = 0;
      }
   }

   alg_curr_x += sig_dx;
   alg_curr_y += sig_dy;

   if (alg_vectoring == 1 &&
         alg_curr_x >= 0 && alg_curr_x < ALG_MAX_X &&
         alg_curr_y >= 0 && alg_curr_y < ALG_MAX_Y)
   {
      /* we're vectoring ... current point is still within limits so
       * extend the current vector.
       */

      alg_vector_x1 = alg_curr_x;
      alg_vector_y1 = alg_curr_y;
   }
}

int vecx_emu (long cycles)
{
   unsigned c, icycles;
   int ret = 0;

   while (cycles > 0)
   {
      icycles = e6809_sstep (via_ifr & 0x80, 0);

      for (c = 0; c < icycles; c++)
      {
         via_sstep0 ();
         alg_sstep ();
         via_sstep1 ();
      }

      cycles -= (long) icycles;

      fcycles -= (long) icycles;

      if (fcycles < 0)
      {
         vector_t *tmp;

         fcycles += FCYCLES_INIT;
         osint_render ();
         ret = 1;

         /* everything that was drawn during this pass now now enters
          * the erase list for the next pass.
          */

         vector_erse_cnt = vector_draw_cnt;
         vector_draw_cnt = 0;

         tmp = vectors_erse;
         vectors_erse = vectors_draw;
         vectors_draw = tmp;
      }
   }
   return ret;
}
