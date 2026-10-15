//
//  cxdelta3.h
//  PVPatchEngine
//
//  Small C facade over the vendored xdelta3 decoder. Swift drives the decode loop
//  (input, output and source-block I/O) and never sees the xd3_* types.
//

#ifndef CXDELTA3_H
#define CXDELTA3_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct pv_xd3 pv_xd3;

/// Result of one `pv_xd3_step` call.
/// Provide more patch bytes with `pv_xd3_provide_input`.
#define PV_XD3_NEED_INPUT 1
/// Output is ready: `pv_xd3_output`, then `pv_xd3_consume_output`.
#define PV_XD3_OUTPUT 2
/// Provide block `pv_xd3_wanted_block` with `pv_xd3_provide_block`.
#define PV_XD3_NEED_SOURCE_BLOCK 3
/// The VCDIFF file header was parsed.
#define PV_XD3_GOT_HEADER 4
/// A window started or finished; just step again.
#define PV_XD3_PROGRESS 5
/// Invalid or corrupt input; see `pv_xd3_message`.
#define PV_XD3_ERROR (-1)
/// Target window adler32 mismatch; see `pv_xd3_checksums`.
#define PV_XD3_ERROR_CHECKSUM (-2)
/// Secondary compressor not built in.
#define PV_XD3_ERROR_SECONDARY (-3)

/// `source_block_size` must be a power of two. `ignore_checksum` disables the per-window adler32 check.
pv_xd3 *pv_xd3_create(uint32_t source_block_size, uint64_t source_size, int ignore_checksum);
void pv_xd3_destroy(pv_xd3 *decoder);

/// The buffer must stay valid until the next `PV_XD3_NEED_INPUT`.
void pv_xd3_provide_input(pv_xd3 *decoder, const uint8_t *data, size_t length, int is_last);
int pv_xd3_step(pv_xd3 *decoder);

const uint8_t *pv_xd3_output(const pv_xd3 *decoder, size_t *length);
void pv_xd3_consume_output(pv_xd3 *decoder);

uint64_t pv_xd3_wanted_block(const pv_xd3 *decoder);
/// `data` must stay valid until a different block is provided or the decoder is destroyed.
void pv_xd3_provide_block(pv_xd3 *decoder, const uint8_t *data, uint32_t length);

/// Returns non-zero when the stream ended in the middle of a window.
int pv_xd3_finish(pv_xd3 *decoder);
const char *pv_xd3_message(const pv_xd3 *decoder);
/// Expected (from the patch) and actual adler32 of the window that failed verification.
void pv_xd3_checksums(const pv_xd3 *decoder, uint32_t *expected, uint32_t *actual);

/// zlib CRC-32 (fast in unoptimised builds too).
uint32_t pv_crc32(uint32_t crc, const uint8_t *data, size_t length);

#ifdef __cplusplus
}
#endif

#endif
