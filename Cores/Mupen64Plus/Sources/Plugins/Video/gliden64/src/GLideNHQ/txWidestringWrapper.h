#ifndef ___TXWIDESCREENWRAPPER_H__
#define ___TXWIDESCREENWRAPPER_H__

#include <string>
#include <algorithm>

#ifdef OS_ANDROID

int tx_swprintf(wchar_t* ws, size_t len, const wchar_t* format, ...);
bool wccmp(const wchar_t* w1, const wchar_t* w2);

#define BUF_SIZE 2048

class tx_wstring {
public:
	tx_wstring() {}
	tx_wstring(const wchar_t * wstr);
	tx_wstring(const tx_wstring & other);
	void assign(const wchar_t * wstr);
	void assign(const tx_wstring & wstr);
	void append(const tx_wstring & wstr);
	tx_wstring & operator=(const tx_wstring & other);
	tx_wstring & operator+=(const tx_wstring & other);
	tx_wstring & operator+=(const wchar_t * wstr);
	tx_wstring operator+(const tx_wstring & wstr) const;
	tx_wstring operator+(const wchar_t * wstr) const;
	const wchar_t * c_str() const;
	bool empty() const;
	int compare(const wchar_t * wstr);

private:
	std::wstring _wstring;
	std::string _astring;
	char cbuf[BUF_SIZE];
	wchar_t wbuf[BUF_SIZE];
};

class dummyWString
{
public:
	dummyWString(const char * _str);

	const wchar_t * c_str() const {
		return _wstr.c_str();
	}

private:
	std::wstring _wstr;
};

#define wst(A) dummyWString(A).c_str()

#define removeColon(A)
#else

#define tx_wstring std::wstring
#define tx_swprintf	swprintf
#define wst(A) L##A
#define wccmp(A, B) A[0] == B[0]
inline
void removeColon(tx_wstring& _s)
{
	std::replace(_s.begin(), _s.end(), L':', L'-');
}

#endif // OS_ANDROID

#endif // ___TXWIDESCREENWRAPPER_H__
