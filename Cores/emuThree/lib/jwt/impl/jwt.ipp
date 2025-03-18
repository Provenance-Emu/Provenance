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

#ifndef JWT_IPP
#define JWT_IPP

#include "jwt/config.hpp"
#include "jwt/detail/meta.hpp"
#include <algorithm>
#include <iomanip>

namespace jwt {

/**
 */
static inline void jwt_throw_exception(const std::error_code& ec);

template <typename T, typename Cond>
std::string to_json_str(const T& obj, bool pretty)
{
  return pretty ? obj.create_json_obj().dump(2)
                : obj.create_json_obj().dump()
                ;
}


template <typename T>
std::ostream& write(std::ostream& os, const T& obj, bool pretty)
{
  pretty ? (os << std::setw(2) << obj.create_json_obj())
         : (os                 << obj.create_json_obj())
         ;

  return os;
}


template <typename T, typename Cond>
std::ostream& operator<< (std::ostream& os, const T& obj)
{
  os << obj.create_json_obj();
  return os;
}

//========================================================================

inline void jwt_header::decode(const jwt::string_view enc_str, std::error_code& ec)
{
  ec.clear();
  std::string json_str = base64_decode(enc_str);

  try {
    payload_ = json_t::parse(std::move(json_str));
  } catch(const std::exception&) {
    ec = DecodeErrc::JsonParseError;
    return;
  }

  //Look for the algorithm field
  auto alg_itr = payload_.find("alg");
  if (alg_itr == payload_.end()) {
    ec = DecodeErrc::AlgHeaderMiss;
    return;
  }

  alg_ = str_to_alg(alg_itr.value().get<std::string>());

  if (alg_ != algorithm::NONE)
  {
    auto itr = payload_.find("typ");

    if (itr != payload_.end()) {
      const auto& typ = itr.value().get<std::string>();
      if (strcasecmp(typ.c_str(), "JWT")) {
        ec = DecodeErrc::TypMismatch;
        return;
      }

      typ_ = str_to_type(typ);
    }
  } else {
    //TODO:
  }

  // Populate header
  for (auto it = payload_.begin(); it != payload_.end(); ++it) {
    auto ret = headers_.insert(it.key());
    if (!ret.second) {
      ec = DecodeErrc::DuplClaims;
      //ATTN: Dont stop the decode here
      //Not a hard error.
    }
  }

  return;
}

inline void jwt_header::decode(const jwt::string_view enc_str)
{
  std::error_code ec;
  decode(enc_str, ec);
  if (ec) {
    throw DecodeError(ec.message());
  }
  return;
}

inline void jwt_payload::decode(const jwt::string_view enc_str, std::error_code& ec)
{
  ec.clear();
  std::string json_str = base64_decode(enc_str);
  try {
    payload_ = json_t::parse(std::move(json_str));
  } catch(const std::exception&) {
    ec = DecodeErrc::JsonParseError;
    return;
  }
  //populate the claims set
  for (auto it = payload_.begin(); it != payload_.end(); ++it) {
    auto ret = claim_names_.insert(it.key());
    if (!ret.second) {
      ec = DecodeErrc::DuplClaims;
      break;
    }
  }

  return;
}

inline void jwt_payload::decode(const jwt::string_view enc_str)
{
  std::error_code ec;
  decode(enc_str, ec);
  if (ec) {
    throw DecodeError(ec.message());
  }
  return;
}

inline std::string jwt_signature::encode(const jwt_header& header,
                                         const jwt_payload& payload,
                                         std::error_code& ec)
{
  std::string jwt_msg;
  ec.clear();
  //TODO: Optimize allocations

  sign_func_t sign_fn = get_sign_algorithm_impl(header);

  std::string hdr_sign = header.base64_encode();
  std::string pld_sign = payload.base64_encode();
  std::string data     = hdr_sign + '.' + pld_sign;

  auto res = sign_fn(key_, data);

  if (res.second && res.second != AlgorithmErrc::NoneAlgorithmUsed) {
    ec = res.second;
    return {};
  }

  std::string b64hash;

  if (!res.second) {
    b64hash = base64_encode(res.first.c_str(), res.first.length());
  }

  auto new_len = base64_uri_encode(&b64hash[0], b64hash.length());
  b64hash.resize(new_len);

  jwt_msg = data + '.' + b64hash;

  return jwt_msg;
}

inline verify_result_t jwt_signature::verify(const jwt_header& header,
                                             const jwt::string_view hdr_pld_sign,
                                             const jwt::string_view jwt_sign)
{
  verify_func_t verify_fn = get_verify_algorithm_impl(header);
  return verify_fn(key_, hdr_pld_sign, jwt_sign);
}


inline sign_func_t
jwt_signature::get_sign_algorithm_impl(const jwt_header& hdr) const noexcept
{
  sign_func_t ret = nullptr;

  switch (hdr.algo()) {
  case algorithm::HS256:
    ret = HMACSign<algo::HS256>::sign;
    break;
  case algorithm::HS384:
    ret = HMACSign<algo::HS384>::sign;
    break;
  case algorithm::HS512:
    ret = HMACSign<algo::HS512>::sign;
    break;
  case algorithm::NONE:
    ret = HMACSign<algo::NONE>::sign;
    break;
  case algorithm::RS256:
    ret = PEMSign<algo::RS256>::sign;
    break;
  case algorithm::RS384:
    ret = PEMSign<algo::RS384>::sign;
    break;
  case algorithm::RS512:
    ret = PEMSign<algo::RS512>::sign;
    break;
  case algorithm::ES256:
    ret = PEMSign<algo::ES256>::sign;
    break;
  case algorithm::ES384:
    ret = PEMSign<algo::ES384>::sign;
    break;
  case algorithm::ES512:
    ret = PEMSign<algo::ES512>::sign;
    break;
  default:
    assert (0 && "Code not reached");
  };

  return ret;
}



inline verify_func_t
jwt_signature::get_verify_algorithm_impl(const jwt_header& hdr) const noexcept
{
  verify_func_t ret = nullptr;

  switch (hdr.algo()) {
  case algorithm::HS256:
    ret = HMACSign<algo::HS256>::verify;
    break;
  case algorithm::HS384:
    ret = HMACSign<algo::HS384>::verify;
    break;
  case algorithm::HS512:
    ret = HMACSign<algo::HS512>::verify;
    break;
  case algorithm::NONE:
    ret = HMACSign<algo::NONE>::verify;
    break;
  case algorithm::RS256:
    ret = PEMSign<algo::RS256>::verify;
    break;
  case algorithm::RS384:
    ret = PEMSign<algo::RS384>::verify;
    break;
  case algorithm::RS512:
    ret = PEMSign<algo::RS512>::verify;
    break;
  case algorithm::ES256:
    ret = PEMSign<algo::ES256>::verify;
    break;
  case algorithm::ES384:
    ret = PEMSign<algo::ES384>::verify;
    break;
  case algorithm::ES512:
    ret = PEMSign<algo::ES512>::verify;
    break;
  default:
    assert (0 && "Code not reached");
  };

  return ret;
}


//
template <typename First, typename... Rest,
          typename SFINAE_COND>
jwt_object::jwt_object(
    First&& first, Rest&&... rest)
{
  static_assert (detail::meta::is_parameter_concept<First>::value && 
                 detail::meta::are_all_params<Rest...>::value,
      "All constructor argument types must model ParameterConcept");

  set_parameters(std::forward<First>(first), std::forward<Rest>(rest)...);
}

template <typename Map, typename... Rest>
void jwt_object::set_parameters(
    params::detail::payload_param<Map>&& payload, Rest&&... rargs)
{
  for (const auto& elem : payload.get()) {
    payload_.add_claim(std::move(elem.first), std::move(elem.second));
  }
  set_parameters(std::forward<Rest>(rargs)...);
}

template <typename... Rest>
void jwt_object::set_parameters(
    params::detail::secret_param secret, Rest&&... rargs)
{
  secret_.assign(secret.get().data(), secret.get().length());
  set_parameters(std::forward<Rest>(rargs)...);
}

template <typename... Rest>
void jwt_object::set_parameters(
    params::detail::algorithm_param alg, Rest&&... rargs)
{
  header_.algo(alg.get());
  set_parameters(std::forward<Rest>(rargs)...);
}

template <typename Map, typename... Rest>
void jwt_object::set_parameters(
    params::detail::headers_param<Map>&& header, Rest&&... rargs)
{
  for (const auto& elem : header.get()) {
    header_.add_header(std::move(elem.first), std::move(elem.second));
  }

  set_parameters(std::forward<Rest>(rargs)...);
}

inline void jwt_object::set_parameters()
{
  //sentinel call
  return;
}

inline jwt_object& jwt_object::add_claim(const jwt::string_view name, system_time_t tp)
{
  return add_claim(
      name,
      std::chrono::duration_cast<
        std::chrono::seconds>(tp.time_since_epoch()).count()
      );
}

inline jwt_object& jwt_object::remove_claim(const jwt::string_view name)
{
  payload_.remove_claim(name);
  return *this;
}

inline std::string jwt_object::signature(std::error_code& ec) const
{
  ec.clear();

  //key/secret should be set for any algorithm except NONE
  if (header().algo() != jwt::algorithm::NONE) {
    if (secret_.length() == 0) {
      ec = AlgorithmErrc::KeyNotFoundErr;
      return {};
    }
  }

  jwt_signature jws{secret_};
  return jws.encode(header_, payload_, ec);
}

inline std::string jwt_object::signature() const
{
  std::error_code ec;
  std::string res = signature(ec);
  if (ec) {
    throw SigningError(ec.message());
  }
  return res;
}

template <typename Params, typename SequenceT>
std::error_code jwt_object::verify(
    const Params& dparams,
    const params::detail::algorithms_param<SequenceT>& algos) const
{
  std::error_code ec{};

  //Verify if the algorithm set in the header
  //is any of the one expected by the client.
  auto fitr = std::find_if(algos.get().begin(), 
                           algos.get().end(),
                           [this](const auto& elem) 
                           {
                             return jwt::str_to_alg(elem) == this->header().algo();
                           });

  if (fitr == algos.get().end()) {
    ec = VerificationErrc::InvalidAlgorithm;
    return ec;
  }

  //Check for the expiry timings
  if (has_claim(registered_claims::expiration)) {
    auto curr_time = 
        std::chrono::duration_cast<
                 std::chrono::seconds>(std::chrono::system_clock::now().time_since_epoch()).count();

    auto p_exp = payload()
                 .get_claim_value<uint64_t>(registered_claims::expiration);

    if (static_cast<uint64_t>(curr_time) > static_cast<uint64_t>(p_exp + dparams.leeway)) {
      ec = VerificationErrc::TokenExpired;
      return ec;
    }
  } 

  //Check for issuer
  if (dparams.has_issuer)
  {
    if (has_claim(registered_claims::issuer))
    {
      const std::string& p_issuer = payload()
                                    .get_claim_value<std::string>(registered_claims::issuer);

      if (p_issuer != dparams.issuer) {
        ec = VerificationErrc::InvalidIssuer;
        return ec;
      }
    } else {
      ec = VerificationErrc::InvalidIssuer;
      return ec;
    }
  }

  //Check for audience
  if (dparams.has_aud)
  {
    if (has_claim(registered_claims::audience))
    {
      const std::string& p_aud = payload()
                                 .get_claim_value<std::string>(registered_claims::audience);

      if (p_aud != dparams.aud) {
        ec = VerificationErrc::InvalidAudience;
        return ec;
      }
    } else {
      ec = VerificationErrc::InvalidAudience;
      return ec;
    }
  }

  //Check the subject
  if (dparams.has_sub)
  {
    if (has_claim(registered_claims::subject))
    {
      const std::string& p_sub = payload()
                                 .get_claim_value<std::string>(registered_claims::subject);
      if (p_sub != dparams.sub) {
        ec = VerificationErrc::InvalidSubject;
        return ec;
      }
    } else {
      ec = VerificationErrc::InvalidSubject;
      return ec;
    }
  }

  //Check for NBF
  if (has_claim(registered_claims::not_before))
  {
    auto curr_time =
            std::chrono::duration_cast<
              std::chrono::seconds>(std::chrono::system_clock::now().time_since_epoch()).count();

    auto p_exp = payload()
                 .get_claim_value<uint64_t>(registered_claims::not_before);

    if (static_cast<uint64_t>(p_exp - dparams.leeway) > static_cast<uint64_t>(curr_time)) {
      ec = VerificationErrc::ImmatureSignature;
      return ec;
    }
  }

  //Check IAT validation
  if (dparams.validate_iat) {
    if (!has_claim(registered_claims::issued_at)) {
      ec = VerificationErrc::InvalidIAT;
      return ec;
    } else {
      // Will throw type conversion error
      auto val = payload()
                 .get_claim_value<uint64_t>(registered_claims::issued_at);
      (void)val;
    }
  }

  //Check JTI validation
  if (dparams.validate_jti) {
    if (!has_claim("jti")) {
      ec = VerificationErrc::InvalidJTI;
      return ec;
    }
  }

  return ec;
}


inline std::array<jwt::string_view, 3>
jwt_object::three_parts(const jwt::string_view enc_str)
{
  std::array<jwt::string_view, 3> result;

  size_t fpos = enc_str.find_first_of('.');
  assert (fpos != jwt::string_view::npos);

  result[0] = jwt::string_view{&enc_str[0], fpos};

  size_t spos = enc_str.find_first_of('.', fpos + 1);

  result[1] = jwt::string_view{&enc_str[fpos + 1], spos - fpos - 1};

  if (spos + 1 != enc_str.length()) {
    result[2] = jwt::string_view{&enc_str[spos + 1], enc_str.length() - spos - 1};
  }

  return result;
}

template <typename DecodeParams, typename... Rest>
void jwt_object::set_decode_params(DecodeParams& dparams, params::detail::secret_param s, Rest&&... args)
{
  dparams.secret.assign(s.get().data(), s.get().length());
  dparams.has_secret = true;
  jwt_object::set_decode_params(dparams, std::forward<Rest>(args)...);
}

template <typename DecodeParams, typename T, typename... Rest>
void jwt_object::set_decode_params(DecodeParams& dparams, params::detail::secret_function_param<T>&& s, Rest&&... args)
{
  dparams.secret = s.get(*dparams.payload_ptr);
  dparams.has_secret = true;
  jwt_object::set_decode_params(dparams, std::forward<Rest>(args)...);
}

template <typename DecodeParams, typename... Rest>
void jwt_object::set_decode_params(DecodeParams& dparams, params::detail::leeway_param l, Rest&&... args)
{
  dparams.leeway = l.get();
  jwt_object::set_decode_params(dparams, std::forward<Rest>(args)...);
}

template <typename DecodeParams, typename... Rest>
void jwt_object::set_decode_params(DecodeParams& dparams, params::detail::verify_param v, Rest&&... args)
{
  dparams.verify = v.get();
  jwt_object::set_decode_params(dparams, std::forward<Rest>(args)...);
}

template <typename DecodeParams, typename... Rest>
void jwt_object::set_decode_params(DecodeParams& dparams, params::detail::issuer_param i, Rest&&... args)
{
  dparams.issuer = std::move(i).get();
  dparams.has_issuer = true;
  jwt_object::set_decode_params(dparams, std::forward<Rest>(args)...);
}

template <typename DecodeParams, typename... Rest>
void jwt_object::set_decode_params(DecodeParams& dparams, params::detail::audience_param a, Rest&&... args)
{
  dparams.aud = std::move(a).get();
  dparams.has_aud = true;
  jwt_object::set_decode_params(dparams, std::forward<Rest>(args)...);
}

template <typename DecodeParams, typename... Rest>
void jwt_object::set_decode_params(DecodeParams& dparams, params::detail::subject_param s, Rest&&... args)
{
  dparams.sub = std::move(s).get();
  dparams.has_sub = true;
  jwt_object::set_decode_params(dparams, std::forward<Rest>(args)...);
}

template <typename DecodeParams, typename... Rest>
void jwt_object::set_decode_params(DecodeParams& dparams, params::detail::validate_iat_param v, Rest&&... args)
{
  dparams.validate_iat = v.get();
  jwt_object::set_decode_params(dparams, std::forward<Rest>(args)...);
}

template <typename DecodeParams, typename... Rest>
void jwt_object::set_decode_params(DecodeParams& dparams, params::detail::validate_jti_param v, Rest&&... args)
{
  dparams.validate_jti = v.get();
  jwt_object::set_decode_params(dparams, std::forward<Rest>(args)...);
}

template <typename DecodeParams>
void jwt_object::set_decode_params(DecodeParams& dparams)
{
  (void) dparams; // prevent -Wunused-parameter with gcc
  return;
}

//==================================================================

template <typename SequenceT, typename... Args>
jwt_object decode(const jwt::string_view enc_str,
                  const params::detail::algorithms_param<SequenceT>& algos,
                  std::error_code& ec,
                  Args&&... args)
{
  ec.clear();
  jwt_object obj;

  if (algos.get().size() == 0) {
    ec = DecodeErrc::EmptyAlgoList;
    return obj;
  }

  struct decode_params
  {
    /// key to decode the JWS
    bool has_secret = false;
    std::string secret;

    /// Verify parameter. Defaulted to true.
    bool verify = true;

    /// Leeway parameter. Defaulted to zero seconds.
    uint32_t leeway = 0;

    ///The issuer
    //TODO: optional type
    bool has_issuer = false;
    std::string issuer;

    ///The audience
    //TODO: optional type
    bool has_aud = false;
    std::string aud;

    //The subject
    //TODO: optional type
    bool has_sub = false;
    std::string sub;

    //Validate IAT
    bool validate_iat = false;

    //Validate JTI
    bool validate_jti = false;
    const jwt_payload* payload_ptr = 0;
  };

  decode_params dparams{};
  

  //Signature must have atleast 2 dots
  auto dot_cnt = std::count_if(std::begin(enc_str), std::end(enc_str),
                               [](char ch) { return ch == '.'; });
  if (dot_cnt < 2) {
    ec = DecodeErrc::SignatureFormatError;
    return obj;
  }

  auto parts = jwt_object::three_parts(enc_str);

  //throws decode error
  jwt_header hdr{};
  hdr.decode(parts[0], ec);
  if (ec) {
    return obj;
  }
  //obj.header(jwt_header{parts[0]});
  obj.header(std::move(hdr));

  //If the algorithm is not NONE, it must not
  //have more than two dots ('.') and the split
  //must result in three strings with some length.
  if (obj.header().algo() != jwt::algorithm::NONE) {
    if (dot_cnt > 2) {
      ec = DecodeErrc::SignatureFormatError;
      return obj;
    }
    if (parts[2].length() == 0) {
      ec = DecodeErrc::SignatureFormatError;
      return obj;
    }
  }

  //throws decode error
  jwt_payload payload{};
  payload.decode(parts[1], ec);
  if (ec) {
    return obj;
  }
  obj.payload(std::move(payload));
  dparams.payload_ptr = & obj.payload();
  jwt_object::set_decode_params(dparams, std::forward<Args>(args)...);
  if (dparams.verify) {
    try {
      ec = obj.verify(dparams, algos);
    } catch (const json_ns::detail::type_error&) {
      ec = VerificationErrc::TypeConversionError;
    }

    if (ec) return obj;

    //Verify the signature only if some algorithm was used
    if (obj.header().algo() != algorithm::NONE)
    {
      if (!dparams.has_secret) {
        ec = DecodeErrc::KeyNotPresent;
        return obj;
      }
      jwt_signature jsign{dparams.secret};
 
      // Length of the encoded header and payload only.
      // Addition of '1' to account for the '.' character.
      auto l = parts[0].length() + 1 + parts[1].length();

      //MemoryAllocationError is not caught
      verify_result_t res = jsign.verify(obj.header(), enc_str.substr(0, l), parts[2]);
      if (res.second) {
        ec = res.second;
        return obj;
      }

      if (!res.first) {
        ec = VerificationErrc::InvalidSignature;
        return obj;
      }
    } else {
      ec = AlgorithmErrc::NoneAlgorithmUsed;
    }
  }

  return obj; 
}



template <typename SequenceT, typename... Args>
jwt_object decode(const jwt::string_view enc_str,
                  const params::detail::algorithms_param<SequenceT>& algos,
                  Args&&... args)
{
  std::error_code ec{};
  auto jwt_obj = decode(enc_str,
                        algos,
                        ec,
                        std::forward<Args>(args)...);

  if (ec) {
    jwt_throw_exception(ec);
  }

  return jwt_obj;
}


void jwt_throw_exception(const std::error_code& ec)
{
  const auto& cat = ec.category();

  if (&cat == &theVerificationErrorCategory ||
      std::string(cat.name()) == std::string(theVerificationErrorCategory.name()))
  {
    switch (static_cast<VerificationErrc>(ec.value()))
    {
      case VerificationErrc::InvalidAlgorithm:
      {
        throw InvalidAlgorithmError(ec.message());
      }
      case VerificationErrc::TokenExpired:
      {
        throw TokenExpiredError(ec.message());
      }
      case VerificationErrc::InvalidIssuer:
      {
        throw InvalidIssuerError(ec.message());
      }
      case VerificationErrc::InvalidAudience:
      {
        throw InvalidAudienceError(ec.message());
      }
      case VerificationErrc::InvalidSubject:
      {
        throw InvalidSubjectError(ec.message());
      }
      case VerificationErrc::InvalidIAT:
      {
        throw InvalidIATError(ec.message());
      }
      case VerificationErrc::InvalidJTI:
      {
        throw InvalidJTIError(ec.message());
      }
      case VerificationErrc::ImmatureSignature:
      {
        throw ImmatureSignatureError(ec.message());
      }
      case VerificationErrc::InvalidSignature:
      {
        throw InvalidSignatureError(ec.message());
      }
      case VerificationErrc::TypeConversionError:
      {
        throw TypeConversionError(ec.message());
      }
      default:
        assert (0 && "Unknown error code");
    };
  }

  if (&cat == &theDecodeErrorCategory ||
      std::string(cat.name()) == std::string(theDecodeErrorCategory.name()))
  {
    switch (static_cast<DecodeErrc>(ec.value()))
    {
      case DecodeErrc::SignatureFormatError:
      {
        throw SignatureFormatError(ec.message());
      }
      case DecodeErrc::KeyNotPresent:
      {
        throw KeyNotPresentError(ec.message());
      }
      case DecodeErrc::KeyNotRequiredForNoneAlg:
      {
        // Not an error. Just to be ignored.
        break;
      }
      default:
      {
        throw DecodeError(ec.message());
      }
    };

    assert (0 && "Unknown error code");
  }

  if (&cat == &theAlgorithmErrCategory ||
      std::string(cat.name()) == std::string(theAlgorithmErrCategory.name()))
  {
    switch (static_cast<AlgorithmErrc>(ec.value()))
    {
      case AlgorithmErrc::InvalidKeyErr:
      {
        throw InvalidKeyError(ec.message());
      }
      case AlgorithmErrc::VerificationErr:
      {
        throw InvalidSignatureError(ec.message());
      }
      case AlgorithmErrc::NoneAlgorithmUsed:
      {
        //Not an error actually.
        break;
      }
      default:
        assert (0 && "Unknown error code or not to be treated as an error");
    };
  }
  return;
}

} // END namespace jwt


#endif
