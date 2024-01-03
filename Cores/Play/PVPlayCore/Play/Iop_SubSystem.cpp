// Local Changes: Support old format save files

#include "Iop_SubSystem.h"
#include "IopBios.h"
#include "GenericMipsExecutor.h"
#include "../psx/PsxBios.h"
#include "../states/MemoryStateFile.h"
#include "../states/RegisterStateFile.h"
#include "../Ps2Const.h"
#include "../Log.h"
#include "placeholder_def.h"

using namespace Iop;
using namespace PS2;

#define LOG_NAME ("iop_subsystem")

#define STATE_CPU ("iop_cpu")
#define STATE_RAM ("iop_ram")
#define STATE_SCRATCH ("iop_scratch")
#define STATE_SPURAM ("iop_spuram")

#define STATE_TIMING ("iop_timing")
#define STATE_TIMING_DMA_UPDATE_TICKS ("dmaUpdateTicks")
#define STATE_TIMING_SPU_IRQ_UPDATE_TICKS ("spuIrqUpdateTicks")

CSubSystem::CSubSystem(bool ps2Mode)
    : m_cpu(MEMORYMAP_ENDIAN_LSBF, true)
    , m_cpuArch(MIPS_REGSIZE_32)
    , m_copScu(MIPS_REGSIZE_32)
    , m_ram(new uint8[IOP_RAM_SIZE])
    , m_scratchPad(new uint8[IOP_SCRATCH_SIZE])
    , m_spuRam(new uint8[SPU_RAM_SIZE])
    , m_dmac(m_ram, m_intc)
    , m_counters(ps2Mode ? IOP_CLOCK_OVER_FREQ : IOP_CLOCK_BASE_FREQ, m_intc)
    , m_spuCore0(m_spuRam, SPU_RAM_SIZE, &m_spuSampleCache, 0)
    , m_spuCore1(m_spuRam, SPU_RAM_SIZE, &m_spuSampleCache, 1)
    , m_spu(m_spuCore0)
    , m_spu2(m_spuCore0, m_spuCore1)
#ifdef _IOP_EMULATE_MODULES
    , m_sio2(m_intc)
