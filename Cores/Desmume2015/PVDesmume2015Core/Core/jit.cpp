// Copyright (c) 2021, OpenEmu Team
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of the OpenEmu Team nor the
//       names of its contributors may be used to endorse or promote products
//       derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#ifdef __aarch64__
#include "../../utils/arm_arm/arm_gen.cpp"
#include "../../utils/arm_arm/arm_jit.cpp"
#elif defined(__x86_64__)
#include "../../utils/AsmJit/core/assembler.cpp"
#include "../../utils/AsmJit/core/assert.cpp"
#include "../../utils/AsmJit/core/buffer.cpp"
#include "../../utils/AsmJit/core/compiler.cpp"
#include "../../utils/AsmJit/core/compilercontext.cpp"
#include "../../utils/AsmJit/core/compilerfunc.cpp"
#include "../../utils/AsmJit/core/compileritem.cpp"
#include "../../utils/AsmJit/core/context.cpp"
#include "../../utils/AsmJit/core/cpuinfo.cpp"
#include "../../utils/AsmJit/core/defs.cpp"
#include "../../utils/AsmJit/core/func.cpp"
#include "../../utils/AsmJit/core/logger.cpp"
#include "../../utils/AsmJit/core/memorymanager.cpp"
#include "../../utils/AsmJit/core/memorymarker.cpp"
#include "../../utils/AsmJit/core/operand.cpp"
#include "../../utils/AsmJit/core/stringbuilder.cpp"
#include "../../utils/AsmJit/core/stringutil.cpp"
#include "../../utils/AsmJit/core/virtualmemory.cpp"
#include "../../utils/AsmJit/core/zonememory.cpp"
#include "../../utils/AsmJit/x86/x86assembler.cpp"
#include "../../utils/AsmJit/x86/x86compiler.cpp"
#include "../../utils/AsmJit/x86/x86compilercontext.cpp"
#include "../../utils/AsmJit/x86/x86compilerfunc.cpp"
#include "../../utils/AsmJit/x86/x86compileritem.cpp"
#include "../../utils/AsmJit/x86/x86cpuinfo.cpp"
#include "../../utils/AsmJit/x86/x86defs.cpp"
#include "../../utils/AsmJit/x86/x86func.cpp"
#include "../../utils/AsmJit/x86/x86operand.cpp"
#include "../../utils/AsmJit/x86/x86util.cpp"
#else
#error unknown arch!
#endif
