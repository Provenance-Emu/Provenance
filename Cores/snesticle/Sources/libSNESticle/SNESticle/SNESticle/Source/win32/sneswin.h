
#ifndef _SNESWIN_H
#define _SNESWIN_H

#include "window.h"
#include "snes.h"
#include "snstate.h"
#include "ddsurface.h"
#include "wavfile.h"
#include "mixconvert.h"

class CInputDevice;

enum SnesWinStateE
{
	SNESWIN_STATE_IDLE,
	SNESWIN_STATE_RUN,
	SNESWIN_STATE_PAUSED,
	SNESWIN_STATE_STEPFRAME,
};

class CSnesWin : public CGepWin
{
	SnesSystem		m_Snes;
	SnesRom			m_Rom;
	CDDSurface		m_DDSurface;
	SnesStateT		m_State;
	CWavFile		m_WavFile;
//	CMixConvert		m_MixConvert;

	Char			m_Name[256];

	Uint32			m_uScreenShot;

	SnesWinStateE	m_eState;


	Char			m_DirScreenshot[256];
	Char			m_DirRom[256];
	Char			m_DirDump[256];
	Char			m_DirState[256];

	CInputDevice	*m_pDevice[SNESIO_DEVICE_NUM];

protected:
	void OnPaint();
	void OnDestroy();
	void OnMenuCommand(Uint32 uCmd);
	void SetActive(Bool bActive);

public:


	CSnesWin();
	~CSnesWin();

	void SetName(Char *pName);
	Char *GetName() {return m_Name;}

	Bool LoadRom(char *pFilePath);
	void FreeRom();

	void CreateSurface();
	void CreateMixer();

	void PathResolve(char *pPath, const char *pFilePath,const char *pDir, const char *pExtension);
	void Process();
	void ScreenShot();
	void OpenRomDlg();
	void DumpCPUMem();
	void DumpPPUMem();
	void DumpSPCMem();
	void DisasmCPUMemory();
	void DisasmSPCMemory();
	void Reset();
	void SoftReset();
	void SaveState();
	void RestoreState();
	void Pause();
	void StepFrame();

	void SaveBRAM();
	void LoadBRAM();

	void ReadInput(Emu::SysInputT *pInput);
	void SetInput(Int32 iPort, CInputDevice *pDevice);
//	void UpdatePalette();
//	void SetPalette(Color32T *pPalette);
};


#endif
