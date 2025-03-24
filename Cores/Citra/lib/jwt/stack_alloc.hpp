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

#ifndef STACK_ALLOC_HPP
#define STACK_ALLOC_HPP

/*
 * Based on Howard Hinnants awesome allocator boilerplate code
 * https://howardhinnant.github.io/short_alloc.h
 */

#include <cstddef>
#include <cassert>

namespace jwt {

/*
 */
template <
  /// Size of the stack allocated byte buffer.
  size_t N, 
  /// The alignment required for the buffer.
  size_t alignment = alignof(std::max_align_t)
>
class Arena
{
public: // 'tors
  Arena() noexcept
    : ptr_(buf_)
  {
    static_assert (alignment <= alignof(std::max_align_t),
        "Alignment chosen is more than the maximum supported alignment");
  }

  /// Non copyable and assignable
  Arena(const Arena&) = delete;
  Arena& operator=(const Arena&) = delete;

  ~Arena() 
  { 
    ptr_ = nullptr; 
  }

public: // Public APIs

  /*
   * Reserves space within the buffer of size atleast 'n'
   * bytes.
   * More bytes maybe reserved based on the alignment requirements.
   *
   * Returns:
   * 1. The pointer within the storage buffer where the object can be constructed.
   * 2. nullptr if space cannot be reserved for requested number of bytes 
   *    (+ alignment padding if applicable)
   */
  template <
    /// The requested alignment for this allocation.
    /// Must be less than or equal to the 'alignment'.
    size_t requested_alignment
  >
  char* allocate(size_t n) noexcept;

  /*
   * Free back the space pointed by p within the storage buffer.
   */
  void deallocate(char* p, size_t n) noexcept;

  /*
   * The size of the internal storage buffer.
   */
  constexpr static size_t size() noexcept
  {
    return N;
  }

  /*
   * Returns number of remaining bytes within the storage buffer
   * that can be used for further allocation requests.
   */
  size_t used() const noexcept
  {
    return static_cast<size_t>(ptr_ - buf_);
  }

private: // Private member functions

  /*
   * A check to determine if the pointer 'p'
   * points to a region within storage.
   */
  bool pointer_in_storage(char* p) const noexcept
  {
    return (buf_ <= p) && (p <= (buf_ + N));
  }

  /*
   * Rounds up the number to the next closest number
   * as per the alignment.
   */
  constexpr static size_t align_up(size_t n) noexcept
  {
    return (n + (alignment - 1)) & ~(alignment - 1);
  }

private: // data members
  /// Storage
  alignas(alignment) char buf_[N];

  /// Current allocation pointer within storage
  char* ptr_ = nullptr;
};



/*
 */
template <
  /// The allocator for type T
  typename T,
  /// Number of bytes for the arena
  size_t N,
  /// Alignment of the arena
  size_t align = alignof(std::max_align_t)
>
class stack_alloc
{
public: // typedefs
  using value_type = T;
  using arena_type = Arena<N, align>;

  static auto constexpr alignment = align;
  static auto constexpr size = N;

public: // 'tors
  stack_alloc(arena_type& a)
    : arena_(a)
  {
  }

  stack_alloc(const stack_alloc&) = default;
  stack_alloc& operator=(const stack_alloc&) = delete;

  template <typename U>
  stack_alloc(const stack_alloc<U, N, alignment>& other)
    : arena_(other.arena_)
  {
  }

  template <typename U>
  struct rebind {
    using other = stack_alloc<U, N, alignment>;
  };

public: // Exposed APIs

  /*
   * Allocate memory of 'n' bytes for object
   * of type 'T'
   */
  T* allocate(size_t n) noexcept;

  /*
   * Deallocate the storage reserved for the object
   * of type T pointed by pointer 'p'
   */
  void deallocate(T* p, size_t n) noexcept;

private: // Private APIs

private: // Private data members
  /// The arena
  arena_type& arena_;
};

} // END namespace jwt

#include "jwt/impl/stack_alloc.ipp"

#endif
