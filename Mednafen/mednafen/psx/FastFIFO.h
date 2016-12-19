#ifndef __MDFN_FASTFIFO_H
#define __MDFN_FASTFIFO_H

// size should be a power of 2.
template<typename T, size_t size>
class FastFIFO
{
 public:

 FastFIFO()
 {
  memset(data, 0, sizeof(data));
  read_pos = 0;
  write_pos = 0;
  in_count = 0;
 }

 INLINE ~FastFIFO()
 {

 }

 INLINE void SaveStatePostLoad(void)
 {
  read_pos %= size;
  write_pos %= size;
  in_count %= (size + 1);
 }

 INLINE uint32 CanRead(void)
 {
  return(in_count);
 }

 INLINE uint32 CanWrite(void)
 {
  return(size - in_count);
 }

 INLINE T Peek(void)
 {
  return data[read_pos];
 }

 INLINE T Read(void)
 {
  T ret = data[read_pos];

  read_pos = (read_pos + 1) & (size - 1);
  in_count--;

  return(ret);
 }

 INLINE void Write(const T& wr_data)
 {
  data[write_pos] = wr_data;
  write_pos = (write_pos + 1) & (size - 1);
  in_count++;
 }

 INLINE void Flush(void)
 {
  read_pos = 0;
  write_pos = 0;
  in_count = 0;
 }

 T data[size];
 uint32 read_pos; // Read position
 uint32 write_pos; // Write position
 uint32 in_count; // Number of units in the FIFO
};


#endif