#endif
    , m_speed(m_intc)
    , m_ilink(m_intc)
{
	if(ps2Mode)
	{
		m_bios = std::make_shared<CIopBios>(m_cpu, m_ram, m_scratchPad);
	}
	else
	{
		m_bios = std::make_shared<CPsxBios>(m_cpu, m_ram, PS2::IOP_BASE_RAM_SIZE);
	}

	m_cpu.m_executor = std::make_unique<CGenericMipsExecutor<BlockLookupOneWay>>(m_cpu, (IOP_RAM_SIZE * 4), BLOCK_CATEGORY_PS2_IOP);

	//Read memory map
	m_cpu.m_pMemoryMap->InsertReadMap((0 * IOP_RAM_SIZE), (0 * IOP_RAM_SIZE) + IOP_RAM_SIZE - 1, m_ram, 0x01);
	m_cpu.m_pMemoryMap->InsertReadMap((1 * IOP_RAM_SIZE), (1 * IOP_RAM_SIZE) + IOP_RAM_SIZE - 1, m_ram, 0x02);
	m_cpu.m_pMemoryMap->InsertReadMap((2 * IOP_RAM_SIZE), (2 * IOP_RAM_SIZE) + IOP_RAM_SIZE - 1, m_ram, 0x03);
	m_cpu.m_pMemoryMap->InsertReadMap((3 * IOP_RAM_SIZE), (3 * IOP_RAM_SIZE) + IOP_RAM_SIZE - 1, m_ram, 0x04);
	m_cpu.m_pMemoryMap->InsertReadMap(SPEED_REG_BEGIN, SPEED_REG_END, std::bind(&CSubSystem::ReadIoRegister, this, std::placeholders::_1), 0x05);
	m_cpu.m_pMemoryMap->InsertReadMap(IOP_SCRATCH_ADDR, IOP_SCRATCH_ADDR + IOP_SCRATCH_SIZE - 1, m_scratchPad, 0x06);
	m_cpu.m_pMemoryMap->InsertReadMap(HW_REG_BEGIN, HW_REG_END, std::bind(&CSubSystem::ReadIoRegister, this, std::placeholders::_1), 0x07);

	//Write memory map
	m_cpu.m_pMemoryMap->InsertWriteMap((0 * IOP_RAM_SIZE), (0 * IOP_RAM_SIZE) + IOP_RAM_SIZE - 1, m_ram, 0x01);
	m_cpu.m_pMemoryMap->InsertWriteMap((1 * IOP_RAM_SIZE), (1 * IOP_RAM_SIZE) + IOP_RAM_SIZE - 1, m_ram, 0x02);
	m_cpu.m_pMemoryMap->InsertWriteMap((2 * IOP_RAM_SIZE), (2 * IOP_RAM_SIZE) + IOP_RAM_SIZE - 1, m_ram, 0x03);
	m_cpu.m_pMemoryMap->InsertWriteMap((3 * IOP_RAM_SIZE), (3 * IOP_RAM_SIZE) + IOP_RAM_SIZE - 1, m_ram, 0x04);
	m_cpu.m_pMemoryMap->InsertWriteMap(SPEED_REG_BEGIN, SPEED_REG_END, std::bind(&CSubSystem::WriteIoRegister, this, std::placeholders::_1, std::placeholders::_2), 0x05);
	m_cpu.m_pMemoryMap->InsertWriteMap(IOP_SCRATCH_ADDR, IOP_SCRATCH_ADDR + IOP_SCRATCH_SIZE - 1, m_scratchPad, 0x06);
	m_cpu.m_pMemoryMap->InsertWriteMap(HW_REG_BEGIN, HW_REG_END, std::bind(&CSubSystem::WriteIoRegister, this, std::placeholders::_1, std::placeholders::_2), 0x07);

	//Instruction memory map
	m_cpu.m_pMemoryMap->InsertInstructionMap((0 * IOP_RAM_SIZE), (0 * IOP_RAM_SIZE) + IOP_RAM_SIZE - 1, m_ram, 0x01);
	m_cpu.m_pMemoryMap->InsertInstructionMap((1 * IOP_RAM_SIZE), (1 * IOP_RAM_SIZE) + IOP_RAM_SIZE - 1, m_ram, 0x02);
	m_cpu.m_pMemoryMap->InsertInstructionMap((2 * IOP_RAM_SIZE), (2 * IOP_RAM_SIZE) + IOP_RAM_SIZE - 1, m_ram, 0x03);
	m_cpu.m_pMemoryMap->InsertInstructionMap((3 * IOP_RAM_SIZE), (3 * IOP_RAM_SIZE) + IOP_RAM_SIZE - 1, m_ram, 0x04);

	m_cpu.m_pArch = &m_cpuArch;
	m_cpu.m_pCOP[0] = &m_copScu;
	m_cpu.m_pAddrTranslator = &CMIPS::TranslateAddress64;

	m_dmac.SetReceiveFunction(CDmac::CHANNEL_SPU0, std::bind(&CSpuBase::ReceiveDma, &m_spuCore0, PLACEHOLDER_1, PLACEHOLDER_2, PLACEHOLDER_3, PLACEHOLDER_4));
	m_dmac.SetReceiveFunction(CDmac::CHANNEL_SPU1, std::bind(&CSpuBase::ReceiveDma, &m_spuCore1, PLACEHOLDER_1, PLACEHOLDER_2, PLACEHOLDER_3, PLACEHOLDER_4));
	m_dmac.SetReceiveFunction(CDmac::CHANNEL_DEV9, std::bind(&CSpeed::ReceiveDma, &m_speed, PLACEHOLDER_1, PLACEHOLDER_2, PLACEHOLDER_3, PLACEHOLDER_4));
	m_dmac.SetReceiveFunction(CDmac::CHANNEL_SIO2in, std::bind(&CSio2::ReceiveDmaIn, &m_sio2, PLACEHOLDER_1, PLACEHOLDER_2, PLACEHOLDER_3, PLACEHOLDER_4));
	m_dmac.SetReceiveFunction(CDmac::CHANNEL_SIO2out, std::bind(&CSio2::ReceiveDmaOut, &m_sio2, PLACEHOLDER_1, PLACEHOLDER_2, PLACEHOLDER_3, PLACEHOLDER_4));

	SetupPageTable();
}

CSubSystem::~CSubSystem()
{
	m_bios.reset();
	delete[] m_ram;
	delete[] m_scratchPad;
	delete[] m_spuRam;
}

void CSubSystem::NotifyVBlankStart()
{
	m_bios->NotifyVBlankStart();
	m_intc.AssertLine(Iop::CIntc::LINE_VBLANK);
}

void CSubSystem::NotifyVBlankEnd()
{
	m_bios->NotifyVBlankEnd();
	m_intc.AssertLine(Iop::CIntc::LINE_EVBLANK);
}

