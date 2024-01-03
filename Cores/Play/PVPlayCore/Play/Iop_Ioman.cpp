// Local Changes: Support old format save files

#include <cstring>
#include <stdexcept>
#include <cctype>

#include "StdStream.h"
#include "xml/Utils.h"
#include "std_experimental_map.h"

#include "Iop_Ioman.h"
#include "IopBios.h"
#include "../AppConfig.h"
#include "../Log.h"
#include "../states/XmlStateFile.h"
#include "ioman/PathDirectoryDevice.h"

using namespace Iop;

#define LOG_NAME "iop_ioman"

#define STATE_FILES_FILENAME ("iop_ioman/files.xml")
#define STATE_FILES_FILESNODE "Files"
#define STATE_FILES_FILENODE "File"
#define STATE_FILES_FILENODE_IDATTRIBUTE ("Id")
#define STATE_FILES_FILENODE_PATHATTRIBUTE ("Path")
#define STATE_FILES_FILENODE_FLAGSATTRIBUTE ("Flags")
#define STATE_FILES_FILENODE_DESCPTRATTRIBUTE ("DescPtr")

#define STATE_USERDEVICES_FILENAME ("iop_ioman/userdevices.xml")
#define STATE_USERDEVICES_DEVICESNODE "Devices"
#define STATE_USERDEVICES_DEVICENODE "Device"
#define STATE_USERDEVICES_DEVICENODE_NAMEATTRIBUTE ("Name")
#define STATE_USERDEVICES_DEVICENODE_DESCPTRATTRIBUTE ("DescPtr")

#define STATE_MOUNTEDDEVICES_FILENAME ("iop_ioman/mounteddevices.xml")
#define STATE_MOUNTEDDEVICES_DEVICESNODE "Devices"
#define STATE_MOUNTEDDEVICES_DEVICENODE "Device"
#define STATE_MOUNTEDDEVICES_DEVICENODE_NAMEATTRIBUTE ("Name")
#define STATE_MOUNTEDDEVICES_DEVICENODE_PATHATTRIBUTE ("Path")

#define PREF_IOP_FILEIO_STDLOGGING ("iop.fileio.stdlogging")

#define FUNCTION_WRITE "Write"
#define FUNCTION_ADDDRV "AddDrv"
#define FUNCTION_DELDRV "DelDrv"
#define FUNCTION_MOUNT "Mount"
#define FUNCTION_UMOUNT "Umount"
#define FUNCTION_SEEK64 "Seek64"
#define FUNCTION_DEVCTL "DevCtl"

/** No such file or directory */
#define ERROR_ENOENT 2

//Ref: https://github.com/ps2homebrew/Open-PS2-Loader/blob/master/modules/iopcore/common/cdvdman.h
#define DEVCTL_CDVD_READCLOCK 0x430C
#define DEVCTL_CDVD_GETERROR 0x4320
#define DEVCTL_CDVD_STATUS 0x4322
#define DEVCTL_CDVD_DISKREADY 0x4325

#define DEVCTL_HDD_STATUS 0x4807
#define DEVCTL_HDD_MAXSECTOR 0x4801
#define DEVCTL_HDD_TOTALSECTOR 0x4802
#define DEVCTL_HDD_FREESECTOR 0x480A

#define DEVCTL_PFS_ZONESIZE 0x5001
#define DEVCTL_PFS_ZONEFREE 0x5002

static std::string RightTrim(std::string inputString)
{
	auto nonSpaceEnd = std::find_if(inputString.rbegin(), inputString.rend(), [](int ch) { return !std::isspace(ch); });
	inputString.erase(nonSpaceEnd.base(), inputString.end());
	return inputString;
}

struct PATHINFO
{
	std::string deviceName;
	std::string devicePath;
};

static PATHINFO SplitPath(const char* path)
{
	std::string fullPath(path);
	auto position = fullPath.find(":");
	if(position == std::string::npos)
	{
		throw std::runtime_error("Invalid path.");
	}
	PATHINFO result;
	result.deviceName = std::string(fullPath.begin(), fullPath.begin() + position);
	result.devicePath = std::string(fullPath.begin() + position + 1, fullPath.end());
	//Some games (Street Fighter EX3) provide paths with trailing spaces
	result.devicePath = RightTrim(result.devicePath);
	return result;
}

CIoman::CIoman(CIopBios& bios, uint8* ram)
    : m_bios(bios)
    , m_ram(ram)
    , m_nextFileHandle(3)
{
	CAppConfig::GetInstance().RegisterPreferenceBoolean(PREF_IOP_FILEIO_STDLOGGING, false);

	//Insert standard files if requested.
	if(CAppConfig::GetInstance().GetPreferenceBoolean(PREF_IOP_FILEIO_STDLOGGING)
#ifdef DEBUGGER_INCLUDED
	   || true
#endif
	)
	{
		try
		{
			auto stdoutPath = CAppConfig::GetBasePath() / "ps2_stdout.txt";
			auto stderrPath = CAppConfig::GetBasePath() / "ps2_stderr.txt";

			m_files[FID_STDOUT] = FileInfo{new Framework::CStdStream(fopen(stdoutPath.string().c_str(), "ab"))};
			m_files[FID_STDERR] = FileInfo{new Framework::CStdStream(fopen(stderrPath.string().c_str(), "ab"))};
		}
		catch(...)
		{
			//Humm, some error occured when opening these files...
		}
	}
}

CIoman::~CIoman()
{
	m_files.clear();
	m_devices.clear();
}

