#ifdef OS_WINDOWS
# include <windows.h>
#else
# include <winlnxdefs.h>
#endif // OS_WINDOWS
#include <assert.h>

#include <PluginAPI.h>

#include <N64.h>
#include <GLideN64.h>
#include <RSP.h>
#include <RDP.h>
#include <VI.h>
#include <Config.h>
#include <FrameBufferInfo.h>
#include <TextureFilterHandler.h>
#include <Log.h>
#include "Graphics/Context.h"
#include <DisplayWindow.h>

PluginAPI & PluginAPI::get()
{
	static PluginAPI api;
	return api;
}

#ifdef RSPTHREAD
class APICommand {
public:
	virtual bool run() = 0;
};

void RSP_ThreadProc(std::mutex * _pRspThreadMtx, std::mutex * _pPluginThreadMtx, std::condition_variable_any * _pRspThreadCv, std::condition_variable_any * _pPluginThreadCv, APICommand ** _pCommand)
{
	_pRspThreadMtx->lock();
	RSP_Init();
	GBI.init();
	Config_LoadConfig();
	dwnd().start();
	assert(!gfxContext.isError());

	while (true) {
		_pPluginThreadMtx->lock();
		_pPluginThreadCv->notify_one();
		_pPluginThreadMtx->unlock();
		_pRspThreadCv->wait(*_pRspThreadMtx);
		if (*_pCommand != nullptr && !(*_pCommand)->run())
			return;
		assert(!gfxContext.isError());
	}
}

void PluginAPI::_callAPICommand(APICommand & _command)
{
	m_pCommand = &_command;
	m_pluginThreadMtx.lock();
	m_rspThreadMtx.lock();
	m_rspThreadCv.notify_one();
	m_rspThreadMtx.unlock();
	m_pluginThreadCv.wait(m_pluginThreadMtx);
	m_pluginThreadMtx.unlock();
	m_pCommand = nullptr;
}

class ProcessDListCommand : public APICommand {
public:
	bool run() {
		RSP_ProcessDList();
		return true;
	}
};

class ProcessRDPListCommand : public APICommand {
public:
	bool run() {
		RDP_ProcessRDPList();
		return true;
	}
};

class ProcessUpdateScreenCommand : public APICommand {
public:
	bool run() {
		VI_UpdateScreen();
		return true;
	}
};

class FBReadCommand : public APICommand {
public:
	FBReadCommand(u32 _addr) : m_addr(_addr) {
	}

	bool run() {
		FBInfo::fbInfo.Read(m_addr);
		return true;
	}
private:
	u32 m_addr;
};

class ReadScreenCommand : public APICommand {
public:
	ReadScreenCommand(void **_dest, long *_width, long *_height)
		: m_dest(_dest)
		, m_width(_width)
		, m_height(_height) {
	}

	bool run() {
		dwnd().readScreen(m_dest, m_width, m_height);
		return true;
	}

private:
	void ** m_dest;
	long * m_width;
	long * m_height;
};

class RomClosedCommand : public APICommand {
public:
	RomClosedCommand(std::mutex * _pRspThreadMtx,
		std::mutex * _pPluginThreadMtx,
		std::condition_variable_any * _pRspThreadCv,
		std::condition_variable_any * _pPluginThreadCv)
		: m_pRspThreadMtx(_pRspThreadMtx)
		, m_pPluginThreadMtx(_pPluginThreadMtx)
		, m_pRspThreadCv(_pRspThreadCv)
		, m_pPluginThreadCv(_pPluginThreadCv) {
	}

	bool run() {
		TFH.dumpcache();
		dwnd().stop();
		GBI.destroy();
		m_pRspThreadMtx->unlock();
		m_pPluginThreadMtx->lock();
		m_pPluginThreadCv->notify_one();
		m_pPluginThreadMtx->unlock();
		return false;
	}

private:
	std::mutex * m_pRspThreadMtx;
	std::mutex * m_pPluginThreadMtx;
	std::condition_variable_any * m_pRspThreadCv;
	std::condition_variable_any * m_pPluginThreadCv;
};
#endif

void PluginAPI::ProcessDList()
{
	LOG(LOG_APIFUNC, "ProcessDList\n");
#ifdef RSPTHREAD
	_callAPICommand(ProcessDListCommand());
#else
	RSP_ProcessDList();
#endif
}

void PluginAPI::ProcessRDPList()
{
	LOG(LOG_APIFUNC, "ProcessRDPList\n");
#ifdef RSPTHREAD
	_callAPICommand(ProcessRDPListCommand());
#else
	RDP_ProcessRDPList();
#endif
}

void PluginAPI::RomClosed()
{
	LOG(LOG_APIFUNC, "RomClosed\n");
	m_bRomOpen = false;
#ifdef RSPTHREAD
	_callAPICommand(RomClosedCommand(
					&m_rspThreadMtx,
					&m_pluginThreadMtx,
					&m_rspThreadCv,
					&m_pluginThreadCv)
	);
	delete m_pRspThread;
	m_pRspThread = nullptr;
#else
	TFH.dumpcache();
	dwnd().stop();
	GBI.destroy();
#endif
}

