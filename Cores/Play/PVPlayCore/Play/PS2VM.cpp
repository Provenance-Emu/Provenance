// Local Changes: Support old format save files

#include <cstdio>
#include <exception>
#include <memory>
#include <climits>
#include <fenv.h>
#include "FpUtils.h"
#include "make_unique.h"
#include "string_format.h"
#include "PS2VM.h"
#include "PS2VM_Preferences.h"
#include "ee/PS2OS.h"
#include "ee/EeExecutor.h"
#include "Ps2Const.h"
#include "iop/Iop_SifManPs2.h"
#include "StdStream.h"
#include "StdStreamUtils.h"
#include "states/MemoryStateFile.h"
#include "zip/ZipArchiveWriter.h"
#include "zip/ZipArchiveReader.h"
#include "xml/Node.h"
#include "xml/Writer.h"
#include "xml/Parser.h"
#include "AppConfig.h"
#include "PathUtils.h"
#include "ThreadUtils.h"
#include "iop/IopBios.h"
#include "iop/ioman/HardDiskDevice.h"
#include "iop/ioman/OpticalMediaDevice.h"
#include "iop/ioman/PreferenceDirectoryDevice.h"
#include "Log.h"
#include "DiskUtils.h"
#ifdef __ANDROID__
#include "android/JavaVM.h"
#endif

#define LOG_NAME ("ps2vm")

#define THREAD_NAME ("PS2VM Thread")

#define STATE_VM_TIMING_XML ("vm_timing.xml")
#define STATE_VM_TIMING_VBLANK_TICKS ("vblankTicks")
#define STATE_VM_TIMING_IN_VBLANK ("inVblank")
#define STATE_VM_TIMING_EE_EXECUTION_TICKS ("eeExecutionTicks")
#define STATE_VM_TIMING_IOP_EXECUTION_TICKS ("iopExecutionTicks")
#define STATE_VM_TIMING_SPU_UPDATE_TICKS ("spuUpdateTicks")

#define PREF_PS2_ROM0_DIRECTORY_DEFAULT ("vfs/rom0")
#define PREF_PS2_HOST_DIRECTORY_DEFAULT ("vfs/host")
#define PREF_PS2_MC0_DIRECTORY_DEFAULT ("vfs/mc0")
#define PREF_PS2_MC1_DIRECTORY_DEFAULT ("vfs/mc1")
#define PREF_PS2_HDD_DIRECTORY_DEFAULT ("vfs/hdd")
#define PREF_PS2_ARCADEROMS_DIRECTORY_DEFAULT ("arcaderoms")

CPS2VM::CPS2VM()
    : m_eeProfilerZone(CProfiler::GetInstance().RegisterZone("EE"))
    , m_iopProfilerZone(CProfiler::GetInstance().RegisterZone("IOP"))
    , m_spuProfilerZone(CProfiler::GetInstance().RegisterZone("SPU"))
    , m_gsSyncProfilerZone(CProfiler::GetInstance().RegisterZone("GSSYNC"))
    , m_otherProfilerZone(CProfiler::GetInstance().RegisterZone("OTHER"))
{
	// clang-format off
	static const std::pair<const char*, const char*> basicDirectorySettings[] =
	{
		std::make_pair(PREF_PS2_ROM0_DIRECTORY, PREF_PS2_ROM0_DIRECTORY_DEFAULT),
		std::make_pair(PREF_PS2_HOST_DIRECTORY, PREF_PS2_HOST_DIRECTORY_DEFAULT),
		std::make_pair(PREF_PS2_MC0_DIRECTORY, PREF_PS2_MC0_DIRECTORY_DEFAULT),
		std::make_pair(PREF_PS2_MC1_DIRECTORY, PREF_PS2_MC1_DIRECTORY_DEFAULT),
		std::make_pair(PREF_PS2_HDD_DIRECTORY, PREF_PS2_HDD_DIRECTORY_DEFAULT),
		std::make_pair(PREF_PS2_ARCADEROMS_DIRECTORY, PREF_PS2_ARCADEROMS_DIRECTORY_DEFAULT),
	};
	// clang-format on

	for(const auto& basicDirectorySetting : basicDirectorySettings)
	{
		auto setting = basicDirectorySetting.first;
		auto path = basicDirectorySetting.second;

		auto absolutePath = CAppConfig::GetBasePath() / path;
		Framework::PathUtils::EnsurePathExists(absolutePath);
		CAppConfig::GetInstance().RegisterPreferencePath(setting, absolutePath);

		auto currentPath = CAppConfig::GetInstance().GetPreferencePath(setting);
		if(!fs::exists(currentPath))
		{
			CAppConfig::GetInstance().SetPreferencePath(setting, absolutePath);
		}
	}

	CAppConfig::GetInstance().RegisterPreferencePath(PREF_PS2_CDROM0_PATH, "");

	Framework::PathUtils::EnsurePathExists(GetStateDirectoryPath());

	CAppConfig::GetInstance().RegisterPreferenceBoolean(PREF_PS2_LIMIT_FRAMERATE, true);
	ReloadFrameRateLimit();

	CAppConfig::GetInstance().RegisterPreferenceInteger(PREF_AUDIO_SPUBLOCKCOUNT, 100);
	ReloadSpuBlockCountImpl();
}

