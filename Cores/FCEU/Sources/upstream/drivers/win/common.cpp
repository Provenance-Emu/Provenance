#include "common.h"

bool directoryExists(const char* dirname)
{
	DWORD res = GetFileAttributes(dirname);
	return res != 0xFFFFFFFF && res & FILE_ATTRIBUTE_DIRECTORY;
}

void WindowBoundsCheckResize(int &windowPosX, int &windowPosY, int windowSizeX, long windowRight)
{
		if (windowRight < 59) {
		windowPosX = 59 - windowSizeX;
		}
		if (windowPosY < -18) {
		windowPosY = -18;
		} 
}

void WindowBoundsCheckNoResize(int &windowPosX, int &windowPosY, long windowRight)
{
		if (windowRight < 59) {
		windowPosX = 0;
		}

		if (windowPosY < -18) {
		windowPosY = -18;
		} 
}

int recalculateResizedItemCoordinate(int initialValue, int initialBase, int newBase, unsigned int resizingType)
{
	switch (resizingType)
	{
		default:
		case WINDOW_ITEM_RESIZE_TYPE_LEFT_ALIGNED:
		{
			return initialValue;
		}
		case WINDOW_ITEM_RESIZE_TYPE_RIGHT_ALIGNED:
		{
			return newBase - (initialBase - initialValue);
		}
		case WINDOW_ITEM_RESIZE_TYPE_CENTER_ALIGNED:
		{
			return initialValue + (newBase - initialBase) / 2;
		}
		case WINDOW_ITEM_RESIZE_TYPE_MULTIPLY:
		{
			return (newBase * initialValue) / initialBase;
			break;
		}
	}
}

// Check if a filename/path has the given extension. The extension is expected to be at the very end of the filename
void AddExtensionIfMissing(char * name, unsigned int maxsize, const char * extension)
{
	std::string tempName = name;
	
	// Non-null terminated lengths of both strings, +1 for null termination
	if ((strlen(name) + strlen(extension) + 1) <= maxsize)
	{
		unsigned int x = tempName.rfind(extension);

		// x == -1 means the extension string wasn't found
		// if the extension was found in the middle of the string, this doesn't count as extension
		if ((x == -1) || ((x + strlen(extension)) < tempName.size()))
		{
			tempName.append(extension);
			strcpy(name, tempName.c_str());
		}
	}
}
// Overloaded operator of above, which deals with native std::string variants.
void AddExtensionIfMissing(std::string &name, const char * extension)
{
	unsigned int x = name.rfind(extension);

	if ((x == -1) || ((x + strlen(extension)) < name.size()))
		name.append(extension);
}

std::string GetPath(std::string filename)
{
	return filename.substr(0, filename.find_last_of("/\\") + 1);
}

bool IsRelativePath(char* name)
{
	if (name[0] == '.')
		if (name[1] == '\\') return true;
		else if (name[1] == '.' && name[2] == '\\') return true;
	return false;
}

bool IsRelativePath(const char* name)
{
	if (name[0] == '.')
		if (name[1] == '\\') return true;
		else if (name[1] == '.' && name[2] == '\\') return true;
	return false;
}

bool IsRelativePath(std::string name)
{
	if (name[0] == '.')
		if (name[1] == '\\') return true;
		else if (name[1] == '.' && name[2] == '\\') return true;
	return false;
}

//Precondition: IsRelativePath() == true
std::string ConvertRelativePath(std::string name)
{
	extern std::string BaseDirectory;
	return BaseDirectory + '\\' + name.substr(2, name.length());
}