void CIoman::PrepareOpenThunk()
{
	if(m_openThunkPtr != 0) return;

	static const uint32 thunkSize = 0x30;
	auto sysmem = m_bios.GetSysmem();
	m_openThunkPtr = sysmem->AllocateMemory(thunkSize, 0, 0);

	static const int16 stackAlloc = 0x10;

	CMIPSAssembler assembler(reinterpret_cast<uint32*>(m_ram + m_openThunkPtr));

	auto finishLabel = assembler.CreateLabel();

	//Save return value (stored in T0)
	assembler.ADDIU(CMIPS::SP, CMIPS::SP, -stackAlloc);
	assembler.SW(CMIPS::RA, 0x00, CMIPS::SP);

	//Call open handler
	assembler.JALR(CMIPS::A3);
	assembler.SW(CMIPS::T0, 0x04, CMIPS::SP);

	//Check if open handler reported error, if so, leave return value untouched
	//TODO: Release handle if we failed to open properly
	assembler.BLTZ(CMIPS::V0, finishLabel);
	assembler.LW(CMIPS::RA, 0x00, CMIPS::SP);

	assembler.LW(CMIPS::V0, 0x04, CMIPS::SP);

	assembler.MarkLabel(finishLabel);
	assembler.JR(CMIPS::RA);
	assembler.ADDIU(CMIPS::SP, CMIPS::SP, stackAlloc);

	assert((assembler.GetProgramSize() * 4) <= thunkSize);
}

std::string CIoman::GetId() const
{
	return "ioman";
}

std::string CIoman::GetFunctionName(unsigned int functionId) const
{
	switch(functionId)
	{
	case 4:
		return "open";
		break;
	case 5:
		return "close";
		break;
	case 6:
		return "read";
		break;
	case 7:
		return FUNCTION_WRITE;
		break;
	case 8:
		return "seek";
		break;
	case 11:
		return "mkdir";
		break;
	case 13:
		return "dopen";
		break;
	case 14:
		return "dclose";
		break;
	case 15:
		return "dread";
		break;
	case 16:
		return "getstat";
		break;
	case 20:
		return FUNCTION_ADDDRV;
		break;
	case 21:
		return FUNCTION_DELDRV;
		break;
	case 31:
		return FUNCTION_DEVCTL;
		break;
	default:
		return "unknown";
		break;
	}
}

void CIoman::RegisterDevice(const char* name, const Ioman::DevicePtr& device)
{
	m_devices[name] = device;
}

uint32 CIoman::Open(uint32 flags, const char* path)
{
	CLog::GetInstance().Print(LOG_NAME, "Open(flags = 0x%08X, path = '%s');\r\n", flags, path);

	int32 handle = PreOpen(flags, path);
	if(handle < 0)
	{
		return handle;
	}

	assert(!IsUserDeviceFileHandle(handle));
	return handle;
}

Framework::CStream* CIoman::OpenInternal(uint32 flags, const char* path)
{
	auto pathInfo = SplitPath(path);
	auto deviceIterator = m_devices.find(pathInfo.deviceName);
	if(deviceIterator == m_devices.end())
	{
		throw std::runtime_error("Device not found.");
	}
	auto stream = deviceIterator->second->GetFile(flags, pathInfo.devicePath.c_str());
	if(!stream)
	{
		throw std::runtime_error("File not found.");
	}
	return stream;
}

uint32 CIoman::Close(uint32 handle)
{
	CLog::GetInstance().Print(LOG_NAME, "Close(handle = %d);\r\n", handle);

	uint32 result = 0xFFFFFFFF;
	assert(!IsUserDeviceFileHandle(handle));
	try
	{
		auto file(m_files.find(handle));
		if(file == std::end(m_files))
		{
			throw std::runtime_error("Invalid file handle.");
		}
		FreeFileHandle(handle);
		//Returns handle instead of 0 (needed by Naruto: Ultimate Ninja 2)
		result = handle;
	}
	catch(const std::exception& except)
	{
		CLog::GetInstance().Warn(LOG_NAME, "%s: Error occured while trying to close file : %s\r\n", __FUNCTION__, except.what());
	}
	return result;
}

uint32 CIoman::Read(uint32 handle, uint32 size, void* buffer)
{
	CLog::GetInstance().Print(LOG_NAME, "Read(handle = %d, size = 0x%X, buffer = ptr);\r\n", handle, size);

	uint32 result = 0xFFFFFFFF;
	assert(!IsUserDeviceFileHandle(handle));
	try
	{
		auto stream = GetFileStream(handle);
		if(stream->IsEOF())
		{
			result = 0;
		}
		else
		{
			result = static_cast<uint32>(stream->Read(buffer, size));
		}
	}
	catch(const std::exception& except)
	{
		CLog::GetInstance().Warn(LOG_NAME, "%s: Error occured while trying to read file : %s\r\n", __FUNCTION__, except.what());
	}
	return result;
}

uint32 CIoman::Write(uint32 handle, uint32 size, const void* buffer)
{
	CLog::GetInstance().Print(LOG_NAME, "Write(handle = %d, size = 0x%X, buffer = ptr);\r\n", handle, size);

	uint32 result = 0xFFFFFFFF;
	assert(!IsUserDeviceFileHandle(handle));
	try
	{
		auto stream = GetFileStream(handle);
		if(!stream)
		{
			throw std::runtime_error("Failed to obtain file stream.");
		}
		result = static_cast<uint32>(stream->Write(buffer, size));
		if((handle == FID_STDOUT) || (handle == FID_STDERR))
		{
			//Force flusing stdout and stderr
			stream->Flush();
		}
	}
	catch(const std::exception& except)
	{
		if((handle != FID_STDOUT) && (handle != FID_STDERR))
		{
			CLog::GetInstance().Warn(LOG_NAME, "%s: Error occured while trying to write file : %s\r\n", __FUNCTION__, except.what());
		}
	}
	return result;
}

uint32 CIoman::Seek(uint32 handle, int32 position, uint32 whence)
{
	CLog::GetInstance().Print(LOG_NAME, "Seek(handle = %d, position = %d, whence = %d);\r\n",
	                          handle, position, whence);

	uint32 result = -1U;
	assert(!IsUserDeviceFileHandle(handle));
	try
	{
		auto stream = GetFileStream(handle);
		auto direction = ConvertWhence(whence);
		stream->Seek(position, direction);
		result = static_cast<uint32>(stream->Tell());
	}
	catch(const std::exception& except)
	{
		CLog::GetInstance().Warn(LOG_NAME, "%s: Error occured while trying to seek file : %s\r\n", __FUNCTION__, except.what());
	}
	return result;
}

