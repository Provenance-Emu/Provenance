#include <Config.h>
#include "GLFunctions.h"
#include "opengl_Attributes.h"
#include "opengl_CachedFunctions.h"
#include "opengl_UnbufferedDrawer.h"

using namespace opengl;

UnbufferedDrawer::UnbufferedDrawer(const GLInfo & _glinfo, CachedVertexAttribArray * _cachedAttribArray)
: m_glInfo(_glinfo)
, m_cachedAttribArray(_cachedAttribArray)
{
	m_cachedAttribArray->enableVertexAttribArray(triangleAttrib::position, false);
	m_cachedAttribArray->enableVertexAttribArray(triangleAttrib::color, false);
	m_cachedAttribArray->enableVertexAttribArray(triangleAttrib::texcoord, false);
	m_cachedAttribArray->enableVertexAttribArray(triangleAttrib::numlights, false);
	m_cachedAttribArray->enableVertexAttribArray(triangleAttrib::modify, false);

	m_cachedAttribArray->enableVertexAttribArray(rectAttrib::position, false);
	m_cachedAttribArray->enableVertexAttribArray(rectAttrib::texcoord0, false);
	m_cachedAttribArray->enableVertexAttribArray(rectAttrib::texcoord1, false);

	m_attribsData.fill(nullptr);
}

UnbufferedDrawer::~UnbufferedDrawer()
{
}

bool UnbufferedDrawer::_updateAttribPointer(u32 _index, const void * _ptr)
{
	if (m_attribsData[_index] == _ptr)
		return false;

	m_attribsData[_index] = _ptr;
	return true;
}

void UnbufferedDrawer::drawTriangles(const graphics::Context::DrawTriangleParameters & _params)
{
	{
		m_cachedAttribArray->enableVertexAttribArray(triangleAttrib::position, true);
		const void * ptr = &_params.vertices->x;
		if (_updateAttribPointer(triangleAttrib::position, ptr))
			glVertexAttribPointer(triangleAttrib::position, 4, GL_FLOAT, GL_FALSE, sizeof(SPVertex), ptr);
	}

	if (_params.combiner->usesShade()) {
		m_cachedAttribArray->enableVertexAttribArray(triangleAttrib::color, true);
		const void * ptr = _params.flatColors ? &_params.vertices->flat_r : &_params.vertices->r;
		if (_updateAttribPointer(triangleAttrib::color, ptr))
			glVertexAttribPointer(triangleAttrib::color, 4, GL_FLOAT, GL_FALSE, sizeof(SPVertex), ptr);
	}
	else
		m_cachedAttribArray->enableVertexAttribArray(triangleAttrib::color, false);

	if (_params.combiner->usesTexture()) {
		m_cachedAttribArray->enableVertexAttribArray(triangleAttrib::texcoord, true);
		const void * ptr = &_params.vertices->s;
		if (_updateAttribPointer(triangleAttrib::texcoord, ptr))
			glVertexAttribPointer(triangleAttrib::texcoord, 2, GL_FLOAT, GL_FALSE, sizeof(SPVertex), ptr);
	} else
		m_cachedAttribArray->enableVertexAttribArray(triangleAttrib::texcoord, false);

	{
		m_cachedAttribArray->enableVertexAttribArray(triangleAttrib::modify, true);
		const void * ptr = &_params.vertices->modify;
		if (_updateAttribPointer(triangleAttrib::modify, ptr))
			glVertexAttribPointer(triangleAttrib::modify, 4, GL_BYTE, GL_FALSE, sizeof(SPVertex), ptr);
	}

	if (isHWLightingAllowed())
		glVertexAttrib1f(triangleAttrib::numlights, GLfloat(_params.vertices[0].HWLight));

	m_cachedAttribArray->enableVertexAttribArray(rectAttrib::position, false);
	m_cachedAttribArray->enableVertexAttribArray(rectAttrib::texcoord0, false);
	m_cachedAttribArray->enableVertexAttribArray(rectAttrib::texcoord1, false);

	if (_params.elements == nullptr) {
		glDrawArrays(GLenum(_params.mode), 0, _params.verticesCount);
		return;
	}

	if (config.frameBufferEmulation.N64DepthCompare == 0) {
		glDrawElements(GLenum(_params.mode), _params.elementsCount, GL_UNSIGNED_BYTE, _params.elements);
		return;
	}

	// Draw polygons one by one
	for (GLuint i = 0; i < _params.elementsCount; i += 3) {
		glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);
		glDrawElements(GLenum(_params.mode), 3, GL_UNSIGNED_BYTE, (u8*)_params.elements + i);
	}
}

