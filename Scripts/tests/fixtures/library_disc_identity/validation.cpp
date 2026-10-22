// No ROM bytes: observed values at the DiscIO boundary, including failed reads.
#include "LibraryDiscIdentity.h"
#include <cassert>

struct ObservedVolume {
    DiscIO::Platform platform = DiscIO::Platform::GameCubeDisc;
    std::string id = "GTEST1";
    std::optional<unsigned char> disc = 0;
    std::optional<unsigned short> revision = 0;
    auto GetVolumeType() const { return platform; }
    auto GetGameID() const { return id; }
    auto GetDiscNumber() const { return disc; }
    auto GetRevision() const { return revision; }
};
int main() {
    ObservedVolume volume;
    auto first = PVLibraryIdentity::Read(volume);
    assert(first && first->gameID == "GTEST1" && first->discNumber == 0 && first->revision == 0);
    volume.disc = 1;
    volume.revision = 7;
    auto second = PVLibraryIdentity::Read(volume);
    assert(second && second->discNumber == 1 && second->revision == 7);
    volume.platform = DiscIO::Platform::WiiDisc;
    assert(PVLibraryIdentity::Read(volume)->revision == 7);
    volume.disc.reset();
    assert(!PVLibraryIdentity::Read(volume)); // unreadable/truncated disc header
    volume.disc = 0;
    volume.revision.reset();
    assert(!PVLibraryIdentity::Read(volume)); // unreadable revision must not become zero
    volume.revision = 0;
    volume.id.clear();
    assert(!PVLibraryIdentity::Read(volume)); // missing/homebrew ID stays unresolved
    volume.id = "GTEST1";
    volume.platform = DiscIO::Platform::ELFOrDOL;
    assert(!PVLibraryIdentity::Read(volume));
    volume.platform = DiscIO::Platform::Triforce;
    assert(!PVLibraryIdentity::Read(volume));
    volume.platform = DiscIO::Platform::WiiWAD;
    volume.disc.reset();
    volume.revision = 65535;
    auto wad = PVLibraryIdentity::Read(volume);
    assert(wad && wad->discNumber == 0 && wad->revision == 65535);
    volume.revision.reset();
    assert(!PVLibraryIdentity::Read(volume));
    volume.revision = 0;
    volume.id.clear();
    assert(!PVLibraryIdentity::Read(volume));
}
