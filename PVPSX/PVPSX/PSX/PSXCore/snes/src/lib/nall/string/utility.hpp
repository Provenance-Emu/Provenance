#ifndef NALL_STRING_UTILITY_HPP
#define NALL_STRING_UTILITY_HPP

size_t nall_strlcpy(nall_v059::string &dest, const char *src, size_t length) {
  dest.reserve(length);
  return nall_strlcpy(dest(), src, length);
}

size_t nall_strlcat(nall_v059::string &dest, const char *src, size_t length) {
  dest.reserve(length);
  return nall_strlcat(dest(), src, length);
}

nall_v059::string substr(const char *src, size_t start, size_t length) {
  nall_v059::string dest;
  if(length == 0) {
    //copy entire string
    dest = src + start;
  } else {
    //copy partial string
    nall_strlcpy(dest, src + start, length + 1);
  }
  return dest;
}

/* very simplistic wrappers to return nall_v059::string& instead of char* type */

nall_v059::string& strlower(nall_v059::string &str) { strlower(str()); return str; }
nall_v059::string& strupper(nall_v059::string &str) { strupper(str()); return str; }
nall_v059::string& strtr(nall_v059::string &dest, const char *before, const char *after) { strtr(dest(), before, after); return dest; }
nall_v059::string& ltrim(nall_v059::string &str, const char *key) { ltrim(str(), key); return str; }
nall_v059::string& rtrim(nall_v059::string &str, const char *key) { rtrim(str(), key); return str; }
nall_v059::string& trim (nall_v059::string &str, const char *key) { trim (str(), key); return str; }
nall_v059::string& ltrim_once(nall_v059::string &str, const char *key) { ltrim_once(str(), key); return str; }
nall_v059::string& rtrim_once(nall_v059::string &str, const char *key) { rtrim_once(str(), key); return str; }
nall_v059::string& trim_once (nall_v059::string &str, const char *key) { trim_once (str(), key); return str; }

/* arithmetic <> string */

nall_v059::string strhex(uintmax_t value) {
  nall_v059::string temp;
  temp.reserve(strhex(0, value));
  strhex(temp(), value);
  return temp;
}

nall_v059::string strsigned(intmax_t value) {
  nall_v059::string temp;
  temp.reserve(strsigned(0, value));
  strsigned(temp(), value);
  return temp;
}

nall_v059::string strunsigned(uintmax_t value) {
  nall_v059::string temp;
  temp.reserve(strunsigned(0, value));
  strunsigned(temp(), value);
  return temp;
}

nall_v059::string strbin(uintmax_t value) {
  nall_v059::string temp;
  temp.reserve(strbin(0, value));
  strbin(temp(), value);
  return temp;
}

nall_v059::string strdouble(double value) {
  nall_v059::string temp;
  temp.reserve(strdouble(0, value));
  strdouble(temp(), value);
  return temp;
}

#endif