//////////////////////////////////////////////////
//Various Message Functions
//////////////////////////////////////////////////

void CPS2VM::CreateGSHandler(const CGSHandler::FactoryFunction& factoryFunction)
{
	m_mailBox.SendCall([this, factoryFunction]() { CreateGsHandlerImpl(factoryFunction); }, true);
}

CGSHandler* CPS2VM::GetGSHandler()
{
	return m_ee->m_gs;
}

void CPS2VM::DestroyGSHandler()
{
	if(m_ee->m_gs == nullptr) return;
	m_mailBox.SendCall([this]() { DestroyGsHandlerImpl(); }, true);
}

void CPS2VM::CreatePadHandler(const CPadHandler::FactoryFunction& factoryFunction)
{
	if(m_pad != nullptr) return;
	m_mailBox.SendCall([this, factoryFunction]() { CreatePadHandlerImpl(factoryFunction); }, true);
}

CPadHandler* CPS2VM::GetPadHandler()
{
	return m_pad;
}

bool CPS2VM::HasGunListener() const
{
	return m_gunListener != nullptr;
}

void CPS2VM::SetGunListener(CGunListener* listener)
{
	m_gunListener = listener;
}

void CPS2VM::ReportGunPosition(float x, float y)
{
	if(m_gunListener)
	{
		m_gunListener->SetGunPosition(x, y);
	}
}

void CPS2VM::DestroyPadHandler()
{
	if(m_pad == nullptr) return;
	m_mailBox.SendCall([this]() { DestroyPadHandlerImpl(); }, true);
}

void CPS2VM::CreateSoundHandler(const CSoundHandler::FactoryFunction& factoryFunction)
{
	if(m_soundHandler != nullptr) return;
	m_mailBox.SendCall([this, factoryFunction]() { CreateSoundHandlerImpl(factoryFunction); }, true);
}

CSoundHandler* CPS2VM::GetSoundHandler()
{
	return m_soundHandler;
}

void CPS2VM::ReloadSpuBlockCount()
{
	m_mailBox.SendCall([this]() { ReloadSpuBlockCountImpl(); });
}

void CPS2VM::DestroySoundHandler()
{
	if(m_soundHandler == nullptr) return;
	m_mailBox.SendCall([this]() { DestroySoundHandlerImpl(); }, true);
}

void CPS2VM::SetEeFrequencyScale(uint32 numerator, uint32 denominator)
{
	m_eeFreqScaleNumerator = numerator;
	m_eeFreqScaleDenominator = denominator;
	ReloadFrameRateLimit();
}

void CPS2VM::ReloadFrameRateLimit()
{
	uint32 frameRate = 60;
	if(m_ee && m_ee->m_gs)
	{
		frameRate = m_ee->m_gs->GetCrtFrameRate();
	}
	bool limitFrameRate = CAppConfig::GetInstance().GetPreferenceBoolean(PREF_PS2_LIMIT_FRAMERATE);
	m_frameLimiter.SetFrameRate(limitFrameRate ? frameRate : 0);

	//At 1x scale, IOP runs 8 times slower than EE
	uint32 eeFreqScaled = PS2::EE_CLOCK_FREQ * m_eeFreqScaleNumerator / m_eeFreqScaleDenominator;
	m_iopTickStep = (m_eeTickStep / 8) * m_eeFreqScaleDenominator / m_eeFreqScaleNumerator;

	uint32 frameTicks = eeFreqScaled / frameRate;
	m_onScreenTicksTotal = frameTicks * 9 / 10;
	m_vblankTicksTotal = frameTicks / 10;

	m_spuUpdateTicksTotal = (static_cast<int64>(eeFreqScaled) << SPU_UPDATE_TICKS_PRECISION) / (static_cast<int64>(DST_SAMPLE_RATE));
	m_spuUpdateTicksTotal *= static_cast<int64>(SAMPLES_PER_UPDATE);
}

CVirtualMachine::STATUS CPS2VM::GetStatus() const
{
	return m_nStatus;
}

void CPS2VM::StepEe()
{
	if(GetStatus() == RUNNING) return;
	m_singleStepEe = true;
	m_mailBox.SendCall(std::bind(&CPS2VM::ResumeImpl, this), true);
}

void CPS2VM::StepIop()
{
	if(GetStatus() == RUNNING) return;
	m_singleStepIop = true;
	m_mailBox.SendCall(std::bind(&CPS2VM::ResumeImpl, this), true);
}

void CPS2VM::StepVu0()
{
	if(GetStatus() == RUNNING) return;
	m_singleStepVu0 = true;
	m_mailBox.SendCall(std::bind(&CPS2VM::ResumeImpl, this), true);
}

