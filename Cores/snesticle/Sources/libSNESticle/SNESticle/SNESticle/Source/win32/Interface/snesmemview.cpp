
#include "resource.h"
#include "types.h"
#include "snesmemview.h"
#include "snes.h"


CSnesMemView::CSnesMemView()
{
	SetSize(330, m_TextMetrics.tmHeight * 20);

	m_eView = SNESMEMVIEW_NONE;
	m_pSnes = NULL;
	m_pRom = NULL;

	ShowWindow(SW_SHOW);
}

void CSnesMemView::SetView(SnesSystem *pSnes, SnesRom *pRom, SnesMemViewE eView) 
{	
	m_pSnes  = pSnes;
	m_pRom  = pRom;
	m_eView = eView;
	m_iLine = 0;
	SetScrollRange();

	switch (eView)
	{
	case SNESMEMVIEW_CPU: SetTitle("CPU Memory"); break;
		/*
	case NESMEMVIEW_PPU: SetTitle("PPU Memory"); break;
	case NESMEMVIEW_PRGROM: SetTitle("PRG ROM"); break;
	case NESMEMVIEW_CHRROM: SetTitle("CHR ROM"); break;
	*/
	default:
		SetTitle("Memory View");
		break;
	}

	OnPaint();
}


Uint8 CSnesMemView::ReadByte(Uint32 uAddr)
{
	if (m_pSnes)
	{
		switch (m_eView)
		{
		case SNESMEMVIEW_CPU:
			return SNCPUPeek8(m_pSnes->GetCpu(), uAddr);
			/*
		case NESMEMVIEW_PPU:
			return m_pNes->GetPPU()->VramRead(uAddr);
		case NESMEMVIEW_PRGROM:
			return m_pRom->m_Prg.ReadByte(uAddr);
		case NESMEMVIEW_CHRROM:
			return m_pRom->m_Chr.ReadByte(uAddr);
		case NESMEMVIEW_NONE:
			return 0;
			*/
		}
	}
	return 0;

}

Uint32 CSnesMemView::GetAddrSize()
{
	if (m_pSnes)
	{
		switch (m_eView)
		{
			/*
		case NESMEMVIEW_PRGROM:
			return m_pRom->m_Prg.GetSize();
		case NESMEMVIEW_CHRROM:
			return m_pRom->m_Chr.GetSize();
			*/
		case SNESMEMVIEW_CPU:
			return 0x1000000;
			/*
		case NESMEMVIEW_PPU:
			return 0x4000;
			*/
		case SNESMEMVIEW_NONE:
			return 0;
		}
	}
	return 0;
}

void CSnesMemView::OnMenuCommand(Uint32 uCmd)
{
	switch (uCmd)
	{
	case IDM_FILE_CLOSE:
		CloseWindow(GetWnd());
		break;
	case IDM_FILE_WRITE:
		//WriteBinary(
		break;

	case IDM_VIEW_CPUMEMORY:
		SetView(m_pSnes, m_pRom, SNESMEMVIEW_CPU);
		break;
		/*
	case IDM_VIEW_PPUMEMORY:
		SetView(m_pNes, m_pRom, NESMEMVIEW_PPU);
		break;
	case IDM_VIEW_PRGROM:
		SetView(m_pNes, m_pRom, NESMEMVIEW_PRGROM);
		break;
	case IDM_VIEW_CHRROM:
		SetView(m_pNes, m_pRom, NESMEMVIEW_CHRROM);
		break;
		*/
	}
}


