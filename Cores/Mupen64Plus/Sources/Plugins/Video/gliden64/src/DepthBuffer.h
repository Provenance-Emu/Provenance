#ifndef DEPTHBUFFER_H
#define DEPTHBUFFER_H

#include "Types.h"
#include "Textures.h"
#include "Graphics/ObjectHandle.h"
#include "Graphics/Parameter.h"

struct FrameBuffer;

struct DepthBuffer
{
	DepthBuffer();
	~DepthBuffer();
	void initDepthImageTexture(FrameBuffer * _pBuffer);
	void initDepthBufferTexture(FrameBuffer * _pBuffer);
	CachedTexture * resolveDepthBufferTexture(FrameBuffer * _pBuffer);
	CachedTexture * copyDepthBufferTexture(FrameBuffer * _pBuffer);

	void setDepthAttachment(graphics::ObjectHandle _fbo, graphics::BufferTargetParam _target);
	void activateDepthBufferTexture(FrameBuffer * _pBuffer);

	void bindDepthImageTexture(graphics::ObjectHandle _fbo);

	u32 m_address, m_width;
	bool m_cleared;

	CachedTexture *m_pDepthBufferTexture;

	graphics::ObjectHandle m_depthRenderbuffer;
	u32 m_depthRenderbufferWidth;

	CachedTexture *m_pDepthImageZTexture;
	CachedTexture *m_pDepthImageDeltaZTexture;
	graphics::ObjectHandle m_ZTextureClearFBO;
	graphics::ObjectHandle m_DeltaZTextureClearFBO;

	// multisampling
	CachedTexture *m_pResolveDepthBufferTexture;
	bool m_resolved;

	// render to depth buffer
	graphics::ObjectHandle m_copyFBO;
	CachedTexture *m_pDepthBufferCopyTexture;
	bool m_copied;

private:
	void _initDepthImageTexture(FrameBuffer * _pBuffer, CachedTexture& _cachedTexture, graphics::ObjectHandle & _clearFBO);
	void _initDepthBufferTexture(FrameBuffer * _pBuffer, CachedTexture *_pTexture, bool _multisample);
	void _initDepthBufferRenderbuffer(FrameBuffer * _pBuffer);
};

class DepthBufferList
{
public:
	void init();
	void destroy();
	void saveBuffer(u32 _address);
	void removeBuffer(u32 _address);
	void clearBuffer();
	void setCleared(bool _cleared);
	DepthBuffer *findBuffer(u32 _address);
	DepthBuffer * getCurrent() const {return m_pCurrent;}

	static DepthBufferList & get();

	const u16 * const getZLUT() const {return m_pzLUT;}

private:
	DepthBufferList();
	DepthBufferList(const DepthBufferList &) = delete;
	~DepthBufferList();

	void _createScreenSizeBuffer(u32 _address);

	typedef std::list<DepthBuffer> DepthBuffers;
	DepthBuffers m_list;
	DepthBuffer *m_pCurrent;
	u16 * m_pzLUT;
};

inline
DepthBufferList & depthBufferList()
{
	return DepthBufferList::get();
}

void DepthBuffer_Init();
void DepthBuffer_Destroy();

#endif