void CPS2VM::StepVu1()
{
	if(GetStatus() == RUNNING) return;
	m_singleStepVu1 = true;
	m_mailBox.SendCall(std::bind(&CPS2VM::ResumeImpl, this), true);
}

void CPS2VM::Resume()
{
	if(m_nStatus == RUNNING) return;
	m_mailBox.SendCall(std::bind(&CPS2VM::ResumeImpl, this), true);
	OnRunningStateChange();
}

void CPS2VM::Pause()
{
	if(m_nStatus == PAUSED) return;
	m_mailBox.SendCall(std::bind(&CPS2VM::PauseImpl, this), true);
	OnMachineStateChange();
	OnRunningStateChange();
}

void CPS2VM::PauseAsync()
{
	if(m_nStatus == PAUSED) return;
	m_mailBox.SendCall([this]() {
		PauseImpl();
		OnMachineStateChange();
		OnRunningStateChange();
	});
}

void CPS2VM::Reset(uint32 eeRamSize, uint32 iopRamSize)
{
	assert(m_nStatus == PAUSED);
	BeforeExecutableReloaded = ExecutableReloadedHandler();
	AfterExecutableReloaded = ExecutableReloadedHandler();
	m_eeRamSize = eeRamSize;
	m_iopRamSize = iopRamSize;
	ResetVM();
}

void CPS2VM::Initialize()
{
	m_nEnd = false;
	m_thread = std::thread([&]() { EmuThread(); });
	Framework::ThreadUtils::SetThreadName(m_thread, THREAD_NAME);
}

void CPS2VM::Destroy()
{
	m_mailBox.SendCall(std::bind(&CPS2VM::DestroyImpl, this));
	m_thread.join();
	DestroyVM();
}

fs::path CPS2VM::GetStateDirectoryPath()
{
	return CAppConfig::GetBasePath() / fs::path("states/");
}

fs::path CPS2VM::GenerateStatePath(unsigned int slot) const
{
	auto stateFileName = string_format("%s.st%d.zip", m_ee->m_os->GetExecutableName(), slot);
	return GetStateDirectoryPath() / fs::path(stateFileName);
}

std::future<bool> CPS2VM::SaveState(const fs::path& statePath)
{
	auto promise = std::make_shared<std::promise<bool>>();
	auto future = promise->get_future();
	m_mailBox.SendCall(
	    [this, promise, statePath]() {
		    auto result = SaveVMState(statePath);
		    promise->set_value(result);
	    });
	return future;
}

std::future<bool> CPS2VM::LoadState(const fs::path& statePath)
{
    auto promise = std::make_shared<std::promise<bool>>();
    auto future = promise->get_future();

    try {
        auto stateStream = Framework::CreateInputStdStream(statePath.native());
        Framework::CZipArchiveReader archive(stateStream);
        CRegisterStateFile registerFile(*archive.BeginReadFile("iop_timing"));
    } catch(...) {
        printf("PS2VM: Old Save format, shifting BIOS_ADDRESS_STATE_BASE = 0x1000 ...\n");
        // Get IoP State from fresh boot
        Reset();
        m_ee->m_os->BootFromCDROM();
        std::thread t([this, statePath] {
            fs::path tmpSave = statePath.parent_path();
            tmpSave /= "PlayTmp.svs";
            sleep(5);
            Pause();
            // Create new format Save State with IoP in Save State
            SaveVMState(tmpSave);
            // Load IoP_SubSystem Save State
            LoadVMState(tmpSave);
            // Load Old Save State File with ee subsystem ram shift of 0x1000 (in ee/PS2OS.cpp)
            auto result = LoadVMState(statePath);
            std::memcpy(
                (void*)((m_ee->m_ram) + 0x1000 ),
                        (void*)((m_ee->m_ram )),
                        0x300);
            Resume();
            
       });
       t.detach();
       promise->set_value(true);
       return future;
    }
    
	m_mailBox.SendCall(
    [this, promise, statePath]() {
        auto result = LoadVMState(statePath);
        promise->set_value(result);
    });
    return future;
}

void CPS2VM::TriggerFrameDump(const FrameDumpCallback& frameDumpCallback)
{
#ifdef DEBUGGER_INCLUDED
	m_mailBox.SendCall(
	    [=]() {
		    std::unique_lock<std::mutex> frameDumpCallbackMutexLock(m_frameDumpCallbackMutex);
		    if(m_frameDumpCallback) return;
		    m_frameDumpCallback = frameDumpCallback;
	    },
	    false);
#endif
}

CPS2VM::CPU_UTILISATION_INFO CPS2VM::GetCpuUtilisationInfo() const
{
	return m_cpuUtilisation;
}

#ifdef DEBUGGER_INCLUDED

