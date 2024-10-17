typedef struct {
  struct {
    unsigned char type;
    unsigned char cpuid;
    unsigned short len;
  } header;
  unsigned int regs[32];
} packet_t;

