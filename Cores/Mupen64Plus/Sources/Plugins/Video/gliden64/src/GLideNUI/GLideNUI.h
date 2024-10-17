#ifndef GLIDENUII_H
#define GLIDENUII_H

#if defined(__cplusplus)
extern "C" {
#endif

#ifdef OS_WINDOWS
#define EXPORT	__declspec(dllexport)
#define CALL		__cdecl
#else
#define EXPORT 	__attribute__((visibility("default")))
#define CALL
#endif

EXPORT bool CALL RunConfig(const wchar_t * _strFileName, const char * _romName);
EXPORT int CALL RunAbout(const wchar_t * _strFileName);
EXPORT void CALL LoadConfig(const wchar_t * _strFileName);
EXPORT void CALL LoadCustomRomSettings(const wchar_t * _strFileName, const char * _romName);
EXPORT void CALL SaveScreenshot(const wchar_t * _folder, const char * _name, int _width, int _height, const unsigned char * _data);

#if defined(__cplusplus)
}
#endif

#endif // GLIDENUII_H
