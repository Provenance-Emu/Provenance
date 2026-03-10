************************************************
*                                              *
*     CZ80 (Z80 CPU emulator) version 0.91     *
*          Compiled with Dev-C++               *
*  Copyright 2004-2005 Stéphane Dallongeville  *
*                                              *
************************************************

CZ80 is a Z80 CPU emulator, priorities were given to :
- code size
- speed
- accuracy
- portablity

It supports almost all undocumented opcodes and flags.

The emulator can be freely distribued and used for any non commercial
project as long you don't forget to credit me somewhere :)
If you want some support about the CZ80, you can contact me on
the Gens forum (http://gens.consolemul.com then go to the forum).


You should find the following files in the emulation pack :
- cz80.h          -> header file (prototypes, declarations...)
- cz80.c          -> contains emulation core itself
- cz80.inc        -> contains most used macros
- cz80jmp.inc     -> Jump table definition when Jump Table used
- cz80exec.inc    -> contains the major Cz80_Exec(...) function
- cz80_op.inc     -> contains code for simple Z80 opcodes emulation
- cz80_opCB.inc   -> contains code for CB prefixed Z80 opcodes emulation
- cz80_opED.inc   -> contains code for ED prefixed Z80 opcodes emulation
- cz80_opXY.inc   -> contains code for DD/FD prefixed Z80 opcodes emulation
- cz80_opXYCB.inc -> contains code for DD/FD + CB prefixed Z80 opcodes emulation
- readme.txt      -> the current file you're reading ;)


* How compile the emulator ?
****************************

The emulator has been written with Dev-CPP 4.9.X.X
You will maybe need to modify the u8, u16, u32, s8, s16, s32 and FASTCALL
definitions (cz80.h) according to your C compiler and the target system.
Then compile the cz80.c file, you should obtain a cz80.o (or cz80.obj) file...
at this moment, you're ready to use the emulator just by linking the file in your project :)


* How to use the emulator ?
***************************

1) Include the header file in your source :
------------------------------------------

#include "cz80.h"


2) Init the CZ80 core :
-----------------------

If you want to use the internal CZ80 context offered :

  Cz80_Init(&CZ80);

but you can also define your own CZ80 context :

  cz80_struc My_Z80;

  ....

  Cz80_Init(&My_Z80);


You'll can emulate as many Z80 CPU as you want by defining severals CZ80 contexts.


3) Set up your fetch region (where the Z80 will run code from) :
----------------------------------------------------------------

  Cz80_Set_Fetch(&CZ80, 0x0000, 0x7FFF, (u32) your_ROM);
  Cz80_Set_Fetch(&CZ80, 0xA000, 0xFFFF, (u32) your_RAM);
  ...


4) Set up your memory (where the Z80 will read and write data) :
----------------------------------------------------------------

  Cz80_Set_ReadB(&CZ80, your_z80readbyte_function);
  Cz80_Set_WriteB(&CZ80, your_z80readbyte_function);

You can improve CZ80 performance by using WORD read/write function.
For that, you need to enable the 'CZ80_USE_WORD_HANDLER' define in cz80.h file.
In this case, you'll need to add that :

#if CZ80_USE_WORD_HANDLER
  Cz80_Set_ReadW(&CZ80, your_z80readword_function);
  Cz80_Set_WriteW(&CZ80, your_z80readword_function);
#endif

Your read function need to be of CZ80_READ type :
typedef u32  FASTCALL CZ80_READ(u32 adr);

Your write function need to be of CZ80_WRITE type :
typedef void FASTCALL CZ80_WRITE(u32 adr, u32 data);


5) Set Up your port (where the Z80 will read and write IO data) :
-----------------------------------------------------------------

  Cz80_Set_INPort(&CZ80, your_z80readport_function);
  Cz80_Set_OUTPort(&CZ80, your_z80writport_function);

Your readPort function need to be of CZ80_READ type :
typedef u32  FASTCALL CZ80_READ(u32 adr);

Your writePort function need to be of CZ80_WRITE type :
typedef void FASTCALL CZ80_WRITE(u32 adr, u32 data);


6) Set Up your interrupt callback function :
--------------------------------------------

  Cz80_Set_IRQ_Callback(&CZ80, your_z80irqcallback_function);

Your IRQ callback function need to be of CZ80_INT_CALLBACK type :
typedef s32  FASTCALL CZ80_INT_CALLBACK(s32 param);

If you don't understand what i am talking about here, just ignore...
it's not needed in almost case.


6) Set Up your RETI callback function :
---------------------------------------

  Cz80_Set_RETI_Callback(&CZ80, your_z80reticallback_function);

Your RETI callback function need to be of CZ80_RETI_CALLBACKtype :
typedef void FASTCALL CZ80_RETI_CALLBACK();

Again, if you don't understand what i am talking about here, ignore...


7) Reset the CZ80 core before fisrt use :
-----------------------------------------

  Cz80_Reset(&CZ80);


8) Do some cycles :
-------------------

Then it's time to really do some work, if you want to execute 1000 cycles, just do :

  cycles_done = Cz80_Exec(&CZ80, 1000);

Cz80_Exec function return the number of cycles actually done.
Since each instruction take more than 1 cycle, Cz80_Exec will execute a bit more than
you requested, for instance here, it can return 1008 cycles instead of 1000.
In this case, adjust the number of cycle to do like that :

  cycles_by_frame = 4800;
  extra_cycles = 0;
  while (true)
  {
     ...
     extra_cycles = CZ80_Exec(&CZ80, cycles_by_frame - extra_cycles) - cycles_by_frame;
     ...
  }

If Cz80_Exec returns a negatif value, an error occured.


9) Do an interrupt request :
----------------------------

  Cz80_Set_IRQ(&CZ80, 0);

or for a NMI :

  Cz80_Set_NMI(&CZ80);


10) Cancel an interrupt request :
---------------------------------

  Cz80_Clear_IRQ(&CZ80);

or for a NMI :

  Cz80_Clear_NMI(&CZ80);



* Switchs
*********

There are severals switchs in the cz80.h file which permit you to configure
CZ80 depending your needs.

- CZ80_FETCH_BITS (default = 4)

This defines the number of bits to select fetch region.
This value must be 4 <= X <= 12
Greater value offers permit to have more fetch region.
In almost case, 4 is enough, but if you have fetch region smaller than 0x1000 bytes,
increase this value.

- CZ80_LITTLE_ENDIAN

Define the endianess of the target platform.
x86 CPU use Little Endian.

- CZ80_USE_JUMPTABLE

Set it to 1 to use Jump table instead of big case statement.
This can bring some small speed improvemen.
Be careful, some compiler doesn't support (computed label) so it's
saffer to not use it.

- CZ80_SIZE_OPT

Add some extras optimisation for the code size versus speed.
Minor changes anyway...

- CZ80_USE_WORD_HANDLER

See the "Set Up Memory" section for more détail.

- CZ80_EXACT

Enable accurate emulation of extended undocumented opcode and flags.
minor speed decrease when activated.
Even without that flag, CZ80 is already uite accurate, keep it
disable unless you need it or if speed isn't important for you.

- CZ80_DEBUG

Used by me, keep it disable :p



* History
*********

Version 0.90 :
--------------

* Initial release for debugging purpose ^^
