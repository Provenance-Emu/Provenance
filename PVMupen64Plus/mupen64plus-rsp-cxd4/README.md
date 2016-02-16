# Vector Technology as Implemented for Use with a RISC and SIMD Technology Signal Processor
A vector processor uses long registers addressable by segment-precision, where each segment is _n_ bits wide.  The power of a vector processor is that many complex matrix operations, whose algorithms take many scalar CPU instructions and clock cycles to emulate on a regular, personal computer processor, can often times formulate and transfer the correct result in less than a single clock cycle.  The impossibility to replicate this precise behavior has paved the way for vendor businesses to protect their systems against hardware emulation since the introduction of display devices rendering three-dimensional graphics.  The Nintendo 64 was the first video game system to employ this convenience to their advantage.
***

## Project Reality's Signal Processor

In the engineering make-up of the Nintendo 64 (original codename:  Project Reality) is a modified MIPS family revision 4000 co-processor called the "Reality Coprocessor" (RCP).  More importantly, the signal processor in this component is responsible for all vector memory operations and transactions, which are almost all impossible to emulate with full accuracy on a scalar, personal computer processor.  The vector technology implemented into this design is that accepted from Silicon Graphics, Inc.

### RSP Vector Operation Matrices

Here, the entire MIPS R4000 instruction set was modified for very fast, exception-free processing flow, and operation definitions for each instruction do not fall within the scope of this section.  Presented instead are layouts of the new instructions added to the scalar unit (those under `LWC2` and `SWC2`, even though they do interface with the vector unit) and the vector unit (essentially, any instruction under `COP2` whose mnemonic starts with a 'V').  Information of how pre-existing MIPS R4000 instructions were modified or which ones were removed is the adventure of the MIPS programmer to research.

`C2` _vd_, _vs_, _vt_[_element_] `/* exceptions:  scalar divide reads */`

|  COP2  | element |  vs1  |  vs2  |  vt   |  func  |
| ------ |:-------:| ----- | ----- | ----- | ------ |
|`010010`| `1eeee` |`ttttt`|`sssss`|`ddddd`|`??????`|

The major types of VU computational instructions are _multiply,_ _add,_ _select,_ _logical,_ and _divide._

Multiply instructions are the most frequent and classifiable as follows:

* If `a == 0`, then round the product loaded to the accumulator (`VMUL*` and `VMUD*`).
* If `a == 1`, then the product is added to an accumulator element (`VMAC*` and `VMAD*`).
* If `(format & 0b100) == 0`, then the operation is single-precision (`VMUL*` and `VMAC*`).
* If `(format & 0b100) != 0`, then the operation is double-precision (`VMUD*` and `VMAD*`).

|_op-code_|   Type   |
| -------:| -------- |
| `00axxx`| multiply |
| `01xxxx`| add      |
| `100xxx`| select   |
| `101xxx`| logical  |
| `110xxx`| divide   |

* `00 (VMULF)` Vector Multiply Signed Fractions
* `01 (VMULU)` Vector Multiply Unsigned Fractions
* `02 reserved` `VRNDP` was intended for MPEG DCT rounding but omitted.
* `03 reserved` `VMULQ` was intended for MPEG inverse quantization but omitted.
* `04 (VMUDL)` Vector Multiply Low Partial Products
* `05 (VMUDM)` Vector Multiply Mid Partial Products
* `06 (VMUDN)` Vector Multiply Mid Partial Products
* `07 (VMUDH)` Vector Multiply High Partial Products
* `10 (VMACF)` Vector Multiply-Accumulate Signed Fractions
* `11 (VMACU)` Vector Multiply-Accumulate Unsigned Fractions
* `12 reserved` `VRNDN` was intended for MPEG DCT rounding but omitted.
* `13 (VMACQ)` Vector Accumulator Oddification
* `14 (VMADL)` Vector Multiply-Accumulate Low Partial Products
* `15 (VMADM)` Vector Multiply-Accumulate Mid Partial Products
* `16 (VMADN)` Vector Multiply-Accumulate Mid Partial Products
* `17 (VMADH)` Vector Multiply-Accumulate High Partial Products
* `20 (VADD)` Vector Add Short Elements
* `21 (VSUB)` Vector Subtract Short Elements
* `22 reserved`
* `23 (VABS)` Vector Absolute Value of Short Elements
* `24 (VADDC)` Vector Add Short Elements with Carry
* `25 (VSUBC)` Vector Subtract Short Elements with Carry
* `26 reserved`
* `27 reserved`
* `30 reserved`
* `31 reserved`
* `32 reserved`
* `33 reserved`
* `34 reserved`
* `35 (VSAR)` Vector Accumulator Read
* `36 reserved`
* `37 reserved`
* `40 (VLT)` Vector Select Less Than
* `41 (VEQ)` Vector Select Equal
* `42 (VNE)` Vector Select Not Equal
* `43 (VGE)` Vector Select Greater Than or Equal
* `44 (VCL)` Vector Select Clip Test Low
* `45 (VCH)` Vector Select Clip Test High
* `46 (VCR)` Vector Select Clip Test Low (single-precision)
* `47 (VMRG)` Vector Select Merge
* `50 (VAND)` Vector AND Short Elements
* `51 (VNAND)` Vector NAND Short Elements
* `52 (VOR)` Vector OR Short Elements
* `53 (VNOR)` Vector NOR Short Elements
* `54 (VXOR)` Vector XOR Short Elements
* `55 (VNXOR)` Vector NXOR Short Elements
* `56 reserved`
* `57 reserved`
* `60 (VRCP)` Vector Element Scalar Reciprocal (single-precision)
* `61 (VRCPL)` Vector Element Scalar Reciprocal Low
* `62 (VRCPH)` Vector Element Scalar Reciprocal High
* `63 (VMOV)` Vector Element Scalar Move
* `64 (VRSQ)` Vector Element Scalar SQRT Reciprocal (single-precision)
* `65 (VRSQL)` Vector Element Scalar SQRT Reciprocal Low
* `66 (VRSQH)` Vector Element Scalar SQRT Reciprocal High
* `67 (VNOP)` Vector Null Instruction
* `70 reserved`
* `71 reserved`
* `72 reserved`
* `73 reserved`
* `74 reserved`
* `75 reserved`
* `76 reserved`
* `77 reserved`

