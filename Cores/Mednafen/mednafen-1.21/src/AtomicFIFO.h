#ifndef __MDFN_ATOMICFIFO_H
#define __MDFN_ATOMICFIFO_H

#include <atomic>

template<typename T, size_t size>
class AtomicFIFO
{
 public:

 AtomicFIFO()
 {
  read_pos = 0;
  write_pos = 0;
  in_count.store(0, std::memory_order_release);
 }

 ~AtomicFIFO()
 {

 }

 INLINE size_t CanRead(void)
 {
  return in_count.load(std::memory_order_acquire);
 }

 INLINE size_t CanWrite(void)
 {
  return size - in_count.load(std::memory_order_acquire);
 }

 INLINE T Read(void)
 {
  T ret = data[read_pos];
  read_pos = (read_pos + 1) % size;
  in_count.fetch_sub(1, std::memory_order_release);
  return ret;
 }

 INLINE T Peek(void)
 {
  return data[read_pos];
 }

 INLINE void Write(T v)
 {
  data[write_pos] = v;
  write_pos = (write_pos + 1) % size;
  in_count.fetch_add(1, std::memory_order_release);
 }

 private:
 T data[size];
 size_t read_pos;  // Read position
 size_t write_pos; // Write position
 std::atomic_size_t in_count;
};


#endif