#define TAGS_SECTION_TAGS ("tags")
#define TAGS_SECTION_EE_FUNCTIONS ("ee_functions")
#define TAGS_SECTION_EE_COMMENTS ("ee_comments")
#define TAGS_SECTION_VU1_FUNCTIONS ("vu1_functions")
#define TAGS_SECTION_VU1_COMMENTS ("vu1_comments")
#define TAGS_SECTION_IOP ("iop")
#define TAGS_SECTION_IOP_FUNCTIONS ("functions")
#define TAGS_SECTION_IOP_COMMENTS ("comments")

#define TAGS_PATH ("tags/")

fs::path CPS2VM::MakeDebugTagsPackagePath(const char* packageName)
{
	auto tagsPath = CAppConfig::GetBasePath() / fs::path(TAGS_PATH);
	Framework::PathUtils::EnsurePathExists(tagsPath);
	auto tagsPackagePath = tagsPath / (std::string(packageName) + std::string(".tags.xml"));
	return tagsPackagePath;
}

void CPS2VM::LoadDebugTags(const char* packageName)
{
	try
	{
		auto packagePath = MakeDebugTagsPackagePath(packageName);
		auto stream = Framework::CreateInputStdStream(packagePath.native());
		std::unique_ptr<Framework::Xml::CNode> document(Framework::Xml::CParser::ParseDocument(stream));
		Framework::Xml::CNode* tagsNode = document->Select(TAGS_SECTION_TAGS);
		if(!tagsNode) return;
		m_ee->m_EE.m_Functions.Unserialize(tagsNode, TAGS_SECTION_EE_FUNCTIONS);
		m_ee->m_EE.m_Comments.Unserialize(tagsNode, TAGS_SECTION_EE_COMMENTS);
		m_ee->m_VU1.m_Functions.Unserialize(tagsNode, TAGS_SECTION_VU1_FUNCTIONS);
		m_ee->m_VU1.m_Comments.Unserialize(tagsNode, TAGS_SECTION_VU1_COMMENTS);
		{
			Framework::Xml::CNode* sectionNode = tagsNode->Select(TAGS_SECTION_IOP);
			if(sectionNode)
			{
				m_iop->m_cpu.m_Functions.Unserialize(sectionNode, TAGS_SECTION_IOP_FUNCTIONS);
				m_iop->m_cpu.m_Comments.Unserialize(sectionNode, TAGS_SECTION_IOP_COMMENTS);
				m_iop->m_bios->LoadDebugTags(sectionNode);
			}
		}
	}
	catch(...)
	{
	}
}

void CPS2VM::SaveDebugTags(const char* packageName)
{
	try
	{
		auto packagePath = MakeDebugTagsPackagePath(packageName);
		auto stream = Framework::CreateOutputStdStream(packagePath.native());
		std::unique_ptr<Framework::Xml::CNode> document(new Framework::Xml::CNode(TAGS_SECTION_TAGS, true));
		m_ee->m_EE.m_Functions.Serialize(document.get(), TAGS_SECTION_EE_FUNCTIONS);
		m_ee->m_EE.m_Comments.Serialize(document.get(), TAGS_SECTION_EE_COMMENTS);
		m_ee->m_VU1.m_Functions.Serialize(document.get(), TAGS_SECTION_VU1_FUNCTIONS);
		m_ee->m_VU1.m_Comments.Serialize(document.get(), TAGS_SECTION_VU1_COMMENTS);
		{
			Framework::Xml::CNode* iopNode = new Framework::Xml::CNode(TAGS_SECTION_IOP, true);
			m_iop->m_cpu.m_Functions.Serialize(iopNode, TAGS_SECTION_IOP_FUNCTIONS);
			m_iop->m_cpu.m_Comments.Serialize(iopNode, TAGS_SECTION_IOP_COMMENTS);
			m_iop->m_bios->SaveDebugTags(iopNode);
			document->InsertNode(iopNode);
		}
		Framework::Xml::CWriter::WriteDocument(stream, document.get());
	}
	catch(...)
	{
	}
}

#endif

//////////////////////////////////////////////////
//Non extern callable methods
//////////////////////////////////////////////////

void CPS2VM::ValidateThreadContext()
{
	auto currThreadId = std::this_thread::get_id();
	auto vmThreadId = m_thread.get_id();
	assert(vmThreadId == std::thread::id() || currThreadId == vmThreadId);
}

void CPS2VM::CreateVM()
{
	m_iop = std::make_unique<Iop::CSubSystem>(true);
	auto iopOs = dynamic_cast<CIopBios*>(m_iop->m_bios.get());

	m_ee = std::make_unique<Ee::CSubSystem>(m_iop->m_ram, *iopOs);
	m_OnRequestLoadExecutableConnection = m_ee->m_os->OnRequestLoadExecutable.Connect(std::bind(&CPS2VM::ReloadExecutable, this, std::placeholders::_1, std::placeholders::_2));
	m_OnCrtModeChangeConnection = m_ee->m_os->OnCrtModeChange.Connect(std::bind(&CPS2VM::OnCrtModeChange, this));

	ResetVM();
}

