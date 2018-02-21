#include <Config.h>
#include <CRC.h>
#include "GLFunctions.h"
#include "opengl_Attributes.h"
#include "opengl_BufferedDrawer.h"

using namespace graphics;
using namespace opengl;

const u32 BufferedDrawer::m_bufMaxSize = 4194304;
#ifndef GL_DEBUG
const GLbitfield BufferedDrawer::m_bufAccessBits = GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT;
const GLbitfield BufferedDrawer::m_bufMapBits = GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT;
#else
const GLbitfield BufferedDrawer::m_bufAccessBits = GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT;
const GLbitfield BufferedDrawer::m_bufMapBits = GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_FLUSH_EXPLICIT_BIT;
#endif

BufferedDrawer::BufferedDrawer(const GLInfo & _glinfo, CachedVertexAttribArray * _cachedAttribArray, CachedBindBuffer * _bindBuffer)
: m_glInfo(_glinfo)
, m_cachedAttribArray(_cachedAttribArray)
, m_bindBuffer(_bindBuffer)
{
	m_vertices.resize(VERTBUFF_SIZE);
	/* Init buffers for rects */
	glGenVertexArrays(1, &m_rectsBuffers.vao);
	glBindVertexArray(m_rectsBuffers.vao);
	_initBuffer(m_rectsBuffers.vbo, m_bufMaxSize);
	m_cachedAttribArray->enableVertexAttribArray(rectAttrib::position, true);
	m_cachedAttribArray->enableVertexAttribArray(rectAttrib::texcoord0, true);
	m_cachedAttribArray->enableVertexAttribArray(rectAttrib::texcoord1, true);
	glVertexAttribPointer(rectAttrib::position, 4, GL_FLOAT, GL_FALSE, sizeof(RectVertex), (const GLvoid *)(offsetof(RectVertex, x)));
	glVertexAttribPointer(rectAttrib::texcoord0, 2, GL_FLOAT, GL_FALSE, sizeof(RectVertex), (const GLvoid *)(offsetof(RectVertex, s0)));
	glVertexAttribPointer(rectAttrib::texcoord1, 2, GL_FLOAT, GL_FALSE, sizeof(RectVertex), (const GLvoid *)(offsetof(RectVertex, s1)));

	/* Init buffers for triangles */
	glGenVertexArrays(1, &m_trisBuffers.vao);
	glBindVertexArray(m_trisBuffers.vao);
	_initBuffer(m_trisBuffers.vbo, m_bufMaxSize);
	_initBuffer(m_trisBuffers.ebo, m_bufMaxSize);
	m_cachedAttribArray->enableVertexAttribArray(triangleAttrib::position, true);
	m_cachedAttribArray->enableVertexAttribArray(triangleAttrib::color, true);
	m_cachedAttribArray->enableVertexAttribArray(triangleAttrib::texcoord, true);
	m_cachedAttribArray->enableVertexAttribArray(triangleAttrib::modify, true);
	m_cachedAttribArray->enableVertexAttribArray(triangleAttrib::numlights, false);
	glVertexAttribPointer(triangleAttrib::position, 4, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const GLvoid *)(offsetof(Vertex, x)));
	glVertexAttribPointer(triangleAttrib::color, 4, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const GLvoid *)(offsetof(Vertex, r)));
	glVertexAttribPointer(triangleAttrib::texcoord, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const GLvoid *)(offsetof(Vertex, s)));
	glVertexAttribPointer(triangleAttrib::modify, 4, GL_BYTE, GL_TRUE, sizeof(Vertex), (const GLvoid *)(offsetof(Vertex, modify)));
}

