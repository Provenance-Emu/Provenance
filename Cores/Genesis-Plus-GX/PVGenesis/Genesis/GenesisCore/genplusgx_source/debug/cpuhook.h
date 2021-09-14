/***************************************************************************************
 *  Genesis Plus GX
 *  CPU hooking support
 *
 *  HOOK_CPU should be defined in a makefile or MSVC project to enable this functionality
 *
 *  Copyright DrMefistO (2018-2019)
 *
 *  Copyright feos (2019)
 *
 *  Redistribution and use of this code or any derivative works are permitted
 *  provided that the following conditions are met:
 *
 *   - Redistributions may not be sold, nor may they be used in a commercial
 *     product or activity.
 *
 *   - Redistributions that are modified from the original source must include the
 *     complete source code, including the source code for all components used by a
 *     binary built from the modified sources. However, as a special exception, the
 *     source code distributed need not include anything that is normally distributed
 *     (in either source or binary form) with the major components (compiler, kernel,
 *     and so on) of the operating system on which the executable runs, unless that
 *     component itself accompanies the executable.
 *
 *   - Redistributions must reproduce the above copyright notice, this list of
 *     conditions and the following disclaimer in the documentation and/or other
 *     materials provided with the distribution.
 *
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 *  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 *  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 *  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 *  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 *  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 *  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 *  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 *  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *  POSSIBILITY OF SUCH DAMAGE.
 *
 ****************************************************************************************/

#ifndef _CPUHOOK_H_
#define _CPUHOOK_H_


typedef enum {
  HOOK_ANY      = (0 << 0),
  
  // M68K
  HOOK_M68K_E   = (1 << 0),
  HOOK_M68K_R   = (1 << 1),
  HOOK_M68K_W   = (1 << 2),
  HOOK_M68K_RW  = HOOK_M68K_R | HOOK_M68K_W,
  
  // VDP
  HOOK_VRAM_R   = (1 << 3),
  HOOK_VRAM_W   = (1 << 4),
  HOOK_VRAM_RW  = HOOK_VRAM_R | HOOK_VRAM_W,
  
  HOOK_CRAM_R   = (1 << 5),
  HOOK_CRAM_W   = (1 << 6),
  HOOK_CRAM_RW  = HOOK_CRAM_R | HOOK_CRAM_W,
  
  HOOK_VSRAM_R  = (1 << 7),
  HOOK_VSRAM_W  = (1 << 8),
  HOOK_VSRAM_RW = HOOK_VSRAM_R | HOOK_VSRAM_W,
  
  // Z80
  HOOK_Z80_E    = (1 << 9),
  HOOK_Z80_R    = (1 << 10),
  HOOK_Z80_W    = (1 << 11),
  HOOK_Z80_RW   = HOOK_Z80_R | HOOK_Z80_W,
  
  // REGS
  HOOK_VDP_REG  = (1 << 12),
  HOOK_M68K_REG = (1 << 13),
} hook_type_t;


/* CPU hook is called on read, write, and execute.
 */
void (*cpu_hook)(hook_type_t type, int width, unsigned int address, unsigned int value);

/* Use set_cpu_hook() to assign a callback that can process the data provided
 * by cpu_hook().
 */
void set_cpu_hook(void(*hook)(hook_type_t type, int width, unsigned int address, unsigned int value));


#endif /* _CPUHOOK_H_ */