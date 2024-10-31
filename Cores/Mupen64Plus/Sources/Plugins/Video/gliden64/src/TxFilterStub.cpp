#include "GLideNHQ/Ext_TxFilter.h"

TAPI boolean TAPIENTRY
txfilter_init(int maxwidth, int maxheight, int maxbpp, int options, int cachesize,
	const wchar_t *txCachePath, const wchar_t *txDumpPath, const wchar_t * texPackPath,
	const wchar_t* ident, dispInfoFuncExt callback)
{
	return 0;
}

TAPI void TAPIENTRY
txfilter_shutdown(void) 
{}

TAPI boolean TAPIENTRY
txfilter_filter(uint8 *src, int srcwidth, int srcheight, uint16 srcformat,
		 uint64 g64crc, GHQTexInfo *info)
{
	return 0;
}

TAPI boolean TAPIENTRY
txfilter_hirestex(uint64 g64crc, uint64 r_crc64, uint16 *palette, GHQTexInfo *info)
{
	return 0;
}

TAPI uint64 TAPIENTRY
txfilter_checksum(uint8 *src, int width, int height, int size, int rowStride, uint8 *palette)
{
	return 0U;
}

TAPI boolean TAPIENTRY
txfilter_dmptx(uint8 *src, int width, int height, int rowStridePixel, uint16 gfmt, uint16 n64fmt, uint64 r_crc64)
{
	return 0;
}

TAPI boolean TAPIENTRY
txfilter_reloadhirestex()
{
	return 0;
}

TAPI void TAPIENTRY
txfilter_dumpcache(void)
{}