void CPS2VM::ResetVM()
{
	assert(m_eeRamSize != 0);
	assert(m_iopRamSize != 0);

	assert(m_eeRamSize <= PS2::EE_RAM_SIZE);
	assert(m_iopRamSize <= PS2::IOP_RAM_SIZE);

	m_ee->Reset(m_eeRamSize);
	m_iop->Reset();

	if(m_ee->m_gs != NULL)
	{
		m_ee->m_gs->Reset();
	}

	{
		auto iopOs = dynamic_cast<CIopBios*>(m_iop->m_bios.get());
		assert(iopOs);

		iopOs->Reset(m_iopRamSize, std::make_shared<Iop::CSifManPs2>(m_ee->m_sif, m_ee->m_ram, m_iop->m_ram));

		iopOs->GetIoman()->RegisterDevice("rom0", std::make_shared<Iop::Ioman::CPreferenceDirectoryDevice>(PREF_PS2_ROM0_DIRECTORY));
		iopOs->GetIoman()->RegisterDevice("host", std::make_shared<Iop::Ioman::CPreferenceDirectoryDevice>(PREF_PS2_HOST_DIRECTORY));
		iopOs->GetIoman()->RegisterDevice("host0", std::make_shared<Iop::Ioman::CPreferenceDirectoryDevice>(PREF_PS2_HOST_DIRECTORY));
		iopOs->GetIoman()->RegisterDevice("mc0", std::make_shared<Iop::Ioman::CPreferenceDirectoryDevice>(PREF_PS2_MC0_DIRECTORY));
		iopOs->GetIoman()->RegisterDevice("mc1", std::make_shared<Iop::Ioman::CPreferenceDirectoryDevice>(PREF_PS2_MC1_DIRECTORY));
		iopOs->GetIoman()->RegisterDevice("cdrom", Iop::Ioman::DevicePtr(new Iop::Ioman::COpticalMediaDevice(m_cdrom0)));
		iopOs->GetIoman()->RegisterDevice("cdrom0", Iop::Ioman::DevicePtr(new Iop::Ioman::COpticalMediaDevice(m_cdrom0)));
		iopOs->GetIoman()->RegisterDevice("hdd0", std::make_shared<Iop::Ioman::CHardDiskDevice>());

		iopOs->GetLoadcore()->SetLoadExecutableHandler(std::bind(&CPS2OS::LoadExecutable, m_ee->m_os, std::placeholders::_1, std::placeholders::_2));
	}

	CDROM0_SyncPath();

	SetEeFrequencyScale(1, 1);

	m_vblankTicks = m_onScreenTicksTotal;
	m_spuUpdateTicks = m_spuUpdateTicksTotal;
	m_inVblank = false;

	m_eeExecutionTicks = 0;
	m_iopExecutionTicks = 0;

	m_currentSpuBlock = 0;
	m_iop->m_spuCore0.SetDestinationSamplingRate(DST_SAMPLE_RATE);
	m_iop->m_spuCore1.SetDestinationSamplingRate(DST_SAMPLE_RATE);

	RegisterModulesInPadHandler();
	m_gunListener = nullptr;
}

void CPS2VM::DestroyVM()
{
	CDROM0_Reset();
}

bool CPS2VM::SaveVMState(const fs::path& statePath)
{
	if(m_ee->m_gs == NULL)
	{
		printf("PS2VM: GS Handler was not instancied. Cannot save state.\r\n");
		return false;
	}

	try
	{
		auto stateStream = Framework::CreateOutputStdStream(statePath.native());
		Framework::CZipArchiveWriter archive;

		m_ee->SaveState(archive);
		m_iop->SaveState(archive);
		m_ee->m_gs->SaveState(archive);
		SaveVmTimingState(archive);

		archive.Write(stateStream);
	}
	catch(...)
	{
		return false;
	}

	return true;
}

bool CPS2VM::LoadVMState(const fs::path& statePath)
{
	if(m_ee->m_gs == NULL)
	{
		printf("PS2VM: GS Handler was not instancied. Cannot load state.\r\n");
		return false;
	}

	try
	{
		auto stateStream = Framework::CreateInputStdStream(statePath.native());
		Framework::CZipArchiveReader archive(stateStream);

		try
		{
            m_ee->LoadState(archive);
            m_iop->LoadState(archive);
            m_ee->m_gs->LoadState(archive);
			LoadVmTimingState(archive);
            
			ReloadFrameRateLimit();
		}
		catch(...)
		{
			//Any error that occurs in the previous block is critical
			PauseImpl();
			throw;
		}
	}
	catch(...)
	{
		return false;
	}

	OnMachineStateChange();

	return true;
}

