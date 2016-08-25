
// This file is part of the PicoDrive Megadrive Emulator

// Copyright (c) 2011 FinalDave (emudave (at) gmail.com)

// This code is licensed under the GNU General Public License version 2.0 and the MAME License.
// You can choose the license that has the most advantages for you.

// SVN repository can be found at http://code.google.com/p/cyclone68000/

// Disa 68000 Disassembler
#ifndef __GNUC__
#pragma warning(disable:4115)
#endif

#define _CRT_SECURE_NO_WARNINGS
#include <stdio.h>
#include <string.h>
#include "Disa.h"

unsigned int DisaPc=0;
char *DisaText=NULL; // Text buffer to write in
static char Tasm[]="bwl?";
static char Comment[64]="";
unsigned short (CPU_CALL *DisaWord)(unsigned int a)=NULL;

static unsigned int DisaLong(unsigned int a)
{
  unsigned int d=0;
  if (DisaWord==NULL) return d;

  d= DisaWord(a)<<16;
  d|=DisaWord(a+2)&0xffff;
  return d;
}

// Get text version of the effective address
int DisaGetEa(char *t,int ea,int size)
{
  ea&=0x3f; t[0]=0;
  if ((ea&0x38)==0x00) { sprintf(t,"d%d",ea  ); return 0; }    // 000rrr
  if ((ea&0x38)==0x08) { sprintf(t,"a%d",ea&7); return 0; }    // 001rrr
  if ((ea&0x38)==0x10) { sprintf(t,"(a%d)",ea&7); return 0; }  // 010rrr
  if ((ea&0x38)==0x18) { sprintf(t,"(a%d)+",ea&7); return 0; } // 011rrr
  if ((ea&0x38)==0x20) { sprintf(t,"-(a%d)",ea&7); return 0; } // 100rrr
  if ((ea&0x38)==0x28) { sprintf(t,"($%x,a%d)",DisaWord(DisaPc)&0xffff,ea&7); DisaPc+=2; return 0; } // 101rrr

  if ((ea&0x38)==0x30)
  {
    // 110nnn - An + Disp + D/An
    int areg=0,ext=0,off=0,da=0,reg=0,wol=0,scale=0;
    ext=DisaWord(DisaPc)&0xffff;
    
    areg=ea&7;
    off=ext&0xff;    da =ext&0x8000?'a':'d';
    reg=(ext>>12)&7; wol=ext&0x0800?'l':'w';
    scale=1<<((ext>>9)&3);

    if (scale<2) sprintf(t,"($%x,a%d,%c%d.%c)",   off,areg,da,reg,wol);
    else         sprintf(t,"($%x,a%d,%c%d.%c*%d)",off,areg,da,reg,wol,scale); // 68020

    DisaPc+=2;
    return 0;
  }

  if (ea==0x38) { sprintf(t,"$%x.w",DisaWord(DisaPc)&0xffff); DisaPc+=2; return 0; } // 111000 - Absolute short
  if (ea==0x39) { sprintf(t,"$%x.l",DisaLong(DisaPc));        DisaPc+=4; return 0; } // 111001 - Absolute long

  if (ea==0x3a)
  {
    // 111010 - PC Relative
    int ext=DisaWord(DisaPc)&0xffff;
    sprintf(t,"($%x,pc)",ext);
    sprintf(Comment,"; =%x",DisaPc+(short)ext); // Comment where pc+ext is
    DisaPc+=2;
    return 0;
  }

  if (ea==0x3b)
  {
    // 111011 - PC Relative + D/An
    int ext=0,off=0,da=0,reg=0,wol=0,scale=0;
    ext=DisaWord(DisaPc)&0xffff;
    
    off=ext&0xff;    da =ext&0x8000?'a':'d';
    reg=(ext>>12)&7; wol=ext&0x0800?'l':'w';
    scale=1<<((ext>>9)&3);

    if (scale<2) sprintf(t,"($%x,pc,%c%d.%c)",   off,da,reg,wol);
    else         sprintf(t,"($%x,pc,%c%d.%c*%d)",off,da,reg,wol,scale); // 68020

    sprintf(Comment,"; =%x",DisaPc+(char)off); // Comment where pc+ext is
    DisaPc+=2;
    return 0;
  }

  if (ea==0x3c)
  {
    // 111100 - Immediate
    switch (size)
    {
      case 0: sprintf(t,"#$%x",DisaWord(DisaPc)&0x00ff); DisaPc+=2; return 0;
      case 1: sprintf(t,"#$%x",DisaWord(DisaPc)&0xffff); DisaPc+=2; return 0;
      case 2: sprintf(t,"#$%x",DisaLong(DisaPc)       ); DisaPc+=4; return 0;
    }
    return 1;
  }

// Unknown effective address
  sprintf(t,"ea=(%d%d%d %d%d%d)",
    (ea>>5)&1,(ea>>4)&1,(ea>>3)&1,
    (ea>>2)&1,(ea>>1)&1, ea    &1);
  return 1;
}

