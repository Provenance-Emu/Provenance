/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

#ifdef UNZIP_SUPPORT

#include <assert.h>
#include <ctype.h>
#ifdef SYSTEM_ZIP
#include <minizip/unzip.h>
#else
#include "unzip/unzip.h"
#endif
#include "snes9x.h"
#include "memmap.h"


bool8 LoadZip (const char *zipname, uint32 *TotalFileSize, uint8 *buffer)
{
	*TotalFileSize = 0;

	unzFile	file = unzOpen(zipname);
	if (file == NULL)
		return (FALSE);

	// find largest file in zip file (under MAX_ROM_SIZE) or a file with extension .1, or a file named program.rom
	char	filename[132];
	uint32	filesize = 0;
	int		port = unzGoToFirstFile(file);

	unz_file_info	info;

	while (port == UNZ_OK)
	{
		char	name[132];
		unzGetCurrentFileInfo(file, &info, name, 128, NULL, 0, NULL, 0);

		if (info.uncompressed_size > CMemory::MAX_ROM_SIZE + 512)
		{
			port = unzGoToNextFile(file);
			continue;
		}

		if (info.uncompressed_size > filesize)
		{
			strcpy(filename, name);
			filesize = info.uncompressed_size;
		}

		int	len = strlen(name);
		if (len > 2 && name[len - 2] == '.' && name[len - 1] == '1')
		{
			strcpy(filename, name);
			filesize = info.uncompressed_size;
			break;
		}

		if (strncasecmp(name, "program.rom", 11) == 0)
		{
			strcpy(filename, name);
			filesize = info.uncompressed_size;
			break;
		}

		port = unzGoToNextFile(file);
	}

	int len = strlen(zipname);
	if (!(port == UNZ_END_OF_LIST_OF_FILE || port == UNZ_OK) || filesize == 0 ||
		(len > 5 && strcasecmp(zipname + len - 5, ".msu1") == 0 && strcasecmp(filename, "program.rom") != 0))
	{
		if (unzClose(file) != UNZ_OK)
			assert(FALSE);
		return (FALSE);
	}

	// find extension
	char	tmp[2] = { 0, 0 };
	char	*ext = strrchr(filename, '.');
	if (ext)
		ext++;
	else
		ext = tmp;

	uint8	*ptr = buffer;
	bool8	more = FALSE;

	unzLocateFile(file, filename, 0);
	unzGetCurrentFileInfo(file, &info, filename, 128, NULL, 0, NULL, 0);

	if (unzOpenCurrentFile(file) != UNZ_OK)
	{
		unzClose(file);
		return (FALSE);
	}

	do
	{
		assert(info.uncompressed_size <= CMemory::MAX_ROM_SIZE + 512);

		uint32 FileSize = info.uncompressed_size;
		int	l = unzReadCurrentFile(file, ptr, FileSize);

		if (unzCloseCurrentFile(file) == UNZ_CRCERROR)
		{
			unzClose(file);
			return (FALSE);
		}

		if (l <= 0 || l != (int) FileSize)
		{
			unzClose(file);
			return (FALSE);
		}

		FileSize = Memory.HeaderRemove(FileSize, ptr);
		ptr += FileSize;
		*TotalFileSize += FileSize;

		int	len;

		if (ptr - Memory.ROM < CMemory::MAX_ROM_SIZE + 512 && (isdigit(ext[0]) && ext[1] == 0 && ext[0] < '9'))
		{
			more = TRUE;
			ext[0]++;
		}
		else
		if (ptr - Memory.ROM < CMemory::MAX_ROM_SIZE + 512)
		{
			if (ext == tmp)
				len = strlen(filename);
			else
				len = ext - filename - 1;

			if ((len == 7 || len == 8) && strncasecmp(filename, "sf", 2) == 0 &&
				isdigit(filename[2]) && isdigit(filename[3]) && isdigit(filename[4]) &&
				isdigit(filename[5]) && isalpha(filename[len - 1]))
			{
				more = TRUE;
				filename[len - 1]++;
			}
		}
		else
			more = FALSE;

		if (more)
		{
			if (unzLocateFile(file, filename, 0) != UNZ_OK ||
				unzGetCurrentFileInfo(file, &info, filename, 128, NULL, 0, NULL, 0) != UNZ_OK ||
				unzOpenCurrentFile(file) != UNZ_OK)
				break;
		}
	} while (more);

	unzClose(file);

	return (TRUE);
}

#endif
