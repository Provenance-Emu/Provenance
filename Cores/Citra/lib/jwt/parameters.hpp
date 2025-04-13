/*
Copyright (c) 2017 Arun Muralidharan

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
 */

#ifndef CPP_JWT_PARAMETERS_HPP
#define CPP_JWT_PARAMETERS_HPP

#include <map>
#include <chrono>
#include <string>
#include <vector>
#include <utility>
#include <unordered_map>

#include "jwt/algorithm.hpp"
#include "jwt/detail/meta.hpp"
#include "jwt/string_view.hpp"

namespace jwt {

using system_time_t = std::chrono::time_point<std::chrono::system_clock>;

namespace params {


namespace detail {
/**
 * Parameter for providing the payload.
 * Takes a Mapping concept representing
 * key-value pairs.
 *
 * NOTE: MappingConcept allows only strings
 * for both keys and values. Use `add_header`
 * API of `jwt_object` otherwise.
 *
 * Modeled as ParameterConcept.
 */
template <typename MappingConcept>
struct payload_param
{
  payload_param(MappingConcept&& mc)
    : payload_(std::forward<MappingConcept>(mc))
  {}

  MappingConcept get() && { return std::move(payload_); }
  const MappingConcept& get() const& { return payload_; }

  MappingConcept payload_;
};

/**
 * Parameter for providing the secret key.
 * Stores only the view of the provided string
 * as string_view. Later the implementation may or
 * may-not copy it.
 *
 * Modeled as ParameterConcept.
 */
struct secret_param
{
  secret_param(string_view sv)
    : secret_(sv)
  {}

  string_view get() { return secret_; }
  string_view secret_;
};

template <typename T>
struct secret_function_param
{
  T get() const { return fun_; }
  template <typename U>
  std::string get(U&& u) const { return fun_(u);}
  T fun_;
};

/**
 * Parameter for providing the algorithm to use.
 * The parameter can accept either the string representation
 * or the enum class.
 *
 * Modeled as ParameterConcept.
 */
struct algorithm_param
{
  algorithm_param(const string_view alg)
    : alg_(str_to_alg(alg))
  {}

  algorithm_param(jwt::algorithm alg)
    : alg_(alg)
  {}

  jwt::algorithm get() const noexcept
  {
    return alg_;
  }

  typename jwt::algorithm alg_;
};

/**
 * Parameter for providing additional headers.
 * Takes a mapping concept representing
 * key-value pairs.
 *
 * Modeled as ParameterConcept.
 */
template <typename MappingConcept>
struct headers_param
{
  headers_param(MappingConcept&& mc)
    : headers_(std::forward<MappingConcept>(mc))
  {}

  MappingConcept get() && { return std::move(headers_); }
  const MappingConcept& get() const& { return headers_; }

  MappingConcept headers_;
};

/**
 */
struct verify_param
{
  verify_param(bool v)
    : verify_(v)
  {}

  bool get() const { return verify_; }

  bool verify_;
};

/**
 */
template <typename Sequence>
struct algorithms_param
{
  algorithms_param(Sequence&& seq)
    : seq_(std::forward<Sequence>(seq))
  {}

  Sequence get() && { return std::move(seq_); }
  const Sequence& get() const& { return seq_; }

  Sequence seq_;
};

/**
 */
struct leeway_param
{
  leeway_param(uint32_t v)
    : leeway_(v)
  {}

  uint32_t get() const noexcept { return leeway_; }

  uint32_t leeway_;
};

/**
 */
struct audience_param
{
  audience_param(std::string aud)
    : aud_(std::move(aud))
  {}

  const std::string& get() const& noexcept { return aud_; }
  std::string get() && noexcept { return aud_; }

  std::string aud_;
};

/**
 */
struct issuer_param
{
  issuer_param(std::string iss)
    : iss_(std::move(iss))
  {}

  const std::string& get() const& noexcept { return iss_; }
  std::string get() && noexcept { return iss_; }

  std::string iss_;
};

/**
 */
struct subject_param
{
  subject_param(std::string sub)
    : sub_(std::move(sub))
  {}

  const std::string& get() const& noexcept { return sub_; }
  std::string get() && noexcept { return sub_; }

  std::string sub_;
};

/**
 */
struct validate_iat_param
{
  validate_iat_param(bool v)
    : iat_(v)
  {}