static void GetOffset(char *text)
{
  int off=(short)DisaWord(DisaPc); DisaPc+=2;

  if (off<0) sprintf(text,"-$%x",-off);
  else       sprintf(text,"$%x",  off);
}

// ================ Opcodes 0x0000+ ================
static int DisaArithImm(int op)
{
  // Or/And/Sub/Add/Eor/Cmp Immediate 0000ttt0 xxDDDddd (tt=type, xx=size extension, DDDddd=Dest ea)
  int dea=0;
  char seat[64]="",deat[64]="";
  int type=0,size=0;
  char *arith[8]={"or","and","sub","add","?","eor","cmp","?"};

  type=(op>>9)&7; if (type==4 || type>=7) return 1;
  size=(op>>6)&3; if (size>=3) return 1;
  dea=op&0x3f; if (dea==0x3c) return 1;

  DisaGetEa(seat,0x3c,size);
  DisaGetEa(deat,dea, size);

  sprintf(DisaText,"%si.%c %s, %s",arith[type],Tasm[size],seat,deat);
  return 0;
}

// ================ Opcodes 0x0108+ ================
static int DisaMovep(int op)
{
  // movep.x (Aa),Dn - 0000nnn1 dx001aaa  nn
  int dn=0,dir=0,size=0,an=0;
  char offset[32]="";

  dn  =(op>>9)&7;
  dir =(op>>7)&1;
  size=(op>>6)&1; size++;
  an  = op    &7;

  GetOffset(offset);
  if (dir) sprintf(DisaText,"movep.%c d%d, (%s,a%d)",Tasm[size],dn,offset,an);
  else     sprintf(DisaText,"movep.%c (%s,a%d), d%d",Tasm[size],offset,an,dn);

  return 0;
}

// ================ Opcodes 0x007c+ ================
static int DisaArithSr(int op)
{
  // Ori/Andi/Eori $nnnn,sr 0000t0tx 0s111100
  char *opcode[6]={"ori","andi","","","","eori"};
  char seat[64]="";
  int type=0,size=0;

  type=(op>>9)&5;
  size=(op>>6)&1;

  DisaGetEa(seat,0x3c,size);
  sprintf(DisaText,"%s.%c %s, %s", opcode[type], Tasm[size], seat, size?"sr":"ccr");

  return 0;
}

// ================ Opcodes 0x0100+ ================
static int DisaBtstReg(int op)
{
  // Btst/Bchg/Bclr/Bset 0000nnn1 tteeeeee (nn=reg number, eeeeee=Dest ea)
  int type=0;
  int sea=0,dea=0;
  char seat[64]="",deat[64]="";
  char *opcode[4]={"btst","bchg","bclr","bset"};

  sea =(op>>9)&7;
  type=(op>>6)&3;
  dea=  op&0x3f;

  if ((dea&0x38)==0x08) return 1; // movep
  DisaGetEa(seat,sea,0);
  DisaGetEa(deat,dea,0);

  sprintf(DisaText,"%s %s, %s",opcode[type],seat,deat);
  return 0;
}

