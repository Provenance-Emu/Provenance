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

#import <Foundation/Foundation.h>
#import "PVDuckStation.h"

#define TickCount DuckTickCount
#include "OpenGLHostDisplay.hpp"
#include "common/align.h"
#include "common/assert.h"
#include "common/log.h"
#include <array>
#include <tuple>
#undef TickCount

#include <dlfcn.h>
#include <os/log.h>

#include <glad.h>

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
#import <OpenGLES/gltypes.h>
//#import <OpenGLES/ES3/gl.h>
//#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/EAGL.h>
#else
#import <OpenGL/OpenGL.h>
#endif

#define OE_CORE_LOG OS_LOG_DEFAULT

namespace OpenEmu {
class ContextGL final : public GL::Context
{
public:
	ContextGL(const WindowInfo& wi);
	~ContextGL() override;
	
	static std::unique_ptr<Context> Create(const WindowInfo& wi, const Version* versions_to_try,
										   size_t num_versions_to_try);
	
	void* GetProcAddress(const char* name) override;
	bool ChangeSurface(const WindowInfo& new_wi) override;
	void ResizeSurface(u32 new_surface_width = 0, u32 new_surface_height = 0) override;
	bool SwapBuffers() override;
	bool MakeCurrent() override;
	bool DoneCurrent() override;
	bool SetSwapInterval(s32 interval) override;
	std::unique_ptr<Context> CreateSharedContext(const WindowInfo& wi) override;
	
private:
	//! returns true if dimensions have changed
	bool UpdateDimensions();
	
//	void* m_opengl_module_handle = nullptr;
};

#pragma mark -

class OGLHostDisplayTexture final : public HostDisplayTexture
{
public:
	OGLHostDisplayTexture(GL::Texture texture, HostDisplayPixelFormat format)
	: m_texture(std::move(texture)), m_format(format){}
	~OGLHostDisplayTexture() override = default;
	
	void* GetHandle() const override { return reinterpret_cast<void*>(static_cast<uintptr_t>(m_texture.GetGLId())); }
	u32 GetWidth() const override { return m_texture.GetWidth(); }
	u32 GetHeight() const override { return m_texture.GetHeight(); }
	u32 GetLayers() const override { return 1; }
	u32 GetLevels() const override { return 1; }
	u32 GetSamples() const override { return m_texture.GetSamples(); }
	HostDisplayPixelFormat GetFormat() const override { return m_format; }
	
	GLuint GetGLID() const { return m_texture.GetGLId(); }
	
private:
	GL::Texture m_texture;
	HostDisplayPixelFormat m_format;
};

}

using namespace OpenEmu;

#pragma mark -

OpenGLHostDisplay::OpenGLHostDisplay(PVDuckStationCore *core) :
_current(core)
{
	
}

OpenGLHostDisplay::~OpenGLHostDisplay()
{
	AssertMsg(!m_gl_context, "Context should have been destroyed by now");
}

HostDisplay::RenderAPI OpenGLHostDisplay::GetRenderAPI() const
{
	return RenderAPI::OpenGLES;
}

void* OpenGLHostDisplay::GetRenderDevice() const
{
	return nullptr;
}

void* OpenGLHostDisplay::GetRenderContext() const
{
	return m_gl_context.get();
}

static constexpr std::array<std::tuple<GLenum, GLenum, GLenum>, static_cast<u32>(HostDisplayPixelFormat::Count)>
  s_display_pixel_format_mapping = {{
	{},                                                  // Unknown
	{GL_RGBA8, GL_RGBA, GL_UNSIGNED_BYTE},               // RGBA8
	{GL_RGBA8, GL_BGRA, GL_UNSIGNED_BYTE},               // BGRA8
	{GL_RGB565, GL_RGB, GL_UNSIGNED_SHORT_5_6_5},        // RGB565
	{GL_RGB5_A1, GL_BGRA, GL_UNSIGNED_SHORT_1_5_5_5_REV} // RGBA5551
  }};

