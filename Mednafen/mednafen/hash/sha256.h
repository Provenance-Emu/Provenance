#ifndef __MDFN_SHA256_H
#define __MDFN_SHA256_H

#include <array>

typedef std::array<uint8, 32> sha256_digest;

void sha256_test(void);
sha256_digest sha256(const void* data, const uint64 len);

static INLINE constexpr uint8 sha256_cton(char c)
{
 return ((c >= 'A' && c <= 'F') ? c - 'A' + 0xa : ((c >= 'a' && c <= 'f') ? c - 'a' + 0xa : c - '0'));
};

static INLINE constexpr uint8 sha256_cton2(char c, char d)
{
 return (sha256_cton(c) << 4) | (sha256_cton(d) << 0);
};

static INLINE constexpr sha256_digest operator "" _sha256(const char *s, std::size_t sz)
{
 //static_assert(sz == 65, "Malformed SHA-256 string.");
 return /*(sz == 65 ? (void)0 : abort()),*/ sha256_digest({{ sha256_cton2(s[0], s[1]), sha256_cton2(s[2], s[3]), sha256_cton2(s[4], s[5]), sha256_cton2(s[6], s[7]),
		      sha256_cton2(s[8], s[9]), sha256_cton2(s[10], s[11]), sha256_cton2(s[12], s[13]), sha256_cton2(s[14], s[15]),
		      sha256_cton2(s[16], s[17]), sha256_cton2(s[18], s[19]), sha256_cton2(s[20], s[21]), sha256_cton2(s[22], s[23]),
		      sha256_cton2(s[24], s[25]), sha256_cton2(s[26], s[27]), sha256_cton2(s[28], s[29]), sha256_cton2(s[30], s[31]),
		      sha256_cton2(s[32], s[33]), sha256_cton2(s[34], s[35]), sha256_cton2(s[36], s[37]), sha256_cton2(s[38], s[39]),
		      sha256_cton2(s[40], s[41]), sha256_cton2(s[42], s[43]), sha256_cton2(s[44], s[45]), sha256_cton2(s[46], s[47]),
		      sha256_cton2(s[48], s[49]), sha256_cton2(s[50], s[51]), sha256_cton2(s[52], s[53]), sha256_cton2(s[54], s[55]),
		      sha256_cton2(s[56], s[57]), sha256_cton2(s[58], s[59]), sha256_cton2(s[60], s[61]), sha256_cton2(s[62], s[63]), }
		    });
}


#endif
