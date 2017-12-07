/*
 *   Copyright (c) 2015 - 2017 Kulykov Oleh <info@resident.name>
 *
 *   Permission is hereby granted, free of charge, to any person obtaining a copy
 *   of this software and associated documentation files (the "Software"), to deal
 *   in the Software without restriction, including without limitation the rights
 *   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *   copies of the Software, and to permit persons to whom the Software is
 *   furnished to do so, subject to the following conditions:
 *
 *   The above copyright notice and this permission notice shall be included in
 *   all copies or substantial portions of the Software.
 *
 *   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 *   THE SOFTWARE.
 */


#include "LzmaSDKObjCTypes.h"

/**
 @brief Compress non-empty buffer object with LZMA2.
 @warning First byte of the return data is LZMA2 properties.
 @warning Input buffer should be less or equal to 4Gb.
 @param dataForCompress Non-empty buffer to compress.
 @param compressionRatio Compression ratio in range [0.0f; 1.0f]
 @return Compressed data or nil on error.
 */
LZMASDKOBJC_EXTERN NSData * _Nullable LzmaSDKObjCBufferCompressLZMA2(NSData * _Nonnull dataForCompress, const float compressionRatio);


/**
 @brief Decompress non-empty buffer object compressed with LZMA2 and have first byte as properties.
 @warning First byte of input data should be is LZMA2 properties.
 @warning Input buffer should be less or equal to 4Gb.
 @param dataForDecompress Non-empty compressed buffer.
 @return Decompressed data or nil on error.
 */
LZMASDKOBJC_EXTERN NSData * _Nullable LzmaSDKObjCBufferDecompressLZMA2(NSData * _Nonnull dataForDecompress);
