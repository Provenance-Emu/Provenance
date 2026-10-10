// Provenance replacement for VBA-M's core/base/file_util_desktop.cpp.
//
// Upstream's desktop file layer opens every ROM/BIOS through `fex` (the
// 7z/RAR/zip archive library under src/core/fex). Provenance's importer hands
// the core an already-extracted ROM, and the vendored 1.8 core this replaces
// had likewise swapped `fex` out for a plain fopen() (OpenEmu port). So this
// file keeps upstream's public API (core/base/file_util.h, non-libretro
// branch) and its gzip helpers verbatim, and only `utilLoad`/`utilFindType`
// read plain files instead of scanning archives.
//
// When bumping the submodule, diff this against
// visualboyadvance-m/src/core/base/file_util_desktop.cpp.

#include "core/base/file_util.h"

#if defined(__LIBRETRO__)
#error "This file is only for non-libretro builds"
#endif

#include <cstdlib>
#include <cstring>
#include <strings.h>

#include "core/base/internal/memgzio.h"
#include "core/base/message.h"

#define MAX_CART_SIZE 0x8000000  // 128MB

namespace {

bool utilIsGzipFile(const char* file) {
    if (strlen(file) > 3) {
        const char* p = strrchr(file, '.');

        if (p != NULL) {
            if (strcasecmp(p, ".gz") == 0)
                return true;
            if (strcasecmp(p, ".z") == 0)
                return true;
        }
    }

    return false;
}

int utilGetSize(int size) {
    int res = 1;
    while (res < size)
        res <<= 1;
    return res;
}

int(ZEXPORT* utilGzWriteFunc)(gzFile, const voidp, unsigned int) = NULL;
int(ZEXPORT* utilGzReadFunc)(gzFile, voidp, unsigned int) = NULL;
int(ZEXPORT* utilGzCloseFunc)(gzFile) = NULL;
z_off_t(ZEXPORT* utilGzSeekFunc)(gzFile, z_off_t, int) = NULL;

}  // namespace

uint8_t* utilLoad(const char* file, bool (*accept)(const char*), uint8_t* data, int& size) {
    // `accept` only filters archive members upstream. It is still called for
    // its side effect: utilIsGBAImage() sets coreOptions.cpuIsMultiBoot for
    // `.mb` images. Its verdict is ignored so a ROM with an unexpected
    // extension still loads, as it did with the vendored core.
    if (accept)
        (void)accept(file);

    FILE* fp = utilOpenFile(file, "rb");
    if (!fp) {
        systemMessage(MSG_CANNOT_OPEN_FILE, N_("Cannot open file %s"), file);
        return NULL;
    }

    fseek(fp, 0, SEEK_END);
    long fileSizeLong = ftell(fp);
    fseek(fp, 0, SEEK_SET);

    if (fileSizeLong <= 0 || fileSizeLong > MAX_CART_SIZE) {
        fclose(fp);
        systemMessage(MSG_ERROR_READING_IMAGE, N_("Error reading image from %s: %s"), file, "bad size");
        return NULL;
    }

    int fileSize = (int)fileSizeLong;
    if (size == 0)
        size = fileSize;

    if (size > MAX_CART_SIZE) {
        fclose(fp);
        return NULL;
    }

    uint8_t* image = data;

    if (image == NULL) {
        // allocate buffer memory if none was passed to the function
        image = (uint8_t*)malloc(utilGetSize(size));
        if (image == NULL) {
            fclose(fp);
            systemMessage(MSG_OUT_OF_MEMORY, N_("Failed to allocate memory for %s"), "data");
            return NULL;
        }
        size = fileSize;
    }

    // Read image
    int read = fileSize <= size ? fileSize : size;  // do not read beyond file
    size_t got = fread(image, 1, (size_t)read, fp);
    fclose(fp);

    if (got != (size_t)read) {
        systemMessage(MSG_ERROR_READING_IMAGE, N_("Error reading image from %s: %s"), file, "short read");
        if (data == NULL)
            free(image);
        return NULL;
    }

    size = fileSize;

    return image;
}

IMAGE_TYPE utilFindType(const char* file) {
    if (utilIsGBAImage(file))
        return IMAGE_GBA;
    if (utilIsGBImage(file))
        return IMAGE_GB;
    return IMAGE_UNKNOWN;
}

void utilStripDoubleExtension(const char* file, char* buffer, size_t len) {
    (void)len;
    if (buffer != file)  // allows conversion in place
        strcpy(buffer, file);

    if (utilIsGzipFile(file)) {
        char* p = strrchr(buffer, '.');

        if (p)
            *p = 0;
    }
}

gzFile utilAutoGzOpen(const char* file, const char* mode) {
    return gzopen(file, mode);
}

gzFile utilGzOpen(const char* file, const char* mode) {
    utilGzWriteFunc = (int(ZEXPORT*)(gzFile, void* const, unsigned int))gzwrite;
    utilGzReadFunc = gzread;
    utilGzCloseFunc = gzclose;
    utilGzSeekFunc = gzseek;

    return utilAutoGzOpen(file, mode);
}

gzFile utilMemGzOpen(char* memory, int available, const char* mode) {
    utilGzWriteFunc = memgzwrite;
    utilGzReadFunc = memgzread;
    utilGzCloseFunc = memgzclose;
    utilGzSeekFunc = memgzseek;

    return memgzopen(memory, available, mode);
}

int utilGzWrite(gzFile file, const voidp buffer, unsigned int len) {
    return utilGzWriteFunc(file, buffer, len);
}

int utilGzRead(gzFile file, voidp buffer, unsigned int len) {
    return utilGzReadFunc(file, buffer, len);
}

int utilGzClose(gzFile file) {
    return utilGzCloseFunc(file);
}

z_off_t utilGzSeek(gzFile file, z_off_t offset, int whence) {
    return utilGzSeekFunc(file, offset, whence);
}

long utilGzMemTell(gzFile file) {
    return memtell(file);
}

void utilWriteData(gzFile gzFile, variable_desc* data) {
    while (data->address) {
        utilGzWrite(gzFile, data->address, data->size);
        data++;
    }
}

void utilReadData(gzFile gzFile, variable_desc* data) {
    while (data->address) {
        utilGzRead(gzFile, data->address, data->size);
        data++;
    }
}

void utilReadDataSkip(gzFile gzFile, variable_desc* data) {
    while (data->address) {
        utilGzSeek(gzFile, data->size, SEEK_CUR);
        data++;
    }
}

int utilReadInt(gzFile gzFile) {
    int i = 0;
    utilGzRead(gzFile, &i, sizeof(int));
    return i;
}

void utilWriteInt(gzFile gzFile, int i) {
    utilGzWrite(gzFile, &i, sizeof(int));
}