std::unique_ptr<HostDisplayTexture> OpenGLHostDisplay::CreateTexture(u32 width, u32 height, u32 layers,
																	 u32 levels, u32 samples,
																	 HostDisplayPixelFormat format,
																	 const void* data, u32 data_stride,
																	 bool dynamic /* = false */)
{
	if (layers != 1 || levels != 1) {
		return {};
	}
	
	const auto [gl_internal_format, gl_format, gl_type] = s_display_pixel_format_mapping[static_cast<u32>(format)];
	
	// TODO: Set pack width
	Assert(!data || data_stride == (width * sizeof(u32)));
	
	GL::Texture tex;
	if (!tex.Create(width, height, samples, gl_internal_format, gl_format, gl_type, data, data_stride)) {
		return {};
	}
	
	return std::make_unique<OpenEmu::OGLHostDisplayTexture>(std::move(tex), format);
}

void OpenGLHostDisplay::UpdateTexture(HostDisplayTexture* texture, u32 x, u32 y, u32 width, u32 height,
									  const void* texture_data, u32 texture_data_stride)
{
	OpenEmu::OGLHostDisplayTexture* tex = static_cast<OpenEmu::OGLHostDisplayTexture*>(texture);
	const auto [gl_internal_format, gl_format, gl_type] =
	s_display_pixel_format_mapping[static_cast<u32>(texture->GetFormat())];
	GLint alignment;
	if (texture_data_stride & 1) {
		alignment = 1;
	} else if (texture_data_stride & 2) {
		alignment = 2;
	} else {
		alignment = 4;
	}
	
	GLint old_texture_binding = 0, old_alignment = 0, old_row_length = 0;
	glGetIntegerv(GL_TEXTURE_BINDING_2D, &old_texture_binding);
	glBindTexture(GL_TEXTURE_2D, tex->GetGLID());
	
	glGetIntegerv(GL_UNPACK_ALIGNMENT, &old_alignment);
	glPixelStorei(GL_UNPACK_ALIGNMENT, alignment);
	
	glGetIntegerv(GL_UNPACK_ROW_LENGTH, &old_row_length);
	glPixelStorei(GL_UNPACK_ROW_LENGTH, texture_data_stride / GetDisplayPixelFormatSize(texture->GetFormat()));
	
	glTexSubImage2D(GL_TEXTURE_2D, 0, x, y, width, height, gl_format, gl_type, texture_data);
	
	glPixelStorei(GL_UNPACK_ROW_LENGTH, old_row_length);
	
	glPixelStorei(GL_UNPACK_ALIGNMENT, old_alignment);
	glBindTexture(GL_TEXTURE_2D, old_texture_binding);
}

bool OpenGLHostDisplay::DownloadTexture(const void* texture_handle, HostDisplayPixelFormat texture_format,
										u32 x, u32 y, u32 width, u32 height, void* out_data,
										u32 out_data_stride)
{
	GLint alignment;
	if (out_data_stride & 1) {
		alignment = 1;
	} else if (out_data_stride & 2) {
		alignment = 2;
	} else {
		alignment = 4;
	}
	
	GLint old_alignment = 0, old_row_length = 0;
	glGetIntegerv(GL_PACK_ALIGNMENT, &old_alignment);
	glPixelStorei(GL_PACK_ALIGNMENT, alignment);
	glGetIntegerv(GL_PACK_ROW_LENGTH, &old_row_length);
	glPixelStorei(GL_PACK_ROW_LENGTH, out_data_stride / GetDisplayPixelFormatSize(texture_format));
	
	const GLuint texture = static_cast<GLuint>(reinterpret_cast<uintptr_t>(texture_handle));
	const auto [gl_internal_format, gl_format, gl_type] =
	s_display_pixel_format_mapping[static_cast<u32>(texture_format)];
	
	GL::Texture::GetTextureSubImage(texture, 0, x, y, 0, width, height, 1, gl_format, gl_type,
									height * out_data_stride, out_data);
	
	glPixelStorei(GL_PACK_ALIGNMENT, old_alignment);
	glPixelStorei(GL_PACK_ROW_LENGTH, old_row_length);
	return true;
}

