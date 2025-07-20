/* Copyright (C) 2010-2018 The RetroArch team
 *
 * ---------------------------------------------------------------------------------------
 * The following license statement only applies to this libretro SDK code part (glsm.h).
 * ---------------------------------------------------------------------------------------
 *
 * Permission is hereby granted, free of charge,
 * to any person obtaining a copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation the rights to
 * use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
 * and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
 * INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#ifndef LIBRETRO_SDK_GLSM_H
#define LIBRETRO_SDK_GLSM_H

#include <retro_common_api.h>

#include <boolean.h>
#include <libretro.h>
#include <glsym/rglgen_headers.h>

RETRO_BEGIN_DECLS

#ifdef HAVE_OPENGLES2
typedef double GLdouble;
typedef double GLclampd;
#endif

#if defined(HAVE_OPENGLES2)
#define RARCH_GL_RENDERBUFFER GL_RENDERBUFFER
#define RARCH_GL_DEPTH24_STENCIL8 GL_DEPTH24_STENCIL8_OES
#define RARCH_GL_DEPTH_ATTACHMENT GL_DEPTH_ATTACHMENT
#define RARCH_GL_STENCIL_ATTACHMENT GL_STENCIL_ATTACHMENT
#elif (defined(__MACH__) && (defined(__ppc__) || defined(__ppc64__)))
#define RARCH_GL_RENDERBUFFER GL_RENDERBUFFER_EXT
#define RARCH_GL_DEPTH24_STENCIL8 GL_DEPTH24_STENCIL8_EXT
#define RARCH_GL_DEPTH_ATTACHMENT GL_DEPTH_ATTACHMENT_EXT
#define RARCH_GL_STENCIL_ATTACHMENT GL_STENCIL_ATTACHMENT_EXT
#elif defined(HAVE_PSGL)
#define RARCH_GL_RENDERBUFFER GL_RENDERBUFFER_OES
#define RARCH_GL_DEPTH24_STENCIL8 GL_DEPTH24_STENCIL8_SCE
#define RARCH_GL_DEPTH_ATTACHMENT GL_DEPTH_ATTACHMENT_OES
#define RARCH_GL_STENCIL_ATTACHMENT GL_STENCIL_ATTACHMENT_OES
#else
#define RARCH_GL_RENDERBUFFER GL_RENDERBUFFER
#define RARCH_GL_DEPTH24_STENCIL8 GL_DEPTH24_STENCIL8
#define RARCH_GL_DEPTH_ATTACHMENT GL_DEPTH_ATTACHMENT
#define RARCH_GL_STENCIL_ATTACHMENT GL_STENCIL_ATTACHMENT
#endif

#if defined(HAVE_PSGL)
#define RARCH_GL_FRAMEBUFFER GL_FRAMEBUFFER_OES
#define RARCH_GL_FRAMEBUFFER_COMPLETE GL_FRAMEBUFFER_COMPLETE_OES
#define RARCH_GL_COLOR_ATTACHMENT0 GL_COLOR_ATTACHMENT0_EXT
#elif (defined(__MACH__) && (defined(__ppc__) || defined(__ppc64__)))
#define RARCH_GL_FRAMEBUFFER GL_FRAMEBUFFER_EXT
#define RARCH_GL_FRAMEBUFFER_COMPLETE GL_FRAMEBUFFER_COMPLETE_EXT
#define RARCH_GL_COLOR_ATTACHMENT0 GL_COLOR_ATTACHMENT0_EXT
#else
#define RARCH_GL_FRAMEBUFFER GL_FRAMEBUFFER
#define RARCH_GL_FRAMEBUFFER_COMPLETE GL_FRAMEBUFFER_COMPLETE
#define RARCH_GL_COLOR_ATTACHMENT0 GL_COLOR_ATTACHMENT0
#endif

#ifndef GL_FOG
#define GL_FOG 0x0B60
#endif

#ifndef GL_ALPHA_TEST
#define GL_ALPHA_TEST 0x0BC0
#endif

#ifndef GL_CLIP_DISTANCE0
#define GL_CLIP_DISTANCE0 0x3000
#endif

#define MAX_ATTRIB 8

enum
{
   SGL_DEPTH_TEST             = 0,
   SGL_BLEND,
   SGL_POLYGON_OFFSET_FILL,
   SGL_FOG,
   SGL_CULL_FACE,
   SGL_ALPHA_TEST,
   SGL_SCISSOR_TEST,
   SGL_STENCIL_TEST,
#if !defined(HAVE_OPENGLES)
   SGL_DEPTH_CLAMP,
   SGL_CLIP_DISTANCE0,
#endif
   SGL_DITHER,
   SGL_SAMPLE_ALPHA_TO_COVERAGE,
   SGL_SAMPLE_COVERAGE,
#ifndef HAVE_OPENGLES
   SGL_COLOR_LOGIC_OP,
#endif
   SGL_CAP_MAX
};

enum glsm_state_ctl
{
   GLSM_CTL_NONE = 0,
   GLSM_CTL_STATE_SETUP,
   GLSM_CTL_STATE_BIND,
   GLSM_CTL_STATE_UNBIND,
   GLSM_CTL_STATE_CONTEXT_RESET,
   GLSM_CTL_STATE_CONTEXT_DESTROY,
   GLSM_CTL_STATE_CONTEXT_INIT,
   GLSM_CTL_IS_IMM_VBO,
   GLSM_CTL_SET_IMM_VBO,
   GLSM_CTL_UNSET_IMM_VBO,
   GLSM_CTL_IMM_VBO_DISABLE,
   GLSM_CTL_IMM_VBO_DRAW,
   GLSM_CTL_PROC_ADDRESS_GET
};

typedef bool (*glsm_imm_vbo_draw)(void *);
typedef bool (*glsm_imm_vbo_disable)(void *);
typedef bool (*glsm_framebuffer_lock)(void *);

typedef struct glsm_ctx_proc_address
{
   retro_get_proc_address_t addr;
} glsm_ctx_proc_address_t;

typedef struct glsm_ctx_params
{
   glsm_framebuffer_lock    framebuffer_lock;
   glsm_imm_vbo_draw        imm_vbo_draw;
   glsm_imm_vbo_disable     imm_vbo_disable;
   retro_hw_context_reset_t context_reset;
   retro_hw_context_reset_t context_destroy;
   retro_environment_t environ_cb;
   bool stencil;
   unsigned major;
   unsigned minor;
   enum retro_hw_context_type context_type;
} glsm_ctx_params_t;

GLuint glsm_get_current_framebuffer(void);

bool glsm_ctl(enum glsm_state_ctl state, void *data);

RETRO_END_DECLS

#endif