// ================ Opcodes 0x0800+ ================
static int DisaBtstImm(int op)
{
  // Btst/Bchg/Bclr/Bset 00001000 tteeeeee 00 nn (eeeeee=ea, nn=bit number)
  int type=0;
  char seat[64]="",deat[64]="";
  char *opcode[4]={"btst","bchg","bclr","bset"};

  type=(op>>6)&3;
  DisaGetEa(seat,   0x3c,0);
  DisaGetEa(deat,op&0x3f,0);

  sprintf(DisaText,"%s %s, %s",opcode[type],seat,deat);
  return 0;
}

// ================ Opcodes 0x1000+ ================
static int DisaMove(int op)
{
  // Move 00xxdddD DDssssss (xx=size extension, ssssss=Source EA, DDDddd=Dest ea)
  int sea=0,dea=0;
  char inst[64]="",seat[64]="",deat[64]="";
  char *movea="";
  int size=0;

  if ((op&0x01c0)==0x0040) movea="a"; // See if it's a movea opcode

  // Find size extension
  switch (op&0x3000)
  {
    case 0x1000: size=0; break;
    case 0x3000: size=1; break;
    case 0x2000: size=2; break;
    default: return 1;
  }

  sea = op&0x003f;
  DisaGetEa(seat,sea,size);
  
  dea =(op&0x01c0)>>3;
  dea|=(op&0x0e00)>>9;
  DisaGetEa(deat,dea,size);

  sprintf(inst,"move%s.%c",movea,Tasm[size]);
  sprintf(DisaText,"%s %s, %s",inst,seat,deat);
  return 0;
}

// ================ Opcodes 0x4000+ ================
static int DisaNeg(int op)
{
  // 01000tt0 xxeeeeee (tt=negx/clr/neg/not, xx=size, eeeeee=EA)
  char eat[64]="";
  int type=0,size=0;
  char *opcode[4]={"negx","clr","neg","not"};

  type=(op>>9)&3;
  size=(op>>6)&3; if (size>=3) return 1;
  DisaGetEa(eat,op&0x3f,size);

  sprintf(DisaText,"%s.%c %s",opcode[type],Tasm[size],eat);
  return 0;
}

// ================ Opcodes 0x40c0+ ================
static int DisaMoveSr(int op)
{
  // 01000tt0 11eeeeee (tt=type, xx=size, eeeeee=EA)
  int type=0,ea=0;
  char eat[64]="";

  type=(op>>9)&3;
  ea=op&0x3f;
  DisaGetEa(eat,ea,1);

  switch (type)
  {
    default: sprintf(DisaText,"move sr, %s", eat); break;
    case 1:  sprintf(DisaText,"move ccr, %s",eat); break;
    case 2:  sprintf(DisaText,"move %s, ccr",eat); break;
    case 3:  sprintf(DisaText,"move %s, sr", eat); break;
  }
  return 0;
}

static int OpChk(int op)
{
  int sea=0,dea=0;
  char seat[64]="",deat[64]="";

  sea=op&0x003f;
  DisaGetEa(seat,sea,0);

  dea=(op>>9)&7; dea|=8;
  DisaGetEa(deat,dea,2);

  sprintf(DisaText,"chk %s, %s",seat,deat);
  return 0;
}

// ================ Opcodes 0x41c0+ ================
static int DisaLea(int op)
{
  // Lea 0100nnn1 11eeeeee (eeeeee=ea)
  int sea=0,dea=0;
  char seat[64]="",deat[64]="";

  sea=op&0x003f;
  DisaGetEa(seat,sea,0);

  dea=(op>>9)&7; dea|=8;
  DisaGetEa(deat,dea,2);

  sprintf(DisaText,"lea %s, %s",seat,deat);
  return 0;
}

