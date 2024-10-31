#include "../../Config.h"
#include <Graphics/Context.h>
#include "opengl_ColorBufferReaderWithBufferStorage.h"

using namespace graphics;
using namespace opengl;

ColorBufferReaderWithBufferStorage::ColorBufferReaderWithBufferStorage(CachedTexture * _pTexture,
	CachedBindBuffer * _bindBuffer)
	: ColorBufferReader(_pTexture), m_bindBuffer(_bindBuffer)
{
	_initBuffers();
}

ColorBufferReaderWithBufferStorage::~ColorBufferReaderWithBufferStorage()
{
	_destroyBuffers();
}

void ColorBufferReaderWithBufferStorage::_initBuffers()
{
	m_numPBO = config.frameBufferEmulation.copyToRDRAM;
	if (m_numPBO > _maxPBO)
		m_numPBO = _maxPBO;

	// Generate Pixel Buffer Objects
	glGenBuffers(m_numPBO, m_PBO);
	m_curIndex = 0;

	// Initialize Pixel Buffer Objects
	for (u32 index = 0; index < m_numPBO; ++index) {
		m_bindBuffer->bind(Parameter(GL_PIXEL_PACK_BUFFER), ObjectHandle(m_PBO[index]));
		m_fence[index] = 0;
		glBufferStorage(GL_PIXEL_PACK_BUFFER, m_pTexture->textureBytes, nullptr, GL_MAP_READ_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT);
		m_PBOData[index] = glMapBufferRange(GL_PIXEL_PACK_BUFFER, 0, m_pTexture->textureBytes, GL_MAP_READ_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT);
	}

	m_bindBuffer->bind(Parameter(GL_PIXEL_PACK_BUFFER), ObjectHandle::null);
}

void ColorBufferReaderWithBufferStorage::_destroyBuffers()
{
	glDeleteBuffers(m_numPBO, m_PBO);

	for (u32 index = 0; index < m_numPBO; ++index) {
		m_PBO[index] = 0;
		glDeleteSync(m_fence[index]);
	}
}

const u8 * ColorBufferReaderWithBufferStorage::_readPixels(const ReadColorBufferParams& _params, u32& _heightOffset,
	u32& _stride)
{
	GLenum format = GLenum(_params.colorFormat);
	GLenum type = GLenum(_params.colorType);

	m_bindBuffer->bind(Parameter(GL_PIXEL_PACK_BUFFER), ObjectHandle(m_PBO[m_curIndex]));
	glReadPixels(_params.x0, _params.y0, m_pTexture->realWidth, _params.height, format, type, 0);

	if (!_params.sync) {
		//Setup a fence sync object so that we know when glReadPixels completes
		m_fence[m_curIndex] = glFenceSync(GL_SYNC_GPU_COMMANDS_COMPLETE, 0);
		m_curIndex = (m_curIndex + 1) % m_numPBO;
		//Wait for glReadPixels to complete for the currently selected PBO
		if (m_fence[m_curIndex] != 0) {
			glClientWaitSync(m_fence[m_curIndex], 0, 100000000);
			glDeleteSync(m_fence[m_curIndex]);
			m_fence[m_curIndex] = 0;
		}
	} else {
		glFinish();
	}

	_heightOffset = 0;
	_stride = m_pTexture->realWidth;

	return reinterpret_cast<u8*>(m_PBOData[m_curIndex]);
}

void ColorBufferReaderWithBufferStorage::cleanUp()
{
	m_bindBuffer->bind(Parameter(GL_PIXEL_PACK_BUFFER), ObjectHandle::null);
}
