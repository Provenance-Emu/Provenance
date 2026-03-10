#undef uint8
#undef uint16
#undef uint32
#undef int8
#undef int16
#undef int32

#define uint8  u8
#define uint16 u16
#define uint32 u32
#define int8   s8
#define int16  s16
#define int32  s32

#define READ_BYTE(BASE, ADDR) (BASE)[MEM_BE2(ADDR)]
#define WRITE_BYTE(BASE, ADDR, VAL) (BASE)[MEM_BE2(ADDR)] = (VAL)

#define load_param(param, size) \
  memcpy(param, &state[bufferptr], size); \
  bufferptr += size;
  
#define save_param(param, size) \
  memcpy(&state[bufferptr], param, size); \
  bufferptr += size;
