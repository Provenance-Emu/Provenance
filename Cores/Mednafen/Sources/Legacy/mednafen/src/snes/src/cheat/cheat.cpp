#include <../base.hpp>

#define CHEAT_CPP
namespace bSNES_v059 {

Cheat cheat;

bool Cheat::enabled() const {
  return system_enabled;
}

void Cheat::enable(bool state) {
  system_enabled = state;
}

void Cheat::remove_read_patches(void)
{
 memset(bitmask, 0x00, sizeof(bitmask));
 resize(0); 
}

void Cheat::install_read_patch(const CheatCode& code)
{
 add(code);

 unsigned addr = code.addr;
 bitmask[addr >> 3] |= 1 << (addr & 7);
}


void Cheat::read(unsigned addr, uint8 &data) const {
  for(unsigned i = 0; i < size(); i++) {
    const CheatCode &code = operator[](i);

    if(addr == code.addr && (code.compare < 0 || data == code.compare)) {
      data = code.data;
      break;
    }
  }
}

Cheat::Cheat() {
  system_enabled = false;
  memset(bitmask, 0x00, sizeof(bitmask));
}

#if 0
//===============
//encode / decode
//===============

bool Cheat::decode(const char *s, unsigned &addr, uint8 &data, Type &type) {
  string t = s;
  strlower(t);

  #define ischr(n) ((n >= '0' && n <= '9') || (n >= 'a' && n <= 'f'))

  if(strlen(t) == 8 || (strlen(t) == 9 && t[6] == ':')) {
    //strip ':'
    if(strlen(t) == 9 && t[6] == ':') t = string() << substr(t, 0, 6) << substr(t, 7);
    //validate input
    for(unsigned i = 0; i < 8; i++) if(!ischr(t[i])) return false;

    type = ProActionReplay;
    unsigned r = strhex((const char*)t);
    addr = r >> 8;
    data = r & 0xff;
    return true;
  } else if(strlen(t) == 9 && t[4] == '-') {
    //strip '-'
    t = string() << substr(t, 0, 4) << substr(t, 5);
    //validate input
    for(unsigned i = 0; i < 8; i++) if(!ischr(t[i])) return false;

    type = GameGenie;
    strtr(t, "df4709156bc8a23e", "0123456789abcdef");
    unsigned r = strhex((const char*)t);
    //8421 8421 8421 8421 8421 8421
    //abcd efgh ijkl mnop qrst uvwx
    //ijkl qrst opab cduv wxef ghmn
    addr = (!!(r & 0x002000) << 23) | (!!(r & 0x001000) << 22)
         | (!!(r & 0x000800) << 21) | (!!(r & 0x000400) << 20)
         | (!!(r & 0x000020) << 19) | (!!(r & 0x000010) << 18)
         | (!!(r & 0x000008) << 17) | (!!(r & 0x000004) << 16)
         | (!!(r & 0x800000) << 15) | (!!(r & 0x400000) << 14)
         | (!!(r & 0x200000) << 13) | (!!(r & 0x100000) << 12)
         | (!!(r & 0x000002) << 11) | (!!(r & 0x000001) << 10)
         | (!!(r & 0x008000) <<  9) | (!!(r & 0x004000) <<  8)
         | (!!(r & 0x080000) <<  7) | (!!(r & 0x040000) <<  6)
         | (!!(r & 0x020000) <<  5) | (!!(r & 0x010000) <<  4)
         | (!!(r & 0x000200) <<  3) | (!!(r & 0x000100) <<  2)
         | (!!(r & 0x000080) <<  1) | (!!(r & 0x000040) <<  0);
    data = r >> 24;
    return true;
  } else {
    return false;
  }

  #undef ischr
}

bool Cheat::encode(string &s, unsigned addr, uint8 data, Type type) {
  char t[16];

  if(type == ProActionReplay) {
    sprintf(t, "%.6x%.2x", addr, data);
    s = t;
    return true;
  } else if(type == GameGenie) {
    unsigned r = addr;
    addr = (!!(r & 0x008000) << 23) | (!!(r & 0x004000) << 22)
         | (!!(r & 0x002000) << 21) | (!!(r & 0x001000) << 20)
         | (!!(r & 0x000080) << 19) | (!!(r & 0x000040) << 18)
         | (!!(r & 0x000020) << 17) | (!!(r & 0x000010) << 16)
         | (!!(r & 0x000200) << 15) | (!!(r & 0x000100) << 14)
         | (!!(r & 0x800000) << 13) | (!!(r & 0x400000) << 12)
         | (!!(r & 0x200000) << 11) | (!!(r & 0x100000) << 10)
         | (!!(r & 0x000008) <<  9) | (!!(r & 0x000004) <<  8)
         | (!!(r & 0x000002) <<  7) | (!!(r & 0x000001) <<  6)
         | (!!(r & 0x080000) <<  5) | (!!(r & 0x040000) <<  4)
         | (!!(r & 0x020000) <<  3) | (!!(r & 0x010000) <<  2)
         | (!!(r & 0x000800) <<  1) | (!!(r & 0x000400) <<  0);
    sprintf(t, "%.2x%.2x-%.4x", data, addr >> 16, addr & 0xffff);
    strtr(t, "0123456789abcdef", "df4709156bc8a23e");
    s = t;
    return true;
  } else {
    return false;
  }
}
#endif

}
