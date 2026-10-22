// Owned synthetic byte containers, not runnable games or signed WADs.
#include "LibraryDiscIdentity.h"
#include <cassert>
#include <filesystem>
#include <fstream>
#include <vector>

struct FileReader {
    std::ifstream stream;
    uint64_t size;
    explicit FileReader(const std::filesystem::path& path) : stream(path, std::ios::binary), size(std::filesystem::file_size(path)) {}
    uint64_t GetDataSize() const { return size; }
    bool Read(uint64_t offset, uint64_t count, uint8_t* out) {
        stream.clear();
        stream.seekg(offset);
        stream.read(reinterpret_cast<char*>(out), count);
        return stream.gcount() == static_cast<std::streamsize>(count);
    }
};
void Set32(std::vector<uint8_t>& bytes, size_t offset, uint32_t value) {
    for (int i = 3; i >= 0; --i) { bytes[offset + i] = value & 0xff; value >>= 8; }
}
bool Check(const std::filesystem::path& path, const std::vector<uint8_t>& bytes, bool inflatedSize = false) {
    { std::ofstream file(path, std::ios::binary); file.write(reinterpret_cast<const char*>(bytes.data()), bytes.size()); }
    FileReader reader(path);
    if (inflatedSize) reader.size = 0x100000; // bounds alone must not admit a short read
    return PVLibraryIdentity::HasReadableIdentityBytes(reader);
}
int main(int argc, char** argv) {
    assert(argc == 2);
    auto path = std::filesystem::path(argv[1]) / "identity-container.bin";
    std::vector<uint8_t> wad(0x40 + 0x1e4);
    Set32(wad, 0, 0x20);
    Set32(wad, 4, 0x49730000);
    Set32(wad, 0x14, 0x1e4);
    Set32(wad, 0x40, 0x00010001); // RSA2048 signature type; no valid cryptographic signature
    Set32(wad, 0x40 + 0x18c, 0x00010001);
    std::copy_n("TEST", 4, wad.begin() + 0x40 + 0x190);
    std::copy_n("01", 2, wad.begin() + 0x40 + 0x198); // readable title-ID/group prefix
    wad[0x40 + 0x1dd] = 7;
    assert(Check(path, wad)); // byte-read preflight only; not a valid ROM/WAD assertion
    wad[0x40 + 0x1dd] = 0;
    assert(Check(path, wad)); // a fully observed zero revision is valid
    std::vector<uint8_t> padded(0x340 + 0x1e4);
    std::copy_n(wad.begin(), 0x20, padded.begin());
    Set32(padded, 8, 17);
    Set32(padded, 0x10, 0x2a4);
    std::copy(wad.begin() + 0x40, wad.end(), padded.begin() + 0x340);
    assert(Check(path, padded)); // each preceding section is independently 64-byte aligned
    wad.resize(0x40 + 0x19a); // entire ID prefix survives, EOF before title_version
    assert(!Check(path, wad));
    assert(!Check(path, wad, true)); // exact-read rejects despite reported size
    Set32(wad, 0x14, 0xffffffff);
    assert(!Check(path, wad, true)); // malformed declared size cannot allocate gigabytes
    Set32(wad, 0x14, 0x1e4);
    Set32(wad, 0x10, 0xffffffff);
    assert(!Check(path, wad, true)); // malformed prefix offset/size
    std::vector<uint8_t> disc(0x20);
    Set32(disc, 0x1c, 0xc2339f3d);
    assert(!Check(path, disc)); // readable blank GC header
    std::fill(disc.begin(), disc.begin() + 6, ' ');
    assert(!Check(path, disc));
    std::fill(disc.begin(), disc.begin() + 6, '0');
    assert(!Check(path, disc));
    std::copy_n("GNHE5d", 6, disc.begin());
    assert(Check(path, disc));
    Set32(disc, 0x1c, 0);
    Set32(disc, 0x18, 0x5d1c9ea3);
    assert(Check(path, disc));
    disc[2] = 0xff;
    assert(!Check(path, disc));
    std::filesystem::remove(path);
}