int32 CIoman::Mkdir(const char* path)
{
	CLog::GetInstance().Print(LOG_NAME, "Mkdir(path = '%s');\r\n", path);
	try
	{
		auto pathInfo = SplitPath(path);
		auto deviceIterator = m_devices.find(pathInfo.deviceName);
		if(deviceIterator == m_devices.end())
		{
			throw std::runtime_error("Device not found.");
		}

		deviceIterator->second->MakeDirectory(pathInfo.devicePath.c_str());
		return 0;
	}
	catch(const std::exception& except)
	{
		CLog::GetInstance().Warn(LOG_NAME, "%s: Error occured while trying to create directory : %s\r\n", __FUNCTION__, except.what());
		return -1;
	}
}

int32 CIoman::Dopen(const char* path)
{
	CLog::GetInstance().Print(LOG_NAME, "Dopen(path = '%s');\r\n",
	                          path);
	int32 handle = -1;
	try
	{
		auto pathInfo = SplitPath(path);
		auto deviceIterator = m_devices.find(pathInfo.deviceName);
		if(deviceIterator == m_devices.end())
		{
			throw std::runtime_error("Device not found.");
		}
		auto directory = deviceIterator->second->GetDirectory(pathInfo.devicePath.c_str());
		handle = m_nextFileHandle++;
		m_directories[handle] = std::move(directory);
	}
	catch(const std::exception& except)
	{
		CLog::GetInstance().Warn(LOG_NAME, "%s: Error occured while trying to open directory : %s\r\n", __FUNCTION__, except.what());
	}
	return handle;
}

int32 CIoman::Dclose(uint32 handle)
{
	CLog::GetInstance().Print(LOG_NAME, "Dclose(handle = %d);\r\n",
	                          handle);

	auto directoryIterator = m_directories.find(handle);
	if(directoryIterator == std::end(m_directories))
	{
		return -1;
	}

	m_directories.erase(directoryIterator);
	return 0;
}

int32 CIoman::Dread(uint32 handle, Ioman::DIRENTRY* dirEntry)
{
	CLog::GetInstance().Print(LOG_NAME, "Dread(handle = %d, entry = ptr);\r\n",
	                          handle);

	auto directoryIterator = m_directories.find(handle);
	if(directoryIterator == std::end(m_directories))
	{
		return -1;
	}

	auto& directory = directoryIterator->second;
	if(directory->IsDone())
	{
		return 0;
	}

	directory->ReadEntry(dirEntry);

	return strlen(dirEntry->name);
}

uint32 CIoman::GetStat(const char* path, Ioman::STAT* stat)
{
	CLog::GetInstance().Print(LOG_NAME, "GetStat(path = '%s', stat = ptr);\r\n", path);

	try
	{
		//Try with device's built-in GetStat
		auto pathInfo = SplitPath(path);
		auto deviceIterator = m_devices.find(pathInfo.deviceName);
		if(deviceIterator != m_devices.end())
		{
			bool succeeded = false;
			if(deviceIterator->second->TryGetStat(pathInfo.devicePath.c_str(), succeeded, *stat))
			{
				return succeeded ? 0 : -1;
			}
		}
	}
	catch(const std::exception& except)
	{
		//Warn, but carry on even if failed this
		CLog::GetInstance().Warn(LOG_NAME, "%s: Error occured while trying device's GetStat for '%s'. : %s\r\n",
		                         __FUNCTION__, path, except.what());
	}

	//Try with a directory
	{
		int32 fd = Dopen(path);
		if(fd >= 0)
		{
			Dclose(fd);
			memset(stat, 0, sizeof(Ioman::STAT));
			stat->mode = Ioman::STAT_MODE_DIR;
			return 0;
		}
	}

	//Try with a file
	{
		int32 fd = Open(Ioman::CDevice::OPEN_FLAG_RDONLY, path);
		if(fd >= 0)
		{
			uint32 size = Seek(fd, 0, SEEK_DIR_END);
			Close(fd);
			memset(stat, 0, sizeof(Ioman::STAT));
			stat->mode = Ioman::STAT_MODE_FILE;
			stat->loSize = size;
			return 0;
		}
	}

	return -1;
}

int32 CIoman::AddDrv(CMIPS& context)
{
	auto devicePtr = context.m_State.nGPR[CMIPS::A0].nV0;

	CLog::GetInstance().Print(LOG_NAME, FUNCTION_ADDDRV "(devicePtr = 0x%08X);\r\n",
	                          devicePtr);

	auto device = reinterpret_cast<const Ioman::DEVICE*>(m_ram + devicePtr);
	auto deviceName = device->namePtr ? reinterpret_cast<const char*>(m_ram + device->namePtr) : nullptr;
	FRAMEWORK_MAYBE_UNUSED auto deviceDesc = device->descPtr ? reinterpret_cast<const char*>(m_ram + device->descPtr) : nullptr;
	CLog::GetInstance().Print(LOG_NAME, "Requested registration of device '%s'.\r\n", deviceName);
	//We only support "cdfs" & "dev9x" for now
	if(!deviceName || (strcmp(deviceName, "cdfs") && strcmp(deviceName, "dev9x")))
	{
		return -1;
	}
	m_userDevices.insert(std::make_pair(deviceName, devicePtr));
	InvokeUserDeviceMethod(context, devicePtr, offsetof(Ioman::DEVICEOPS, initPtr), devicePtr);
	return 0;
}

uint32 CIoman::DelDrv(uint32 drvNamePtr)
{
	CLog::GetInstance().Print(LOG_NAME, FUNCTION_DELDRV "(drvNamePtr = %s);\r\n",
	                          PrintStringParameter(m_ram, drvNamePtr).c_str());
	return -1;
}