bool OpenGLHostDisplay::SupportsDisplayPixelFormat(HostDisplayPixelFormat format) const
{
	return (std::get<0>(s_display_pixel_format_mapping[static_cast<u32>(format)]) != static_cast<GLenum>(0));
}

bool OpenGLHostDisplay::BeginSetDisplayPixels(HostDisplayPixelFormat format, u32 width, u32 height,
											  void** out_buffer, u32* out_pitch)
{
	const u32 pixel_size = GetDisplayPixelFormatSize(format);
	const u32 stride = Common::AlignUpPow2(width * pixel_size, 4);
	const u32 size_required = stride * height * pixel_size;
	const u32 buffer_size = Common::AlignUpPow2(size_required * 2, 4 * 1024 * 1024);
	if (!m_display_pixels_texture_pbo || m_display_pixels_texture_pbo->GetSize() < buffer_size) {
		m_display_pixels_texture_pbo.reset();
		m_display_pixels_texture_pbo = GL::StreamBuffer::Create(GL_PIXEL_UNPACK_BUFFER, buffer_size);
		if (!m_display_pixels_texture_pbo) {
			return false;
		}
	}
	
	const auto map = m_display_pixels_texture_pbo->Map(GetDisplayPixelFormatSize(format), size_required);
	m_display_texture_format = format;
	m_display_pixels_texture_pbo_map_offset = map.buffer_offset;
	m_display_pixels_texture_pbo_map_size = size_required;
	*out_buffer = map.pointer;
	*out_pitch = stride;
	
	if (m_display_pixels_texture_id == 0) {
		glGenTextures(1, &m_display_pixels_texture_id);
		glBindTexture(GL_TEXTURE_2D, m_display_pixels_texture_id);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, 1);
	}
	
	SetDisplayTexture(reinterpret_cast<void*>(static_cast<uintptr_t>(m_display_pixels_texture_id)), format, width,
					  height, 0, 0, width, height);
	return true;
}

void OpenGLHostDisplay::EndSetDisplayPixels()
{
	const u32 width = static_cast<u32>(m_display_texture_view_width);
	const u32 height = static_cast<u32>(m_display_texture_view_height);
	
	const auto [gl_internal_format, gl_format, gl_type] =
	s_display_pixel_format_mapping[static_cast<u32>(m_display_texture_format)];
	
	// glTexImage2D should be quicker on Mali...
	m_display_pixels_texture_pbo->Unmap(m_display_pixels_texture_pbo_map_size);
	m_display_pixels_texture_pbo->Bind();
	glBindTexture(GL_TEXTURE_2D, m_display_pixels_texture_id);
	glTexImage2D(GL_TEXTURE_2D, 0, gl_internal_format, width, height, 0, gl_format, gl_type,
				 reinterpret_cast<void*>(static_cast<uintptr_t>(m_display_pixels_texture_pbo_map_offset)));
	glBindTexture(GL_TEXTURE_2D, 0);
	m_display_pixels_texture_pbo->Unbind();
	
	m_display_pixels_texture_pbo_map_offset = 0;
	m_display_pixels_texture_pbo_map_size = 0;
}

bool OpenGLHostDisplay::SetDisplayPixels(HostDisplayPixelFormat format, u32 width, u32 height,
										 const void* buffer, u32 pitch)
{
	if (m_display_pixels_texture_id == 0) {
		glGenTextures(1, &m_display_pixels_texture_id);
		glBindTexture(GL_TEXTURE_2D, m_display_pixels_texture_id);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, 1);
	} else {
		glBindTexture(GL_TEXTURE_2D, m_display_pixels_texture_id);
	}
	
	const auto [gl_internal_format, gl_format, gl_type] = s_display_pixel_format_mapping[static_cast<u32>(format)];
	
	glTexImage2D(GL_TEXTURE_2D, 0, gl_internal_format, width, height, 0, gl_format, gl_type, buffer);
	
	glBindTexture(GL_TEXTURE_2D, 0);
	
	SetDisplayTexture(reinterpret_cast<void*>(static_cast<uintptr_t>(m_display_pixels_texture_id)), format, width,
					  height, 0, 0, width, height);
	return true;
}

