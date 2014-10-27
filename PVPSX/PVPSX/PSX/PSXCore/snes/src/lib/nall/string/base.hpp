#ifndef NALL_STRING_BASE_HPP
#define NALL_STRING_BASE_HPP

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <nall/stdint.hpp>
#include <nall/utf8.hpp>
#include <nall/vector.hpp>

inline char chrlower(char c);
inline char chrupper(char c);
inline int stricmp(const char *dest, const char *src);
inline int strpos (const char *str, const char *key);
inline int qstrpos(const char *str, const char *key);
inline bool strbegin (const char *str, const char *key);
inline bool stribegin(const char *str, const char *key);
inline bool strend (const char *str, const char *key);
inline bool striend(const char *str, const char *key);
inline char* strlower(char *str);
inline char* strupper(char *str);
inline char* strtr(char *dest, const char *before, const char *after);
inline uintmax_t strhex     (const char *str);
inline intmax_t  strsigned  (const char *str);
inline uintmax_t strunsigned(const char *str);
inline uintmax_t strbin     (const char *str);
inline double    strdouble  (const char *str);
inline size_t strhex     (char *str, uintmax_t value, size_t length = 0);
inline size_t strsigned  (char *str, intmax_t  value, size_t length = 0);
inline size_t strunsigned(char *str, uintmax_t value, size_t length = 0);
inline size_t strbin     (char *str, uintmax_t value, size_t length = 0);
inline size_t strdouble  (char *str, double    value, size_t length = 0);
inline bool match(const char *pattern, const char *str);
inline bool strint (const char *str, int &result);
inline bool strmath(const char *str, int &result);
inline size_t nall_strlcpy(char *dest, const char *src, size_t length);
inline size_t nall_strlcat(char *dest, const char *src, size_t length);
inline char* ltrim(char *str, const char *key = " ");
inline char* rtrim(char *str, const char *key = " ");
inline char* trim (char *str, const char *key = " ");
inline char* ltrim_once(char *str, const char *key = " ");
inline char* rtrim_once(char *str, const char *key = " ");
inline char* trim_once (char *str, const char *key = " ");

namespace nall_v059 {
  class string;
  template<typename T> inline string to_string(T);

  class string {
  public:
    static string printf(const char*, ...);

    inline void reserve(size_t);
    inline unsigned length() const;

    inline string& assign(const char*);
    inline string& append(const char*);
    template<typename T> inline string& operator= (T value);
    template<typename T> inline string& operator<<(T value);

    inline operator const char*() const;
    inline char* operator()();
    inline char& operator[](int);

    inline bool operator==(const char*) const;
    inline bool operator!=(const char*) const;
    inline bool operator< (const char*) const;
    inline bool operator<=(const char*) const;
    inline bool operator> (const char*) const;
    inline bool operator>=(const char*) const;

    inline string();
    inline string(const char*);
    inline string(const string&);
    inline string& operator=(const string&);
    inline ~string();

    inline bool readfile(const char*);
    inline string& replace (const char*, const char*);
    inline string& qreplace(const char*, const char*);

  protected:
    char *data;
    size_t size;

  #if defined(QT_CORE_LIB)
  public:
    inline operator QString() const;
  #endif
  };

  class lstring : public vector<string> {
  public:
    template<typename T> inline lstring& operator<<(T value);

    inline int find(const char*);
    inline void split (const char*, const char*, unsigned = 0);
    inline void qsplit(const char*, const char*, unsigned = 0);
  };
};

inline size_t nall_strlcpy(nall_v059::string &dest, const char *src, size_t length);
inline size_t nall_strlcat(nall_v059::string &dest, const char *src, size_t length);
inline nall_v059::string& strlower(nall_v059::string &str);
inline nall_v059::string& strupper(nall_v059::string &str);
inline nall_v059::string& strtr(nall_v059::string &dest, const char *before, const char *after);
inline nall_v059::string& ltrim(nall_v059::string &str, const char *key = " ");
inline nall_v059::string& rtrim(nall_v059::string &str, const char *key = " ");
inline nall_v059::string& trim (nall_v059::string &str, const char *key = " ");
inline nall_v059::string& ltrim_once(nall_v059::string &str, const char *key = " ");
inline nall_v059::string& rtrim_once(nall_v059::string &str, const char *key = " ");
inline nall_v059::string& trim_once (nall_v059::string &str, const char *key = " ");

inline nall_v059::string substr(const char *src, size_t start = 0, size_t length = 0);
inline nall_v059::string strhex     (uintmax_t value);
inline nall_v059::string strsigned  (intmax_t  value);
inline nall_v059::string strunsigned(uintmax_t value);
inline nall_v059::string strbin     (uintmax_t value);
inline nall_v059::string strdouble  (double    value);

#endif