static int MakeRegList(char *list,int mask,int ea)
{
  int reverse=0,i=0,low=0,len=0;

  if ((ea&0x38)==0x20) reverse=1; // -(An), bitfield is reversed

  mask&=0xffff; list[0]=0;

  for (i=0;i<17;i++)
  {
    int bit=0;
    
    // Mask off bit i:
    if (reverse) bit=0x8000>>i; else bit=1<<i;
    bit&=mask;

    if (bit==0 || i==8)
    {
      // low to i-1 are a continuous section, add it:
      char add[16]="";
      int ad=low&8?'a':'d';
      if (low==i-1) sprintf(add,"%c%d/",     ad,low&7);
      if (low< i-1) sprintf(add,"%c%d-%c%d/",ad,low&7, ad,(i-1)&7);
      strcat(list,add);

      low=i; // Next section
    }

    if (bit==0) low=i+1;
  }

  // Knock off trailing '/'
  len=strlen(list);
  if (len>0) if (list[len-1]=='/') list[len-1]=0; 
  return 0;
}

// ================ Opcodes 0x4800+ ================
static int DisaNbcd(int op)
{
  // Nbcd 01001000 00eeeeee  (eeeeee=ea)
  int ea=0;
  char eat[64]="";

  ea=op&0x003f;
  DisaGetEa(eat,ea,0);

  sprintf(DisaText,"nbcd %s",eat);
  return 0;
}

// ================ Opcodes 0x4840+ ================
static int DisaSwap(int op)
{
  // Swap, 01001000 01000nnn swap Dn
  sprintf(DisaText,"swap d%d",op&7);
  return 0;
}

// ================ Opcodes 0x4850+ ================
static int DisaPea(int op)
{
  // Pea 01001000 01eeeeee  (eeeeee=ea)  pea 
  int ea=0;
  char eat[64]="";

  ea=op&0x003f; if (ea<0x10) return 1; // swap opcode
  DisaGetEa(eat,ea,2);

  sprintf(DisaText,"pea %s",eat);
  return 0;
}

// ================ Opcodes 0x4880+ ================
static int DisaExt(int op)
{
  // Ext 01001000 1x000nnn (x=size, eeeeee=EA)
  char eat[64]="";
  int size=0;

  size=(op>>6)&1; size++;
  DisaGetEa(eat,op&0x3f,size);

  sprintf(DisaText,"ext.%c %s",Tasm[size],eat);
  return 0;
}

// ================ Opcodes 0x4890+ ================
static int DisaMovem(int op)
{
  // Movem 01001d00 1xeeeeee regmask  d=direction, x=size, eeeeee=EA
  int dir=0,size=0;
  int ea=0,mask=0;
  char list[64]="",eat[64]="";

  dir=(op>>10)&1;
  size=((op>>6)&1)+1;
  ea=op&0x3f; if (ea<0x10) return 1; // ext opcode

  mask=DisaWord(DisaPc)&0xffff; DisaPc+=2;

  MakeRegList(list,mask,ea); // Turn register mask into text
  DisaGetEa(eat,ea,size);

  if (dir) sprintf(DisaText,"movem.%c %s, %s",Tasm[size],eat,list);
  else     sprintf(DisaText,"movem.%c %s, %s",Tasm[size],list,eat);
  return 0;
}

// ================ Opcodes 0x4e40+ ================
static int DisaTrap(int op)
{
  sprintf(DisaText,"trap #%d",op&0xf);
  return 0;
}

// ================ Opcodes 0x4e50+ ================
static int DisaLink(int op)
{
  // Link opcode, 01001110 01010nnn dd   link An,#offset
  char eat[64]="";
  char offset[32]="";

  DisaGetEa(eat,(op&7)|8,0);
  GetOffset(offset);

  sprintf(DisaText,"link %s,#%s",eat,offset);

  return 0;
}

// ================ Opcodes 0x4e58+ ================
static int DisaUnlk(int op)
{
  // Link opcode, 01001110 01011nnn dd   unlk An
  char eat[64]="";

  DisaGetEa(eat,(op&7)|8,0);
  sprintf(DisaText,"unlk %s",eat);

  return 0;
}

// ================ Opcodes 0x4e60+ ================
static int DisaMoveUsp(int op)
{
  // Move USP opcode, 01001110 0110dnnn move An to/from USP (d=direction)
  int ea=0,dir=0;
  char eat[64]="";

  dir=(op>>3)&1;
  ea=(op&7)|8;
  DisaGetEa(eat,ea,0);

  if (dir) sprintf(DisaText,"move usp, %s",eat);
  else     sprintf(DisaText,"move %s, usp",eat);
  return 0;
}