  bool get() const noexcept { return iat_; }

  bool iat_;
};

/**
 */
struct validate_jti_param
{
  validate_jti_param(bool v)
    : jti_(v)
  {}

  bool get() const noexcept { return jti_; }

  bool jti_;
};

/**
 */
struct nbf_param
{
  nbf_param(const jwt::system_time_t tp)
    : duration_(std::chrono::duration_cast<
        std::chrono::seconds>(tp.time_since_epoch()).count())
  {}

  nbf_param(const uint64_t epoch)
    : duration_(epoch)
  {}
 
  uint64_t get() const noexcept { return duration_; }

  uint64_t duration_;
};

} // END namespace detail

// Useful typedef
using param_init_list_t = std::initializer_list<std::pair<jwt::string_view, jwt::string_view>>;
using param_seq_list_t  = std::initializer_list<jwt::string_view>;


/**
 */
inline detail::payload_param<std::unordered_map<std::string, std::string>>
payload(const param_init_list_t& kvs)
{
  std::unordered_map<std::string, std::string> m;

  for (const auto& elem : kvs) {
    m.emplace(elem.first.data(), elem.second.data());
  }

  return { std::move(m) };
}

/**
 */
template <typename MappingConcept>
detail::payload_param<MappingConcept>
payload(MappingConcept&& mc)
{
  static_assert (jwt::detail::meta::is_mapping_concept<MappingConcept>::value,
      "Template parameter does not meet the requirements for MappingConcept.");

  return { std::forward<MappingConcept>(mc) };
}


/**
 */
inline detail::secret_param secret(const string_view sv)
{
  return { sv };
}

template <typename T>
inline std::enable_if_t<!std::is_convertible<T, string_view>::value, detail::secret_function_param<T>>  
secret(T&& fun)
{
  return detail::secret_function_param<T>{ fun };
}

/**
 */
inline detail::algorithm_param algorithm(const string_view sv)
{
  return { sv };
}

/**
 */
inline detail::algorithm_param algorithm(jwt::algorithm alg)
{
  return { alg };
}

/**
 */
inline detail::headers_param<std::map<std::string, std::string>>
headers(const param_init_list_t& kvs)
{
  std::map<std::string, std::string> m;

  for (const auto& elem : kvs) {
    m.emplace(elem.first.data(), elem.second.data());
  }

  return { std::move(m) };
}

/**
 */
template <typename MappingConcept>
detail::headers_param<MappingConcept>
headers(MappingConcept&& mc)
{
  static_assert (jwt::detail::meta::is_mapping_concept<MappingConcept>::value,
       "Template parameter does not meet the requirements for MappingConcept.");

  return { std::forward<MappingConcept>(mc) };
}

/**
 */
inline detail::verify_param
verify(bool v)
{
  return { v };
}

/**
 */
inline detail::leeway_param
leeway(uint32_t l)
{
  return { l };
}

/**
 */
inline detail::algorithms_param<std::vector<std::string>>
algorithms(const param_seq_list_t& seq)
{
  std::vector<std::string> vec;
  vec.reserve(seq.size());

  for (const auto& e: seq) { vec.emplace_back(e.data(), e.length()); }

  return { std::move(vec) };
}

template <typename SequenceConcept>
detail::algorithms_param<SequenceConcept>
algorithms(SequenceConcept&& sc)
{
  return { std::forward<SequenceConcept>(sc) };
}

/**
 */
inline detail::audience_param
aud(const jwt::string_view aud)
{
  return { aud.data() };
}

/**
 */
inline detail::issuer_param
issuer(const jwt::string_view iss)
{
  return { iss.data() };
}

/**
 */
inline detail::subject_param
sub(const jwt::string_view subj)
{
  return { subj.data() };
}

/**
 */
inline detail::validate_iat_param
validate_iat(bool v)
{
  return { v };
}

/**
 */
inline detail::validate_jti_param
validate_jti(bool v)
{
  return { v };
}

/**
 */
inline detail::nbf_param
nbf(const system_time_t tp)
{
  return { tp };
}

/**
 */
inline detail::nbf_param
nbf(const uint64_t epoch)
{
  return { epoch };
}

} // END namespace params
} // END namespace jwt

#endif
