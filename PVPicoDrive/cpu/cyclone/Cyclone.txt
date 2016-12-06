
      _____            __                                     
     / ___/__ __ ____ / /___   ___  ___   ___________________ 
    / /__ / // // __// // _ \ / _ \/ -_) ___________________  
    \___/ \_, / \__//_/ \___//_//_/\__/ ___________________   
         /___/                                                
         ___________________  ____ ___   ___   ___   ___      
        ___________________  / __// _ \ / _ \ / _ \ / _ \     
       ___________________  / _ \/ _  // // // // // // /     
                            \___/\___/ \___/ \___/ \___/      
                                                              
___________________________________________________________________________

  Copyright (c) 2004,2011 FinalDave (emudave (at) gmail.com)
  Copyright (c) 2005-2011 Gražvydas "notaz" Ignotas (notasas (at) gmail.com)

  This code is licensed under the GNU General Public License version 2.0 and the MAME License.
  You can choose the license that has the most advantages for you.

  Homepage: http://code.google.com/p/cyclone68000/

___________________________________________________________________________


About
-----

Cyclone 68000 is an emulator for the 68000 microprocessor, written in ARM 32-bit assembly.
It is aimed at chips such as ARM7 and ARM9 cores, StrongARM and XScale, to interpret 68000
code as fast as possible. It can emulate all 68000 instructions quite accurately, instruction
timing was synchronized with MAME's Musashi. Most 68k features are emulated (trace mode,
address errors), but prefetch is not emulated.


How to Compile
--------------

Like Starscream and A68K, Cyclone uses a 'Core Creator' program which calculates and outputs
all possible 68000 Opcodes and a jump table into file called Cyclone.s or Cyclone.asm.
Only Cyclone.h and the mentioned .s or .asm file will be needed for your project, other files
are here to produce or test it.

First unzip "Cyclone.zip" into a "Cyclone" directory. The next thing to do is to edit config.h
file to tune Cyclone for your project. There are lots of options in config.h, but all of them
are documented and have defaults. You should set a define value to 1 to enable option, and
to 0 to disable.

After you are done with config.h, save it and compile Cyclone. If you are using Linux, Cygwin,
mingw or similar, you can simply cd to Cyclone/proj and type "make". If you are under Windows
and have Visual Studio installed, you can import cyclone.dsp in the proj/ directory and compile
it from there (this will produce cyclone.exe which you will have to run to get .s or .asm).
You can also use Microsoft command line compile tools by entering Cyclone/proj directory and
typing "nmake -f Makefile.win". Note that this step is done only to produce .s or .asm, and it
is done using native tools on your PC (not using cross-compiler or similar).

The .s file is meant to be compiled with GNU assembler, and .asm with ARMASM.EXE
(the Microsoft ARM assembler). Once you have the file, you can add it to your
Makefile/project/whatever.


Adding to your project
----------------------

Compiling the .s or .asm (from previous step) for your target platform may require custom
build rules in your Makefile/project.

If you use some gcc-based toolchain, you will need to add Cyclone.o to an object list in
the Makefile. GNU make will use "as" to build Cyclone.o from Cyclone.s by default, so
you may need to define correct cross-assembler by setting AS variable like this:

AS = arm-linux-as

This might be different in your case, basically it should be same prefix as for gcc.
You may also need to specify floating point type in your assembler flags for Cyclone.o
to link properly. This is done like this:

ASFLAGS = -mfloat-abi=soft

Note that Cyclone does not use floating points, this is just to make the linker happy.


If you are using Visual Studio, you may need to add "custom build step", which creates
Cyclone.obj from Cyclone.asm (asmasm.exe Cyclone.asm). Alternatively you can create
Cyclone.obj by using armasm once and then just add it to you project.

Don't worry if this seem very minimal - its all you need to run as many 68000s as you want.
It works with both C and C++.


Byteswapped Memory
------------------

If you have used Starscream, A68K or Turbo68K or similar emulators you'll be familiar with this!

Any memory which the 68000 can access directly must be have every two bytes swapped around.
This is to speed up 16-bit memory accesses, because the 68000 has Big-Endian memory
and ARM has Little-Endian memory (in most cases).

Now you may think you only technically have to byteswap ROM, not RAM, because
16-bit RAM reads go through a memory handler and you could just return (mem[a]<<8) | mem[a+1].

