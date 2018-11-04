                                    MUSASHI
                                    =======

                                  Version 3.4

             A portable Motorola M680x0 processor emulation engine.
            Copyright 1998-2002 Karl Stenerud.  All rights reserved.



INTRODUCTION:
------------

Musashi is a Motorola 68000, 68010, 68EC020, and 68020 emulator written in C.
This emulator was written with two goals in mind: portability and speed.

The emulator is written to ANSI C89 specifications.  It also uses inline
functions, which are C9X compliant.

It has been successfully running in the MAME project (www.mame.net) for years
and so has had time to mature.



LICENSE AND COPYRIGHT:
---------------------

Copyright © 1998-2001 Karl Stenerud

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.



AVAILABILITY:
------------
The latest version of this code can be obtained at:
https://github.com/kstenerud/Musashi



CONTACTING THE AUTHOR:
---------------------
I can be reached at kstenerud@gmail.com



BASIC CONFIGURATION:
-------------------
The basic configuration will give you a standard 68000 that has sufficient
functionality to work in a primitive environment.

This setup assumes that you only have 1 device interrupting it, that the
device will always request an autovectored interrupt, and it will always clear
the interrupt before the interrupt service routine finishes (but could
possibly re-assert the interrupt).
You will have only one address space, no tracing, and no instruction prefetch.

To implement the basic configuration:

- Open m68kconf.h and verify that the settings for INLINE will work with your
  compiler. (Currently set to "static __inline__", which works in gcc 2.9.
  For C9X compliance, it should be "inline")

- In your host program, implement the following functions:
    unsigned int  m68k_read_memory_8(unsigned int address);
    unsigned int  m68k_read_memory_16(unsigned int address);
    unsigned int  m68k_read_memory_32(unsigned int address);
    void m68k_write_memory_8(unsigned int address, unsigned int value);
    void m68k_write_memory_16(unsigned int address, unsigned int value);
    void m68k_write_memory_32(unsigned int address, unsigned int value);

- In your host program, be sure to call m68k_pulse_reset() once before calling
  any of the other functions as this initializes the core.

- Use m68k_execute() to execute instructions and m68k_set_irq() to cause an
  interrupt.



ADDING PROPER INTERRUPT HANDLING:
--------------------------------
The interrupt handling in the basic configuration doesn't emulate the
interrupt acknowledge phase of the CPU and automatically clears an interrupt
request during interrupt processing.
While this works for most systems, you may need more accurate interrupt
handling.

To add proper interrupt handling:

- In m68kconf.h, set M68K_EMULATE_INT_ACK to OPT_SPECIFY_HANDLER

- In m68kconf.h, set M68K_INT_ACK_CALLBACK(A) to your interrupt acknowledge
  routine

- Your interrupt acknowledge routine must return an interrupt vector,
  M68K_INT_ACK_AUTOVECTOR, or M68K_INT_ACK_SPURIOUS.  most m68k
  implementations just use autovectored interrupts.

- When the interrupting device is satisfied, you must call m68k_set_irq(0) to
  remove the interrupt request.



MULTIPLE INTERRUPTS:
-------------------
The above system will work if you have only one device interrupting the CPU,
but if you have more than one device, you must do a bit more.

To add multiple interrupts:

- You must make an interrupt arbitration device that will take the highest
  priority interrupt and encode it onto the IRQ pins on the CPU.

- The interrupt arbitration device should use m68k_set_irq() to set the
  highest pending interrupt, or 0 for no interrupts pending.



SEPARATE IMMEDIATE READS:
------------------------
You can write faster memory access functions if you know whether you are
fetching from ROM or RAM.  Immediate reads are always from the program space
(Always in ROM unless it is running self-modifying code).

To enable separate immediate reads:

- In m68kconf.h, turn on M68K_SEPARATE_READ_IMM.

- In your host program, implement the following functions:
    unsigned int  m68k_read_immediate_16(unsigned int address);
    unsigned int  m68k_read_immediate_32(unsigned int address);

- If you need to know the current PC (for banking and such), set
  M68K_MONITOR_PC to OPT_SPECIFY_HANDLER, and set M68K_SET_PC_CALLBACK(A) to
  your routine.



ADDRESS SPACES:
--------------
Most systems will only implement one address space, placing ROM at the lower
addresses and RAM at the higher.  However, there is the possibility that a
system will implement ROM and RAM in the same address range, but in different
address spaces.

In this case, you might get away with assuming that immediate reads are in the
program space and all other reads are in the data space, if it weren't for the
fact that the exception vectors are fetched from the data space.  As a result,
anyone implementing this kind of system will have to copy the vector table
from ROM to RAM using pc-relative instructions.