int32 CIoman::DevCtlVirtual(CMIPS& context)
{
	uint32 deviceNamePtr = context.m_State.nGPR[CMIPS::A0].nV0;
	uint32 commandId = context.m_State.nGPR[CMIPS::A1].nV0;
	uint32 inputPtr = context.m_State.nGPR[CMIPS::A2].nV0;
	uint32 inputSize = context.m_State.nGPR[CMIPS::A3].nV0;
	uint32 outputPtr = context.m_pMemoryMap->GetWord(context.m_State.nGPR[CMIPS::SP].nV0 + 0x10);
	uint32 outputSize = context.m_pMemoryMap->GetWord(context.m_State.nGPR[CMIPS::SP].nV0 + 0x14);

	CLog::GetInstance().Print(LOG_NAME, FUNCTION_DEVCTL "(deviceName = %s, cmd = 0x%08X, input = 0x%08X, inputSize = 0x%08X, output = 0x%08X, outputSize = 0x%08X);\r\n",
	                          PrintStringParameter(m_ram, deviceNamePtr).c_str(), commandId, inputPtr, inputSize, outputPtr, outputSize);

	auto deviceName = reinterpret_cast<const char*>(m_ram + deviceNamePtr);
	auto input = reinterpret_cast<const uint32*>(m_ram + inputPtr);
	auto output = reinterpret_cast<uint32*>(m_ram + outputPtr);

	return DevCtl(deviceName, commandId, input, inputSize, output, outputSize);
}

int32 CIoman::Mount(const char* fsName, const char* devicePath)
{
	CLog::GetInstance().Print(LOG_NAME, FUNCTION_MOUNT "(fsName = '%s', devicePath = '%s');\r\n",
	                          fsName, devicePath);

	auto pathInfo = SplitPath(devicePath);
	auto deviceIterator = m_devices.find(pathInfo.deviceName);
	if(deviceIterator == m_devices.end())
	{
		return -1;
	}

	auto device = deviceIterator->second;
	uint32 result = 0;
	try
	{
		auto mountedDeviceName = std::string(fsName);
		//Strip any colons we might have in the string
		mountedDeviceName.erase(std::remove(mountedDeviceName.begin(), mountedDeviceName.end(), ':'), mountedDeviceName.end());
		assert(m_devices.find(mountedDeviceName) == std::end(m_devices));
		assert(m_mountedDevices.find(mountedDeviceName) == std::end(m_mountedDevices));

		auto mountedDevice = device->Mount(pathInfo.devicePath.c_str());
		m_devices[mountedDeviceName] = mountedDevice;
		m_mountedDevices[mountedDeviceName] = devicePath;
	}
	catch(const std::exception& except)
	{
		CLog::GetInstance().Warn(LOG_NAME, "%s: Error occurred while trying to mount : %s : %s\r\n", __FUNCTION__, devicePath, except.what());
		result = -1;
	}
	return result;
}

int32 CIoman::Umount(const char* deviceName)
{
	CLog::GetInstance().Print(LOG_NAME, FUNCTION_UMOUNT "(deviceName = '%s');\r\n", deviceName);

	auto mountedDeviceName = std::string(deviceName);
	//Strip any colons we might have in the string
	mountedDeviceName.erase(std::remove(mountedDeviceName.begin(), mountedDeviceName.end(), ':'), mountedDeviceName.end());

	auto deviceIterator = m_devices.find(mountedDeviceName);
	if(deviceIterator == std::end(m_devices))
	{
		//Device not found
		return -1;
	}

	//We maybe need to make sure we don't have outstanding fds?
	m_devices.erase(deviceIterator);

	{
		auto mountedDeviceIterator = m_mountedDevices.find(mountedDeviceName);
		assert(mountedDeviceIterator != std::end(m_mountedDevices));
		m_mountedDevices.erase(mountedDeviceIterator);
	}

	return 0;
}

uint64 CIoman::Seek64(uint32 handle, int64 position, uint32 whence)
{
	CLog::GetInstance().Print(LOG_NAME, FUNCTION_SEEK64 "(handle = %d, position = %ld, whence = %d);\r\n",
	                          handle, position, whence);

	uint64 result = -1ULL;
	assert(!IsUserDeviceFileHandle(handle));
	try
	{
		auto stream = GetFileStream(handle);
		auto direction = ConvertWhence(whence);
		stream->Seek(position, direction);
		result = stream->Tell();
	}
	catch(const std::exception& except)
	{
		CLog::GetInstance().Warn(LOG_NAME, "%s: Error occured while trying to seek file : %s\r\n", __FUNCTION__, except.what());
	}
	return result;
}