// ================ Opcodes 0x4e70+ ================
static int Disa4E70(int op)
{
  char *inst[8]={"reset","nop","stop","rte","rtd","rts","trapv","rtr"};
  int n=0;

  n=op&7;

  sprintf(DisaText,"%s",inst[n]);

  //todo - 'stop' with 16 bit data
  
  return 0;
}

// ================ Opcodes 0x4a00+ ================
static int DisaTst(int op)
{
  // Tst 01001010 xxeeeeee  (eeeeee=ea)
  int ea=0;
  char eat[64]="";
  int size=0;

  ea=op&0x003f;
  DisaGetEa(eat,ea,0);
  size=(op>>6)&3; if (size>=3) return 1;

  sprintf(DisaText,"tst.%c %s",Tasm[size],eat);
  return 0;
}

static int DisaTas(int op)
{
  // Tas 01001010 11eeeeee  (eeeeee=ea)
  int ea=0;
  char eat[64]="";

  ea=op&0x003f;
  DisaGetEa(eat,ea,0);

  sprintf(DisaText,"tas %s",eat);
  return 0;
}

// ================ Opcodes 0x4e80+ ================
static int DisaJsr(int op)
{
  // Jsr/Jmp 0100 1110 1mEE Eeee (eeeeee=ea m=1=jmp)
  int sea=0;
  char seat[64]="";

  sea=op&0x003f;
  DisaGetEa(seat,sea,0);

  sprintf(DisaText,"j%s %s", op&0x40?"mp":"sr", seat);
  return 0;
}

// ================ Opcodes 0x5000+ ================
static int DisaAddq(int op)
{
  // 0101nnnt xxeeeeee (nnn=#8,1-7 t=addq/subq xx=size, eeeeee=EA)
  int num=0,type=0,size=0,ea=0;
  char eat[64]="";

  num =(op>>9)&7; if (num==0) num=8;
  type=(op>>8)&1;
  size=(op>>6)&3; if (size>=3) return 1;
  ea  = op&0x3f;

  DisaGetEa(eat,ea,size);

  sprintf(DisaText,"%s.%c #%d, %s",type?"subq":"addq",Tasm[size],num,eat);
  return 0;
}

// ================ Opcodes 0x50c0+ ================
static int DisaSet(int op)
{
  // 0101cccc 11eeeeee (sxx ea)
  static char *cond[16]=
  {"t" ,"f", "hi","ls","cc","cs","ne","eq",
   "vc","vs","pl","mi","ge","lt","gt","le"};
  char *cc="";
  int ea=0;
  char eat[64]="";

  cc=cond[(op>>8)&0xf]; // Get condition code
  ea=op&0x3f;
  if ((ea&0x38)==0x08) return 1; // dbra, not scc

  DisaGetEa(eat,ea,0);
  sprintf(DisaText,"s%s %s",cc,eat);
  return 0;
}

// ================ Opcodes 0x50c8+ ================
static int DisaDbra(int op)
{
  // 0101cccc 11001nnn offset  (dbra/dbxx Rn,offset)
  int dea=0; char deat[64]="";
  int pc=0,Offset=0;

  static char *BraCode[16]=
  {"bt" ,"bra","bhi","bls","bcc","bcs","bne","beq",
   "bvc","bvs","bpl","bmi","bge","blt","bgt","ble"};
  char *Bra="";

  dea=op&7;
  DisaGetEa(deat,dea,2);

  // Get condition code
  Bra=BraCode[(op>>8)&0xf];

  // Get offset
  pc=DisaPc;
  Offset=(short)DisaWord(DisaPc); DisaPc+=2;

  sprintf(DisaText,"d%s %s, %x",Bra,deat,pc+Offset);
  return 0;
}