void BufferedDrawer::_initBuffer(Buffer & _buffer, GLuint _bufSize)
{
	_buffer.size = _bufSize;
	glGenBuffers(1, &_buffer.handle);
	m_bindBuffer->bind(Parameter(_buffer.type), ObjectHandle(_buffer.handle));
	if (m_glInfo.bufferStorage) {
		glBufferStorage(_buffer.type, _bufSize, nullptr, m_bufAccessBits);
		_buffer.data = (GLubyte*)glMapBufferRange(_buffer.type, 0, _bufSize, m_bufMapBits);
	} else {
		glBufferData(_buffer.type, _bufSize, nullptr, GL_DYNAMIC_DRAW);
	}
}

BufferedDrawer::~BufferedDrawer()
{
	m_bindBuffer->bind(Parameter(GL_ARRAY_BUFFER), ObjectHandle::null);
	m_bindBuffer->bind(Parameter(GL_ELEMENT_ARRAY_BUFFER), ObjectHandle::null);
	GLuint buffers[3] = { m_rectsBuffers.vbo.handle, m_trisBuffers.vbo.handle, m_trisBuffers.ebo.handle };
	glDeleteBuffers(3, buffers);
	glBindVertexArray(0);
	GLuint arrays[2] = { m_rectsBuffers.vao, m_trisBuffers.vao };
	glDeleteVertexArrays(2, arrays);
}

void BufferedDrawer::_updateBuffer(Buffer & _buffer, u32 _count, u32 _dataSize, const void * _data)
{
	if (_buffer.offset + _dataSize >= _buffer.size) {
		_buffer.offset = 0;
		_buffer.pos = 0;
	}

	if (m_glInfo.bufferStorage) {
		memcpy(&_buffer.data[_buffer.offset], _data, _dataSize);
#ifdef GL_DEBUG
		m_bindBuffer->bind(Parameter(_buffer.type), ObjectHandle(_buffer.handle));
		glFlushMappedBufferRange(_buffer.type, _buffer.offset, _dataSize);
#endif
	} else {
		m_bindBuffer->bind(Parameter(_buffer.type), ObjectHandle(_buffer.handle));
		void* buffer_pointer = glMapBufferRange(_buffer.type, _buffer.offset, _dataSize, GL_MAP_WRITE_BIT | GL_MAP_UNSYNCHRONIZED_BIT);
		memcpy(buffer_pointer, _data, _dataSize);
		glUnmapBuffer(_buffer.type);
	}

	_buffer.offset += _dataSize;
	_buffer.pos += _count;
}

void BufferedDrawer::_updateRectBuffer(const graphics::Context::DrawRectParameters & _params)
{
	const BuffersType type = BuffersType::rects;
	if (m_type != type) {
		glBindVertexArray(m_rectsBuffers.vao);
		m_type = type;
	}

	Buffer & buffer = m_rectsBuffers.vbo;
	const size_t dataSize = _params.verticesCount * sizeof(RectVertex);

	if (m_glInfo.bufferStorage) {
		_updateBuffer(buffer, _params.verticesCount, dataSize, _params.vertices);
		return;
	}

	const u32 crc = CRC_Calculate(0xFFFFFFFF, _params.vertices, dataSize);
	auto iter = m_rectBufferOffsets.find(crc);
	if (iter != m_rectBufferOffsets.end()) {
		buffer.pos = iter->second;
		return;
	}

	const GLintptr prevOffset = buffer.offset;
	_updateBuffer(buffer, _params.verticesCount, dataSize, _params.vertices);
	if (buffer.offset < prevOffset)
		m_rectBufferOffsets.clear();

	buffer.pos = buffer.offset / sizeof(RectVertex);
	m_rectBufferOffsets[crc] = buffer.pos;
}


void BufferedDrawer::drawRects(const graphics::Context::DrawRectParameters & _params)
{
	_updateRectBuffer(_params);

	m_cachedAttribArray->enableVertexAttribArray(rectAttrib::texcoord0, _params.texrect);
	m_cachedAttribArray->enableVertexAttribArray(rectAttrib::texcoord1, _params.texrect);

	glDrawArrays(GLenum(_params.mode), m_rectsBuffers.vbo.pos - _params.verticesCount, _params.verticesCount);
}