void CSubSystem::SaveState(Framework::CZipArchiveWriter& archive)
{
	archive.InsertFile(std::make_unique<CMemoryStateFile>(STATE_CPU, &m_cpu.m_State, sizeof(MIPSSTATE)));
	archive.InsertFile(std::make_unique<CMemoryStateFile>(STATE_RAM, m_ram, IOP_RAM_SIZE));
	archive.InsertFile(std::make_unique<CMemoryStateFile>(STATE_SCRATCH, m_scratchPad, IOP_SCRATCH_SIZE));
	archive.InsertFile(std::make_unique<CMemoryStateFile>(STATE_SPURAM, m_spuRam, SPU_RAM_SIZE));
	m_intc.SaveState(archive);
	m_dmac.SaveState(archive);
	m_counters.SaveState(archive);
	m_spuCore0.SaveState(archive);
	m_spuCore1.SaveState(archive);
	m_ilink.SaveState(archive);
#ifdef _IOP_EMULATE_MODULES
	m_sio2.SaveState(archive);
#endif
	m_bios->SaveState(archive);

	//Save timing state
	{
		auto registerFile = std::make_unique<CRegisterStateFile>(STATE_TIMING);
		registerFile->SetRegister32(STATE_TIMING_DMA_UPDATE_TICKS, m_dmaUpdateTicks);
		registerFile->SetRegister32(STATE_TIMING_SPU_IRQ_UPDATE_TICKS, m_spuIrqUpdateTicks);
		archive.InsertFile(std::move(registerFile));
	}
}

void CSubSystem::LoadState(Framework::CZipArchiveReader& archive)
{
    try {
        CRegisterStateFile registerFile(*archive.BeginReadFile(STATE_TIMING));
        m_dmaUpdateTicks = registerFile.GetRegister32(STATE_TIMING_DMA_UPDATE_TICKS);
        m_spuIrqUpdateTicks = registerFile.GetRegister32(STATE_TIMING_SPU_IRQ_UPDATE_TICKS);
        printf("Iop_SubSystem: DMA %d SPU %d\n", m_dmaUpdateTicks, m_spuIrqUpdateTicks);
        //Read and check differences in memory to invalidate executor blocks only if necessary
        {
            auto stream = archive.BeginReadFile(STATE_RAM);
            static const uint32 bufferSize = 0x1000;
            uint8 buffer[bufferSize];
            for(uint32 i = 0; i < IOP_RAM_SIZE; i += bufferSize)
            {
                stream->Read(buffer, bufferSize);
                if(memcmp(m_ram + i, buffer, bufferSize))
                {
                    m_cpu.m_executor->ClearActiveBlocksInRange(i, i + bufferSize, false);
                }
                memcpy(m_ram + i, buffer, bufferSize);
            }
        }
        archive.BeginReadFile(STATE_CPU)->Read(&m_cpu.m_State, sizeof(MIPSSTATE));
        archive.BeginReadFile(STATE_SCRATCH)->Read(m_scratchPad, IOP_SCRATCH_SIZE);
        archive.BeginReadFile(STATE_SPURAM)->Read(m_spuRam, SPU_RAM_SIZE);
        m_intc.LoadState(archive);
        m_dmac.LoadState(archive);
        m_counters.LoadState(archive);
        m_spuSampleCache.Clear();
        m_spuCore0.LoadState(archive);
        m_spuCore1.LoadState(archive);
        m_ilink.LoadState(archive);
        #ifdef _IOP_EMULATE_MODULES
        m_sio2.LoadState(archive);
        #endif
        m_bios->LoadState(archive);
    } catch(...) {
        printf("Iop_SubSystem: Old Save File, skipping IoP State Load...\n");
        m_dmaUpdateTicks = 0;
        m_spuIrqUpdateTicks = 0;
    }
}

void CSubSystem::Reset()
{
	memset(m_ram, 0, IOP_RAM_SIZE);
	memset(m_scratchPad, 0, IOP_SCRATCH_SIZE);
	memset(m_spuRam, 0, SPU_RAM_SIZE);
	m_cpu.Reset();
	m_cpu.m_executor->Reset();
	m_cpu.m_analysis->Clear();
	m_spuSampleCache.Clear();
	m_spuCore0.Reset();
	m_spuCore1.Reset();
	m_spu.Reset();
	m_spu2.Reset();
#ifdef _IOP_EMULATE_MODULES
	m_sio2.Reset();
#endif
	m_speed.Reset();
	m_ilink.Reset();
	m_counters.Reset();
	m_dmac.Reset();
	m_intc.Reset();

	m_cpu.m_Comments.RemoveTags();
	m_cpu.m_Functions.RemoveTags();

	m_dmaUpdateTicks = 0;
	m_spuIrqUpdateTicks = 0;
}

