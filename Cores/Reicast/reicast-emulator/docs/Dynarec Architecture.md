Import from skmp's old dead blog, https://web.archive.org/web/20110812025705/http://drk.emudev.org:80/blog/?page_id=18

Dynarec Architecture
===

Design document for the rec_v2 dynarec. This is WIP but i’m bored so i’l make it public :)

The rec_v2 dynarec is designed to be modular and require minimum work for porting to different host cpus. Its also designed to be simple (simpler than v1x) to allow for simpler optimization passes and for relatively easy mitigation to ssa-based model. For reference both v1 and v2 are based on an IL that is kinda independent from both the source and destination arch (i’l call it shil from now on).

Some history first
---

The original rec_v1 for mainline was designed for translation to x86 (and only that). The shil opcodes are more-or-less x86 opcodes but use sh4 registers. Flags can be saved/set with two opcodes (SaveT and LoadT) to the T register using any of the SetCC conditions. Other special opcodes are memory opcodes. These were expanded to memory moves/calls depending on a 16bit lookup table after calculating the memory address.Loads from known memory addresses were converted to direct calls/moves depending on their location. Register allocation was dynamic for 4 registers (ebp,esi,edi,ebx) and fixed for the entire block. This was the dynarec used on the nullDC 1.0.0 beta 1 release.

For nullDC 1.0.0 b1.5/1.6 rec_v1x (x for extended :p) was used. It had a much more complex memory mapping scheme allowing for direct (no-lookup) memory access for any buffer mapped (ram/vram/aram). It also included code to more accurately detect memory constants and convert em to direct moves, as well as memory opcode ‘patching’ using exceptions to ensure correct logical flow in the case on an unpredicted memory access. X86 page protection and windows file mapping were the base for all that stuff. There were also many other fixes and optimizations such as the addition of a multilevel call stack cache, indirect jump/calls multilevel prediction and other fun stuff, mainly targeting the ‘glue’ code of the dynarec.Also a lot of fat was cut down from the block prologue/epilogue (like not loading registers when their initial value isn’t writen, smaller code for interrupt checks, etc)

nullDC 1.0.3 used r1x with some more work to implement more sh4 opcodes (like pref for faster SQ writebacks) and some heuristics to detect blocks that didn’t work with constant-memory-read-to-constant forwarding.As far as i remember there weren’t any remarkable changes apart from that :p

nullDC 1.0.4 added support for block relocation to better utilize/organize dynarec memory

Some good things about v1/v1x
---
- It is fast. On a core2-level cpu it gets 1:7 to 1:1.2 sh4:x86 cycle ratio.It generates about 30 bytes per sh4 opcode (including all linking/block overhead). The x86 code executes at around 1.2 opcodes per cycle.
- It is fairly compact and modular (~ 3k lines for the il compiler, around 10k lines for most of the important code). Its logically organised into the block manager, the dynarec driver, the sh4 analyzer/decoder, the optimizer and the il-compiler. It also supports super-blocks and hot-spot detection but these features were never used.
- A full block graph is used so blocks can be easily and safely removed undoing any static linking between em :)
- Full support for loaded/smc code with page protection and block verification (similar to the system i implemented for pcsx2)

Some bad things
---
- It's modeled around x86 (ie, x86 flags are supported and can be accessed any time with the SaveT/LoadT opcodes). While this allows a cheap way to generate fast code it makes interpretation of the IL almost impossible.It also makes porting to flag-less cpu architectures much much much much harder.
- It’s not as compact as it could be
- It doesn’t provide a fallback for its opcodes
- It doesn’t use 3-way opcodes (these can simplify optimization a lot on the IL level)
- The full block graph is a bit memory intesive

When the psp port started there was the need for some dynarec that could easyly run on both x86 and mips and share as much code as possible to catch bugs on the easy & nice development platofrm (pc). This after some rewrites resulted to the rec_v2 as it is presented on this document :)

rec_v2 features
---
- A very modular design (frontend/decoder are data driven, the block manager is simple, the compiler is tiny)
- ALL platform dependant code is isolated with the ngen interface (native generator)
- There is no block graph or block descriptors, each address is mapped to a single code pointer.
- Heuristic based support for code modifications, as well as icache flush support. Single block invalidation isn’t possible leading to a much simpler model for the dynarec
- A default implementation for most of the dynarec opcodes (only 7 opcodes _must_ be provided natively)
- All opcodes have fixed input and output fields, with full description on which physical registers they use so data flow computation is simple.
- Support for x86, mips, Cortex-A8 and powerpc !

Well, there are a few drawbacks to the design as wel
---
- Block modification needs special detection for some games (like Doa2le)
- The dynarec cache can be flushed only ‘at once’ and not at block level. This isn’t usualy a problem
- It’s nowhere as complete as rec_v1 (but its slowly getting there !)
- It’s noticeably slower than rec_v1, up to 3x on some points. Build in idle loop detection makes that problem less visible and more work on the opcodes will make it faster

The shil format
---
Shil (for sh il) is the fully ‘expanded’ form of the opcodes that the dynarec uses internally. Its a simple struct with 2 possible outputs (rd and rd1) and 3 possible inputs (rs1,rs2,rs3). Each input can be an register or a 32 bit imm. Currently there are C implementations for almost all the shil opcodes (only 7 opcodes are required to be implemented by the ngen backend).There were in total 36 shil opcodes last time i counted em ;)

Sh4 decoder (dec_*)
---
The sh4 decoder gets a stream of sh4 opcodes and converts em to shil. The decoder supports both ‘native’ opcodes (they have a function to handle the translation) and a data driven mapping (this part is really hacky). The decoder currently stops at a branch or when a maximum amount of cycles is reached. While the code is a bit overcomplicated the uglyness is self-contained as the shil format is fairly clean and nice :)

Shil optimiser
---
The shil optimiser gets the block as output from the decoder and performs some basic optimisations.Currently it only does dead code elimination.

Native generator/Shil compiler (ngen_*)
---
The compiler is invoked to compile a block after it has been processed by the optimiser. The compiler is isolated from the rest of the code with the ngen interface (ngen_* are supplied by each dynarec implementation). It communicates with the dynarec driver and the block manager to complete the task. The compiler usualy consists of a case() to implement the opcodes, some code to handle block header/footer, glue code for the dynarec driver and the dynarec mainloop. This is the only cpu isa depedant part of the dynarec.

Currently the x86 implementation is around 900 lines, the psp one 1300 (but includes a lot of emitter helpers) the arm one around 600 (but misses many opcodes) and ppc around 400 (but its not working reliably yet)

Block Manager (bm_*)
---
The block manager is repsosible for keeping the sh4 addr <-> code mappings and replying to queries about em to the dynarec code. It has a full implementation in C but some parts can be also implemented as part of the dynarec loop to improve performance. Right now it uses cached hashed lists to do the mappings. While the bm is fairly fast (the cache takes care of that) the big idea is that it shound’t be used a lot as extensibe prediction can remove most of the queries :)

Dynarec Driver (rdv_*)
---
Its the small glue code that ‘drives’ the emulation and provides functions needed by the ngen interface. Generally any function that doesn’t belong clearly to one of the other parts and it is portable across all shil compilers ends up in here :) 