void OpenGLHostDisplay::SetVSync(bool enabled)
{
	if (m_gl_context->GetWindowInfo().type == WindowInfo::Type::Surfaceless) {
		return;
	}
	
	// Window framebuffer has to be bound to call SetSwapInterval.
	GLint current_fbo = 0;
	glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING, &current_fbo);
	glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);
	m_gl_context->SetSwapInterval(enabled ? 1 : 0);
	glBindFramebuffer(GL_DRAW_FRAMEBUFFER, current_fbo);
//	_current.renderDelegate.enableVSync = enabled;
}

const char* OpenGLHostDisplay::GetGLSLVersionString() const
{
	if (GLAD_GL_VERSION_3_3) {
		return "#version 330";
	} else {
		return "#version 130";
	}
}

std::string OpenGLHostDisplay::GetGLSLVersionHeader() const
{
	std::string header = GetGLSLVersionString();
	header += "\n\n";
	
	return header;
}

bool OpenGLHostDisplay::HasRenderDevice() const
{
	return m_gl_context != nullptr;
}

bool OpenGLHostDisplay::HasRenderSurface() const
{
	return m_window_info.type != WindowInfo::Type::Surfaceless;
}

bool OpenGLHostDisplay::CreateRenderDevice(const WindowInfo& wi, std::string_view adapter_name,
										   bool debug_device, bool threaded_presentation)
{
	static constexpr std::array<GL::Context::Version, 3> versArray {{{GL::Context::Profile::Core, 4, 1}, {GL::Context::Profile::Core, 3, 3}, {GL::Context::Profile::Core, 3, 2}}};
	
	m_gl_context = ContextGL::Create(wi, versArray.data(), versArray.size());
	if (!m_gl_context) {
		os_log_fault(OE_CORE_LOG, "Failed to create any GL context");
		return false;
	}
	
	gladLoadGL();
	m_window_info = wi;
	m_window_info.surface_width = m_gl_context->GetSurfaceWidth();
	m_window_info.surface_height = m_gl_context->GetSurfaceHeight();
	return true;
}

bool OpenGLHostDisplay::InitializeRenderDevice(std::string_view shader_cache_directory, bool debug_device,
											   bool threaded_presentation)
{
	glGetIntegerv(GL_UNIFORM_BUFFER_OFFSET_ALIGNMENT, reinterpret_cast<GLint*>(&m_uniform_buffer_alignment));
	
	if (!CreateResources()) {
		return false;
	}
	
	// Start with vsync on.
	SetVSync(true);
	
	return true;
}

bool OpenGLHostDisplay::MakeRenderContextCurrent()
{
	if (!m_gl_context->MakeCurrent()) {
		os_log_fault(OE_CORE_LOG, "Failed to make GL context current");
		return false;
	}
	
	return true;
}

bool OpenGLHostDisplay::DoneRenderContextCurrent()
{
	return m_gl_context->DoneCurrent();
}

void OpenGLHostDisplay::DestroyRenderDevice()
{
	if (!m_gl_context) {
		return;
	}
	
	DestroyResources();
	
	m_gl_context->DoneCurrent();
	m_gl_context.reset();
}

bool OpenGLHostDisplay::ChangeRenderWindow(const WindowInfo& new_wi)
{
	Assert(m_gl_context);
	
	if (!m_gl_context->ChangeSurface(new_wi)) {
		os_log_fault(OE_CORE_LOG, "Failed to change surface");
		return false;
	}
	
	m_window_info = new_wi;
	m_window_info.surface_width = m_gl_context->GetSurfaceWidth();
	m_window_info.surface_height = m_gl_context->GetSurfaceHeight();
	
	return true;
}