This makes things bad for emulation, because this means that a non-immediate
read is not necessarily in the data space.
The m68k deals with this by encoding the requested address space on the
function code pins:

                       FC
    Address Space      210
    ------------------ ---
    USER DATA          001
    USER PROGRAM       010
    SUPERVISOR DATA    101
    SUPERVISOR PROGRAM 110
    CPU SPACE          111 <-- not emulated in this core since we emulate
                               interrupt acknowledge in another way.

To emulate the function code pins:

- In m68kconf.h, set M68K_EMULATE_FC to OPT_SPECIFY_HANDLER and set
  M68K_SET_FC_CALLBACK(A) to your function code handler function.

- Your function code handler should select the proper address space for
  subsequent calls to m68k_read_xx (and m68k_write_xx for 68010+).

Note: immediate reads are always done from program space, so technically you
      don't need to implement the separate immediate reads, although you could
      gain more speed improvements leaving them in and doing some clever
      programming.



USING DIFFERENT CPU TYPES:
-------------------------
The default is to enable only the 68000 cpu type.  To change this, change the
settings for M68K_EMULATE_010 etc in m68kconf.h.

To set the CPU type you want to use:

- Make sure it is enabled in m68kconf.h.  Current switches are:
    M68K_EMULATE_010
    M68K_EMULATE_EC020
    M68K_EMULATE_020

- In your host program, call m68k_set_cpu_type() and then call
  m68k_pulse_reset().  Valid CPU types are:
    M68K_CPU_TYPE_68000,
    M68K_CPU_TYPE_68010,
    M68K_CPU_TYPE_68EC020,
    M68K_CPU_TYPE_68020



CLOCK FREQUENCY:
---------------
In order to emulate the correct clock frequency, you will have to calculate
how long it takes the emulation to execute a certain number of "cycles" and
vary your calls to m68k_execute() accordingly.
As well, it is a good idea to take away the CPU's timeslice when it writes to
a memory-mapped port in order to give the device it wrote to a chance to
react.

You can use the functions m68k_cycles_run(), m68k_cycles_remaining(),
m68k_modify_timeslice(), and m68k_end_timeslice() to do this.
Try to use large cycle values in your calls to m68k_execute() since it will
increase throughput.  You can always take away the timeslice later.



MORE CORRECT EMULATION:
----------------------
You may need to enable these in order to properly emulate some of the more
obscure functions of the m68k:

- M68K_EMULATE_BKPT_ACK causes the CPU to call a breakpoint handler on a BKPT
  instruction

- M68K_EMULATE_TRACE causes the CPU to generate trace exceptions when the
  trace bits are set

- M68K_EMULATE_RESET causes the CPU to call a reset handler on a RESET
  instruction.

- M68K_EMULATE_PREFETCH emulates the 4-word instruction prefetch that is part
  of the 68000/68010 (needed for Amiga emulation).
  NOTE: if the CPU fetches a word or longword at an odd address when this
  option is on, it will yield unpredictable results, which is why a real
  68000 will generate an address error exception.

- M68K_EMULATE_ADDRESS_ERROR will cause the CPU to generate address error
  exceptions if it attempts to read a word or longword at an odd address.

- call m68k_pulse_halt() to emulate the HALT pin.



CONVENIENCE FUNCTIONS:
---------------------
These are in here for programmer convenience:

- M68K_INSTRUCTION_HOOK lets you call a handler before each instruction.

- M68K_LOG_ENABLE and M68K_LOG_1010_1111 lets you log illegal and A/F-line
  instructions.



MULTIPLE CPU EMULATION:
----------------------
The default is to use only one CPU.  To use more than one CPU in this core,
there are some things to keep in mind:

- To have different cpus call different functions, use OPT_ON instead of
  OPT_SPECIFY_HANDLER, and use the m68k_set_xxx_callback() functions to set
  your callback handlers on a per-cpu basis.

- Be sure to call set_cpu_type() for each CPU you use.

- Use m68k_set_context() and m68k_get_context() to switch to another CPU.



LOAD AND SAVE CPU CONTEXTS FROM DISK:
------------------------------------
You can use them68k_load_context() and m68k_save_context() functions to load
and save the CPU state to disk.



GET/SET INFORMATION FROM THE CPU:
--------------------------------
You can use m68k_get_reg() and m68k_set_reg() to gain access to the internals
of the CPU.



EXAMPLE:
-------

The subdir example contains a full example (currently DOS only).