// ================ Opcodes 0x6000+ ================
static int DisaBranch(int op)
{
  // Branch 0110cccc nn  (cccc=condition)
  int pc=0,Offset=0;

  static char *BraCode[16]=
  {"bra","bsr","bhi","bls","bcc","bcs","bne","beq",
   "bvc","bvs","bpl","bmi","bge","blt","bgt","ble"};
  char *Bra="";

  // Get condition code
  Bra=BraCode[(op>>8)&0x0f];

  // Get offset
  pc=DisaPc;
  Offset=(char)(op&0xff);
       if (Offset== 0) { Offset=(short)DisaWord(DisaPc); DisaPc+=2; }
  else if (Offset==-1) { Offset=       DisaLong(DisaPc); DisaPc+=4; }

  sprintf(DisaText,"%s %x",Bra,pc+Offset);
  return 0;
}

// ================ Opcodes 0x7000+ ================
static int DisaMoveq(int op)
{
  // Moveq 0111rrr0 nn (rrr=Dest register, nn=data)

  int dea=0; char deat[64]="";
  char *inst="moveq";
  int val=0;

  dea=(op>>9)&7;
  DisaGetEa(deat,dea,2);

  val=(char)(op&0xff);
  sprintf(DisaText,"%s #$%x, %s",inst,val,deat);
  return 0;
}

// ================ Opcodes 0x8000+ ================
static int DisaArithReg(int op)
{
  // 1t0tnnnd xxeeeeee (tt=type:or/sub/and/add xx=size, eeeeee=EA)
  int type=0,size=0,dir=0,rea=0,ea=0;
  char reat[64]="",eat[64]="";
  char *opcode[]={"or","sub","","","and","add"};

  type=(op>>12)&5;
  rea =(op>> 9)&7;
  dir =(op>> 8)&1;
  size=(op>> 6)&3; if (size>=3) return 1;
  ea  = op&0x3f;

  if (dir && ea<0x10) return 1; // addx opcode

  DisaGetEa(reat,rea,size);
  DisaGetEa( eat, ea,size);

  if (dir) sprintf(DisaText,"%s.%c %s, %s",opcode[type],Tasm[size],reat,eat);
  else     sprintf(DisaText,"%s.%c %s, %s",opcode[type],Tasm[size],eat,reat);
  return 0;
}

// ================ Opcodes 0x8100+ ================
static int DisaAbcd(int op)
{
  // 1t00ddd1 0000asss - sbcd/abcd Ds,Dd or -(As),-(Ad)
  int type=0;
  int dn=0,addr=0,sn=0;
  char *opcode[]={"sbcd","abcd"};

  type=(op>>14)&1;
  dn  =(op>> 9)&7;
  addr=(op>> 3)&1;
  sn  = op     &7;

  if (addr) sprintf(DisaText,"%s -(a%d), -(a%d)",opcode[type],sn,dn);
  else      sprintf(DisaText,"%s d%d, d%d",       opcode[type],sn,dn);

  return 0;
}

// ================ Opcodes 0x80c0+ ================
static int DisaMul(int op)
{
  // Div/Mul: 1m00nnns 11eeeeee (m=Mul, nnn=Register Dn, s=signed, eeeeee=EA)
  int type=0,rea=0,sign=0,ea=0,size=1;
  char reat[64]="",eat[64]="";
  char *opcode[2]={"div","mul"};

  type=(op>>14)&1; // div/mul
  rea =(op>> 9)&7;
  sign=(op>> 8)&1;
  ea  = op&0x3f;

  DisaGetEa(reat,rea,size);
  DisaGetEa( eat, ea,size);

  sprintf(DisaText,"%s%c.%c %s, %s",opcode[type],sign?'s':'u',Tasm[size],eat,reat);
  return 0;
}