int32 CIoman::DevCtl(const char* deviceName, uint32 command, const uint32* input, uint32 inputSize, uint32* output, uint32 outputSize)
{
	uint32 result = 0;
	switch(command)
	{
	case DEVCTL_CDVD_READCLOCK:
		assert(inputSize == 0);
		assert(outputSize == 8);
		CLog::GetInstance().Print(LOG_NAME, "CdReadClock();\r\n");
		break;
	case DEVCTL_CDVD_GETERROR:
		assert(outputSize == 4);
		CLog::GetInstance().Print(LOG_NAME, "CdGetError();\r\n");
		output[0] = 0; //No error
		break;
	case DEVCTL_CDVD_STATUS:
		//Used by Star Soldier
		assert(outputSize == 4);
		CLog::GetInstance().Print(LOG_NAME, "CdStatus();\r\n");
		output[0] = 10; //CDVD_STATUS_PAUSED
		break;
	case DEVCTL_CDVD_DISKREADY:
		assert(inputSize == 4);
		assert(outputSize == 4);
		CLog::GetInstance().Print(LOG_NAME, "CdDiskReady(%d);\r\n", input[0]);
		output[0] = 2; //Disk ready
		break;
	case DEVCTL_HDD_STATUS:
		CLog::GetInstance().Print(LOG_NAME, "HddStatus();\r\n");
		break;
	case DEVCTL_HDD_MAXSECTOR:
		CLog::GetInstance().Print(LOG_NAME, "HddMaxSector();\r\n");
		result = 0x400000; //Max num of sectors per partition
		break;
	case DEVCTL_HDD_TOTALSECTOR:
		CLog::GetInstance().Print(LOG_NAME, "HddTotalSector();\r\n");
		result = 0x400000; //Number of sectors
		break;
	case DEVCTL_HDD_FREESECTOR:
		assert(outputSize == 4);
		CLog::GetInstance().Print(LOG_NAME, "HddFreeSector();\r\n");
		output[0] = 0x400000; //Number of sectors
		break;
	case DEVCTL_PFS_ZONESIZE:
		CLog::GetInstance().Print(LOG_NAME, "PfsZoneSize();\r\n");
		result = 0x1000000;
		break;
	case DEVCTL_PFS_ZONEFREE:
		CLog::GetInstance().Print(LOG_NAME, "PfsZoneFree();\r\n");
		result = 0x10;
		break;
	default:
		CLog::GetInstance().Warn(LOG_NAME, "DevCtl -> Unknown(deviceName = '%s', cmd = 0x%08X);\r\n", deviceName, command);
		break;
	}
	return result;
}

int32 CIoman::PreOpen(uint32 flags, const char* path)
{
	int32 handle = AllocateFileHandle();
	try
	{
		auto& file = m_files[handle];
		file.path = path;
		file.flags = flags;

		auto pathInfo = SplitPath(path);
		auto deviceIterator = m_devices.find(pathInfo.deviceName);
		auto userDeviceIterator = m_userDevices.find(pathInfo.deviceName);
		if(deviceIterator != m_devices.end())
		{
			file.stream = deviceIterator->second->GetFile(flags, pathInfo.devicePath.c_str());
			if(!file.stream)
			{
				throw FileNotFoundException();
			}
		}
		else if(userDeviceIterator != m_userDevices.end())
		{
			auto sysmem = m_bios.GetSysmem();
			file.descPtr = sysmem->AllocateMemory(sizeof(Ioman::DEVICEFILE), 0, 0);
			assert(file.descPtr != 0);
			auto desc = reinterpret_cast<Ioman::DEVICEFILE*>(m_ram + file.descPtr);
			desc->devicePtr = userDeviceIterator->second;
			desc->privateData = 0;
			desc->unit = 0;
			desc->mode = flags;
		}
		else
		{
			throw std::runtime_error("Unknown device.");
		}
	}
	catch(const CIoman::FileNotFoundException& except)
	{
		CLog::GetInstance().Warn(LOG_NAME, "%s: Error occurred while trying to open not existing file : %s\r\n", __FUNCTION__, path);
		FreeFileHandle(handle);

		return -ERROR_ENOENT;
	}
	catch(const std::exception& except)
	{
		CLog::GetInstance().Warn(LOG_NAME, "%s: Error occurred while trying to open file : %s : %s\r\n", __FUNCTION__, path, except.what());
		FreeFileHandle(handle);

		return -1;
	}
	return handle;
}

Framework::STREAM_SEEK_DIRECTION CIoman::ConvertWhence(uint32 whence)
{
	switch(whence)
	{
	default:
		assert(false);
		[[fallthrough]];
	case SEEK_DIR_SET:
		return Framework::STREAM_SEEK_SET;
	case SEEK_DIR_CUR:
		return Framework::STREAM_SEEK_CUR;
	case SEEK_DIR_END:
		return Framework::STREAM_SEEK_END;
	}
}

bool CIoman::IsUserDeviceFileHandle(int32 fileHandle) const
{
	auto fileIterator = m_files.find(fileHandle);
	if(fileIterator == std::end(m_files)) return false;
	return GetUserDeviceFileDescPtr(fileHandle) != 0;
}

uint32 CIoman::GetUserDeviceFileDescPtr(int32 fileHandle) const
{
	auto fileIterator = m_files.find(fileHandle);
	assert(fileIterator != std::end(m_files));
	const auto& file = fileIterator->second;
	assert(!((file.descPtr != 0) && file.stream));
	return file.descPtr;
}

int32 CIoman::OpenVirtual(CMIPS& context)
{
	uint32 pathPtr = context.m_State.nGPR[CMIPS::A0].nV0;
	uint32 flags = context.m_State.nGPR[CMIPS::A1].nV0;

	auto path = reinterpret_cast<const char*>(m_ram + pathPtr);

	CLog::GetInstance().Print(LOG_NAME, "OpenVirtual(flags = 0x%08X, path = '%s');\r\n", flags, path);

	int32 handle = PreOpen(flags, path);
	if(handle < 0)
	{
		//PreOpen failed, bail
		return handle;
	}

	if(IsUserDeviceFileHandle(handle))
	{
		PrepareOpenThunk();

		auto devicePath = strchr(path, ':');
		assert(devicePath);
		auto devicePathPos = static_cast<uint32>(devicePath - path);
		uint32 descPtr = GetUserDeviceFileDescPtr(handle);
		auto desc = reinterpret_cast<Ioman::DEVICEFILE*>(m_ram + descPtr);
		auto device = reinterpret_cast<Ioman::DEVICE*>(m_ram + desc->devicePtr);
		auto ops = reinterpret_cast<Ioman::DEVICEOPS*>(m_ram + device->opsPtr);

		context.m_State.nPC = m_openThunkPtr;
		context.m_State.nGPR[CMIPS::A0].nV0 = descPtr;
		context.m_State.nGPR[CMIPS::A1].nV0 = pathPtr + devicePathPos + 1;
		context.m_State.nGPR[CMIPS::A2].nV0 = flags;
		context.m_State.nGPR[CMIPS::A3].nV0 = ops->openPtr;
		context.m_State.nGPR[CMIPS::T0].nV0 = handle;
		return 0;
	}

	return handle;
}

