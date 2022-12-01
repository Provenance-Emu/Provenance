// Copyright (c) 2019, OpenEmu Team
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

#import "OELogging.h"

os_log_t OE_LOG_AUDIO_READ, OE_LOG_AUDIO_WRITE;
os_log_t OE_LOG_CORE_RUN, OE_LOG_CORE_REWIND;
os_log_t OE_LOG_DEFAULT;

__attribute__((constructor))
static void InitializeLogging() {
    OE_LOG_AUDIO_READ   = os_log_create("org.openemu.OpenEmuBase.audio", "read");
    OE_LOG_AUDIO_WRITE  = os_log_create("org.openemu.OpenEmuBase.audio", "write");
    OE_LOG_CORE_RUN     = os_log_create("org.openemu.OpenEmuBase.core", "run");
    OE_LOG_CORE_REWIND  = os_log_create("org.openemu.OpenEmuBase.core", "rewind");
    OE_LOG_DEFAULT      = os_log_create("org.openemu.OpenEmuBase", "default");
}