void CSubSystem::SetupPageTable()
{
	for(uint32 i = 0; i < 2; i++)
	{
		uint32 addressBit = (i == 0) ? 0 : 0x80000000;

		m_cpu.MapPages(addressBit | (PS2::IOP_RAM_SIZE * 0), PS2::IOP_RAM_SIZE, m_ram);
		m_cpu.MapPages(addressBit | (PS2::IOP_RAM_SIZE * 1), PS2::IOP_RAM_SIZE, m_ram);
		m_cpu.MapPages(addressBit | (PS2::IOP_RAM_SIZE * 2), PS2::IOP_RAM_SIZE, m_ram);
		m_cpu.MapPages(addressBit | (PS2::IOP_RAM_SIZE * 3), PS2::IOP_RAM_SIZE, m_ram);

		m_cpu.MapPages(addressBit | PS2::IOP_SCRATCH_ADDR, PS2::IOP_SCRATCH_SIZE, m_scratchPad);
	}
}

uint32 CSubSystem::ReadIoRegister(uint32 address)
{
	if(address == 0x1F801814)
	{
		return 0x14802000;
	}
	else if(address >= CSpu::SPU_BEGIN && address <= CSpu::SPU_END)
	{
		return m_spu.ReadRegister(address);
	}
	else if(
	    (address >= CDmac::DMAC_ZONE1_START && address <= CDmac::DMAC_ZONE1_END) ||
	    (address >= CDmac::DMAC_ZONE2_START && address <= CDmac::DMAC_ZONE2_END) ||
	    (address >= CDmac::DMAC_ZONE3_START && address <= CDmac::DMAC_ZONE3_END))
	{
		return m_dmac.ReadRegister(address);
	}
	else if(address >= CIntc::ADDR_BEGIN && address <= CIntc::ADDR_END)
	{
		return m_intc.ReadRegister(address);
	}
	else if(
	    (address >= CRootCounters::ADDR_BEGIN1 && address <= CRootCounters::ADDR_END1) ||
	    (address >= CRootCounters::ADDR_BEGIN2 && address <= CRootCounters::ADDR_END2))
	{
		return m_counters.ReadRegister(address);
	}
#ifdef _IOP_EMULATE_MODULES
	else if(address >= CSio2::ADDR_BEGIN && address <= CSio2::ADDR_END)
	{
		return m_sio2.ReadRegister(address);
	}
#endif
	else if(address >= CSpu2::REGS_BEGIN && address <= CSpu2::REGS_END)
	{
		return m_spu2.ReadRegister(address);
	}
	else if((address >= 0x1F801000 && address <= 0x1F801020) || (address >= 0x1F801400 && address <= 0x1F801420))
	{
		CLog::GetInstance().Print(LOG_NAME, "Reading from SSBUS.\r\n");
	}
	else if(address >= CDev9::ADDR_BEGIN && address <= CDev9::ADDR_END)
	{
		return m_dev9.ReadRegister(address);
	}
	else if(address >= SPEED_REG_BEGIN && address <= SPEED_REG_END)
	{
		return m_speed.ReadRegister(address);
	}
	else if(address >= CIlink::ADDR_BEGIN && address <= CIlink::ADDR_END)
	{
		return m_ilink.ReadRegister(address);
	}
	else
	{
		CLog::GetInstance().Print(LOG_NAME, "Reading an unknown hardware register (0x%08X).\r\n", address);
	}
	return 0;
}