### RSP Vector Load Transfers

The VR-DMEM transaction instruction cycles are still processed by the scalar unit, not the vector unit.  In the modern implementations accepted by most vector unit communications systems today, the transfer instructions are classifiable under five groups:

1.  BV, SV, LV, DV
2.  PV, UV, XV, ZV
3.  HV, FV, AV
4.  QV, RV
5.  TV, WV

Not all of those instructions were implemented as of the time of the Nintendo 64's RCP, however.  Additionally, their ordering in the opcode matrix was a little skewed to what is seen below.  At this time, it is better to use only three categories of instructions:
* _normal_:  Anything under Group I or Group IV is normal type.  Only the element must be aligned; `addr & 1` may resolve true.
* _packed_:  Anything under Group II or Group III.  Useful for working with specially mapped data, such as pixels.
* _transposed_:  `LTV`, *LTWV,* `STV`, and `SWV` can be found in heaps of 16 instructions, all dedicated to matrix transposition through eight diagonals of halfword elements.

`LWC2` _vt_[_element_], _offset_(_base_)

|  LWC2  | base  |  vt   |  rd   | element |  offset  |
| ------ | ----- | ----- | ----- |:-------:| -------- |
|`110010`|`sssss`|`ttttt`|`?????`| `eeee`  | `Xxxxxxx`|

* `00 (LBV)` Load Byte to Vector Unit
* `01 (LSV)` Load Shortword to Vector Unit
* `02 (LLV)` Load Longword to Vector Unit
* `03 (LDV)` Load Doubleword to Vector Unit
* `04 (LQV)` Load Quadword to Vector Unit
* `05 (LRV)` Load Rest to Vector Unit
* `06 (LPV)` Load Packed Signed to Vector Unit
* `07 (LUV)` Load Packed Unsigned to Vector Unit
* `10 (LHV)` Load Alternate Bytes to Vector Unit
* `11 (LFV)` Load Alternate Fourths to Vector Unit
* `12 reserved` *LTWV*
* `13 (LTV)` Load Transposed to Vector Unit
* `14 reserved`
* `15 reserved`
* `16 reserved`
* `17 reserved`

`SWC2` _vt_[_element_], _offset_(_base_)

|  SWC2  | base  |  vt   |  rd   | element |  offset  |
| ------ | ----- | ----- | ----- |:-------:| -------- |
|`111010`|`sssss`|`ttttt`|`?????`| `eeee`  | `Xxxxxxx`|

* `00 (SBV)` Store Byte from Vector Unit
* `01 (SSV)` Store Shortword from Vector Unit
* `02 (SLV)` Store Longword from Vector Unit
* `03 (SDV)` Store Doubleword from Vector Unit
* `04 (SQV)` Store Quadword from Vector Unit
* `05 (SRV)` Store Rest from Vector Unit
* `06 (SPV)` Store Packed Signed from Vector Unit
* `07 (SUV)` Store Packed Unsigned from Vector Unit
* `10 (SHV)` Store Alternate Bytes from Vector Unit
* `11 (SFV)` Store Alternate Fourths from Vector Unit
* `12 (SWV)` Store Transposed Wrapped from Vector Unit
* `13 (STV)` Store Transposed from Vector Unit
* `14 reserved`
* `15 reserved`
* `16 reserved`
* `17 reserved`

If, by any chance, the opcode specifier is greater than 17 [oct], it was probably meant to execute the extended counterparts to the above loads and stores, which were questionably obsolete and remain reserved.

## Informational References for Vector Processor Architecture

_Instruction Methods for Performing Data Formatting While Moving Data Between Memory and a Vector Register File_
United States patent no. 5,812,147
Timothy J. Van Hook
*Silicon Graphics, Inc.*

_Method and System for Efficient Matrix Multiplication in a SIMD Processor Architecture_
United States patent no. 7,873,812
Tibet Mimar

_Efficient Handling of Vector High-Level Language Constructs in a SIMD Processor_
United States patent no. 7,793,084
Tibet Mimar

_Flexible Vector Modes of Operation for SIMD Processor_
patent pending?
Tibet Mimar

_Programming a Vector Processor and Parallel Programming of an Asymmetric Dual Multiprocessor Comprised of a Vector Processor and a RISC Processor_
United States patent no. 6,016,395
Moataz Ali Mohamed
*Samsung Electronics Co., Ltd.*

_Execution Unit for Processing a Data Stream Independently and in Parallel_
United States patent no. 6,401,194
Le Trong Nguyen
*Samsung Electronics Co., Ltd.*
