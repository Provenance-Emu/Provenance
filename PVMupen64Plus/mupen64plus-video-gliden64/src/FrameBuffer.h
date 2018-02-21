#ifndef FRAMEBUFFER_H
#define FRAMEBUFFER_H

#include <list>
#include <vector>

#include "Types.h"
#include "Textures.h"
#include "Graphics/ObjectHandle.h"

struct gDPTile;
struct DepthBuffer;

const int fingerprint[4] = { 2, 6, 4, 3 };

struct FrameBuffer
{
	FrameBuffer();
	~FrameBuffer();
	void init(u32 _address, u16 _format, u16 _size, u16 _width, bool _cfb);
	void updateEndAddress();
	void resolveMultisampledTexture(bool _bForce = false);
	CachedTexture * getTexture(u32 _t);
	CachedTexture * getTextureBG(u32 _t);
	void setBufferClearParams(u32 _fillcolor, s32 _ulx, s32 _uly, s32 _lrx, s32 _lry);
	void copyRdram();
	void setDirty();
	bool isValid(bool _forceCheck) const;
	bool _isMarioTennisScoreboard() const;
	bool isAuxiliary() const;

	u32 m_startAddress, m_endAddress;
	u32 m_size, m_width, m_height;
	float m_scale;
	bool m_copiedToRdram;
	bool m_fingerprint;
	bool m_cleared;
	bool m_changed;
	bool m_cfb;
	bool m_isDepthBuffer;
	bool m_isPauseScreen;
	bool m_isOBScreen;
	bool m_isMainBuffer;
	bool m_readable;

	struct {
		u32 uls, ult;
	} m_loadTileOrigin;
	u32 m_loadType;

	graphics::ObjectHandle m_FBO;
	CachedTexture *m_pTexture;
	DepthBuffer *m_pDepthBuffer;

	// multisampling
	graphics::ObjectHandle m_resolveFBO;
	CachedTexture *m_pResolveTexture;
	bool m_resolved;

	// subtexture
	graphics::ObjectHandle m_SubFBO;
	CachedTexture *m_pSubTexture;

	std::vector<u8> m_RdramCopy;

private:
	struct {
		u32 fillcolor = 0;
		s32 ulx = 0;
		s32 uly = 0;
		s32 lrx = 0;
		s32 lry = 0;
	} m_clearParams;

	void _initTexture(u16 _width, u16 _height, u16 _format, u16 _size, CachedTexture *_pTexture);
	void _setAndAttachTexture(graphics::ObjectHandle _fbo, CachedTexture *_pTexture, u32 _t, bool _multisampling);
	bool _initSubTexture(u32 _t);
	CachedTexture * _getSubTexture(u32 _t);
	mutable u32 m_validityChecked;
};

class FrameBufferList
{
public:
	void init();
	void destroy();
	void saveBuffer(u32 _address, u16 _format, u16 _size, u16 _width, bool _cfb);
	void removeAux();
	void copyAux();
	void removeBuffer(u32 _address);
	void removeBuffers(u32 _width);
	void attachDepthBuffer();
	void clearDepthBuffer(DepthBuffer * _pDepthBuffer);
	FrameBuffer * findBuffer(u32 _startAddress);
	FrameBuffer * getBuffer(u32 _startAddress);
	FrameBuffer * findTmpBuffer(u32 _address);
	FrameBuffer * getCurrent() const {return m_pCurrent;}
	void setCurrent(FrameBuffer * _pCurrent) { m_pCurrent = _pCurrent; }
	void renderBuffer();
	void setBufferChanged(f32 _maxY);
	void clearBuffersChanged();
	void setCurrentDrawBuffer() const;
	void fillRDRAM(s32 ulx, s32 uly, s32 lrx, s32 lry);

	FrameBuffer * getCopyBuffer() const { return m_pCopy; }
	void setCopyBuffer(FrameBuffer * _pBuffer) { m_pCopy = _pBuffer; }
	void depthBufferCopyRdram();

	void fillBufferInfo(void * _pinfo, u32 _size);

	static FrameBufferList & get();

private:
	FrameBufferList() : m_pCurrent(nullptr), m_pCopy(nullptr), m_prevColorImageHeight(0) {}
	FrameBufferList(const FrameBufferList &) = delete;

	void removeIntersections();

	void _createScreenSizeBuffer();
	void _renderScreenSizeBuffer();

	typedef std::list<FrameBuffer> FrameBuffers;
	FrameBuffers m_list;
	FrameBuffer * m_pCurrent;
	FrameBuffer * m_pCopy;
	u32 m_prevColorImageHeight;
};

inline
FrameBufferList & frameBufferList()
{
	return FrameBufferList::get();
}

u32 cutHeight(u32 _address, u32 _height, u32 _stride);
void calcCoordsScales(const FrameBuffer * _pBuffer, f32 & _scaleX, f32 & _scaleY);

void FrameBuffer_Init();
void FrameBuffer_Destroy();
void FrameBuffer_CopyToRDRAM( u32 _address , bool _sync );
void FrameBuffer_CopyChunkToRDRAM(u32 _address);
void FrameBuffer_CopyFromRDRAM(u32 address, bool bUseAlpha);
void FrameBuffer_AddAddress(u32 address, u32 _size);
bool FrameBuffer_CopyDepthBuffer(u32 address);
bool FrameBuffer_CopyDepthBufferChunk(u32 address);
void FrameBuffer_ActivateBufferTexture(u32 t, u32 _frameBufferAddress);
void FrameBuffer_ActivateBufferTextureBG(u32 t, u32 _frameBufferAddress);

#endif
