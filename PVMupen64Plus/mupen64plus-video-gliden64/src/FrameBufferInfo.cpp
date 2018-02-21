#include <assert.h>
#include "FrameBufferInfoAPI.h"
#include "FrameBufferInfo.h"
#include "Config.h"
#include "gSP.h"
#include "FrameBuffer.h"
#include "DepthBuffer.h"
#include "RSP.h"
#include "VI.h"
#include "Log.h"

namespace FBInfo {

	FBInfo fbInfo;

	FBInfo::FBInfo()
	{
		reset();
	}

	void FBInfo::reset() {
		m_supported = false;
		m_writeBuffers.fill(nullptr);
		m_readBuffers.fill(nullptr);
	}

	FBInfo::BufferSearchResult FBInfo::_findBuffer(const BuffersArray& _buffers, const FrameBuffer* _buf) const
	{
		u32 i = 0;
		while (_buffers[i] != nullptr) {
			if (_buffers[i++] == _buf)
				return BufferSearchResult(true, i);
		}
		assert(i < _buffers.size());
		return BufferSearchResult(false, i);
	}


	void FBInfo::Write(u32 addr, u32 size)
	{
		const u32 address = RSP_SegmentToPhysical(addr);
		const FrameBuffer* writeBuffer = frameBufferList().findBuffer(address);
		if (writeBuffer == nullptr)
			return;
		const auto findRes = _findBuffer(m_writeBuffers, writeBuffer);
		if (!findRes.first)
			m_writeBuffers[findRes.second] = writeBuffer;
		FrameBuffer_AddAddress(address, size);
	}

	void FBInfo::WriteList(FrameBufferModifyEntry *plist, u32 size)
	{
		LOG(LOG_WARNING, "FBWList size=%u\n", size);
	}

	void FBInfo::Read(u32 addr)
	{
		const u32 address = RSP_SegmentToPhysical(addr);
		FrameBuffer * pBuffer = frameBufferList().findBuffer(address);

		if (pBuffer == nullptr || _findBuffer(m_writeBuffers, pBuffer).first)
			return;

		const auto findRes = _findBuffer(m_readBuffers, pBuffer);
		if (pBuffer->m_isDepthBuffer) {
			if (config.frameBufferEmulation.fbInfoReadDepthChunk != 0)
				FrameBuffer_CopyDepthBufferChunk(address);
			else if (!findRes.first)
				FrameBuffer_CopyDepthBuffer(address);
		} else {
			if (config.frameBufferEmulation.fbInfoReadColorChunk != 0)
				FrameBuffer_CopyChunkToRDRAM(address);
			else if (!findRes.first)
				FrameBuffer_CopyToRDRAM(address, true);
		}

		if (!findRes.first)
			m_readBuffers[findRes.second] = pBuffer;
	}

	void FBInfo::GetInfo(void *pinfo)
	{
		//	debugPrint("FBGetInfo\n");
		FrameBufferInfo * pFBInfo = (FrameBufferInfo*)pinfo;
		memset(pFBInfo, 0, sizeof(FrameBufferInfo)* 6);

		if (config.frameBufferEmulation.fbInfoDisabled != 0)
			return;

		u32 idx = 0;
		DepthBuffer * pDepthBuffer = depthBufferList().getCurrent();
		if (pDepthBuffer != nullptr) {
			pFBInfo[idx].addr = pDepthBuffer->m_address;
			pFBInfo[idx].width = pDepthBuffer->m_width;
			pFBInfo[idx].height = VI.real_height;
			pFBInfo[idx++].size = 2;
		}
		frameBufferList().fillBufferInfo(&pFBInfo[idx], 6 - idx);

		m_writeBuffers.fill(nullptr);
		m_readBuffers.fill(nullptr);
		m_supported = true;
	}
}