This would work, but remember some systems can execute code from RAM as well as ROM, and
that would fail.
So it's best to use byteswapped ROM and RAM if the 68000 can access it directly.
It's also faster for the memory handlers, because you can do this:
  
  return *(unsigned short *)(mem+a)


Declaring Memory handlers
-------------------------

Before you can reset or execute 68000 opcodes you must first set up a set of memory handlers.
There are 7 functions you have to set up per CPU, like this:

  static unsigned int   MyCheckPc(unsigned int pc)
  static unsigned char  MyRead8  (unsigned int a)
  static unsigned short MyRead16 (unsigned int a)
  static unsigned int   MyRead32 (unsigned int a)
  static void MyWrite8 (unsigned int a,unsigned char  d)
  static void MyWrite16(unsigned int a,unsigned short d)
  static void MyWrite32(unsigned int a,unsigned int   d)

You can think of these functions representing the 68000's memory bus.
The Read and Write functions are called whenever the 68000 reads or writes memory.
For example you might set MyRead8 like this:

  unsigned char MyRead8(unsigned int a)
  {
    a&=0xffffff; // Clip address to 24-bits

    if (a<RomLength) return RomData[a^1]; // ^1 because the memory is byteswapped
    if (a>=0xe00000) return RamData[(a^1)&0xffff];
    return 0xff; // Out of range memory access
  }

The other 5 read/write functions are similar. I'll describe the CheckPc function later on.


Declaring a CPU Context
-----------------------

