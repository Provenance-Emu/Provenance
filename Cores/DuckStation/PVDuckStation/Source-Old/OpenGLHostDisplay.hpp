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

#ifndef OpenEmuOpenGLHostDisplay_hpp
#define OpenEmuOpenGLHostDisplay_hpp

// GLAD has to come first so that Qt doesn't pull in the system GL headers, which are incompatible with glad.
#include <glad.h>

// Hack to prevent Apple's glext.h headers from getting included via qopengl.h, since we still want to use glad.
#ifdef __APPLE__
#define __glext_h_
#endif

#include "common/gl/context.h"
#include "common/gl/program.h"
#include "common/gl/stream_buffer.h"
#include "common/gl/texture.h"
#include "common/window_info.h"
#include "core/host_display.h"
#include <memory>

@class PVDuckStationCore;

namespace OpenEmu {
class OpenGLHostDisplay final: public HostDisplay {
public:
	OpenGLHostDisplay(PVDuckStationCore *core);
	virtual ~OpenGLHostDisplay();
	virtual RenderAPI GetRenderAPI() const override;
	virtual void* GetDevice() const override;
	virtual void* GetContext() const override;
	
	virtual bool HasDevice() const override;
	virtual bool HasSurface() const override;
	
	virtual bool CreateDevice(const WindowInfo& wi, bool vsync) override;
	virtual bool SetupDevice() override;
	virtual void DestroySurface() override;
	
	virtual bool MakeCurrent() override;
	virtual bool DoneCurrent() override;
	
	virtual bool ChangeWindow(const WindowInfo& new_wi) override;
	virtual void ResizeWindow(s32 new_window_width, s32 new_window_height) override;
	virtual bool SupportsFullscreen() const override;
	virtual bool IsFullscreen() override;
	virtual bool SetFullscreen(bool fullscreen, u32 width, u32 height, float refresh_rate) override;
	virtual void DestroyResources() override;
	
	virtual bool SetPostProcessingChain(const std::string_view& config) override;
	
	std::unique_ptr<GPUTexture> CreateTexture(u32 width, u32 height, u32 layers, u32 levels, u32 samples,
                                                      GPUTexture::Format format, const void* data, u32 data_stride,
													  bool dynamic = false) override;
//	bool UpdateTexture(GPUTexture* texture, u32 x, u32 y, u32 width, u32 height, const void* data,
//					   u32 pitch) override;
	bool BeginTextureUpdate(GPUTexture* texture, u32 width, u32 height, void** out_buffer, u32* out_pitch)  override;
	void EndTextureUpdate(GPUTexture* texture, u32 x, u32 y, u32 width, u32 height) override;
	bool UpdateTexture(GPUTexture* texture, u32 x, u32 y, u32 width, u32 height, const void* data, u32 pitch) override;
    bool DownloadTexture(GPUTexture* texture, u32 x, u32 y, u32 width, u32 height, void* out_data,
                         u32 out_data_stride) override;

	virtual void SetVSync(bool enabled) override;
	
	virtual bool Render(bool skip_present) override;
	
	virtual bool RenderScreenshot(u32 width, u32 height, std::vector<u32>* out_pixels, u32* out_stride,
                                  GPUTexture::Format* out_format) override;

    bool SupportsTextureFormat(GPUTexture::Format format) const override;

protected:
	const char* GetGLSLVersionString() const;
	std::string GetGLSLVersionHeader() const;
	
	virtual AdapterAndModeList GetAdapterAndModeList() override;
	virtual bool CreateResources() override;
	virtual void DestroyResources() override;
	
	void RenderDisplay();
	void RenderSoftwareCursor();
	
	void RenderDisplay(s32 left, s32 bottom, s32 width, s32 height, void* texture_handle, u32 texture_width,
					   s32 texture_height, s32 texture_view_x, s32 texture_view_y, s32 texture_view_width,
					   s32 texture_view_height, bool linear_filter);
	void RenderSoftwareCursor(s32 left, s32 bottom, s32 width, s32 height, GPUTexture* texture_handle);
	
	std::unique_ptr<GL::Context> m_gl_context;
	
	GL::Program m_display_program;
	GL::Program m_cursor_program;
	GLuint m_display_vao = 0;
	GLuint m_display_nearest_sampler = 0;
	GLuint m_display_linear_sampler = 0;
	GLuint m_uniform_buffer_alignment = 1;
	
	GLuint m_display_pixels_texture_id = 0;
	std::unique_ptr<GL::StreamBuffer> m_display_pixels_texture_pbo;
	u32 m_display_pixels_texture_pbo_map_offset = 0;
	u32 m_display_pixels_texture_pbo_map_size = 0;
	
private:
    PVDuckStationCore *_current;
};
};

#endif /* OpenEmuOpenGLHostDisplay_hpp */