void OpenGLHostDisplay::ResizeRenderWindow(s32 new_window_width, s32 new_window_height)
{
	if (!m_gl_context) {
		return;
	}
	
	m_gl_context->ResizeSurface(static_cast<u32>(new_window_width), static_cast<u32>(new_window_height));
	m_window_info.surface_width = m_gl_context->GetSurfaceWidth();
	m_window_info.surface_height = m_gl_context->GetSurfaceHeight();
}

bool OpenGLHostDisplay::SupportsFullscreen() const
{
	return false;
}

bool OpenGLHostDisplay::IsFullscreen()
{
	return false;
}

bool OpenGLHostDisplay::SetFullscreen(bool fullscreen, u32 width, u32 height, float refresh_rate)
{
	return false;
}

void OpenGLHostDisplay::DestroyRenderSurface()
{
	if (!m_gl_context) {
		return;
	}
	
	m_window_info = {};
	if (!m_gl_context->ChangeSurface(m_window_info)) {
		os_log_fault(OE_CORE_LOG, "Failed to switch to surfaceless");
	}
}

bool OpenGLHostDisplay::CreateResources()
{
	static constexpr char fullscreen_quad_vertex_shader[] = R"(
uniform vec4 u_src_rect;
out vec2 v_tex0;

void main()
{
  vec2 pos = vec2(float((gl_VertexID << 1) & 2), float(gl_VertexID & 2));
  v_tex0 = u_src_rect.xy + pos * u_src_rect.zw;
  gl_Position = vec4(pos * vec2(2.0f, -2.0f) + vec2(-1.0f, 1.0f), 0.0f, 1.0f);
}
)";

	static constexpr char display_fragment_shader[] = R"(
uniform sampler2D samp0;

in vec2 v_tex0;
out vec4 o_col0;

void main()
{
  o_col0 = vec4(texture(samp0, v_tex0).rgb, 1.0);
}
)";

	static constexpr char cursor_fragment_shader[] = R"(
uniform sampler2D samp0;

in vec2 v_tex0;
out vec4 o_col0;

