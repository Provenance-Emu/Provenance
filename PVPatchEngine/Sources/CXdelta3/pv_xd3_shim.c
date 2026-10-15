//
//  pv_xd3_shim.c
//  PVPatchEngine
//
//  C facade over the vendored xdelta3 decoder. See cxdelta3.h.
//

#include "cxdelta3.h"

#include <stdlib.h>
#include <string.h>
#include <zlib.h>

#include "xdelta3.h"

struct pv_xd3 {
    xd3_stream stream;
    xd3_config config;
    xd3_source source;
};

pv_xd3 *pv_xd3_create(uint32_t source_block_size, uint64_t source_size, int ignore_checksum)
{
    pv_xd3 *decoder = calloc(1, sizeof(pv_xd3));
    if (decoder == NULL) {
        return NULL;
    }
    xd3_init_config(&decoder->config, ignore_checksum ? XD3_ADLER32_NOVER : 0);
    if (xd3_config_stream(&decoder->stream, &decoder->config) != 0) {
        free(decoder);
        return NULL;
    }
    decoder->source.blksize = source_block_size;
    if (xd3_set_source_and_size(&decoder->stream, &decoder->source, source_size) != 0) {
        xd3_free_stream(&decoder->stream);
        free(decoder);
        return NULL;
    }
    return decoder;
}

void pv_xd3_destroy(pv_xd3 *decoder)
{
    if (decoder == NULL) {
        return;
    }
    xd3_free_stream(&decoder->stream);
    free(decoder);
}

void pv_xd3_provide_input(pv_xd3 *decoder, const uint8_t *data, size_t length, int is_last)
{
    if (is_last) {
        xd3_set_flags(&decoder->stream, decoder->stream.flags | XD3_FLUSH);
    }
    xd3_avail_input(&decoder->stream, data, (usize_t)length);
}

int pv_xd3_step(pv_xd3 *decoder)
{
    switch (xd3_decode_input(&decoder->stream)) {
    case XD3_INPUT:
        return PV_XD3_NEED_INPUT;
    case XD3_OUTPUT:
        return PV_XD3_OUTPUT;
    case XD3_GETSRCBLK:
        return PV_XD3_NEED_SOURCE_BLOCK;
    case XD3_GOTHEADER:
        return PV_XD3_GOT_HEADER;
    case XD3_WINSTART:
    case XD3_WINFINISH:
        return PV_XD3_PROGRESS;
    default:
        break;
    }
    const char *message = decoder->stream.msg;
    if (message != NULL) {
        if (strstr(message, "checksum mismatch") != NULL) {
            return PV_XD3_ERROR_CHECKSUM;
        }
        if (strstr(message, "secondary compressor") != NULL) {
            return PV_XD3_ERROR_SECONDARY;
        }
    }
    return PV_XD3_ERROR;
}

const uint8_t *pv_xd3_output(const pv_xd3 *decoder, size_t *length)
{
    *length = decoder->stream.avail_out;
    return decoder->stream.next_out;
}

void pv_xd3_consume_output(pv_xd3 *decoder)
{
    xd3_consume_output(&decoder->stream);
}

uint64_t pv_xd3_wanted_block(const pv_xd3 *decoder)
{
    return decoder->source.getblkno;
}

void pv_xd3_provide_block(pv_xd3 *decoder, const uint8_t *data, uint32_t length)
{
    decoder->source.curblk = data;
    decoder->source.onblk = length;
    decoder->source.curblkno = decoder->source.getblkno;
}

int pv_xd3_finish(pv_xd3 *decoder)
{
    return xd3_close_stream(&decoder->stream);
}

const char *pv_xd3_message(const pv_xd3 *decoder)
{
    return decoder->stream.msg != NULL ? decoder->stream.msg : "unknown xdelta3 error";
}

void pv_xd3_checksums(const pv_xd3 *decoder, uint32_t *expected, uint32_t *actual)
{
    *expected = decoder->stream.dec_adler32;
    *actual = (uint32_t)adler32(1L, decoder->stream.next_out, (uInt)decoder->stream.avail_out);
}

uint32_t pv_crc32(uint32_t crc, const uint8_t *data, size_t length)
{
    uLong value = crc;
    while (length > 0) {
        uInt chunk = length > 0x40000000u ? 0x40000000u : (uInt)length;
        value = crc32(value, data, chunk);
        data += chunk;
        length -= chunk;
    }
    return (uint32_t)value;
}