// ================ Opcodes 0x90c0+ ================
static int DisaAritha(int op)
{
  // Suba/Cmpa/Adda 1tt1nnnx 11eeeeee (tt=type, x=size, eeeeee=Source EA)
  int type=0,size=0,sea=0,dea=0;
  char seat[64]="",deat[64]="";
  char *aritha[4]={"suba","cmpa","adda",""};

  type=(op>>13)&3; if (type>=3) return 1;
  size=(op>>8)&1; size++;
  dea =(op>>9)&7; dea|=8; // Dest=An
  sea = op&0x003f; // Source

  DisaGetEa(seat,sea,size);
  DisaGetEa(deat,dea,size);

  sprintf(DisaText,"%s.%c %s, %s",aritha[type],Tasm[size],seat,deat);
  return 0;
}

// ================ Opcodes 0xb000+ ================
static int DisaCmpEor(int op)
{
  // Cmp/Eor 1011rrrt xxeeeeee (rrr=Dn, t=cmp/eor, xx=size extension, eeeeee=ea)
  char reat[64]="",eat[64]="";
  int type=0,size=0;

  type=(op>>8)&1;
  size=(op>>6)&3; if (size>=3) return 1; // cmpa opcode
  if ((op&0xf138)==0xb108) return 1; // cmpm opcode

  DisaGetEa(reat,(op>>9)&7,size);
  DisaGetEa(eat,  op&0x3f, size);

  if (type) sprintf(DisaText,"eor.%c %s, %s",Tasm[size],reat,eat);
  else      sprintf(DisaText,"cmp.%c %s, %s",Tasm[size],eat,reat);
  return 0;
}

// ================ Opcodes 0xb108+ ================
static int DisaCmpm(int op)
{
  // Cmpm  1011ddd1 xx001sss
  int size=0,dea=0,sea=0;
  char deat[64]="",seat[64]="";

  dea =(op>> 9)&7; dea|=8;
  size=(op>> 6)&3; if (size>=3) return 1;
  sea  = op&0x3f;

  DisaGetEa(deat,dea,size);
  DisaGetEa(seat,sea,size);

  sprintf(DisaText,"cmpm.%c (%s)+, (%s)+",Tasm[size],seat,deat);

  return 0;
}

// ================ Opcodes 0xc140+ ================
// 1100ttt1 01000sss  exg ds,dt
// 1100ttt1 01001sss  exg as,at
// 1100ttt1 10001sss  exg as,dt
static int DisaExg(int op)
{
  int tr=0,type=0,sr=0;

  tr  =(op>>9)&7;
  type= op&0xf8;
  sr  = op&7;

       if (type==0x40) sprintf(DisaText,"exg d%d, d%d",sr,tr);
  else if (type==0x48) sprintf(DisaText,"exg a%d, a%d",sr,tr);
  else if (type==0x88) sprintf(DisaText,"exg a%d, d%d",sr,tr);
  else return 1;

  return 0;
}

// ================ Opcodes 0xd100+ ================
static int DisaAddx(int op)
{
  // 1t01ddd1 xx000sss addx
  int type=0,size=0,dea=0,sea=0,mem;
  char deat[64]="",seat[64]="";
  char *opcode[6]={"","subx","","","","addx"};

  type=(op>>12)&5;
  dea =(op>> 9)&7;
  size=(op>> 6)&3; if (size>=3) return 1;
  sea = op&7;
  mem = op&8;
  if(mem) { sea+=0x20; dea+=0x20; }

  DisaGetEa(deat,dea,size);
  DisaGetEa(seat,sea,size);

  sprintf(DisaText,"%s.%c %s, %s",opcode[type],Tasm[size],seat,deat);
  return 0;
}

// ================ Opcodes 0xe000+ ================
static char *AsrName[4]={"as","ls","rox","ro"};
static int DisaAsr(int op)
{
  // Asr/l/Ror/l etc - 1110cccd xxuttnnn
  // (ccc=count, d=direction xx=size extension, u=use reg for count, tt=type, nnn=register Dn)
  int count=0,dir=0,size=0,usereg=0,type=0,num=0;

  count =(op>>9)&7;
  dir   =(op>>8)&1;
  size  =(op>>6)&3; if (size>=3) return 1; // todo Asr EA
  usereg=(op>>5)&1;
  type  =(op>>3)&3;
  num   = op    &7; // Register number

  if (usereg==0) count=((count-1)&7)+1; // because ccc=000 means 8

  sprintf(DisaText,"%s%c.%c %c%d, d%d",
    AsrName[type], dir?'l':'r', Tasm[size],
    usereg?'d':'#', count, num);
  return 0;
}