void main()
{
  o_col0 = texture(samp0, v_tex0);
}
)";

	if (!m_display_program.Compile(GetGLSLVersionHeader() + fullscreen_quad_vertex_shader, {},
								   GetGLSLVersionHeader() + display_fragment_shader) ||
		!m_cursor_program.Compile(GetGLSLVersionHeader() + fullscreen_quad_vertex_shader, {},
								  GetGLSLVersionHeader() + cursor_fragment_shader)) {
		os_log_fault(OE_CORE_LOG, "Failed to compile display shaders");
		return false;
	}
	
	m_display_program.BindFragData(0, "o_col0");
	m_cursor_program.BindFragData(0, "o_col0");
	
	if (!m_display_program.Link() || !m_cursor_program.Link()) {
		os_log_fault(OE_CORE_LOG, "Failed to link display programs");
		return false;
	}
	
	m_display_program.Bind();
	m_display_program.RegisterUniform("u_src_rect");
	m_display_program.RegisterUniform("samp0");
	m_display_program.Uniform1i(1, 0);
	m_cursor_program.Bind();
	m_cursor_program.RegisterUniform("u_src_rect");
	m_cursor_program.RegisterUniform("samp0");
	m_cursor_program.Uniform1i(1, 0);
	
	glGenVertexArrays(1, &m_display_vao);
	
	// samplers
	glGenSamplers(1, &m_display_nearest_sampler);
	glSamplerParameteri(m_display_nearest_sampler, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glSamplerParameteri(m_display_nearest_sampler, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glGenSamplers(1, &m_display_linear_sampler);
	glSamplerParameteri(m_display_linear_sampler, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glSamplerParameteri(m_display_linear_sampler, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	
	return true;
}

void OpenGLHostDisplay::DestroyResources()
{
	if (m_display_pixels_texture_id != 0) {
		glDeleteTextures(1, &m_display_pixels_texture_id);
		m_display_pixels_texture_id = 0;
	}
	
	if (m_display_vao != 0) {
		glDeleteVertexArrays(1, &m_display_vao);
		m_display_vao = 0;
	}
	if (m_display_linear_sampler != 0) {
		glDeleteSamplers(1, &m_display_linear_sampler);
		m_display_linear_sampler = 0;
	}
	if (m_display_nearest_sampler != 0) {
		glDeleteSamplers(1, &m_display_nearest_sampler);
		m_display_nearest_sampler = 0;
	}
	
	m_cursor_program.Destroy();
	m_display_program.Destroy();
}

bool OpenGLHostDisplay::Render()
{
#warning "fix me"
    GLuint framebuffer = 0; //[[[_current renderDelegate] alternateThreadFramebufferFront] unsignedIntValue];

	glDisable(GL_SCISSOR_TEST);
	glBindFramebuffer(GL_DRAW_FRAMEBUFFER, framebuffer);
	glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
	glClear(GL_COLOR_BUFFER_BIT);

	RenderDisplay();

	RenderSoftwareCursor();

	m_gl_context->SwapBuffers();

	return true;
}

void OpenGLHostDisplay::RenderDisplay()
{
	if (!HasDisplayTexture()) {
		return;
	}
	
	const auto [left, top, width, height] = CalculateDrawRect(GetWindowWidth(), GetWindowHeight(), m_display_top_margin);
	
	RenderDisplay(left, GetWindowHeight() - top - height, width, height, m_display_texture_handle,
				  m_display_texture_width, m_display_texture_height, m_display_texture_view_x, m_display_texture_view_y,
				  m_display_texture_view_width, m_display_texture_view_height, m_display_linear_filtering);
}

void OpenGLHostDisplay::RenderDisplay(s32 left, s32 bottom, s32 width, s32 height, void* texture_handle,
									  u32 texture_width, s32 texture_height, s32 texture_view_x,
									  s32 texture_view_y, s32 texture_view_width, s32 texture_view_height,
									  bool linear_filter)
{
	glViewport(left, bottom, width, height);
	glDisable(GL_BLEND);
	glDisable(GL_CULL_FACE);
	glDisable(GL_DEPTH_TEST);
	glDisable(GL_SCISSOR_TEST);
	glDepthMask(GL_FALSE);
	glBindTexture(GL_TEXTURE_2D, static_cast<GLuint>(reinterpret_cast<uintptr_t>(texture_handle)));
	m_display_program.Bind();
	
	const float position_adjust = m_display_linear_filtering ? 0.5f : 0.0f;
	const float size_adjust = m_display_linear_filtering ? 1.0f : 0.0f;
	const float flip_adjust = (texture_view_height < 0) ? -1.0f : 1.0f;
	m_display_program.Uniform4f(0, (static_cast<float>(texture_view_x) + position_adjust) / static_cast<float>(texture_width),
								(static_cast<float>(texture_view_y) + (position_adjust * flip_adjust)) / static_cast<float>(texture_height),
								(static_cast<float>(texture_view_width) - size_adjust) / static_cast<float>(texture_width),
								(static_cast<float>(texture_view_height) - (size_adjust * flip_adjust)) / static_cast<float>(texture_height));
	glBindSampler(0, linear_filter ? m_display_linear_sampler : m_display_nearest_sampler);
	glBindVertexArray(m_display_vao);
	glDrawArrays(GL_TRIANGLES, 0, 3);
	glBindSampler(0, 0);
}

void OpenGLHostDisplay::RenderSoftwareCursor()
{
	if (!HasSoftwareCursor()) {
		return;
	}
	
	const auto [left, top, width, height] = CalculateSoftwareCursorDrawRect();
	RenderSoftwareCursor(left, GetWindowHeight() - top - height, width, height, m_cursor_texture.get());
}

void OpenGLHostDisplay::RenderSoftwareCursor(s32 left, s32 bottom, s32 width, s32 height,
											 HostDisplayTexture* texture_handle)
{
	glViewport(left, bottom, width, height);
	glEnable(GL_BLEND);
	glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ZERO);
	glBlendEquationSeparate(GL_FUNC_ADD, GL_FUNC_ADD);
	glDisable(GL_CULL_FACE);
	glDisable(GL_DEPTH_TEST);
	glDisable(GL_SCISSOR_TEST);
	glDepthMask(GL_FALSE);
	m_cursor_program.Bind();
	glBindTexture(GL_TEXTURE_2D, static_cast<OGLHostDisplayTexture*>(texture_handle)->GetGLID());
	
	m_cursor_program.Uniform4f(0, 0.0f, 0.0f, 1.0f, 1.0f);
	glBindSampler(0, m_display_linear_sampler);
	glBindVertexArray(m_display_vao);
	glDrawArrays(GL_TRIANGLES, 0, 3);
	glBindSampler(0, 0);
}

bool OpenGLHostDisplay::SetPostProcessingChain(const std::string_view& config)
{
	return false;
}

static std::string GetFullscreenModeString(u32 width, u32 height, float refresh_rate)
{
	char val[64];
	snprintf(val, sizeof(val), "%u x %u @ %f hz", width, height, refresh_rate);
	return val;
}

HostDisplay::AdapterAndModeList OpenGLHostDisplay::GetAdapterAndModeList()
{
	AdapterAndModeList aml;
	
	if (m_gl_context) {
		for (const GL::Context::FullscreenModeInfo& fmi : m_gl_context->EnumerateFullscreenModes()) {
			aml.fullscreen_modes.push_back(GetFullscreenModeString(fmi.width, fmi.height, fmi.refresh_rate));
		}
	}
	
	return aml;
}

bool OpenGLHostDisplay::RenderScreenshot(u32 width, u32 height, std::vector<u32>* out_pixels, u32* out_stride,
										 HostDisplayPixelFormat* out_format)
{
	// do nothing: OpenEmu handles all the screen shotting stuff.
	return false;
}

#pragma mark -

ContextGL::ContextGL(const WindowInfo& wi) : Context(wi)
{
//	m_opengl_module_handle = dlopen("/System/Library/Frameworks/OpenGL.framework/Versions/Current/OpenGL", RTLD_NOW);
//	if (!m_opengl_module_handle) {
//		os_log_fault(OE_CORE_LOG, "Could not open OpenGL.framework, function lookups will probably fail");
//	}
}

ContextGL::~ContextGL() = default;

std::unique_ptr<GL::Context> ContextGL::Create(const WindowInfo& wi, const Version* versions_to_try,
											   size_t num_versions_to_try)
{
	std::unique_ptr<ContextGL> context = std::make_unique<ContextGL>(wi);
	return context;
}

void* ContextGL::GetProcAddress(const char* name)
{
//	void* addr = m_opengl_module_handle ? dlsym(m_opengl_module_handle, name) : nullptr;
//	if (addr) {
//		return addr;
//	}
//
//	return dlsym(RTLD_NEXT, name);
    void* addr = dlsym(RTLD_DEFAULT, name);
    if (addr)
      return addr;

    return dlsym(RTLD_NEXT, name);
}

bool ContextGL::ChangeSurface(const WindowInfo& new_wi)
{
	return true;
}

void ContextGL::ResizeSurface(u32 new_surface_width /*= 0*/, u32 new_surface_height /*= 0*/)
{
	UpdateDimensions();
}

bool ContextGL::UpdateDimensions()
{
	return true;
}

bool ContextGL::SwapBuffers()
{
	return true;
}

bool ContextGL::MakeCurrent()
{
	return true;
}

bool ContextGL::DoneCurrent()
{
	return true;
}

bool ContextGL::SetSwapInterval(s32 interval)
{
	return true;
}

std::unique_ptr<GL::Context> ContextGL::CreateSharedContext(const WindowInfo& wi)
{
	std::unique_ptr<ContextGL> context = std::make_unique<ContextGL>(wi);
	
	return context;
}
