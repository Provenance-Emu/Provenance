// Copyright 2020 Citra Emulator Project
// Licensed under GPLv2 or any later version
// Refer to the license.txt file included.

// Local Changes: Add Save/Load State by Path

#include <chrono>
#include <cryptopp/hex.h>
#include "common/archives.h"
#include "common/logging/log.h"
#include "common/scm_rev.h"
#include "common/zstd_compression.h"
#include "core/core.h"
#include "core/movie.h"
#include "core/savestate.h"
#include "network/network.h"

#include <boost/iostreams/device/array.hpp>
#include <boost/iostreams/stream.hpp>
#include <zstd.h>
#include <algorithm>


namespace Core {

#pragma pack(push, 1)
struct CSTHeader {
    std::array<u8, 4> filetype;  /// Unique Identifier to check the file type (always "CST"0x1B)
    u64_le program_id;           /// ID of the ROM being executed. Also called title_id
    std::array<u8, 20> revision; /// Git hash of the revision this savestate was created with
    u64_le time;                 /// The time when this save state was created
    
    std::array<u8, 216> reserved{}; /// Make heading 256 bytes so it has consistent size
};
static_assert(sizeof(CSTHeader) == 256, "CSTHeader should be 256 bytes");
#pragma pack(pop)

constexpr std::array<u8, 4> header_magic_bytes{{'C', 'S', 'T', 0x1B}};

static std::string GetSaveStatePath(u64 program_id, u32 slot) {
    const u64 movie_id = Movie::GetInstance().GetCurrentMovieID();
    if (movie_id) {
        return fmt::format("{}{:016X}.movie{:016X}.{:02d}.cst",
                           FileUtil::GetUserPath(FileUtil::UserPath::StatesDir), program_id,
                           movie_id, slot);
    } else {
        return fmt::format("{}{:016X}.{:02d}.cst",
                           FileUtil::GetUserPath(FileUtil::UserPath::StatesDir), program_id, slot);
    }
}

static bool ValidateSaveState(const CSTHeader& header, SaveStateInfo& info, u64 program_id,
                              u32 slot) {
    const auto path = GetSaveStatePath(program_id, slot);
    if (header.filetype != header_magic_bytes) {
        LOG_WARNING(Core, "Invalid save state file {}", path);
        return false;
    }
    info.time = header.time;
    
    if (header.program_id != program_id) {
        LOG_WARNING(Core, "Save state file isn't for the current game {}", path);
        return false;
    }
    const std::string revision = fmt::format("{:02x}", fmt::join(header.revision, ""));
    if (revision == Common::g_scm_rev) {
        info.status = SaveStateInfo::ValidationStatus::OK;
    } else {
        LOG_WARNING(Core, "Save state file {} created from a different revision {}", path,
                    revision);
        info.status = SaveStateInfo::ValidationStatus::RevisionDismatch;
    }
    return true;
}

std::vector<SaveStateInfo> ListSaveStates(u64 program_id) {
    std::vector<SaveStateInfo> result;
    result.reserve(SaveStateSlotCount);
    for (u32 slot = 1; slot <= SaveStateSlotCount; ++slot) {
        const auto path = GetSaveStatePath(program_id, slot);
        if (!FileUtil::Exists(path)) {
            continue;
        }
        
        SaveStateInfo info;
        info.slot = slot;
        
        FileUtil::IOFile file(path, "rb");
        if (!file) {
            LOG_ERROR(Core, "Could not open file {}", path);
            continue;
        }
        CSTHeader header;
        if (file.GetSize() < sizeof(header)) {
            LOG_ERROR(Core, "File too small {}", path);
            continue;
        }
        if (file.ReadBytes(&header, sizeof(header)) != sizeof(header)) {
            LOG_ERROR(Core, "Could not read from file {}", path);
            continue;
        }
        if (!ValidateSaveState(header, info, program_id, slot)) {
            continue;
        }
        
        result.emplace_back(std::move(info));
    }
    return result;
}

void System::SaveState(u32 slot) const {
    std::ostringstream sstream{std::ios_base::binary};
    // Serialize
    oarchive oa{sstream};
    oa&* this;
    
    const std::string& str{sstream.str()};
    auto buffer = Common::Compression::CompressDataZSTDDefault(
                                                               reinterpret_cast<const u8*>(str.data()), str.size());
    
    const auto path = GetSaveStatePath(title_id, slot);
    if (!FileUtil::CreateFullPath(path)) {
        throw std::runtime_error("Could not create path " + path);
    }
    
    FileUtil::IOFile file(path, "wb");
    if (!file) {
        throw std::runtime_error("Could not open file " + path);
    }
    
    CSTHeader header{};
    header.filetype = header_magic_bytes;
    header.program_id = title_id;
    std::string rev_bytes;
    CryptoPP::StringSource ss(Common::g_scm_rev, true,
                              new CryptoPP::HexDecoder(new CryptoPP::StringSink(rev_bytes)));
    std::memcpy(header.revision.data(), rev_bytes.data(), sizeof(header.revision));
    header.time = std::chrono::duration_cast<std::chrono::seconds>(
                                                                   std::chrono::system_clock::now().time_since_epoch())
    .count();
    
    if (file.WriteBytes(&header, sizeof(header)) != sizeof(header) ||
        file.WriteBytes(buffer.data(), buffer.size()) != buffer.size()) {
        throw std::runtime_error("Could not write to file " + path);
    }
}

void System::LoadState(u32 slot) {
    if (Network::GetRoomMember().lock()->IsConnected()) {
        throw std::runtime_error("Unable to load while connected to multiplayer");
    }
    
    const auto path = GetSaveStatePath(title_id, slot);
    
    std::vector<u8> decompressed;
    {
        std::vector<u8> buffer(FileUtil::GetSize(path) - sizeof(CSTHeader));
        
        FileUtil::IOFile file(path, "rb");
        
        // load header
        CSTHeader header;
        if (file.ReadBytes(&header, sizeof(header)) != sizeof(header)) {
            throw std::runtime_error("Could not read from file at " + path);
        }
        
        // validate header
        SaveStateInfo info;
        if (!ValidateSaveState(header, info, title_id, slot)) {
            throw std::runtime_error("Invalid savestate");
        }
        
        if (file.ReadBytes(buffer.data(), buffer.size()) != buffer.size()) {
            throw std::runtime_error("Could not read from file at " + path);
        }
        decompressed = Common::Compression::DecompressDataZSTD(buffer);
    }
    std::istringstream sstream{
        std::string{reinterpret_cast<char*>(decompressed.data()), decompressed.size()},
        std::ios_base::binary};
    decompressed.clear();
    
    // Deserialize
    iarchive ia{sstream};
    ia&* this;
}

bool InitMem() {
    if (!save_addr2) {
        kern_return_t retval = vm_allocate(mach_task_self(), &save_addr2, (size_t)size2, VM_FLAGS_ANYWHERE);
        int tries=0;
        if (retval != KERN_SUCCESS) {
            return false;
        }
    }
    if (!save_addr) {
        kern_return_t retval = vm_allocate(mach_task_self(), &save_addr, (size_t)size, VM_FLAGS_ANYWHERE);
        int tries=0;
        if (retval != KERN_SUCCESS) {
            return false;
        }
    }
    for (size_t i = 0; i < size2; i++) {
        ((u8 *)save_addr2)[i] = 0;
    }
    for (size_t i = 0; i < size; i++) {
        ((u8 *)save_addr)[i] = 0;
    }
    return true;
}

void SaveState(std::string path, u64 _title_id) {
    usleep(1000);
    InitMem();
    boost::iostreams::stream<boost::iostreams::basic_array_sink<char>> *stream=new boost::iostreams::stream<boost::iostreams::basic_array_sink<char>>(reinterpret_cast<char*>(save_addr2), size2);
    // Serialize
    oarchive *oa=new oarchive{*stream};
    *oa&* &System::GetInstance();
    const std::size_t compressed_size =
        ZSTD_compress(
                      (void *)(reinterpret_cast<const u8*>(save_addr)),
                      (size_t)size,
                      (void *)(reinterpret_cast<const u8*>(save_addr2)),
                      (size_t)size2,
                      (s32)std::clamp(ZSTD_CLEVEL_DEFAULT, ZSTD_minCLevel(), ZSTD_maxCLevel())
        );
    if (!FileUtil::CreateFullPath(path)) {
        throw std::runtime_error("Could not create path " + path);
    }
    FileUtil::IOFile *file = new FileUtil::IOFile(path, "wb");
    if (!file) {
        throw std::runtime_error("Could not open file " + path);
    }
    CSTHeader header{};
    header.filetype = header_magic_bytes;
    header.program_id = _title_id;
    std::string rev_bytes;
    CryptoPP::StringSource ss(Common::g_scm_rev, true,
                              new CryptoPP::HexDecoder(new CryptoPP::StringSink(rev_bytes)));
    std::memcpy(header.revision.data(), rev_bytes.data(), sizeof(header.revision));
    header.time = std::chrono::duration_cast<std::chrono::seconds>(std::chrono::system_clock::now().time_since_epoch())
    .count();
    if (file->WriteBytes(&header, sizeof(header)) != sizeof(header) ||
        file->WriteBytes((size_t *)save_addr, compressed_size) != compressed_size) {
        throw std::runtime_error("Could not write to file " + path);
    }
    delete file;
    delete oa;
    delete stream;
}

void LoadState(std::string path) {
    InitMem();
    size_t buffer_size=FileUtil::GetSize(path) - sizeof(CSTHeader);
    FileUtil::IOFile *file=new FileUtil::IOFile(path, "rb");
    // load header
    CSTHeader header;
    if (file->ReadBytes(&header, sizeof(header)) != sizeof(header)) {
        printf("Could not read from file at %s ", path.c_str());
    }
    if (file->ReadBytes((size_t *)save_addr, buffer_size) != buffer_size) {
        printf("Could not read from file at %s", path.c_str());
    }
    // decompress
    const std::size_t decompressed_size =
        ZSTD_getFrameContentSize((void *)save_addr, buffer_size);
    const std::size_t uncompressed_result_size = ZSTD_decompress(
        (void *)save_addr2, decompressed_size, (void *)save_addr, buffer_size);
    printf("Load State\n");
    // Deserialize
    boost::iostreams::stream<boost::iostreams::basic_array_source<char>> stream(reinterpret_cast<char*>(save_addr2), decompressed_size);
    boost::archive::binary_iarchive *ia = new boost::archive::binary_iarchive{stream};
    *ia&* &System::GetInstance();
    delete ia;
    delete file;
}

void CleanState() {
    vm_deallocate(mach_task_self(), save_addr2, size2);
    vm_deallocate(mach_task_self(), save_addr, size);
    save_addr2=0;
    save_addr=0;
}

} // namespace Core
