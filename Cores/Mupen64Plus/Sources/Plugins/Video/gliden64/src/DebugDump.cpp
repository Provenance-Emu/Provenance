#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fstream>
#include <memory>
#include <vector>
#include "PluginAPI.h"
#include "Log.h"
#include "wst.h"
#include "DebugDump.h"
#include "DisplayWindow.h"

#ifdef DEBUG_DUMP

class BufferedLog
{
public:
	BufferedLog(u32 _mode);
	BufferedLog(const BufferedLog&) = delete;
	~BufferedLog();

	void print(const char* _message);
	bool needPrint(u32 _mode) const;

private:
	u32 m_mode;
	std::ofstream m_log;
	std::vector<char> m_logBuffer;
};

BufferedLog::BufferedLog(u32 _mode) : m_mode(_mode)
{
	try {
		m_logBuffer.resize(1024*1024);
		m_log.rdbuf()->pubsetbuf(&m_logBuffer.front(), m_logBuffer.size());
	} catch(std::bad_alloc&) {
		LOG(LOG_ERROR, "Failed to alloc memory for log buffer\n");
	}

	wchar_t logPath[PLUGIN_PATH_SIZE + 16];
	api().GetUserDataPath(logPath);
	gln_wcscat(logPath, wst("/gliden64.debug.log"));
	const size_t bufSize = PLUGIN_PATH_SIZE * 6;
	char cbuf[bufSize];
	wcstombs(cbuf, logPath, bufSize);
	m_log.open(cbuf, std::ios::trunc);
}

BufferedLog::~BufferedLog()
{
	m_log.flush();
	m_log.close();
}

void BufferedLog::print(const char* _message)
{
	m_log << _message;
}

bool BufferedLog::needPrint(u32 _mode) const
{
	return (m_mode&_mode) != 0;
}

std::unique_ptr<BufferedLog> g_log;

void DebugMsg(u32 _mode, const char * _format, ...)
{
	if (!g_log || !g_log->needPrint(_mode))
		return;

	char buf[1024];
	char* text = buf;
	if ((_mode & DEBUG_IGNORED) != 0) {
		sprintf(buf, "Ignored: ");
		text += strlen(buf);
	}
	if ((_mode & DEBUG_ERROR) != 0) {
		sprintf(buf, "Error: ");
		text += strlen(buf);
	}

	va_list va;
	va_start(va, _format);
	vsprintf(text, _format, va);
	va_end(va);

	g_log->print(buf);
}

void StartDump(u32 _mode)
{
	dwnd().getDrawer().showMessage("Start commands logging\n", Milliseconds(750));
	g_log.reset(new BufferedLog(_mode));
}

void EndDump()
{
	dwnd().getDrawer().showMessage("Stop commands logging\n", Milliseconds(750));
	g_log.reset();
}

void SwitchDump(u32 _mode)
{
	if (_mode == 0)
		return;

	if (!g_log)
		StartDump(_mode);
	else
		EndDump();
}

bool IsDump()
{
	return !!g_log;
}

#endif // DEBUG_DUMP
