#pragma once
#include "DiscIO/Enums.h"
#include "DiscIO/DiscUtils.h"
#include <algorithm>
#include <array>
#include <cstdint>
#include <optional>
#include <string>
#include <string_view>

namespace PVLibraryIdentity {
inline bool IsAlphanumericID(std::string_view id) {
    return id.size() == 6 && id != "000000" && std::all_of(id.begin(), id.end(), [](unsigned char c) {
        return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9');
    });
}

inline bool IsWADID(std::string_view id) {
    // TMDReader returns either six alphanumeric bytes or the observed 64-bit
    // title ID in hexadecimal. A zero title ID does not identify a title.
    return IsAlphanumericID(id) || (id.size() == 16 && id != "0000000000000000" &&
        std::all_of(id.begin(), id.end(), [](unsigned char c) {
            return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f');
        }));
}

// Validate decoded blob bytes before CreateVolume: VolumeWAD zero-initializes
// its declared TMD buffer and ignores short reads. Its optional revision alone
// therefore cannot establish that a revision was observed.
template <typename Reader> bool HasReadableIdentityBytes(Reader& reader) {
    std::array<uint8_t, 0x20> header{};
    if (!reader.Read(0, header.size(), header.data())) {
        return false;
    }
    const auto be32 = [](const uint8_t* bytes) -> uint32_t {
        return (uint32_t(bytes[0]) << 24) | (uint32_t(bytes[1]) << 16) |
            (uint32_t(bytes[2]) << 8) | uint32_t(bytes[3]);
    };
    if (be32(header.data() + 0x18) == DiscIO::WII_DISC_MAGIC ||
        be32(header.data() + 0x1c) == DiscIO::GAMECUBE_DISC_MAGIC) {
        return IsAlphanumericID({reinterpret_cast<const char*>(header.data()), 6});
    }
    const auto magic = be32(header.data() + 2);
    if (magic != 0x00204973 && magic != 0x00206962) {
        return false;
    }
    const uint64_t headerSize = be32(header.data());
    const uint64_t certSize = be32(header.data() + 8);
    const uint64_t ticketSize = be32(header.data() + 0x10);
    const uint64_t tmdSize = be32(header.data() + 0x14);
    // IOS::ES::IsValidTMDSize uses these format limits. Bound before any
    // parser allocation, not after VolumeWAD has allocated declared lengths.
    constexpr uint64_t minTMD = 0x1e4;
    constexpr uint64_t maxTMD = 0x49e4;
    if (headerSize != 0x20 || tmdSize < minTMD || tmdSize > maxTMD) {
        return false;
    }
    const auto align64 = [](uint64_t value) { return (value + 63) & ~uint64_t(63); };
    const uint64_t tmdOffset = align64(headerSize) + align64(certSize) + align64(ticketSize);
    // Conservative identity-reader budget for header/cert/ticket metadata.
    // Prevent a malformed large file from triggering multi-gigabyte parser
    // allocations; larger containers remain unresolved by this capability.
    constexpr uint64_t maxMetadataPrefix = 16 * 1024 * 1024;
    const uint64_t dataSize = reader.GetDataSize();
    if (tmdOffset > maxMetadataPrefix || tmdOffset > dataSize || tmdSize > dataSize - tmdOffset) {
        return false;
    }
    std::array<uint8_t, maxTMD> tmd{};
    return reader.Read(tmdOffset, tmdSize, tmd.data());
}
struct Identity {
    std::string gameID;
    unsigned char discNumber;
    unsigned short revision;
};
// Keep failed DiscIO reads optional. WAD has no disc-number field; its valid
// TMD supplies ID/revision and defines a single title (disc zero).
template <typename Volume> std::optional<Identity> Read(const Volume& volume) {
    const auto platform = volume.GetVolumeType();
    if (platform != DiscIO::Platform::GameCubeDisc && platform != DiscIO::Platform::WiiDisc &&
        platform != DiscIO::Platform::WiiWAD) {
        return std::nullopt;
    }
    const auto gameID = volume.GetGameID();
    const auto revision = volume.GetRevision();
    if (!revision || (platform == DiscIO::Platform::WiiWAD ? !IsWADID(gameID) : !IsAlphanumericID(gameID))) {
        return std::nullopt;
    }
    if (platform == DiscIO::Platform::WiiWAD) {
        return Identity{gameID, 0, *revision};
    }
    const auto disc = volume.GetDiscNumber();
    if (!disc) {
        return std::nullopt;
    }
    return Identity{gameID, *disc, *revision};
}
}
