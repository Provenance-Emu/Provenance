/*
 *   Copyright (c) 2015 - 2020 Oleh Kulykov <olehkulykov@gmail.com>
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


#import <Foundation/Foundation.h>

#include "LzmaSDKObjCBufferProcessor.h"

#include "../lzma/C/Lzma2Enc.h"
#include "../lzma/C/Lzma2Dec.h"
#include "../lzma/C/LzmaEnc.h"
#include "../lzma/C/LzmaDec.h"

static void * LzmaSDKObjCBufferProcessorAlloc(size_t size) {
    return (size > 0) ? malloc(size) : NULL;
}

static void LzmaSDKObjCBufferProcessorFree(void *address) {
    if (address) {
        free(address);
    }
}

static void * LzmaSDKObjCBufferProcessorSzAlloc(ISzAllocPtr p, size_t size) {
    return LzmaSDKObjCBufferProcessorAlloc(size);
}

static void LzmaSDKObjCBufferProcessorSzFree(ISzAllocPtr p, void * address) {
    LzmaSDKObjCBufferProcessorFree(address);
}

typedef struct _LzmaSDKObjCBufferProcessorReader final : ISeqInStream {
	const unsigned char * data;
	unsigned int dataSize;
	unsigned int offset;
} LzmaSDKObjCBufferProcessorReader;

typedef struct _LzmaSDKObjCBufferProcessorWriter final : ISeqOutStream {
	__strong NSMutableData * data;
} LzmaSDKObjCBufferProcessorWriter;


static size_t LzmaSDKObjCBufferProcessorWrite(const ISeqOutStream * pp, const void * data, size_t size) {
	LzmaSDKObjCBufferProcessorWriter * p = (LzmaSDKObjCBufferProcessorWriter *)pp;
	[p->data appendBytes:data length:size];
	return size;
}

static SRes LzmaSDKObjCBufferProcessorRead(const ISeqInStream * pp, void * data, size_t * size) {
	LzmaSDKObjCBufferProcessorReader * p = (LzmaSDKObjCBufferProcessorReader *)pp;
	size_t sizeToRead = *size;
	size_t avaiableSize = p->dataSize - p->offset;
	if (avaiableSize < sizeToRead) sizeToRead = avaiableSize;
	memcpy(data, &p->data[p->offset], sizeToRead);
	p->offset += sizeToRead;
	*size = sizeToRead;
	return SZ_OK;
}

NSData * _Nullable LzmaSDKObjCBufferCompressLZMA2(NSData * _Nonnull dataForCompress, const float compressionRatio) {
	if (!dataForCompress) return nil;
	const unsigned char * data = (const unsigned char *)[dataForCompress bytes];
	const unsigned int dataSize = (unsigned int)[dataForCompress length];
	if (!data || dataSize <= LZMA_PROPS_SIZE) return nil;

	ISzAlloc localAlloc = { LzmaSDKObjCBufferProcessorSzAlloc, LzmaSDKObjCBufferProcessorSzFree };

	CLzma2EncHandle handle = Lzma2Enc_Create(&localAlloc, &localAlloc);
	if (!handle) return nil;

	CLzma2EncProps props;
	Lzma2EncProps_Init(&props);
	props.lzmaProps.writeEndMark = 1;
	props.lzmaProps.numThreads = 1;
	props.numTotalThreads = 1;

	if (compressionRatio < 0.0f) props.lzmaProps.level = 0;
	else if (compressionRatio > 1.0f) props.lzmaProps.level = 9;
	else props.lzmaProps.level = compressionRatio * 9.0f;

	SRes res = Lzma2Enc_SetProps(handle, &props);
	if (res != SZ_OK) return nil;
	const Byte properties = Lzma2Enc_WriteProperties(handle);

	LzmaSDKObjCBufferProcessorWriter outStream;
	memset(&outStream, 0, sizeof(LzmaSDKObjCBufferProcessorWriter));
	outStream.data = [NSMutableData dataWithCapacity:dataSize / 4];
	[outStream.data appendBytes:&properties length:sizeof(Byte)];
	outStream.Write = LzmaSDKObjCBufferProcessorWrite;

	LzmaSDKObjCBufferProcessorReader inStream;
	memset(&inStream, 0, sizeof(LzmaSDKObjCBufferProcessorReader));
	inStream.data = data;
	inStream.dataSize = dataSize;
	inStream.Read = LzmaSDKObjCBufferProcessorRead;

    res = Lzma2Enc_Encode2(handle,
                           (ISeqOutStream *)&outStream,
                           NULL,
                           NULL,
                           (ISeqInStream *)&inStream,
                           NULL,
                           0,
                           NULL);

	Lzma2Enc_Destroy(handle);
	return [outStream.data length] > sizeof(Byte) ? outStream.data : nil;
}

NSData * _Nullable LzmaSDKObjCBufferCompressLZMA(NSData * _Nonnull dataForCompress, int lc, int lp, int pb, UInt32 dictSize) {
    if (!dataForCompress) return nil;
    const unsigned char * data = (const unsigned char *)[dataForCompress bytes];
    const unsigned int dataSize = (unsigned int)[dataForCompress length];

    ISzAlloc localAlloc = { LzmaSDKObjCBufferProcessorSzAlloc, LzmaSDKObjCBufferProcessorSzFree };

    CLzmaEncHandle handle = LzmaEnc_Create(&localAlloc);
    if (!handle) return nil;

    CLzmaEncProps props;
    LzmaEncProps_Init(&props);
    props.lc = lc;
    props.lp = lp;
    props.pb = pb;
    props.dictSize = dictSize;

    SRes res = LzmaEnc_SetProps(handle, &props);
    if (res != SZ_OK) return nil;

    Byte header[LZMA_PROPS_SIZE + 8];
    size_t headerSize = LZMA_PROPS_SIZE;
    UInt64 fileSize;
    res = LzmaEnc_WriteProperties(handle, header, &headerSize);
    for (int i = 0; i < 8; i++) header[headerSize++] = (Byte)((unsigned long long)dataSize >> (8 * i));

    LzmaSDKObjCBufferProcessorWriter outStream;
    memset(&outStream, 0, sizeof(LzmaSDKObjCBufferProcessorWriter));
    outStream.data = [NSMutableData dataWithCapacity:dataSize / 4];
    [outStream.data appendBytes:&header length:headerSize];
    outStream.Write = LzmaSDKObjCBufferProcessorWrite;

    LzmaSDKObjCBufferProcessorReader inStream;
    memset(&inStream, 0, sizeof(LzmaSDKObjCBufferProcessorReader));
    inStream.data = data;
    inStream.dataSize = dataSize;
    inStream.Read = LzmaSDKObjCBufferProcessorRead;

    res = LzmaEnc_Encode(handle,
                   (ISeqOutStream *)&outStream,
                   (ISeqInStream *)&inStream,
                   NULL,
                   &localAlloc,
                   &localAlloc);

    LzmaEnc_Destroy(handle, &localAlloc, &localAlloc);
    return [outStream.data length] > sizeof(Byte) ? outStream.data : nil;
}

NSData * _Nullable LzmaSDKObjCBufferDecompressLZMA2(NSData * _Nonnull dataForDecompress) {
	if (!dataForDecompress) return nil;
	const unsigned char * data = (const unsigned char *)[dataForDecompress bytes];
	const unsigned int dataSize = (unsigned int)[dataForDecompress length];
	if (!data || dataSize <= sizeof(Byte)) return nil;

	CLzma2Dec dec;
	Lzma2Dec_Construct(&dec);

	const Byte * inData = data;
	SizeT inSize = dataSize;
	const Byte properties = *(inData);
	inData++;
	inSize--;

	ISzAlloc localAlloc = { LzmaSDKObjCBufferProcessorSzAlloc, LzmaSDKObjCBufferProcessorSzFree };

	SRes res = Lzma2Dec_AllocateProbs(&dec, properties, &localAlloc);
	if (res != SZ_OK) return nil;

	res = Lzma2Dec_Allocate(&dec, properties, &localAlloc);
	if (res != SZ_OK) return nil;

	Lzma2Dec_Init(&dec);

	NSMutableData * outData = [NSMutableData dataWithCapacity:dataSize];
	Byte dstBuff[10240];
	while ((inSize > 0) && (res == SZ_OK)) {
		ELzmaStatus status = LZMA_STATUS_NOT_SPECIFIED;
		SizeT dstSize = 10240;
		SizeT srcSize = inSize;

		res = Lzma2Dec_DecodeToBuf(&dec,
								   dstBuff,
								   &dstSize,
								   inData,
								   &srcSize,
								   LZMA_FINISH_ANY,
								   &status);
		if ((inSize >= srcSize) && (res == SZ_OK)) {
			inData += srcSize;
			inSize -= srcSize;
			[outData appendBytes:dstBuff length:dstSize];
		} else {
			break;
		}
	}

	Lzma2Dec_FreeProbs(&dec, &localAlloc);
	Lzma2Dec_Free(&dec, &localAlloc);

	return [outData length] > 0 ? outData : nil;
}

NSData * _Nullable LzmaSDKObjCBufferDecompressLZMA(NSData * _Nonnull dataForDecompress) {
    if (!dataForDecompress) return nil;
    const unsigned char * data = (const unsigned char *)[dataForDecompress bytes];
    const unsigned int dataSize = (unsigned int)[dataForDecompress length];
    if (!data || dataSize <= LZMA_PROPS_SIZE + 8) return nil;

    CLzmaDec dec;
    LzmaDec_Construct(&dec);

    const Byte * inData = data;
    SizeT inSize = dataSize;
    const Byte * properties = inData;
    inData += LZMA_PROPS_SIZE + 8;
    inSize -= LZMA_PROPS_SIZE + 8;

    ISzAlloc localAlloc = { LzmaSDKObjCBufferProcessorSzAlloc, LzmaSDKObjCBufferProcessorSzFree };

    SRes res = LzmaDec_AllocateProbs(&dec, properties, LZMA_PROPS_SIZE, &localAlloc);
    if (res != SZ_OK) return nil;

    res = LzmaDec_Allocate(&dec, properties, LZMA_PROPS_SIZE, &localAlloc);
    if (res != SZ_OK) return nil;

    LzmaDec_Init(&dec);

    NSMutableData * outData = [NSMutableData dataWithCapacity:dataSize];
    Byte dstBuff[10240];
    while ((inSize > 0) && (res == SZ_OK)) {
        ELzmaStatus status = LZMA_STATUS_NOT_SPECIFIED;
        SizeT dstSize = 10240;
        SizeT srcSize = inSize;

        res = LzmaDec_DecodeToBuf(&dec,
                                  dstBuff,
                                  &dstSize,
                                  inData,
                                  &srcSize,
                                  LZMA_FINISH_ANY,
                                  &status);
        if ((inSize >= srcSize) && (res == SZ_OK)) {
            inData += srcSize;
            inSize -= srcSize;
            [outData appendBytes:dstBuff length:dstSize];
        } else {
            break;
        }
    }

    LzmaDec_FreeProbs(&dec, &localAlloc);
    LzmaDec_Free(&dec, &localAlloc);

    return [outData length] > 0 ? outData : nil;
}
