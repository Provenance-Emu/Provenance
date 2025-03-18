/*
// The MIT License (MIT)
// 
// Copyright (c) 2015 Howard Hinnant
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
 */

#ifndef STACK_ALLOC_IPP
#define STACK_ALLOC_IPP

namespace jwt {

template <size_t N, size_t alignment>
template <size_t reqested_alignment>
char* Arena<N, alignment>::allocate(size_t n) noexcept
{
  static_assert (reqested_alignment <= alignment,
      "Requested alignment is too small for this arena");

  assert (pointer_in_storage(ptr_) &&
      "No more space in the arena or it has outgrown its capacity");

  n = align_up(n);

  if ((ptr_ + n) <= (buf_ + N)) {
    char* ret = ptr_;
    ptr_ += n;

    return ret;
  }

  assert (0 && "Code should not reach here");

  return nullptr;
}

template <size_t N, size_t alignment>
void Arena<N, alignment>::deallocate(char* p, size_t n) noexcept
{
  assert (pointer_in_storage(p) &&
      "The address to de deleted does not lie inside the storage");

  n = align_up(n);

  if ((p + n) == ptr_) {
    ptr_ = p;
  }

  return;
}

template <typename T, size_t N, size_t alignment>
T* stack_alloc<T, N, alignment>::allocate(size_t n) noexcept
{
  return reinterpret_cast<T*>(
      arena_.template allocate<alignof(T)>(n * sizeof(T))
  );
}

template <typename T, size_t N, size_t alignment>
void stack_alloc<T, N, alignment>::deallocate(T* p, size_t n) noexcept
{
  arena_.deallocate(reinterpret_cast<char*>(p), n);
  return;
}

}


#endif
