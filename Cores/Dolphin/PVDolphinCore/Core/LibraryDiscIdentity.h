#pragma once
#include "DiscIO/Enums.h"
#include <optional>
#include <string>

namespace PVLibraryIdentity {
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
    if (gameID.empty() || !revision) {
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