int32 CIoman::CloseVirtual(CMIPS& context)
{
	int32 handle = context.m_State.nGPR[CMIPS::A0].nV0;

	CLog::GetInstance().Print(LOG_NAME, "CloseVirtual(handle = %d);\r\n", handle);

	auto fileIterator = m_files.find(handle);
	if(fileIterator == std::end(m_files))
	{
		CLog::GetInstance().Warn(LOG_NAME, "%s : Provided invalid fd %d.\r\n",
		                         __FUNCTION__, handle);
		return -1;
	}

	if(IsUserDeviceFileHandle(handle))
	{
		//TODO: Free file handle
		uint32 descPtr = GetUserDeviceFileDescPtr(handle);
		auto desc = reinterpret_cast<Ioman::DEVICEFILE*>(m_ram + descPtr);
		InvokeUserDeviceMethod(context, desc->devicePtr,
		                       offsetof(Ioman::DEVICEOPS, closePtr),
		                       descPtr);
		return 0;
	}
	else
	{
		return Close(handle);
	}
}

int32 CIoman::ReadVirtual(CMIPS& context)
{
	int32 handle = context.m_State.nGPR[CMIPS::A0].nV0;
	uint32 bufferPtr = context.m_State.nGPR[CMIPS::A1].nV0;
	uint32 count = context.m_State.nGPR[CMIPS::A2].nV0;

	CLog::GetInstance().Print(LOG_NAME, "ReadVirtual(handle = %d, size = 0x%X, buffer = ptr);\r\n", handle, count);

	auto fileIterator = m_files.find(handle);
	if(fileIterator == std::end(m_files))
	{
		CLog::GetInstance().Warn(LOG_NAME, "%s : Provided invalid fd %d.\r\n",
		                         __FUNCTION__, handle);
		return -1;
	}

	if(IsUserDeviceFileHandle(handle))
	{
		uint32 descPtr = GetUserDeviceFileDescPtr(handle);
		auto desc = reinterpret_cast<Ioman::DEVICEFILE*>(m_ram + descPtr);
		InvokeUserDeviceMethod(context, desc->devicePtr,
		                       offsetof(Ioman::DEVICEOPS, readPtr),
		                       descPtr, bufferPtr, count);
		return 0;
	}
	else
	{
		return Read(handle, count, m_ram + bufferPtr);
	}
}

int32 CIoman::WriteVirtual(CMIPS& context)
{
	int32 handle = context.m_State.nGPR[CMIPS::A0].nV0;
	uint32 bufferPtr = context.m_State.nGPR[CMIPS::A1].nV0;
	uint32 count = context.m_State.nGPR[CMIPS::A2].nV0;

	CLog::GetInstance().Print(LOG_NAME, "WriteVirtual(handle = %d, size = 0x%X, buffer = ptr);\r\n", handle, count);

	auto fileIterator = m_files.find(handle);
	if(fileIterator == std::end(m_files))
	{
		CLog::GetInstance().Warn(LOG_NAME, "%s : Provided invalid fd %d.\r\n",
		                         __FUNCTION__, handle);
		return -1;
	}

	if(IsUserDeviceFileHandle(handle))
	{
		uint32 descPtr = GetUserDeviceFileDescPtr(handle);
		auto desc = reinterpret_cast<Ioman::DEVICEFILE*>(m_ram + descPtr);
		InvokeUserDeviceMethod(context, desc->devicePtr,
		                       offsetof(Ioman::DEVICEOPS, writePtr),
		                       descPtr, bufferPtr, count);
		return 0;
	}
	else
	{
		return Write(handle, count, m_ram + bufferPtr);
	}
}

int32 CIoman::SeekVirtual(CMIPS& context)
{
	int32 handle = context.m_State.nGPR[CMIPS::A0].nV0;
	uint32 position = context.m_State.nGPR[CMIPS::A1].nV0;
	uint32 whence = context.m_State.nGPR[CMIPS::A2].nV0;

	CLog::GetInstance().Print(LOG_NAME, "SeekVirtual(handle = %d, position = %d, whence = %d);\r\n",
	                          handle, position, whence);

	auto fileIterator = m_files.find(handle);
	if(fileIterator == std::end(m_files))
	{
		CLog::GetInstance().Warn(LOG_NAME, "%s : Provided invalid fd %d.\r\n",
		                         __FUNCTION__, handle);
		return -1;
	}

	if(IsUserDeviceFileHandle(handle))
	{
		uint32 descPtr = GetUserDeviceFileDescPtr(handle);
		auto desc = reinterpret_cast<Ioman::DEVICEFILE*>(m_ram + descPtr);
		InvokeUserDeviceMethod(context, desc->devicePtr,
		                       offsetof(Ioman::DEVICEOPS, lseekPtr),
		                       descPtr, position, whence);
		return 0;
	}
	else
	{
		return Seek(handle, position, whence);
	}
}

void CIoman::InvokeUserDeviceMethod(CMIPS& context, uint32 devicePtr, size_t opOffset, uint32 arg0, uint32 arg1, uint32 arg2)
{
	auto device = reinterpret_cast<Ioman::DEVICE*>(m_ram + devicePtr);
	auto opAddr = *reinterpret_cast<uint32*>(m_ram + device->opsPtr + opOffset);
	context.m_State.nGPR[CMIPS::A0].nV0 = arg0;
	context.m_State.nGPR[CMIPS::A1].nV0 = arg1;
	context.m_State.nGPR[CMIPS::A2].nV0 = arg2;
	context.m_State.nPC = opAddr;
}

int32 CIoman::AllocateFileHandle()
{
	uint32 handle = m_nextFileHandle++;
	assert(m_files.find(handle) == std::end(m_files));
	m_files[handle] = FileInfo();
	return handle;
}