void CPS2VM::SaveVmTimingState(Framework::CZipArchiveWriter& archive)
{
	auto registerFile = std::make_unique<CRegisterStateFile>(STATE_VM_TIMING_XML);
	registerFile->SetRegister32(STATE_VM_TIMING_VBLANK_TICKS, m_vblankTicks);
	registerFile->SetRegister32(STATE_VM_TIMING_IN_VBLANK, m_inVblank);
	registerFile->SetRegister32(STATE_VM_TIMING_EE_EXECUTION_TICKS, m_eeExecutionTicks);
	registerFile->SetRegister32(STATE_VM_TIMING_IOP_EXECUTION_TICKS, m_iopExecutionTicks);
	registerFile->SetRegister64(STATE_VM_TIMING_SPU_UPDATE_TICKS, m_spuUpdateTicks);
	archive.InsertFile(std::move(registerFile));
}

void CPS2VM::LoadVmTimingState(Framework::CZipArchiveReader& archive)
{
	CRegisterStateFile registerFile(*archive.BeginReadFile(STATE_VM_TIMING_XML));
	m_vblankTicks = registerFile.GetRegister32(STATE_VM_TIMING_VBLANK_TICKS);
	m_inVblank = registerFile.GetRegister32(STATE_VM_TIMING_IN_VBLANK) != 0;
	m_eeExecutionTicks = registerFile.GetRegister32(STATE_VM_TIMING_EE_EXECUTION_TICKS);
	m_iopExecutionTicks = registerFile.GetRegister32(STATE_VM_TIMING_IOP_EXECUTION_TICKS);
	m_spuUpdateTicks = registerFile.GetRegister64(STATE_VM_TIMING_SPU_UPDATE_TICKS);
}

void CPS2VM::PauseImpl()
{
	m_nStatus = PAUSED;
}

void CPS2VM::ResumeImpl()
{
#ifdef DEBUGGER_INCLUDED
	m_ee->m_EE.m_executor->DisableBreakpointsOnce();
	m_iop->m_cpu.m_executor->DisableBreakpointsOnce();
	m_ee->m_VU1.m_executor->DisableBreakpointsOnce();
#endif
	m_nStatus = RUNNING;
}

void CPS2VM::DestroyImpl()
{
	DestroyGsHandlerImpl();
	DestroyPadHandlerImpl();
	DestroySoundHandlerImpl();
	m_nEnd = true;
}

void CPS2VM::CreateGsHandlerImpl(const CGSHandler::FactoryFunction& factoryFunction)
{
	auto gs = m_ee->m_gs;
	m_ee->m_gs = factoryFunction();
	m_ee->m_gs->SetIntc(&m_ee->m_intc);
	m_ee->m_gs->Initialize();
	m_ee->m_gs->SendGSCall([this]() {
		static_cast<CEeExecutor*>(m_ee->m_EE.m_executor.get())->AttachExceptionHandlerToThread();
	});
	if(gs)
	{
		m_ee->m_gs->Copy(gs);
		gs->Release();
		delete gs;
	}
	m_OnNewFrameConnection = m_ee->m_gs->OnNewFrame.Connect(std::bind(&CPS2VM::OnGsNewFrame, this));
}

void CPS2VM::DestroyGsHandlerImpl()
{
	if(m_ee->m_gs == nullptr) return;
	m_ee->m_gs->Release();
	delete m_ee->m_gs;
	m_ee->m_gs = nullptr;
}

void CPS2VM::CreatePadHandlerImpl(const CPadHandler::FactoryFunction& factoryFunction)
{
	m_pad = factoryFunction();
	RegisterModulesInPadHandler();
}

void CPS2VM::DestroyPadHandlerImpl()
{
	if(m_pad == nullptr) return;
	delete m_pad;
	m_pad = nullptr;
}

void CPS2VM::CreateSoundHandlerImpl(const CSoundHandler::FactoryFunction& factoryFunction)
{
	m_soundHandler = factoryFunction();
}

void CPS2VM::ReloadSpuBlockCountImpl()
{
	ValidateThreadContext();
	m_currentSpuBlock = 0;
	auto spuBlockCount = CAppConfig::GetInstance().GetPreferenceInteger(PREF_AUDIO_SPUBLOCKCOUNT);
	assert(spuBlockCount <= MAX_BLOCK_COUNT);
	spuBlockCount = std::min<int>(spuBlockCount, MAX_BLOCK_COUNT);
	m_spuBlockCount = spuBlockCount;
}

void CPS2VM::DestroySoundHandlerImpl()
{
	if(m_soundHandler == nullptr) return;
	delete m_soundHandler;
	m_soundHandler = nullptr;
}

void CPS2VM::OnGsNewFrame()
{
#ifdef DEBUGGER_INCLUDED
	std::unique_lock<std::mutex> dumpFrameCallbackMutexLock(m_frameDumpCallbackMutex);
	if(m_dumpingFrame && !m_frameDump.GetPackets().empty())
	{
		m_ee->m_gs->EndFrameDump();
		m_frameDumpCallback(m_frameDump);
		m_dumpingFrame = false;
		m_frameDumpCallback = FrameDumpCallback();
	}
	else if(m_frameDumpCallback)
	{
		m_frameDump.Reset();
		m_ee->m_gs->BeginFrameDump(&m_frameDump);
		m_dumpingFrame = true;
	}
#endif
}