void UnbufferedDrawer::drawRects(const graphics::Context::DrawRectParameters & _params)
{
	{
		m_cachedAttribArray->enableVertexAttribArray(rectAttrib::position, true);
		const void * ptr = &_params.vertices->x;
		if (_updateAttribPointer(rectAttrib::position, ptr))
			glVertexAttribPointer(rectAttrib::position, 4, GL_FLOAT, GL_FALSE, sizeof(RectVertex), ptr);
	}

	if (_params.texrect && _params.combiner->usesTile(0)) {
		m_cachedAttribArray->enableVertexAttribArray(rectAttrib::texcoord0, true);
		const void * ptr = &_params.vertices->s0;
		if (_updateAttribPointer(rectAttrib::texcoord0, ptr))
			glVertexAttribPointer(rectAttrib::texcoord0, 2, GL_FLOAT, GL_FALSE, sizeof(RectVertex), ptr);
	} else
		m_cachedAttribArray->enableVertexAttribArray(rectAttrib::texcoord0, false);

	if (_params.texrect && _params.combiner->usesTile(1)) {
		m_cachedAttribArray->enableVertexAttribArray(rectAttrib::texcoord1, true);
		const void * ptr = &_params.vertices->s1;
		if (_updateAttribPointer(rectAttrib::texcoord1, ptr))
			glVertexAttribPointer(rectAttrib::texcoord1, 2, GL_FLOAT, GL_FALSE, sizeof(RectVertex), ptr);
	} else
		m_cachedAttribArray->enableVertexAttribArray(rectAttrib::texcoord1, false);

	m_cachedAttribArray->enableVertexAttribArray(triangleAttrib::position, false);
	m_cachedAttribArray->enableVertexAttribArray(triangleAttrib::color, false);
	m_cachedAttribArray->enableVertexAttribArray(triangleAttrib::texcoord, false);
	m_cachedAttribArray->enableVertexAttribArray(triangleAttrib::modify, false);

	glDrawArrays(GLenum(_params.mode), 0, _params.verticesCount);
}

void UnbufferedDrawer::drawLine(f32 _width, SPVertex * _vertices)
{
	{
		m_cachedAttribArray->enableVertexAttribArray(triangleAttrib::position, true);
		const void * ptr = &_vertices->x;
		if (_updateAttribPointer(triangleAttrib::position, ptr))
			glVertexAttribPointer(triangleAttrib::position, 4, GL_FLOAT, GL_FALSE, sizeof(SPVertex), ptr);
	}

	{
		m_cachedAttribArray->enableVertexAttribArray(triangleAttrib::color, true);
		const void * ptr = &_vertices->r;
		if (_updateAttribPointer(triangleAttrib::color, ptr))
			glVertexAttribPointer(triangleAttrib::color, 4, GL_FLOAT, GL_FALSE, sizeof(SPVertex), ptr);
	}

	m_cachedAttribArray->enableVertexAttribArray(triangleAttrib::texcoord, false);
	m_cachedAttribArray->enableVertexAttribArray(triangleAttrib::modify, false);

	m_cachedAttribArray->enableVertexAttribArray(rectAttrib::position, false);
	m_cachedAttribArray->enableVertexAttribArray(rectAttrib::texcoord0, false);
	m_cachedAttribArray->enableVertexAttribArray(rectAttrib::texcoord1, false);

	glLineWidth(_width);
	glDrawArrays(GL_LINES, 0, 2);
}
