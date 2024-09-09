#include <tamtypes.h>
#include <kernel.h>
#include <sifrpc.h>
#include <stdarg.h>
#include <sifcmd.h>
#include <loadfile.h>
#include <fileio.h>
#include "../ee/cdvd_rpc.h"


void dump_directory(char *path)
{
	int fd;

	fd=	fioDopen(path);
	if (fd >= 0)
	{
		struct fio_dirent dirent __attribute__((aligned(64)));

		printf("Directory Listing: %s\n", path);

		while (fioDread(fd, &dirent) > 0)
		{
			printf("%02X %08X %08X: %s\n", dirent.fileAttributes, dirent.fileAddress, dirent.fileSize, dirent.fileName);
		}
		fioDclose(fd);
	}
}


int main()
{
	int ret;
	int entry;
	int num_entries;

	int filehandle;
	int filesize;

	struct TocEntry myTocEntries[128];
	static char pathname[1024];

	static char buffer[1024];

	init_scr();

	SifInitRpc(0);

	printf("About to load CDVD.IRX\n");

	ret = SifLoadModule("host:../lib/cdvd.irx", 0, NULL);
	if (ret < 0)
	{

		ret = SifLoadModule("host:cdvd.irx", 0, NULL);
		if (ret < 0)
		{
			printf("Failed to load module!\n");
			SleepThread();
		}
	}

	printf("About to call init CDVD RPC\n\n");
	CDVD_Init();

	printf("About to get all root directory entries:\n\n");

	// Get upto 128 entries from the root
    strcpy(pathname,"/");
	num_entries = CDVD_getdir(pathname, NULL, CDVD_GET_FILES_AND_DIRS, myTocEntries, 128, pathname);

	printf("Retrieved %d directory entries\n\n",num_entries);

	for (entry = 0;entry<num_entries;entry++)
	{
		if (myTocEntries[entry].fileProperties & 0x02)
		{
			printf("Dir name: %s\tLBA = %d\tSize = %d\n",
				myTocEntries[entry].filename,
				myTocEntries[entry].fileLBA,
				myTocEntries[entry].fileSize);
		}
		else
		{
			printf("Filename: %s\tLBA = %d\tSize = %d\n",
				myTocEntries[entry].filename,
				myTocEntries[entry].fileLBA,
				myTocEntries[entry].fileSize);
		}
	}

	printf("\nAbout to get ELF and IRX files only from root directory:\n\n");

	// Get only elf and irx entries from the root
    strcpy(pathname,"/");
	num_entries = CDVD_getdir(pathname, ".IRX .ELF", CDVD_GET_FILES_ONLY, myTocEntries, 128, pathname);

	printf("Retrieved %d TOC Entries\n\n",num_entries);

	for (entry = 0;entry<num_entries;entry++)
	{
		if (myTocEntries[entry].fileProperties & 0x02)
		{
			printf("Dir name: %s\tLBA = %d\tSize = %d\n",
				myTocEntries[entry].filename,
				myTocEntries[entry].fileLBA,
				myTocEntries[entry].fileSize);
		}
		else
		{
			printf("Filename: %s\tLBA = %d\tSize = %d\n",
				myTocEntries[entry].filename,
				myTocEntries[entry].fileLBA,
				myTocEntries[entry].fileSize);
		}
	}


	printf("\nAbout to find SYSTEM.CNF using CDVD_FindFile\n");

	num_entries = CDVD_FindFile("/SYSTEM.CNF",&myTocEntries[0]);
	printf("\nRetrieved %d TOC Entries\n\n",num_entries);

	if(num_entries > 0)
	{
		if (myTocEntries[0].fileProperties & 0x02)
		{
			printf("Dir name: %s\tLBA = %d\tSize = %d\n",
				myTocEntries[0].filename,
				myTocEntries[0].fileLBA,
				myTocEntries[0].fileSize);
		}
		else
		{
			printf("Filename: %s\tLBA = %d\tSize = %d\n",
				myTocEntries[0].filename,
				myTocEntries[0].fileLBA,
				myTocEntries[0].fileSize);
		}
	}

	printf("\nAbout to load SYSTEM.CNF\n\n");

	// open the file
	filehandle = fioOpen("cdfs:/SYSTEM.CNF",O_RDONLY);
	// find the end of it
	filesize = fioLseek(filehandle, 0, SEEK_END);
	// move back to the beginning
	fioLseek(filehandle, 0, SEEK_SET);
	// read the file
	fioRead(filehandle, buffer, filesize);
	// close the file
	fioClose(filehandle);

	printf("Contents of SYSTEM.CNF:\n\n%s\n",buffer);


	dump_directory("cdfs:/");
	dump_directory("host:/");
//	dump_directory("mc0:/");


	printf("Stopping CDVD\n");
	CDVD_Stop();

	SleepThread();
}
