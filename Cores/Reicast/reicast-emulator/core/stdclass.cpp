#include <string.h>
#include <vector>
#include <sys/stat.h>
#include "types.h"

#if BUILD_COMPILER==COMPILER_VC
	#include <io.h>
	#define access _access
	#define R_OK   4
#else
	#include <unistd.h>
#endif

#include "hw/mem/_vmem.h"

string user_config_dir;
string user_data_dir;
std::vector<string> system_config_dirs;
std::vector<string> system_data_dirs;

bool file_exists(const string& filename)
{
	return (access(filename.c_str(), R_OK) == 0);
}

void set_user_config_dir(const string& dir)
{
	user_config_dir = dir;
}

void set_user_data_dir(const string& dir)
{
	user_data_dir = dir;
}

void add_system_config_dir(const string& dir)
{
	system_config_dirs.push_back(dir);
}

void add_system_data_dir(const string& dir)
{
	system_data_dirs.push_back(dir);
}

string get_writable_config_path(const string& filename)
{
	/* Only stuff in the user_config_dir is supposed to be writable,
	 * so we always return that.
	 */
	return (user_config_dir + filename);
}

string get_readonly_config_path(const string& filename)
{
	string user_filepath = get_writable_config_path(filename);
	if(file_exists(user_filepath))
	{
		return user_filepath;
	}

	string filepath;
	for (unsigned int i = 0; i < system_config_dirs.size(); i++) {
		filepath = system_config_dirs[i] + filename;
		if (file_exists(filepath))
		{
			return filepath;
		}
	}

	// Not found, so we return the user variant
	return user_filepath;
}

string get_writable_data_path(const string& filename)
{
	/* Only stuff in the user_data_dir is supposed to be writable,
	 * so we always return that.
	 */
	return (user_data_dir + filename);
}

string get_readonly_data_path(const string& filename)
{
	string user_filepath = get_writable_data_path(filename);
	if(file_exists(user_filepath))
	{
		return user_filepath;
	}

	string filepath;
	for (unsigned int i = 0; i < system_data_dirs.size(); i++) {
		filepath = system_data_dirs[i] + filename;
		if (file_exists(filepath))
		{
			return filepath;
		}
	}

	// Not found, so we return the user variant
	return user_filepath;
}


#if 0
//File Enumeration
void FindAllFiles(FileFoundCB* callback,wchar* dir,void* param)
{
	WIN32_FIND_DATA FindFileData;
	HANDLE hFind = INVALID_HANDLE_VALUE;
	wchar DirSpec[MAX_PATH + 1];  // directory specification
	DWORD dwError;

	strncpy (DirSpec, dir, strlen(dir)+1);
	//strncat (DirSpec, "\\*", 3);
	
	hFind = FindFirstFile( DirSpec, &FindFileData);

	if (hFind == INVALID_HANDLE_VALUE) 
	{
		return;
	} 
	else 
	{

		if ((FindFileData.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)==0)
		{
			callback(FindFileData.cFileName,param);
		}
u32 rv;
		while ( (rv=FindNextFile(hFind, &FindFileData)) != 0) 
		{ 
			if ((FindFileData.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)==0)
			{
				callback(FindFileData.cFileName,param);
			}
		}
		dwError = GetLastError();
		FindClose(hFind);
		if (dwError != ERROR_NO_MORE_FILES) 
		{
			return ;
		}
	}
	return ;
}
#endif

/*
#include "dc\sh4\rec_v1\compiledblock.h"
#include "dc\sh4\rec_v1\blockmanager.h"

bool VramLockedWrite(u8* address);
bool RamLockedWrite(u8* address,u32* sp);

*/