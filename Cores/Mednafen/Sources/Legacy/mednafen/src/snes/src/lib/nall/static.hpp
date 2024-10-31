#ifndef NALL_STATIC_HPP
#define NALL_STATIC_HPP

namespace nall_v059 {
  template<bool condition> struct nall_static_assert;
  template<> struct nall_static_assert<true> {};

  template<bool condition, typename true_type, typename false_type> struct static_if {
    typedef true_type type;
  };

  template<typename true_type, typename false_type> struct static_if<false, true_type, false_type> {
    typedef false_type type;
  };
}

#endif
