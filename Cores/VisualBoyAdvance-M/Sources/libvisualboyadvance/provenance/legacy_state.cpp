// Provenance glue: see legacy_state.h.

#include "legacy_state.h"

#include <cstdio>
#include <cstring>
#include <unistd.h>
#include <zlib.h>

#include "core/base/system.h"
#include "core/gba/gba.h"
#include "core/gba/gbaCheats.h"

namespace pvvba {
namespace {

// Cheat slots in a 1.8-era state (`CheatsData cheatsList[100]`).
constexpr size_t kLegacyCheatSlots = 100;
// Bytes the cheat block grew by between the 1.8 and 2.x layouts.
constexpr size_t kLegacyCheatGrowth = (MAX_CHEATS - kLegacyCheatSlots) * sizeof(CheatsData);
// Bytes of the 2.x cheat block: cheatsNumber, then cheatsList.
constexpr size_t kCheatBlockSize = sizeof(int) + MAX_CHEATS * sizeof(CheatsData);
// Upper bound on what follows the cheat block (RTC, plus the GBA Matrix
// mapper for >32 MB carts); bounds the layout probe.
constexpr size_t kTailSearchWindow = 1024;
// Marker written as `cheatsNumber` while probing the current layout.
constexpr int kCheatsNumberProbe = 0x5EC7A1E5;

bool GunzipFile(const std::string& path, std::vector<uint8_t>& out) {
    gzFile in = gzopen(path.c_str(), "rb");
    if (!in) {
        return false;
    }
    out.clear();
    uint8_t chunk[64 * 1024];
    int n;
    while ((n = gzread(in, chunk, sizeof(chunk))) > 0) {
        out.insert(out.end(), chunk, chunk + n);
    }
    gzclose(in);
    return n == 0;
}

bool GzipFile(const std::string& path, const std::vector<uint8_t>& data) {
    gzFile out = gzopen(path.c_str(), "wb");
    if (!out) {
        return false;
    }
    const int written = gzwrite(out, data.data(), (unsigned)data.size());
    const int closed = gzclose(out);
    return written == (int)data.size() && closed == Z_OK;
}

std::string TempPath(const std::string& directory, const char* tag) {
    static unsigned counter = 0;
    char name[96];
    snprintf(name, sizeof(name), "/pvvba-%s-%d-%u.sgm", tag, (int)getpid(), counter++);
    return directory + name;
}

// Measures the running game's current state layout: its uncompressed length
// and how many bytes follow the cheat block. Writes a throwaway state with a
// marker in `cheatsNumber` and finds the marker near the end.
bool ProbeLayout(const std::string& scratchDirectory, size_t& length, size_t& tailLength) {
    const std::string probePath = TempPath(scratchDirectory, "probe");
    const int savedCheatsNumber = cheatsNumber;
    cheatsNumber = kCheatsNumberProbe;
    const bool wrote = CPUWriteState(probePath.c_str());
    cheatsNumber = savedCheatsNumber;

    std::vector<uint8_t> probe;
    const bool read = wrote && GunzipFile(probePath, probe);
    unlink(probePath.c_str());
    if (!read) {
        return false;
    }

    for (size_t tail = 0; tail <= kTailSearchWindow && tail + kCheatBlockSize <= probe.size(); tail++) {
        int marker = 0;
        memcpy(&marker, probe.data() + probe.size() - tail - kCheatBlockSize, sizeof(marker));
        if (marker == kCheatsNumberProbe) {
            length = probe.size();
            tailLength = tail;
            return true;
        }
    }
    return false;
}

}  // namespace

bool UpgradeLegacyState(std::vector<uint8_t>& data, size_t currentLength, size_t tailLength) {
    if (data.size() + kLegacyCheatGrowth != currentLength || data.size() < tailLength) {
        return false;
    }
    data.insert(data.end() - (std::ptrdiff_t)tailLength, kLegacyCheatGrowth, (uint8_t)0);
    return true;
}

StateLoadResult LoadState(const std::string& path, const std::string& scratchDirectory) {
    std::vector<uint8_t> state;
    size_t currentLength = 0;
    size_t tailLength = 0;
    if (!GunzipFile(path, state) || !ProbeLayout(scratchDirectory, currentLength, tailLength)) {
        return StateLoadResult::ReadFailed;
    }

    if (state.size() == currentLength) {
        return CPUReadState(path.c_str()) ? StateLoadResult::Loaded : StateLoadResult::CoreRejected;
    }

    if (!UpgradeLegacyState(state, currentLength, tailLength)) {
        log("Save state is %zu bytes uncompressed; expected %zu (2.x) or %zu (1.8)\n",
            state.size(), currentLength, currentLength - kLegacyCheatGrowth);
        return StateLoadResult::Incompatible;
    }

    const std::string upgradedPath = TempPath(scratchDirectory, "upgraded");
    const bool loaded = GzipFile(upgradedPath, state) && CPUReadState(upgradedPath.c_str());
    unlink(upgradedPath.c_str());
    return loaded ? StateLoadResult::LoadedLegacy : StateLoadResult::CoreRejected;
}

}  // namespace pvvba
