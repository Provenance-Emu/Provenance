


#ifndef _WINCONSOLE_H
#define _WINCONSOLE_H


class CLineBuffer;
class CMsgNode;

class CWinConsole
{
	HWND	m_hWnd;
	HFONT	m_hFont;

	CLineBuffer *m_pBuffer;
	CMsgNode	*m_pOutNode;

public:
	CWinConsole();
	~CWinConsole();

	void KeyDown(Uint32 ScanCode, Uint32 VirtKey);
	void OnSize(Uint32 Width, Uint32 Height);

	void SetBuffer(CLineBuffer *pBuffer);
	void SetOutput(CMsgNode *pOutNode);

	void Draw();
	void Draw(HDC hDC);
	void SetFont(Char *pFaceName, Int32 PointSize);
};






#endif