void CPS2VM::UpdateEe()
{
#ifdef PROFILE
	CProfilerZone profilerZone(m_eeProfilerZone);
#endif

	while(m_eeExecutionTicks > 0)
	{
		int executed = m_ee->ExecuteCpu(m_singleStepEe ? 1 : m_eeExecutionTicks);
		if(m_ee->IsCpuIdle())
		{
			m_cpuUtilisation.eeIdleTicks += (m_eeExecutionTicks - executed);
			executed = m_eeExecutionTicks;
		}
		m_cpuUtilisation.eeTotalTicks += executed;

		m_ee->m_vpu0->Execute(m_singleStepVu0 ? 1 : executed);
		m_ee->m_vpu1->Execute(m_singleStepVu1 ? 1 : executed);

		m_eeExecutionTicks -= executed;
		m_spuUpdateTicks -= (static_cast<int64>(executed) << SPU_UPDATE_TICKS_PRECISION);
		m_ee->CountTicks(executed);
		m_vblankTicks -= executed;

#ifdef DEBUGGER_INCLUDED
		if(m_singleStepEe || m_singleStepVu0 || m_singleStepVu1) break;
		if(m_ee->m_EE.m_executor->MustBreak()) break;
#endif
	}
}

void CPS2VM::UpdateIop()
{
#ifdef PROFILE
	CProfilerZone profilerZone(m_iopProfilerZone);
#endif

	while(m_iopExecutionTicks > 0)
	{
		int executed = m_iop->ExecuteCpu(m_singleStepIop ? 1 : m_iopExecutionTicks);
		if(m_iop->IsCpuIdle())
		{
			m_cpuUtilisation.iopIdleTicks += (m_iopExecutionTicks - executed);
			executed = m_iopExecutionTicks;
		}
		m_cpuUtilisation.iopTotalTicks += executed;

		m_iopExecutionTicks -= executed;
		m_iop->CountTicks(executed);

#ifdef DEBUGGER_INCLUDED
		if(m_singleStepIop) break;
		if(m_iop->m_cpu.m_executor->MustBreak()) break;
#endif
	}
}

void CPS2VM::UpdateSpu()
{
#ifdef PROFILE
	CProfilerZone profilerZone(m_spuProfilerZone);
#endif

	unsigned int blockOffset = (BLOCK_SIZE * m_currentSpuBlock);
	int16* samplesSpu0 = m_samples + blockOffset;

	m_iop->m_spuCore0.Render(samplesSpu0, BLOCK_SIZE);

	if(m_iop->m_spuCore1.IsEnabled())
	{
		int16 samplesSpu1[BLOCK_SIZE];
		m_iop->m_spuCore1.Render(samplesSpu1, BLOCK_SIZE);

		for(unsigned int i = 0; i < BLOCK_SIZE; i++)
		{
			int32 resultSample = static_cast<int32>(samplesSpu0[i]) + static_cast<int32>(samplesSpu1[i]);
			resultSample = std::max<int32>(resultSample, SHRT_MIN);
			resultSample = std::min<int32>(resultSample, SHRT_MAX);
			samplesSpu0[i] = static_cast<int16>(resultSample);
		}
	}

	m_currentSpuBlock++;
	if(m_currentSpuBlock == m_spuBlockCount)
	{
		if(m_soundHandler)
		{
			m_soundHandler->RecycleBuffers();
			m_soundHandler->Write(m_samples, BLOCK_SIZE * m_spuBlockCount, DST_SAMPLE_RATE);
		}
		m_currentSpuBlock = 0;
	}
}

void CPS2VM::CDROM0_SyncPath()
{
	//TODO: Check if there's an m_cdrom0 already
	//TODO: Check if files are linked to this m_cdrom0 too and do something with them

	CDROM0_Reset();

	auto path = CAppConfig::GetInstance().GetPreferencePath(PREF_PS2_CDROM0_PATH);
	if(!path.empty())
	{
		try
		{
			m_cdrom0 = DiskUtils::CreateOpticalMediaFromPath(path);
			SetIopOpticalMedia(m_cdrom0.get());
		}
		catch(const std::exception& Exception)
		{
			printf("PS2VM: Error mounting cdrom0 device: %s\r\n", Exception.what());
		}
	}
}

void CPS2VM::CDROM0_Reset()
{
	SetIopOpticalMedia(nullptr);
	m_cdrom0.reset();
}

void CPS2VM::SetIopOpticalMedia(COpticalMedia* opticalMedia)
{
	auto iopOs = dynamic_cast<CIopBios*>(m_iop->m_bios.get());
	assert(iopOs);

	iopOs->GetCdvdfsv()->SetOpticalMedia(opticalMedia);
	iopOs->GetCdvdman()->SetOpticalMedia(opticalMedia);
}

