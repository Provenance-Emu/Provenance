#ifndef WST_H
#define WST_H

#include <cstdlib>

#ifdef OS_ANDROID
static
void gln_wcscat(wchar_t* destination, const wchar_t* source)
{
	const u32 bufSize = 512;
	char cbuf[bufSize];
	wcstombs(cbuf, destination, bufSize);
	std::string dest(cbuf);
	wcstombs(cbuf, source, bufSize);
	dest.append(cbuf);
	mbstowcs(destination, dest.c_str(), PLUGIN_PATH_SIZE);
}

class dummyWString
{
public:
	dummyWString(const char * _str)
	{
		wchar_t buf[512];
		mbstowcs(buf, _str, 512);
		_wstr.assign(buf);
	}

	const wchar_t * c_str() const {
		return _wstr.c_str();
	}

private:
	std::wstring _wstr;
};

#define wst(A) dummyWString(A).c_str()
#else // OS_ANDROID
#define gln_wcscat wcscat
#define wst(A) L##A
#endif // OS_ANDROID

#endif // WST_H