void PluginAPI::RomOpen()
{
	LOG(LOG_APIFUNC, "RomOpen\n");
#ifdef RSPTHREAD
	m_pluginThreadMtx.lock();
	m_pRspThread = new std::thread(RSP_ThreadProc, &m_rspThreadMtx, &m_pluginThreadMtx, &m_rspThreadCv, &m_pluginThreadCv, &m_pCommand);
	m_pRspThread->detach();
	m_pluginThreadCv.wait(m_pluginThreadMtx);
	m_pluginThreadMtx.unlock();
#else
	RSP_Init();
	GBI.init();
	Config_LoadConfig();
	dwnd().start();
#endif
	m_bRomOpen = true;
}

void PluginAPI::ShowCFB()
{
	gDP.changed |= CHANGED_CPU_FB_WRITE;
}

void PluginAPI::UpdateScreen()
{
	LOG(LOG_APIFUNC, "UpdateScreen\n");
#ifdef RSPTHREAD
	_callAPICommand(ProcessUpdateScreenCommand());
#else
	VI_UpdateScreen();
#endif
}

void PluginAPI::_initiateGFX(const GFX_INFO & _gfxInfo) const {
	HEADER = _gfxInfo.HEADER;
	DMEM = _gfxInfo.DMEM;
	IMEM = _gfxInfo.IMEM;
	RDRAM = _gfxInfo.RDRAM;

	REG.MI_INTR = _gfxInfo.MI_INTR_REG;
	REG.DPC_START = _gfxInfo.DPC_START_REG;
	REG.DPC_END = _gfxInfo.DPC_END_REG;
	REG.DPC_CURRENT = _gfxInfo.DPC_CURRENT_REG;
	REG.DPC_STATUS = _gfxInfo.DPC_STATUS_REG;
	REG.DPC_CLOCK = _gfxInfo.DPC_CLOCK_REG;
	REG.DPC_BUFBUSY = _gfxInfo.DPC_BUFBUSY_REG;
	REG.DPC_PIPEBUSY = _gfxInfo.DPC_PIPEBUSY_REG;
	REG.DPC_TMEM = _gfxInfo.DPC_TMEM_REG;

	REG.VI_STATUS = _gfxInfo.VI_STATUS_REG;
	REG.VI_ORIGIN = _gfxInfo.VI_ORIGIN_REG;
	REG.VI_WIDTH = _gfxInfo.VI_WIDTH_REG;
	REG.VI_INTR = _gfxInfo.VI_INTR_REG;
	REG.VI_V_CURRENT_LINE = _gfxInfo.VI_V_CURRENT_LINE_REG;
	REG.VI_TIMING = _gfxInfo.VI_TIMING_REG;
	REG.VI_V_SYNC = _gfxInfo.VI_V_SYNC_REG;
	REG.VI_H_SYNC = _gfxInfo.VI_H_SYNC_REG;
	REG.VI_LEAP = _gfxInfo.VI_LEAP_REG;
	REG.VI_H_START = _gfxInfo.VI_H_START_REG;
	REG.VI_V_START = _gfxInfo.VI_V_START_REG;
	REG.VI_V_BURST = _gfxInfo.VI_V_BURST_REG;
	REG.VI_X_SCALE = _gfxInfo.VI_X_SCALE_REG;
	REG.VI_Y_SCALE = _gfxInfo.VI_Y_SCALE_REG;

	CheckInterrupts = _gfxInfo.CheckInterrupts;

	REG.SP_STATUS = nullptr;
}

void PluginAPI::ChangeWindow()
{
	LOG(LOG_APIFUNC, "ChangeWindow\n");
	dwnd().setToggleFullscreen();
	if (!m_bRomOpen)
		dwnd().closeWindow();
}

void PluginAPI::FBWrite(unsigned int _addr, unsigned int _size)
{
	FBInfo::fbInfo.Write(_addr, _size);
}

void PluginAPI::FBRead(unsigned int _addr)
{
#ifdef RSPTHREAD
	_callAPICommand(FBReadCommand(_addr));
#else
	FBInfo::fbInfo.Read(_addr);
#endif
}

void PluginAPI::FBGetFrameBufferInfo(void * _pinfo)
{
	FBInfo::fbInfo.GetInfo(_pinfo);
}

#ifndef MUPENPLUSAPI
void PluginAPI::FBWList(FrameBufferModifyEntry * _plist, unsigned int _size)
{
	FBInfo::fbInfo.WriteList(reinterpret_cast<FBInfo::FrameBufferModifyEntry*>(_plist), _size);
}

void PluginAPI::ReadScreen(void **_dest, long *_width, long *_height)
{
#ifdef RSPTHREAD
	_callAPICommand(ReadScreenCommand(_dest, _width, _height));
#else
	dwnd().readScreen(_dest, _width, _height);
#endif
}
#endif