void BufferedDrawer::_convertFromSPVertex(bool _flatColors, u32 _count, const SPVertex * _data)
{
	if (_count > m_vertices.size())
		m_vertices.resize(_count);

	for (u32 i = 0; i < _count; ++i) {
		const SPVertex & src = _data[i];
		Vertex & dst = m_vertices[i];
		dst.x = src.x;
		dst.y = src.y;
		dst.z = src.z;
		dst.w = src.w;
		if (_flatColors) {
			dst.r = src.flat_r;
			dst.g = src.flat_g;
			dst.b = src.flat_b;
			dst.a = src.flat_a;
		} else {
			dst.r = src.r;
			dst.g = src.g;
			dst.b = src.b;
			dst.a = src.a;
		}
		dst.s = src.s;
		dst.t = src.t;
		dst.modify = src.modify;
	}
}

void BufferedDrawer::_updateTrianglesBuffers(const graphics::Context::DrawTriangleParameters & _params)
{
	const BuffersType type = BuffersType::triangles;

	if (m_type != type) {
		glBindVertexArray(m_trisBuffers.vao);
		m_type = type;
	}

	_convertFromSPVertex(_params.flatColors, _params.verticesCount, _params.vertices);
	const GLsizeiptr vboDataSize = _params.verticesCount * sizeof(Vertex);
	Buffer & vboBuffer = m_trisBuffers.vbo;
	_updateBuffer(vboBuffer, _params.verticesCount, vboDataSize, m_vertices.data());

	if (_params.elements == nullptr)
		return;

	const GLsizeiptr eboDataSize = sizeof(GLubyte) * _params.elementsCount;
	Buffer & eboBuffer = m_trisBuffers.ebo;
	_updateBuffer(eboBuffer, _params.elementsCount, eboDataSize, _params.elements);
}

void BufferedDrawer::drawTriangles(const graphics::Context::DrawTriangleParameters & _params)
{
	_updateTrianglesBuffers(_params);

	if (isHWLightingAllowed())
		glVertexAttrib1f(triangleAttrib::numlights, GLfloat(_params.vertices[0].HWLight));

	if (_params.elements == nullptr) {
		glDrawArrays(GLenum(_params.mode), m_trisBuffers.vbo.pos - _params.verticesCount, _params.verticesCount);
		return;
	}

	if (config.frameBufferEmulation.N64DepthCompare == 0) {
		glDrawElementsBaseVertex(GLenum(_params.mode), _params.elementsCount, GL_UNSIGNED_BYTE,
			(char*)nullptr + m_trisBuffers.ebo.pos - _params.elementsCount, m_trisBuffers.vbo.pos - _params.verticesCount);
		return;
	}

	// Draw polygons one by one
	const GLint eboStartPos = m_trisBuffers.ebo.pos - _params.elementsCount;
	const GLint vboStartPos = m_trisBuffers.vbo.pos - _params.verticesCount;
	for (GLuint i = 0; i < _params.elementsCount; i += 3) {
		glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);
		glDrawElementsBaseVertex(GLenum(_params.mode), 3, GL_UNSIGNED_BYTE,
			(char*)nullptr + eboStartPos + i, vboStartPos);
	}
}

void BufferedDrawer::drawLine(f32 _width, SPVertex * _vertices)
{
	const BuffersType type = BuffersType::triangles;

	if (m_type != type) {
		glBindVertexArray(m_trisBuffers.vao);
		m_type = type;
	}

	_convertFromSPVertex(false, 2, _vertices);
	const GLsizeiptr vboDataSize = 2 * sizeof(Vertex);
	Buffer & vboBuffer = m_trisBuffers.vbo;
	_updateBuffer(vboBuffer, 2, vboDataSize, m_vertices.data());

	glLineWidth(_width);
	glDrawArrays(GL_LINES, m_trisBuffers.vbo.pos - 2, 2);
}
