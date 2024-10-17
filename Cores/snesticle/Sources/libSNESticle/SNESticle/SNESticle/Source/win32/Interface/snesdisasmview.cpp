
#include "resource.h"
#include "types.h"
#include "nesdisasmview.h"
#include "nes.h"

CNesDisasmView::CNesDisasmView()
{
	SetSize(330, m_TextMetrics.tmHeight * 20);

	m_pNes = NULL;

	ShowWindow(SW_SHOW);
}

void CNesDisasmView::SetView(NesMachine *pNes) 
{	
	m_pNes  = pNes;
	m_iLine = 0;
	SetScrollRange();

	SetTitle("CPU Disassembly");
	OnPaint();
}

Int32 CNesDisasmView::Disasm(Uint32 uAddr, Char *pStr)
{
	if (m_pNes)
	{
		NesCPU *pCPU = m_pNes->GetCPU();

		return N6502Disassemble(pCPU, (Uint16)uAddr, pStr);
	}

	strcpy(pStr, "");
	return 1;
}


Uint32 CNesDisasmView::GetAddrSize()
{
	if (m_pNes)
	{
		return 0x10000;
	}
	return 0;
}

void CNesDisasmView::OnMenuCommand(Uint32 uCmd)
{
}

