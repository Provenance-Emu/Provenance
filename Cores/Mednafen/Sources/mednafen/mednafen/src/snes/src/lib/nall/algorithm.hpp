#ifndef NALL_ALGORITHM_HPP
#define NALL_ALGORITHM_HPP

#undef min
#undef max

namespace nall_v059 {
  template<typename T, typename U> T min(const T& t, const U& u) {
    return t < u ? t : u;
  }

  template<typename T, typename U> T max(const T& t, const U& u) {
    return t > u ? t : u;
  }
}

#endif
