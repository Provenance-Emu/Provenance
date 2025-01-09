
//#include <windows.h>
#include <stdio.h>
#include <string.h>
#include "types.h"
#include "surface.h"
#include "bmpfile.h"

typedef Uint8 BYTE;
typedef Uint16 WORD;
typedef Uint32 DWORD;
typedef Int32 LONG;

#define BI_RGB        0L
#define BI_RLE8       1L
#define BI_RLE4       2L
#define BI_BITFIELDS  3L

typedef struct tagBITMAPFILEHEADER {
        WORD    bfType;
        WORD    bfSizeLo;
        WORD    bfSizeHi;
        WORD    bfReserved1;
        WORD    bfReserved2;
        WORD    bfOffBitsLo;
        WORD    bfOffBitsHi;
} BITMAPFILEHEADER;


typedef struct tagBITMAPINFOHEADER{
        DWORD      biSize;
        LONG       biWidth;
        LONG       biHeight;
        WORD       biPlanes;
        WORD       biBitCount;
        DWORD      biCompression;
        DWORD      biSizeImage;
        LONG       biXPelsPerMeter;
        LONG       biYPelsPerMeter;
        DWORD      biClrUsed;
        DWORD      biClrImportant;
} BITMAPINFOHEADER;

typedef struct tagRGBQUAD {
        BYTE    rgbBlue;
        BYTE    rgbGreen;
        BYTE    rgbRed;
        BYTE    rgbReserved;
} RGBQUAD;


Bool BMPWriteFile(Char *pFileName, CSurface *pSurface, PaletteT *pPalette)
{
	FILE *pFile;
	BITMAPFILEHEADER hdr;
	BITMAPINFOHEADER info;
	PixelFormatT *pFormat;
	Int32 iLine;
	Uint32 size;

	// open file
	pFile = fopen(pFileName, "wb");
	if (!pFile)
	{
		return FALSE;
	}

	// write lines
	pSurface->Lock();

	// get surface format
	pFormat  = pSurface->GetFormat();

	// get surface palette
    if (!pFormat->bColorIndex) pPalette = NULL;

	// init header
	memset(&hdr, 0, sizeof(hdr));
	hdr.bfType = 0x4D42;

	// init bitmap info
	memset(&info, 0, sizeof(info));
	info.biSize		    = sizeof(info);
	info.biWidth		= pSurface->GetWidth();
	info.biHeight		= pSurface->GetHeight();
	info.biPlanes		= 1;
	info.biBitCount     = pFormat->uBitDepth;
	info.biCompression  = BI_RGB;
	info.biSizeImage    = pSurface->GetWidth() * pSurface->GetHeight() * pFormat->uBitDepth / 8;
	info.biXPelsPerMeter= 0;
	info.biYPelsPerMeter= 0;
	info.biClrUsed      = pPalette ? 256 : 0;
	info.biClrImportant = 0;

	// write stuff
	fwrite(&hdr, sizeof(hdr), 1, pFile);
	fwrite(&info, sizeof(info), 1, pFile);
	if (pPalette)
	{
		RGBQUAD rgb[256];
		Int32 iColor;
		for (iColor =0; iColor < 256; iColor++)
		{
			rgb[iColor].rgbBlue    = pPalette->Color[iColor].b;
			rgb[iColor].rgbRed     = pPalette->Color[iColor].r;
			rgb[iColor].rgbGreen   = pPalette->Color[iColor].g;
			rgb[iColor].rgbReserved= 0;
		}
		fwrite(rgb, sizeof(RGBQUAD), info.biClrUsed, pFile);
	}

	// store offset of bits
	size = ftell(pFile);
	hdr.bfOffBitsLo = size & 0xFFFF;
	hdr.bfOffBitsHi = (size >> 16) & 0xFFFF;

	for (iLine = pSurface->GetHeight() - 1; iLine >= 0; iLine--)
	{
		// write line
		fwrite(pSurface->GetLinePtr(iLine), pSurface->GetWidth(), pFormat->uBitDepth / 8, pFile);
	}
	pSurface->Unlock();

	// store file size
	size = ftell(pFile);
	hdr.bfSizeLo = size & 0xFFFF;
	hdr.bfSizeHi = (size >> 16) & 0xFFFF;

	// rewrite header
	fseek(pFile, 0, SEEK_SET);
	fwrite(&hdr, sizeof(hdr), 1, pFile);

	fclose(pFile);
	return TRUE;
}








Bool BMPReadFile(Char *pFileName, CSurface *pSurface)
{
	FILE *pFile;
	BITMAPFILEHEADER hdr;
	BITMAPINFOHEADER info;
	Int32 iLine;
	PixelFormatE eFormat;

	// open file
	pFile = fopen(pFileName, "rb");
	if (!pFile)
	{
		printf("BMP ERROR: Cannot open file\n");
		return FALSE;
	}

	// read header
	fread(&hdr, sizeof(hdr), 1, pFile);
	if (hdr.bfType!=0x4D42)
	{
		printf("BMP ERROR: Invalid file header\n");
		fclose(pFile);
		return FALSE;
	}

	// read bitmap info
	fread(&info, sizeof(info), 1, pFile);
	if (info.biSize != sizeof(info))
	{
		printf("BMP ERROR: Invalid file size\n");
		fclose(pFile);
		return FALSE;
	}

	if (info.biCompression != BI_RGB)
	{
		printf("BMP ERROR: unsupported compression\n");
		fclose(pFile);
		return FALSE;
	}

	switch (info.biBitCount)
	{
		case 8:  eFormat = PIXELFORMAT_CI8; break;
		case 16: eFormat = PIXELFORMAT_BGR565; break;
		case 24: eFormat = PIXELFORMAT_BGR8; break;
		case 32: eFormat = PIXELFORMAT_BGRA8; break;
		default:
			printf("BMP ERROR: unsupported bitdepth\n");
			fclose(pFile);
			return FALSE;
	} 

	// allocate surface
	pSurface->Alloc(info.biWidth, info.biHeight, PixelFormatGetByEnum(eFormat));

	// seek to bitmap data
	fseek(pFile, (hdr.bfOffBitsHi << 16) | hdr.bfOffBitsLo, SEEK_SET);

	// read lines
	pSurface->Lock();

	for (iLine = pSurface->GetHeight() - 1; iLine >= 0; iLine--)
	{
		Uint32 nBytes;

		nBytes = pSurface->GetWidth() * info.biBitCount / 8;

		// read line
		fread(pSurface->GetLinePtr(iLine), nBytes, 1, pFile);

		while (nBytes & 3)
		{
			fseek(pFile, 1, SEEK_CUR);
			nBytes++;
		}
	}

	pSurface->Unlock();

	fclose(pFile);
	return TRUE;
}














