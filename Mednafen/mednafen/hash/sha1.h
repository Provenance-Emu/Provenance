#ifndef __MDFN_SHA1_H
#define __MDFN_SHA1_H

#include <array>
#include <string>

typedef std::array<uint8, 20> sha1_digest;

#if 0
class sha1_context
{
 public:
 sha1_context();

 void update(const void* data, const uint64 len);

 sha1_digest finish(void);

 private:
};

static INLINE sha1_digest sha1(const void* data, const uint64 len)
{
 sha1_context ctx;

 ctx.update(data, len);

 return ctx.finish();
}
#endif

void sha1_test(void);
sha1_digest sha1(const void* data, const uint64 len);

static INLINE constexpr uint8 sha1_cton(char c)
{
 return ((c >= 'A' && c <= 'F') ? c - 'A' + 0xa : ((c >= 'a' && c <= 'f') ? c - 'a' + 0xa : c - '0'));
};

static INLINE constexpr uint8 sha1_cton2(char c, char d)
{
 return (sha1_cton(c) << 4) | (sha1_cton(d) << 0);
};

static INLINE constexpr sha1_digest operator "" _sha1(const char *s, std::size_t sz)
{
 //static_assert(sz == 41, "Malformed SHA-1 string.");
 return /*(sz == 41 ? (void)0 : abort()),*/ sha1_digest({{ sha1_cton2(s[0], s[1]), sha1_cton2(s[2], s[3]), sha1_cton2(s[4], s[5]), sha1_cton2(s[6], s[7]),
		      sha1_cton2(s[8], s[9]), sha1_cton2(s[10], s[11]), sha1_cton2(s[12], s[13]), sha1_cton2(s[14], s[15]),
		      sha1_cton2(s[16], s[17]), sha1_cton2(s[18], s[19]), sha1_cton2(s[20], s[21]), sha1_cton2(s[22], s[23]),
		      sha1_cton2(s[24], s[25]), sha1_cton2(s[26], s[27]), sha1_cton2(s[28], s[29]), sha1_cton2(s[30], s[31]),
		      sha1_cton2(s[32], s[33]), sha1_cton2(s[34], s[35]), sha1_cton2(s[36], s[37]), sha1_cton2(s[38], s[39])
		    }});
}


#endif