void CPS2VM::RegisterModulesInPadHandler()
{
	if(m_pad == nullptr) return;

	auto iopOs = dynamic_cast<CIopBios*>(m_iop->m_bios.get());
	assert(iopOs);

	m_pad->RemoveAllListeners();
	m_pad->InsertListener(iopOs->GetPadman());
	m_pad->InsertListener(&m_iop->m_sio2);
}

void CPS2VM::ReloadExecutable(const char* executablePath, const CPS2OS::ArgumentList& arguments)
{
	{
		//SPU RAM is not cleared by a LoadExecPS2 operation, we must keep its contents
		//Deus Ex uses SPU RAM to keep game state in between executable reloads
		auto savedSpuRam = std::vector<uint8>(PS2::SPU_RAM_SIZE);
		memcpy(savedSpuRam.data(), m_iop->m_spuRam, PS2::SPU_RAM_SIZE);
		ResetVM();
		memcpy(m_iop->m_spuRam, savedSpuRam.data(), PS2::SPU_RAM_SIZE);
	}
	if(BeforeExecutableReloaded)
	{
		BeforeExecutableReloaded(this);
	}
	m_ee->m_os->BootFromVirtualPath(executablePath, arguments);
	if(AfterExecutableReloaded)
	{
		AfterExecutableReloaded(this);
	}
}

void CPS2VM::OnCrtModeChange()
{
	ReloadFrameRateLimit();
}

void CPS2VM::EmuThread()
{
	CreateVM();
	fesetround(FE_TOWARDZERO);
	FpUtils::SetDenormalHandlingMode();
	CProfiler::GetInstance().SetWorkThread();
#ifdef __ANDROID__
	JNIEnv* env = nullptr;
	Framework::CJavaVM::AttachCurrentThread(&env, THREAD_NAME);
#endif
#ifdef PROFILE
	CProfilerZone profilerZone(m_otherProfilerZone);
#endif
	static_cast<CEeExecutor*>(m_ee->m_EE.m_executor.get())->AddExceptionHandler();
	m_frameLimiter.BeginFrame();
	while(1)
	{
		while(m_mailBox.IsPending())
		{
			m_mailBox.ReceiveCall();
		}
		if(m_nEnd) break;
		if(m_nStatus == PAUSED)
		{
			std::this_thread::sleep_for(std::chrono::milliseconds(100));
		}
		if(m_nStatus == RUNNING)
		{
			if(m_spuUpdateTicks <= 0)
			{
				UpdateSpu();
				m_spuUpdateTicks += m_spuUpdateTicksTotal;
			}

			{
				//Check vblank stuff
				if(m_vblankTicks <= 0)
				{
					m_inVblank = !m_inVblank;
					if(m_inVblank)
					{
						m_vblankTicks += m_vblankTicksTotal;
						m_ee->NotifyVBlankStart();
						m_iop->NotifyVBlankStart();

						if(m_ee->m_gs != NULL)
						{
#ifdef PROFILE
							CProfilerZone profilerZone(m_gsSyncProfilerZone);
#endif
							m_ee->m_gs->SetVBlank();
						}

						if(m_pad != NULL)
						{
							m_pad->Update(m_ee->m_ram);
						}
#ifdef PROFILE
						{
							CProfiler::GetInstance().CountCurrentZone();
							auto stats = CProfiler::GetInstance().GetStats();
							ProfileFrameDone(stats);
							CProfiler::GetInstance().Reset();
						}

#endif
						m_cpuUtilisation = CPU_UTILISATION_INFO();
					}
					else
					{
						m_vblankTicks += m_onScreenTicksTotal;
						m_ee->NotifyVBlankEnd();
						m_iop->NotifyVBlankEnd();
						if(m_ee->m_gs != NULL)
						{
							m_ee->m_gs->ResetVBlank();
						}
						m_frameLimiter.EndFrame();
						m_frameLimiter.BeginFrame();
					}
				}

				m_eeExecutionTicks += m_eeTickStep;
				m_iopExecutionTicks += m_iopTickStep;

				UpdateEe();
				UpdateIop();
			}
#ifdef DEBUGGER_INCLUDED
			if(
			    m_ee->m_EE.m_executor->MustBreak() ||
			    m_iop->m_cpu.m_executor->MustBreak() ||
			    m_ee->m_VU1.m_executor->MustBreak() ||
			    m_singleStepEe || m_singleStepIop || m_singleStepVu0 || m_singleStepVu1)
			{
				m_nStatus = PAUSED;
				m_singleStepEe = false;
				m_singleStepIop = false;
				m_singleStepVu0 = false;
				m_singleStepVu1 = false;
				OnRunningStateChange();
				OnMachineStateChange();
			}
#endif
		}
	}
	static_cast<CEeExecutor*>(m_ee->m_EE.m_executor.get())->RemoveExceptionHandler();
#ifdef __ANDROID__
	Framework::CJavaVM::DetachCurrentThread();
#endif
}
