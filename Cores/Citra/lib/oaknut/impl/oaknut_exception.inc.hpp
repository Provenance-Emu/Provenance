// SPDX-FileCopyrightText: Copyright (c) 2023 merryhime <https://mary.rs>
// SPDX-License-Identifier: MIT

// reg.hpp
OAKNUT_EXCEPTION(InvalidWSPConversion, "toW: cannot convert WSP to WReg")
OAKNUT_EXCEPTION(InvalidXSPConversion, "toX: cannot convert XSP to XReg")
OAKNUT_EXCEPTION(InvalidWZRConversion, "unexpected WZR passed into an WRegWsp")
OAKNUT_EXCEPTION(InvalidXZRConversion, "unexpected XZR passed into an XRegSp")
OAKNUT_EXCEPTION(InvalidDElem_1, "invalid DElem_1")
OAKNUT_EXCEPTION(InvalidElementIndex, "elem_index is out of range")

// imm.hpp / offset.hpp / list.hpp
OAKNUT_EXCEPTION(InvalidAddSubImm, "invalid AddSubImm")
OAKNUT_EXCEPTION(InvalidBitImm32, "invalid BitImm32")
OAKNUT_EXCEPTION(InvalidBitImm64, "invalid BitImm64")
OAKNUT_EXCEPTION(InvalidImmChoice, "invalid ImmChoice")
OAKNUT_EXCEPTION(InvalidImmConst, "invalid ImmConst")
OAKNUT_EXCEPTION(InvalidImmConstFZero, "invalid ImmConstFZero")
OAKNUT_EXCEPTION(InvalidImmRange, "invalid ImmRange")
OAKNUT_EXCEPTION(InvalidList, "invalid List")
OAKNUT_EXCEPTION(InvalidMovImm16, "invalid MovImm16")
OAKNUT_EXCEPTION(InvalidBitWidth, "invalid width")
OAKNUT_EXCEPTION(LslShiftOutOfRange, "LslShift out of range")
OAKNUT_EXCEPTION(OffsetMisaligned, "misalignment")
OAKNUT_EXCEPTION(OffsetOutOfRange, "out of range")
OAKNUT_EXCEPTION(ImmOutOfRange, "outsized Imm value")

// arm64_encode_helpers.inc.hpp
OAKNUT_EXCEPTION(InvalidAddSubExt, "invalid AddSubExt choice for rm size")
OAKNUT_EXCEPTION(InvalidIndexExt, "invalid IndexExt choice for rm size")
OAKNUT_EXCEPTION(BitPositionOutOfRange, "bit position exceeds size of rt")
OAKNUT_EXCEPTION(RequiresAbsoluteAddressesContext, "absolute addresses required")

// mnemonics_*.inc.hpp
OAKNUT_EXCEPTION(InvalidCombination, "InvalidCombination")
OAKNUT_EXCEPTION(InvalidCond, "Cond cannot be AL or NV here")
OAKNUT_EXCEPTION(InvalidPairFirst, "Requires even register")
OAKNUT_EXCEPTION(InvalidPairSecond, "Invalid second register in pair")
OAKNUT_EXCEPTION(InvalidOperandXZR, "xzr invalid here")

// oaknut.hpp
OAKNUT_EXCEPTION(InvalidAlignment, "invalid alignment")
OAKNUT_EXCEPTION(LabelRedefinition, "label already resolved")