uint32 CSubSystem::WriteIoRegister(uint32 address, uint32 value)
{
	if(address >= CSpu::SPU_BEGIN && address <= CSpu::SPU_END)
	{
		m_spu.WriteRegister(address, static_cast<uint16>(value));
	}
	else if(
	    (address >= CDmac::DMAC_ZONE1_START && address <= CDmac::DMAC_ZONE1_END) ||
	    (address >= CDmac::DMAC_ZONE2_START && address <= CDmac::DMAC_ZONE2_END) ||
	    (address >= CDmac::DMAC_ZONE3_START && address <= CDmac::DMAC_ZONE3_END))
	{
		m_dmac.WriteRegister(address, value);
	}
	else if(address >= CIntc::ADDR_BEGIN && address <= CIntc::ADDR_END)
	{
		m_intc.WriteRegister(address, value);
	}
	else if(
	    (address >= CRootCounters::ADDR_BEGIN1 && address <= CRootCounters::ADDR_END1) ||
	    (address >= CRootCounters::ADDR_BEGIN2 && address <= CRootCounters::ADDR_END2))
	{
		m_counters.WriteRegister(address, value);
	}
#ifdef _IOP_EMULATE_MODULES
	else if(address >= CSio2::ADDR_BEGIN && address <= CSio2::ADDR_END)
	{
		m_sio2.WriteRegister(address, value);
	}
#endif
	else if(address >= CSpu2::REGS_BEGIN && address <= CSpu2::REGS_END)
	{
		return m_spu2.WriteRegister(address, value);
	}
	else if((address >= 0x1F801000 && address <= 0x1F801020) || (address >= 0x1F801400 && address <= 0x1F801420))
	{
		CLog::GetInstance().Print(LOG_NAME, "Writing to SSBUS (0x%08X).\r\n", value);
	}
	else if(address >= CDev9::ADDR_BEGIN && address <= CDev9::ADDR_END)
	{
		m_dev9.WriteRegister(address, value);
	}
	else if(address >= SPEED_REG_BEGIN && address <= SPEED_REG_END)
	{
		m_speed.WriteRegister(address, value);
	}
	else if(address >= CIlink::ADDR_BEGIN && address <= CIlink::ADDR_END)
	{
		m_ilink.WriteRegister(address, value);
	}
	else
	{
		CLog::GetInstance().Warn(LOG_NAME, "Writing to an unknown hardware register (0x%08X, 0x%08X).\r\n", address, value);
	}

	if(
	    m_intc.HasPendingInterrupt() &&
	    (m_cpu.m_State.nHasException == MIPS_EXCEPTION_NONE) &&
	    ((m_cpu.m_State.nCOP0[CCOP_SCU::STATUS] & CMIPS::STATUS_IE) == CMIPS::STATUS_IE))
	{
		m_cpu.m_State.nHasException = MIPS_EXCEPTION_CHECKPENDINGINT;
	}

	return 0;
}

void CSubSystem::CheckPendingInterrupts()
{
	if(!m_cpu.m_State.nHasException)
	{
		if(m_intc.HasPendingInterrupt())
		{
			m_bios->HandleInterrupt();
		}
	}
}

bool CSubSystem::IsCpuIdle()
{
	return m_bios->IsIdle();
}

void CSubSystem::CountTicks(int ticks)
{
	static const int g_dmaUpdateDelay = 10000;
	static const int g_spuIrqCheckDelay = 1000;
	m_counters.Update(ticks);
	m_speed.CountTicks(ticks);
	m_bios->CountTicks(ticks);
	m_dmaUpdateTicks += ticks;
	if(m_dmaUpdateTicks >= g_dmaUpdateDelay)
	{
		m_dmac.ResumeDma(Iop::CDmac::CHANNEL_SPU0);
		m_dmac.ResumeDma(Iop::CDmac::CHANNEL_SPU1);
		m_dmaUpdateTicks -= g_dmaUpdateDelay;
	}
	m_spuIrqUpdateTicks += ticks;
	if(m_spuIrqUpdateTicks >= g_spuIrqCheckDelay)
	{
		bool irqPending = false;
		irqPending |= m_spuCore0.GetIrqPending();
		irqPending |= m_spuCore1.GetIrqPending();
		if(irqPending)
		{
			m_intc.AssertLine(CIntc::LINE_SPU2);
		}
		else
		{
			m_intc.ClearLine(CIntc::LINE_SPU2);
		}
		m_spuIrqUpdateTicks -= g_spuIrqCheckDelay;
	}
}

int CSubSystem::ExecuteCpu(int quota)
{
	int executed = 0;
	CheckPendingInterrupts();
	if(!m_cpu.m_State.nHasException)
	{
		executed = (quota - m_cpu.m_executor->Execute(quota));
	}
	if(m_cpu.m_State.nHasException)
	{
		switch(m_cpu.m_State.nHasException)
		{
		case MIPS_EXCEPTION_SYSCALL:
			m_bios->HandleException();
			assert(m_cpu.m_State.nHasException == MIPS_EXCEPTION_NONE);
			break;
		case MIPS_EXCEPTION_CHECKPENDINGINT:
		{
			m_cpu.m_State.nHasException = MIPS_EXCEPTION_NONE;
			CheckPendingInterrupts();
			//Needs to be cleared again because exception flag might be set by BIOS interrupt handler
			m_cpu.m_State.nHasException = MIPS_EXCEPTION_NONE;
		}
		break;
		}
		assert(m_cpu.m_State.nHasException == MIPS_EXCEPTION_NONE);
	}
	return executed;
}