void CIoman::FreeFileHandle(uint32 handle)
{
	assert(m_files.find(handle) != std::end(m_files));
	m_files.erase(handle);
}

uint32 CIoman::GetFileMode(uint32 handle) const
{
	auto file(m_files.find(handle));
	if(file == std::end(m_files))
	{
		throw std::runtime_error("Invalid file handle.");
	}
	return file->second.flags;
}

Framework::CStream* CIoman::GetFileStream(uint32 handle)
{
	auto file(m_files.find(handle));
	if(file == std::end(m_files))
	{
		throw std::runtime_error("Invalid file handle.");
	}
	return file->second.stream;
}

void CIoman::SetFileStream(uint32 handle, Framework::CStream* stream)
{
	m_files.erase(handle);
	m_files[handle] = {stream};
}

//IOP Invoke
void CIoman::Invoke(CMIPS& context, unsigned int functionId)
{
	switch(functionId)
	{
	case 4:
		context.m_State.nGPR[CMIPS::V0].nD0 = static_cast<int32>(OpenVirtual(context));
		break;
	case 5:
		context.m_State.nGPR[CMIPS::V0].nD0 = static_cast<int32>(CloseVirtual(context));
		break;
	case 6:
		context.m_State.nGPR[CMIPS::V0].nD0 = static_cast<int32>(ReadVirtual(context));
		break;
	case 7:
		context.m_State.nGPR[CMIPS::V0].nD0 = static_cast<int32>(WriteVirtual(context));
		break;
	case 8:
		context.m_State.nGPR[CMIPS::V0].nD0 = static_cast<int32>(SeekVirtual(context));
		break;
	case 11:
		context.m_State.nGPR[CMIPS::V0].nD0 = static_cast<int32>(Mkdir(
		    reinterpret_cast<char*>(&m_ram[context.m_State.nGPR[CMIPS::A0].nV[0]])));
		break;
	case 13:
		context.m_State.nGPR[CMIPS::V0].nD0 = static_cast<int32>(Dopen(
		    reinterpret_cast<char*>(&m_ram[context.m_State.nGPR[CMIPS::A0].nV[0]])));
		break;
	case 14:
		context.m_State.nGPR[CMIPS::V0].nD0 = static_cast<int32>(Dclose(
		    context.m_State.nGPR[CMIPS::A0].nV0));
		break;
	case 15:
		context.m_State.nGPR[CMIPS::V0].nD0 = static_cast<int32>(Dread(
		    context.m_State.nGPR[CMIPS::A0].nV0,
		    reinterpret_cast<Ioman::DIRENTRY*>(&m_ram[context.m_State.nGPR[CMIPS::A1].nV[0]])));
		break;
	case 16:
		context.m_State.nGPR[CMIPS::V0].nD0 = static_cast<int32>(GetStat(
		    reinterpret_cast<char*>(&m_ram[context.m_State.nGPR[CMIPS::A0].nV[0]]),
		    reinterpret_cast<Ioman::STAT*>(&m_ram[context.m_State.nGPR[CMIPS::A1].nV[0]])));
		break;
	case 20:
		context.m_State.nGPR[CMIPS::V0].nD0 = static_cast<int32>(AddDrv(context));
		break;
	case 21:
		context.m_State.nGPR[CMIPS::V0].nD0 = static_cast<int32>(DelDrv(
		    context.m_State.nGPR[CMIPS::A0].nV0));
		break;
	case 31:
		context.m_State.nGPR[CMIPS::V0].nD0 = DevCtlVirtual(context);
		break;
	default:
		CLog::GetInstance().Warn(LOG_NAME, "%s(%08X): Unknown function (%d) called.\r\n", __FUNCTION__, context.m_State.nPC, functionId);
		break;
	}
}

void CIoman::SaveState(Framework::CZipArchiveWriter& archive) const
{
	SaveMountedDevicesState(archive);
	SaveFilesState(archive);
	SaveUserDevicesState(archive);
}

void CIoman::LoadState(Framework::CZipArchiveReader& archive)
{
    try {
        LoadMountedDevicesState(archive);
        printf("Mounted Device State OK\n");
    } catch (...) {
        m_userDevices.clear();
    }	
    LoadFilesState(archive);
	LoadUserDevicesState(archive);
}

void CIoman::SaveFilesState(Framework::CZipArchiveWriter& archive) const
{
	auto fileStateFile = std::make_unique<CXmlStateFile>(STATE_FILES_FILENAME, STATE_FILES_FILESNODE);
	auto filesStateNode = fileStateFile->GetRoot();

	for(const auto& filePair : m_files)
	{
		if(filePair.first == FID_STDOUT) continue;
		if(filePair.first == FID_STDERR) continue;

		const auto& file = filePair.second;

		auto fileStateNode = new Framework::Xml::CNode(STATE_FILES_FILENODE, true);
		fileStateNode->InsertAttribute(Framework::Xml::CreateAttributeIntValue(STATE_FILES_FILENODE_IDATTRIBUTE, filePair.first));
		fileStateNode->InsertAttribute(Framework::Xml::CreateAttributeIntValue(STATE_FILES_FILENODE_FLAGSATTRIBUTE, file.flags));
		fileStateNode->InsertAttribute(Framework::Xml::CreateAttributeIntValue(STATE_FILES_FILENODE_DESCPTRATTRIBUTE, file.descPtr));
		fileStateNode->InsertAttribute(Framework::Xml::CreateAttributeStringValue(STATE_FILES_FILENODE_PATHATTRIBUTE, file.path.c_str()));
		filesStateNode->InsertNode(fileStateNode);
	}

	archive.InsertFile(std::move(fileStateFile));
}