static int DisaAsrEa(int op)
{
  // Asr/l/Ror/l etc EA - 11100ttd 11eeeeee 
  int type=0,dir=0,size=1;
  char eat[64]="";

  type=(op>>9)&3;
  dir =(op>>8)&1;
  DisaGetEa(eat,op&0x3f,size);

  sprintf(DisaText,"%s%c.w %s", AsrName[type], dir?'l':'r', eat);
  return 0;
}

// =================================================================

static int TryOp(int op)
{
  if ((op&0xf100)==0x0000) DisaArithImm(op); // Ori/And/Sub/Add/Eor/Cmp Immediate
  if ((op&0xf5bf)==0x003c) DisaArithSr(op); // Ori/Andi/Eori $nnnn,sr
  if ((op&0xf100)==0x0100) DisaBtstReg(op);
  if ((op&0xf138)==0x0108) DisaMovep(op);
  if ((op&0xff00)==0x0800) DisaBtstImm(op); // Btst/Bchg/Bclr/Bset
  if ((op&0xc000)==0x0000) DisaMove(op);
  if ((op&0xf900)==0x4000) DisaNeg(op); // Negx/Clr/Neg/Not
  if ((op&0xf140)==0x4100) OpChk(op);
  if ((op&0xf1c0)==0x41c0) DisaLea(op);
  if ((op&0xf9c0)==0x40c0) DisaMoveSr(op);
  if ((op&0xffc0)==0x4800) DisaNbcd(op);
  if ((op&0xfff8)==0x4840) DisaSwap(op);
  if ((op&0xffc0)==0x4840) DisaPea(op);
  if ((op&0xffb8)==0x4880) DisaExt(op);
  if ((op&0xfb80)==0x4880) DisaMovem(op);
  if ((op&0xff00)==0x4a00) DisaTst(op);
  if ((op&0xffc0)==0x4ac0) DisaTas(op);
  if ((op&0xfff0)==0x4e40) DisaTrap(op);
  if ((op&0xfff8)==0x4e50) DisaLink(op);
  if ((op&0xfff8)==0x4e58) DisaUnlk(op);
  if ((op&0xfff0)==0x4e60) DisaMoveUsp(op);
  if ((op&0xfff8)==0x4e70) Disa4E70(op);
  if ((op&0xff80)==0x4e80) DisaJsr(op);
  if ((op&0xf000)==0x5000) DisaAddq(op);
  if ((op&0xf0c0)==0x50c0) DisaSet(op);
  if ((op&0xf0f8)==0x50c8) DisaDbra(op);
  if ((op&0xf000)==0x6000) DisaBranch(op);
  if ((op&0xa000)==0x8000) DisaArithReg(op); // Or/Sub/And/Add
  if ((op&0xb1f0)==0x8100) DisaAbcd(op);
  if ((op&0xb130)==0x9100) DisaAddx(op);
  if ((op&0xb0c0)==0x80c0) DisaMul(op);
  if ((op&0xf100)==0x7000) DisaMoveq(op);
  if ((op&0x90c0)==0x90c0) DisaAritha(op);
  if ((op&0xf000)==0xb000) DisaCmpEor(op);
  if ((op&0xf138)==0xb108) DisaCmpm(op);
  if ((op&0xf130)==0xc100) DisaExg(op);
  if ((op&0xf000)==0xe000) DisaAsr(op);
  if ((op&0xf8c0)==0xe0c0) DisaAsrEa(op);

  // Unknown opcoode
  return 0;
}

int DisaGet()
{
  int op=0;
  if (DisaWord==NULL) return 1;

  Comment[0]=0;
  DisaText[0]=0; // Assume opcode unknown

  op=DisaWord(DisaPc)&0xffff; DisaPc+=2;
  TryOp(op);
  strcat(DisaText,Comment);

  // Unknown opcoode
  return 0;
}