To declare a CPU simple declare a struct Cyclone in your code (don't forget to include Cyclone.h).
For example to declare two 68000s:

  struct Cyclone MyCpu;
  struct Cyclone MyCpu2;

It's probably a good idea to initialize the memory to zero:

  memset(&MyCpu, 0,sizeof(MyCpu));
  memset(&MyCpu2,0,sizeof(MyCpu2));

Next point to your memory handlers:

  MyCpu.checkpc=MyCheckPc;
  MyCpu.read8  =MyRead8;
  MyCpu.read16 =MyRead16;
  MyCpu.read32 =MyRead32;
  MyCpu.write8 =MyWrite8;
  MyCpu.write16=MyWrite16;
  MyCpu.write32=MyWrite32;

You also need to point the fetch handlers - for most systems out there you can just
point them at the read handlers:
  MyCpu.fetch8  =MyRead8;
  MyCpu.fetch16 =MyRead16;
  MyCpu.fetch32 =MyRead32;

( Why a different set of function pointers for fetch?
  Well there are some systems, the main one being CPS2, which return different data
  depending on whether the 'fetch' line on the 68000 bus is high or low.
  If this is the case, you can set up different functions for fetch reads.
  Generally though you don't need to. )

Now you are nearly ready to reset the 68000, except a few more functions,
one of them is: checkpc().


The checkpc() function
----------------------

When Cyclone reads opcodes, it doesn't use a memory handler every time, this would be
far too slow, instead it uses a direct pointer to ARM memory.
For example if your Rom image was at 0x3000000 and the program counter was $206,
Cyclone's program counter would be 0x3000206.

The difference between an ARM address and a 68000 address is also stored in a variable called
'membase'. In the above example it's 0x3000000. To retrieve the real 68k PC, Cyclone just
subtracts 'membase'.

When a long jump happens, Cyclone calls checkpc(). If the PC is in a different bank,
for example Ram instead of Rom, change 'membase', recalculate the new PC and return it:

static int MyCheckPc(unsigned int pc)
{
  pc-=MyCpu.membase; // Get the real program counter

  if (pc<RomLength) MyCpu.membase=(int)RomMem;          // Jump to Rom
  if (pc>=0xff0000) MyCpu.membase=(int)RamMem-0xff0000; // Jump to Ram

  return MyCpu.membase+pc; // New program counter
}

Notice that the membase is always ARM address minus 68000 address.

The above example doesn't consider mirrored ram, but for an example of what to do see
PicoDrive (in Memory.c).

The exact cases when checkpc() is called can be configured in config.h.


Initialization
--------------

Add a call to CycloneInit(). This is really only needed to be called once at startup
if you enabled COMPRESS_JUMPTABLE in config.h, but you can add this in any case,
it won't hurt.


Almost there - Reset the 68000!
-------------------------------

Cyclone doesn't provide a reset function, so next we need to Reset the 68000 to get
the initial Program Counter and Stack Pointer. This is obtained from addresses
000000 and 000004.

Here is code which resets the 68000 (using your memory handlers):

  MyCpu.state_flags=0; // Go to default state (not stopped, halted, etc.)
  MyCpu.srh=0x27; // Set supervisor mode
  MyCpu.a[7]=MyCpu.read32(0); // Get Stack Pointer
  MyCpu.membase=0; // Will be set by checkpc()
  MyCpu.pc=MyCpu.checkpc(MyCpu.read32(4)); // Get Program Counter

And that's ready to go.


Executing the 68000
-------------------

To execute the 68000, set the 'cycles' variable to the number of cycles you wish to execute,
and then call CycloneRun with a pointer to the Cyclone structure.

e.g.:
  // Execute 1000 cycles on the 68000:
  MyCpu.cycles=1000; CycloneRun(&MyCpu);

For each opcode, the number of cycles it took is subtracted and the function returns when
it reaches negative number. The result is stored back to MyCpu.cycles.

e.g.
  // Execute one instruction on the 68000:
  MyCpu.cycles=0; CycloneRun(&MyCpu);
  printf("  The opcode took %d cycles\n", -MyCpu.cycles);

You should try to execute as many cycles as you can for maximum speed.
The number actually executed may be slightly more than requested, i.e. cycles may come
out with a small negative value:

e.g.
  int todo=12000000/60; // 12Mhz, for one 60hz frame
  MyCpu.cycles=todo; CycloneRun(&MyCpu);
  printf("  Actually executed %d cycles\n", todo-MyCpu.cycles);

To calculate the number of cycles executed, use this formula:
  Number of cycles requested - Cycle counter at the end


Interrupts
----------

Causing an interrupt is very simple, simply set the irq variable in the Cyclone structure
to the IRQ number.
To lower the IRQ line, set it to zero.

e.g:
  MyCpu.irq=6; // Interrupt level 6
  MyCpu.cycles=20000; CycloneRun(&MyCpu);

Note that the interrupt is not actually processed until the next call to CycloneRun,
and the interrupt may not be taken until the 68000 interrupt mask is changed to allow it.

If you need to force interrupt processing, you can use CycloneFlushIrq() function.
It is the same as doing

MyCpu.cycles=0; CycloneRun(&MyCpu);

but is better optimized and doesn't update .cycles (returns them instead).
This function can't be used from memory handlers and has no effect if interrupt is masked.

The IRQ isn't checked on exiting from a memory handler. If you need to cause interrupt
check immediately, you should change cycle counter to 0 to cause a return from CycloneRun(),
and then call CycloneRun() again or just call CycloneFlushIrq(). Note that you need to
enable MEMHANDLERS_CHANGE_CYCLES in config.h for this to work.

If you need to do something during the interrupt acknowledge (the moment when interrupt
is taken), you can set USE_INT_ACK_CALLBACK in config.h and specify IrqCallback function.
This function should update the IRQ level (.irq variable in context) and return the
interrupt vector number. But for most cases it should return special constant
CYCLONE_INT_ACK_AUTOVECTOR so that Cyclone uses autovectors, which is what most real
systems were doing. Another less commonly used option is to return CYCLONE_INT_ACK_SPURIOUS
for spurious interrupt.


Accessing Program Counter and registers
---------------------------------------

You can read most Cyclone's registers directly from the structure at any time.
However, the PC value, CCR and cycle counter are cached in ARM registers and can't
be accessed from memory handlers by default. They are written back and can be
accessed after execution.

But if you need to access the mentioned registers during execution, you can set
MEMHANDLERS_NEED_* and MEMHANDLERS_CHANGE_* options in config.h

The Program Counter, should you need to read or write it, is stored with membase
added on. So use this formula to calculate the real 68000 program counter:

  pc = MyCpu.pc - MyCpu.membase;

For performance reasons Cyclone keeps the status register split into .srh
(status register "high" supervisor byte), .xc for the X flag, and .flags for remaining
CCR flags (in ARM order). To easily read/write the status register as normal 68k
16bit SR register, use CycloneGetSr() and CycloneSetSr() utility functions.


Emulating more than one CPU
---------------------------

Since everything is based on the structures, emulating more than one cpu at the same time
is just a matter of declaring more than one structures and timeslicing. You can emulate
as many 68000s as you want.
Just set up the memory handlers for each cpu and run each cpu for a certain number of cycles.

e.g.
  // Execute 1000 cycles on 68000 #1:
  MyCpu.cycles=1000; CycloneRun(&MyCpu);

  // Execute 1000 cycles on 68000 #2:
  MyCpu2.cycles=1000; CycloneRun(&MyCpu2);


Quick API reference
-------------------

void CycloneInit(void);
  Initializes Cyclone. Must be called if the jumptable is compressed,
  doesn't matter otherwise.

void CycloneRun(struct Cyclone *pcy);
  Runs cyclone for pcy->cycles. Writes amount of cycles left back to
  pcy->cycles (always negative).

unsigned int CycloneGetSr(const struct Cyclone *pcy);
  Reads status register in internal form from pcy, converts to standard 68k SR and returns it.

void CycloneSetSr(struct Cyclone *pcy, unsigned int sr);
  Takes standard 68k status register (sr), and updates Cyclone context with it.
  
int CycloneFlushIrq(struct Cyclone *pcy);
  If .irq is greater than IRQ mask in SR, or it is equal to 7 (NMI), processes interrupt
  exception and returns number of cycles used. Otherwise, does nothing and returns 0.

void CyclonePack(const struct Cyclone *pcy, void *save_buffer);
  Writes Cyclone state to save_buffer. This allows to avoid all the trouble figuring what
  actually needs to be saved from the Cyclone structure, as saving whole struct Cyclone
  to a file will also save various pointers, which may become invalid after your program
  is restarted, so simply reloading the structure will cause a crash. save_buffer size
  should be 128 bytes (now it is really using less, but this allows future expansion).

void CycloneUnpack(struct Cyclone *pcy, const void *save_buffer);
  Reloads Cyclone state from save_buffer, which was previously saved by CyclonePack().
  This function uses checkpc() callback to rebase the PC, so .checkpc must be initialized
  before calling it.

Callbacks:

.checkpc
unsigned int (*checkpc)(unsigned int pc);
  This function is called when PC changes are performed in 68k code or because of exceptions.
  It is passed ARM pointer and should return ARM pointer casted to int. It must also update
  .membase if needed. See "The checkpc() function" section above.

unsigned int (*read8  )(unsigned int a);
unsigned int (*read16 )(unsigned int a);
unsigned int (*read32 )(unsigned int a);
  These are the read memory handler callbacks. They are called when 68k code reads from memory.
  The parameter is a 68k address in data space, return value is a data value read. Data value
  doesn't have to be masked to 8 or 16 bits for read8 or read16, Cyclone will do that itself
  if needed.

unsigned int (*fetch8 )(unsigned int a);
unsigned int (*fetch16)(unsigned int a);
unsigned int (*fetch32)(unsigned int a);
  Same as above, but these are reads from program space (PC relative reads mostly).
 
void (*write8 )(unsigned int a,unsigned char  d);
void (*write16)(unsigned int a,unsigned short d);
void (*write32)(unsigned int a,unsigned int   d);
  These are called when 68k code writes to data space. d is the data value.

int (*IrqCallback)(int int_level);
  This function is called when Cyclone acknowledges an interrupt. The parameter is the IRQ
  level being acknowledged, and return value is exception vector to use, or one of these special
  values: CYCLONE_INT_ACK_AUTOVECTOR or CYCLONE_INT_ACK_SPURIOUS. Can be disabled in config.h.
  See "Interrupts" section for more information.

void (*ResetCallback)(void);
  Cyclone will call this function if it encounters RESET 68k instruction.
  Can be disabled in config.h.

int (*UnrecognizedCallback)(void);
  Cyclone will call this function if it encounters illegal instructions (including A-line and
  F-line ones). Can be tuned / disabled in config.h.


Function codes
--------------

Cyclone doesn't pass function codes to it's memory handlers, but they can be calculated:
FC2: just use supervisor state bit from status register (eg. (MyCpu.srh & 0x20) >> 5)
FC1: if we are in fetch* function, then 1, else 0.
FC0: if we are in read* or write*, then 1, else 0.
CPU state (all FC bits set) is active in IrqCallback function.


References
----------

These documents were used while writing Cyclone and should be useful for those who want to
understand deeper how the 68000 works.

MOTOROLA M68000 FAMILY Programmer's Reference Manual
common name: 68kPM.pdf

M68000 8-/16-/32-Bit Microprocessors User's Manual
common name: MC68000UM.pdf

68000 Undocumented Behavior Notes by Bart Trzynadlowski
http://www.trzy.org/files/68knotes.txt

Instruction prefetch on the Motorola 68000 processor by Jorge Cwik
http://pasti.fxatari.com/68kdocs/68kPrefetch.html


ARM Register Usage
------------------

See source code for up to date of register usage, however a summary is here:

  r0-3: Temporary registers
  r4  : Current PC + Memory Base (i.e. pointer to next opcode)
  r5  : Cycles remaining
  r6  : Pointer to Opcode Jump table
  r7  : Pointer to Cpu Context
  r8  : Current Opcode
  r10 : Flags (NZCV) in highest four bits
 (r11 : Temporary register)

Flags are mapped onto ARM flags whenever possible, which speeds up the processing of opcode.
r9 is not used intentionally, because AAPCS defines it as "platform register", so it's
reserved in some systems.


Thanks to...
------------

* All the previous code-generating assembler cpu core guys!
  Who are iirc... Neill Corlett, Neil Bradley, Mike Coates, Darren Olafson
    Karl Stenerud and Bart Trzynadlowski

* Charles Macdonald, for researching just about every console ever
* MameDev+FBA, for keeping on going and going and going


What's New
----------
v0.0099
  * Cyclone no longer uses r9, because AAPCS defines it as "platform register",
    so it's reserved in some systems.
  * Made SPLIT_MOVEL_PD to affect MOVEM too.

v0.0088
  - Reduced amount of code in opcode handlers by ~23% by doing the following:
    - Removed duplicate opcode handlers
    - Optimized code to use less ARM instructions
    - Merged some duplicate handler endings
  + Cyclone now does better job avoiding pipeline interlocks.
  + Replaced incorrect handler of DBT with proper one.
  + Changed "MOVEA (An)+ An" behavior.
  + Fixed flag behavior of ROXR, ASL, LSR and NBCD in certain situations.
    Hopefully got them right now.
  + Cyclone no longer sets most significant bits while pushing PC to stack.
    Amiga Kickstart depends on this.
  + Added optional trace mode emulation.
  + Added optional address error emulation.
  + Additional functionality added for MAME and other ports (see config.h).
  + Added return value for IrqCallback to make it suitable for emulating devices which
    pass the vector number during interrupt acknowledge cycle. For usual autovector
    processing this function must return CYCLONE_INT_ACK_AUTOVECTOR, so those who are
    upgrading must add "return CYCLONE_INT_ACK_AUTOVECTOR;" to their IrqCallback functions.
  * Updated documentation.

v0.0086
  + Cyclone now can be customized to better suit your project, see config.h .
  + Added an option to compress the jumptable at compile-time. Must call CycloneInit()
    at runtime to decompress it if enabled (see config.h).
  + Added missing CHK opcode handler (used by SeaQuest DSV).
  + Added missing TAS opcode handler (Gargoyles,Bubba N Stix,...). As in real genesis,
    memory write-back phase is ignored (but can be enabled in config.h if needed).
  + Added missing NBCD and TRAPV opcode handlers.
  + Added missing addressing mode for CMP/EOR.
  + Added some minor optimizations.
  - Removed 216 handlers for 2927 opcodes which were generated for invalid addressing modes.
  + Fixed flags for ASL, NEG, NEGX, DIVU, ADDX, SUBX, ROXR.
  + Bugs fixed in MOVEP, LINK, ADDQ, DIVS handlers.
  * Undocumented flags for CHK, ABCD, SBCD and NBCD are now emulated the same way as in Musashi.
  + Added Uninitialized Interrupt emulation.
  + Altered timing for about half of opcodes to match Musashi's.

v0.0082
  + Change cyclone to clear cycles before returning when halted
  + Added Irq call back function.  This allows emulators to be notified
    when cyclone has taken an interrupt allowing them to set internal flags
    which can help fix timing problems.

v0.0081
  + .asm version was broken and did not compile with armasm. Fixed.
  + Finished implementing Stop opcode. Now it really stops the processor.

v0.0080
  + Added real cmpm opcode, it was using eor handler before this.
    Fixes Dune and Sensible Soccer.

v0.0078
  note: these bugs were actually found Reesy, I reimplemented these by
        using his changelog as a guide.
  + Fixed a problem with divu which was using long divisor instead of word.
    Fixes gear switching in Top Gear 2.
  + Fixed btst opcode, The bit to test should shifted a max of 31 or 7
    depending on if a register or memory location is being tested.
  + Fixed abcd,sbcd. They did bad decimal correction on invalid BCD numbers
    Score counters in Streets of Rage level end work now.
  + Changed flag handling of abcd,sbcd,addx,subx,asl,lsl,...
    Some ops did not have flag handling at all.
    Some ops must not change Z flag when result is zero, but they did.
    Shift ops must not change X if shift count is zero, but they did.
    There are probably still some flag problems left.
  + Patially implemented Stop and Reset opcodes - Fixes Thunderforce IV

v0.0075
  + Added missing displacement addressing mode for movem (Fantastic Dizzy)
  + Added OSP <-> A7 swapping code in opcodes, which change privilege mode
  + Implemented privilege violation, line emulator and divide by zero exceptions
  + Added negx opcode (Shining Force works!)
  + Added overflow detection for divs/divu

v0.0072
  note: I could only get v0.0069 cyclone, so I had to implement these myself using Dave's
        changelog as a guide.
  + Fixed a problem with divs - remainder should be negative when divident is negative
  + Added movep opcode (Sonic 3 works)
  + Fixed a problem with DBcc incorrectly decrementing if the condition is true (Shadow of the Beast)

v0.0069
  + Added SBCD and the flags for ABCD/SBCD. Score and time now works in games such as
    Rolling Thunder 2, Ghouls 'N Ghosts
  + Fixed a problem with addx and subx with 8-bit and 16-bit values.
    Ghouls 'N' Ghosts now works!

v0.0068
  + Added ABCD opcode (Streets of Rage works now!)

v0.0067
  + Added dbCC (After Burner)
  + Added asr EA (Sonic 1 Boss/Labyrinth Zone)
  + Added andi/ori/eori ccr (Altered Beast)
  + Added trap (After Burner)
  + Added special case for move.b (a7)+ and -(a7), stepping by 2
    After Burner is playable! Eternal Champions shows more
  + Fixed lsr.b/w zero flag (Ghostbusters)
    Rolling Thunder 2 now works!
  + Fixed N flag for .b and .w arithmetic. Golden Axe works!

v0.0066
  + Fixed a stupid typo for exg (orr r10,r10, not orr r10,r8), which caused alignment
    crashes on Strider

v0.0065
  + Fixed a problem with immediate values - they weren't being shifted up correctly for some
    opcodes. Spiderman works, After Burner shows a bit of graphics.
  + Fixed a problem with EA:"110nnn" extension word. 32-bit offsets were being decoded as 8-bit
    offsets by mistake. Castlevania Bloodlines seems fine now.
  + Added exg opcode
  + Fixed asr opcode (Sonic jumping left is fixed)
  + Fixed a problem with the carry bit in rol.b (Marble Madness)

v0.0064
  + Added rtr
  + Fixed addq/subq.l (all An opcodes are 32-bit) (Road Rash)
  + Fixed various little timings

v0.0063
  + Added link/unlk opcodes
  + Fixed various little timings
  + Fixed a problem with dbCC opcode being emitted at set opcodes
  + Improved long register access, the EA fetch now does ldr r0,[r7,r0,lsl #2] whenever
     possible, saving 1 or 2 cycles on many opcodes, which should give a nice speed up.
  + May have fixed N flag on ext opcode?
  + Added dasm for link opcode.

v0.0062
  * I was a bit too keen with the Arithmetic opcodes! Some of them should have been abcd,
    exg and addx. Removed the incorrect opcodes, pending re-adding them as abcd, exg and addx.
  + Changed unknown opcodes to act as nops.
    Not very technical, but fun - a few more games show more graphics ;)

v0.0060
  + Fixed divu (EA intro)
  + Added sf (set false) opcode - SOR2
  * Todo: pea/link/unlk opcodes

v0.0059: Added remainder to divide opcodes.