void CIoman::SaveUserDevicesState(Framework::CZipArchiveWriter& archive) const
{
	auto deviceStateFile = std::make_unique<CXmlStateFile>(STATE_USERDEVICES_FILENAME, STATE_USERDEVICES_DEVICESNODE);
	auto devicesStateNode = deviceStateFile->GetRoot();

	for(const auto& devicePair : m_userDevices)
	{
		auto deviceStateNode = new Framework::Xml::CNode(STATE_USERDEVICES_DEVICENODE, true);
		deviceStateNode->InsertAttribute(Framework::Xml::CreateAttributeStringValue(STATE_USERDEVICES_DEVICENODE_NAMEATTRIBUTE, devicePair.first.c_str()));
		deviceStateNode->InsertAttribute(Framework::Xml::CreateAttributeIntValue(STATE_USERDEVICES_DEVICENODE_DESCPTRATTRIBUTE, devicePair.second));
		devicesStateNode->InsertNode(deviceStateNode);
	}

	archive.InsertFile(std::move(deviceStateFile));
}

void CIoman::SaveMountedDevicesState(Framework::CZipArchiveWriter& archive) const
{
	auto deviceStateFile = std::make_unique<CXmlStateFile>(STATE_MOUNTEDDEVICES_FILENAME, STATE_MOUNTEDDEVICES_DEVICESNODE);
	auto devicesStateNode = deviceStateFile->GetRoot();

	for(const auto& devicePair : m_mountedDevices)
	{
		auto deviceStateNode = new Framework::Xml::CNode(STATE_MOUNTEDDEVICES_DEVICENODE, true);
		deviceStateNode->InsertAttribute(Framework::Xml::CreateAttributeStringValue(STATE_MOUNTEDDEVICES_DEVICENODE_NAMEATTRIBUTE, devicePair.first.c_str()));
		deviceStateNode->InsertAttribute(Framework::Xml::CreateAttributeStringValue(STATE_MOUNTEDDEVICES_DEVICENODE_PATHATTRIBUTE, devicePair.second.c_str()));
		devicesStateNode->InsertNode(deviceStateNode);
	}

	archive.InsertFile(std::move(deviceStateFile));
}

void CIoman::LoadFilesState(Framework::CZipArchiveReader& archive)
{
	std::experimental::erase_if(m_files,
	                            [](const FileMapType::value_type& filePair) {
		                            return (filePair.first != FID_STDOUT) && (filePair.first != FID_STDERR);
	                            });

	auto fileStateFile = CXmlStateFile(*archive.BeginReadFile(STATE_FILES_FILENAME));
	auto fileStateNode = fileStateFile.GetRoot();

	int32 maxFileId = FID_STDERR;
	auto fileNodes = fileStateNode->SelectNodes(STATE_FILES_FILESNODE "/" STATE_FILES_FILENODE);
	for(auto fileNode : fileNodes)
	{
		int32 id = 0, flags = 0, descPtr = 0;
		std::string path;
		if(!Framework::Xml::GetAttributeIntValue(fileNode, STATE_FILES_FILENODE_IDATTRIBUTE, &id)) break;
		if(!Framework::Xml::GetAttributeStringValue(fileNode, STATE_FILES_FILENODE_PATHATTRIBUTE, &path)) break;
		if(!Framework::Xml::GetAttributeIntValue(fileNode, STATE_FILES_FILENODE_FLAGSATTRIBUTE, &flags)) break;
		if(!Framework::Xml::GetAttributeIntValue(fileNode, STATE_FILES_FILENODE_DESCPTRATTRIBUTE, &descPtr)) break;

		FileInfo fileInfo;
		fileInfo.flags = flags;
		fileInfo.path = path;
		fileInfo.descPtr = descPtr;
		fileInfo.stream = (descPtr == 0) ? OpenInternal(flags, path.c_str()) : nullptr;
		m_files[id] = std::move(fileInfo);

		maxFileId = std::max(maxFileId, id);
	}
	m_nextFileHandle = maxFileId + 1;
}

void CIoman::LoadUserDevicesState(Framework::CZipArchiveReader& archive)
{
	m_userDevices.clear();

	auto deviceStateFile = CXmlStateFile(*archive.BeginReadFile(STATE_USERDEVICES_FILENAME));
	auto deviceStateNode = deviceStateFile.GetRoot();

	auto deviceNodes = deviceStateNode->SelectNodes(STATE_USERDEVICES_DEVICESNODE "/" STATE_USERDEVICES_DEVICENODE);
	for(auto deviceNode : deviceNodes)
	{
		std::string name;
		int32 descPtr = 0;
		if(!Framework::Xml::GetAttributeStringValue(deviceNode, STATE_USERDEVICES_DEVICENODE_NAMEATTRIBUTE, &name)) break;
		if(!Framework::Xml::GetAttributeIntValue(deviceNode, STATE_USERDEVICES_DEVICENODE_DESCPTRATTRIBUTE, &descPtr)) break;

		m_userDevices[name] = descPtr;
	}
}

void CIoman::LoadMountedDevicesState(Framework::CZipArchiveReader& archive)
{
	std::experimental::erase_if(m_devices,
	                            [this](const auto& devicePair) {
		                            return (m_mountedDevices.find(devicePair.first) != std::end(m_mountedDevices));
	                            });
	m_mountedDevices.clear();

	auto deviceStateFile = CXmlStateFile(*archive.BeginReadFile(STATE_MOUNTEDDEVICES_FILENAME));
	auto deviceStateNode = deviceStateFile.GetRoot();

	auto deviceNodes = deviceStateNode->SelectNodes(STATE_MOUNTEDDEVICES_DEVICESNODE "/" STATE_MOUNTEDDEVICES_DEVICENODE);
	for(auto deviceNode : deviceNodes)
	{
		std::string name;
		std::string path;
		if(!Framework::Xml::GetAttributeStringValue(deviceNode, STATE_MOUNTEDDEVICES_DEVICENODE_NAMEATTRIBUTE, &name)) break;
		if(!Framework::Xml::GetAttributeStringValue(deviceNode, STATE_MOUNTEDDEVICES_DEVICENODE_PATHATTRIBUTE, &path)) break;

		Mount(name.c_str(), path.c_str());
	}
}
