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

#ifndef JWT_HPP
#define JWT_HPP

#include <set>
#include <array>
#include <string>
#include <chrono>
#include <ostream>
#include <cassert>
#include <cstring>

#include "jwt/assertions.hpp"
#include "jwt/base64.hpp"
#include "jwt/config.hpp"
#include "jwt/algorithm.hpp"
#include "jwt/string_view.hpp"
#include "jwt/parameters.hpp"
#include "jwt/exceptions.hpp"
#if defined(CPP_JWT_USE_VENDORED_NLOHMANN_JSON)
#include "jwt/json/json.hpp"
#else
#include "nlohmann/json.hpp"
#endif
// For convenience
using json_t = nlohmann::json;
using system_time_t = std::chrono::time_point<std::chrono::system_clock>;
namespace json_ns = nlohmann;

namespace jwt {

/**
 * The type of header.
 * NOTE: Only JWT is supported currently.
 */
enum class type
{
  NONE = 0,
  JWT  = 1,
};

/**
 * Converts a string representing a value of type
 * `enum class type` into its actual type.
 */
inline enum type str_to_type(const jwt::string_view typ) noexcept
{
  assert (typ.length() && "Empty type string");

  if (!strcasecmp(typ.data(), "jwt")) return type::JWT;
  else if(!strcasecmp(typ.data(), "none")) return type::NONE;

  JWT_NOT_REACHED("Code not reached");
}


/**
 * Converts an instance of type `enum class type`
 * to its string equivalent.
 */
inline jwt::string_view type_to_str(SCOPED_ENUM type typ)
{
  switch (typ) {
    case type::JWT: return "JWT";
    default:        assert (0 && "Unknown type");
  };

  JWT_NOT_REACHED("Code not reached");
}


/**
 * Registered claim names.
 */
enum class registered_claims
{
  // Expiration Time claim
  expiration = 0,
  // Not Before Time claim
  not_before,
  // Issuer name claim
  issuer,
  // Audience claim
  audience,
  // Issued At Time claim 
  issued_at,
  // Subject claim
  subject,
  // JWT ID claim
  jti,
};


/**
 * Converts an instance of type `enum class registered_claims`
 * to its string equivalent representation.
 */
inline jwt::string_view reg_claims_to_str(SCOPED_ENUM registered_claims claim) noexcept
{
  switch (claim) {
    case registered_claims::expiration: return "exp";
    case registered_claims::not_before: return "nbf";
    case registered_claims::issuer:     return "iss";
    case registered_claims::audience:   return "aud";
    case registered_claims::issued_at:  return "iat";
    case registered_claims::subject:    return "sub";
    case registered_claims::jti:        return "jti";
    default:                            assert (0 && "Not a registered claim");
  };
  JWT_NOT_REACHED("Code not reached");
}

/**
 * A helper class that enables reuse of the 
 * std::set container with custom comparator.
 */
struct jwt_set
{
  /**
   * Transparent comparator.
   * @note: C++14 only.
   */
  struct case_compare
  {
    using is_transparent = std::true_type;

    bool operator()(const jwt::string_view lhs, const jwt::string_view rhs) const noexcept
    {
      int ret = lhs.compare(rhs);
      return (ret < 0);
    }
  };

  using header_claim_set_t = std::set<std::string, case_compare>;
};

// Fwd declaration for friend functions to specify the 
// default arguments
// See: https://stackoverflow.com/a/23336823/434233
template <typename T, typename = typename std::enable_if<
            detail::meta::has_create_json_obj_member<T>{}>::type>
std::string to_json_str(const T& obj, bool pretty=false);

template <typename T>
std::ostream& write(std::ostream& os, const T& obj, bool pretty=false);

template <typename T,
          typename = typename std::enable_if<
                      detail::meta::has_create_json_obj_member<T>{}>::type
         >
std::ostream& operator<< (std::ostream& os, const T& obj);


/**
 * A helper class providing the necessary functionalities
 * for:
 * a) converting an object into JSON string.
 * b) writing to a standard output stream in JSON format.
 * c) writing to standard console in JSON format using
 *    overloaded '<<' operator.
 *
 * @note: The JWT component classes inherits from this
 *        class to get the above functionalities.
 */
struct write_interface
{
  /**
   * Converts an object of type `T` to its JSON
   * string format.
   * @note: Type `T` must have a member function named
   * `create_json_obj`.
   * The check is made at compile time. Check
   * `meta::has_create_json_obj_member` for more details.
   * This check is done in `Cond` template parameter.
   *
   * For pretty print, pass second parameter as `true`.
   */
  template <typename T, typename Cond>
  friend std::string to_json_str(const T& obj, bool pretty);

  /**
   * Writes the object of instance `T` in JSON format
   * to standard output stream.
   * The requirements on type `T` is same as that for 
   * `to_json_str` API.
   */
  template <typename T>
  friend std::ostream& write(
      std::ostream& os, const T& obj, bool pretty);

  /**
   * An overloaded operator for writing to standard
   * ostream in JSON format.
   * The requirements on type `T` is same as that for
   * `to_json_str` API.
   *
   * This API is same in functionality as that of
   * `write` API. Only difference is that, there is no
   * option to write the JSON representation in pretty
   * format.
   */
  template <typename T, typename Cond>
  friend std::ostream& operator<< (std::ostream& os, const T& obj);
};

/**
 * Provides the functionality for doing
 * base64 encoding and decoding from the
 * json string.
 *
 * @note: The JWT component classes inherits from this
 * class to get the base64 related encoding and decoding 
 * functionalities.
 */
template <typename Derived>
struct base64_enc_dec
{
  /**
   * Does URL safe base64 encoding
   */
  std::string base64_encode(bool with_pretty = false) const
  {
    std::string jstr = to_json_str(*static_cast<const Derived*>(this), with_pretty);
    std::string b64_str = jwt::base64_encode(jstr.c_str(), jstr.length());
    // Do the URI safe encoding
    auto new_len = jwt::base64_uri_encode(&b64_str[0], b64_str.length());
    b64_str.resize(new_len);

    return b64_str;
  }

  /**
   * Does URL safe base64 decoding.
   */
  std::string base64_decode(const jwt::string_view encoded_str)
  {
    return jwt::base64_uri_decode(encoded_str.data(), encoded_str.length());
  }

};


/**
 * Component class representing JWT Header.
 */
struct jwt_header: write_interface
                 , base64_enc_dec<jwt_header>
{
public: // 'tors
  /*
   * Default constructor.
   */
  jwt_header()
  {
    payload_["alg"] = "none";
    payload_["typ"] = "JWT";
  }

  /**
   * Constructor taking specified algorithm type
   * and JWT type.
   */
  jwt_header(SCOPED_ENUM algorithm alg, SCOPED_ENUM type typ = type::JWT)
    : alg_(alg)
    , typ_(typ)
  {
    payload_["typ"] = std::string(type_to_str(typ_));
    payload_["alg"] = std::string(alg_to_str(alg_));
  }

  /**
   * Construct the header from an encoded string.
   */
  jwt_header(const jwt::string_view enc_str)
  {
    this->decode(enc_str);
  }

  /// Default Copy and assignment
  jwt_header(const jwt_header&) = default;
  jwt_header& operator=(const jwt_header&) = default;

  ~jwt_header() = default;

public: // Exposed APIs
  /**
   * NOTE: Any previously saved json dump or the encoding of the
   * header would not be valid after modifying the algorithm.
   */
  /**
   * Set the algorithm.
   */
  void algo(SCOPED_ENUM algorithm alg)
  {
    alg_ = alg;
    payload_["alg"] = std::string(alg_to_str(alg_));
  }

  /**
   * Set the algorithm. String overload.
   */
  void algo(const jwt::string_view sv)
  {
    alg_ = str_to_alg(sv.data());
    payload_["alg"] = std::string(alg_to_str(alg_));
  }

  /**
   * Get the algorithm.
   */
  SCOPED_ENUM algorithm algo() const noexcept
  {
    return alg_;
  }

  /**
   * NOTE: Any previously saved json dump or the encoding of the
   * header would not be valid after modifying the type.
   */
  /**
   * Set the JWT type.
   */
  void typ(SCOPED_ENUM type typ) noexcept
  {
    typ_ = typ;
    payload_["typ"] = std::string(type_to_str(typ_));
  }

  /**
   * Set the JWT type header. String overload.
   */
  void typ(const jwt::string_view sv)
  {
    typ_ = str_to_type(sv.data());
    payload_["typ"] = std::string(type_to_str(typ_));
  }

  /**
   * Get the JWT type.
   */
  SCOPED_ENUM type typ() const noexcept
  {
    return typ_;
  }

  /**
   * Add a header to the JWT header.
   */
  template <typename T,
            typename=std::enable_if_t<
                      !std::is_same<jwt::string_view, std::decay_t<T>>::value
                     >
           >
  bool add_header(const jwt::string_view hname, T&& hvalue, bool overwrite=false)
  {
    auto itr = headers_.find(hname);
    if (itr != std::end(headers_) && !overwrite) {
      return false;
    }

    headers_.emplace(hname.data(), hname.length());
    payload_[hname.data()] = std::forward<T>(hvalue);

    return true;
  }

  /**
   * Add a header to the JWT header.
   * Overload which takes the header value as `jwt::string_view`
   */
  bool add_header(const jwt::string_view cname, const jwt::string_view cvalue, bool overwrite=false)
  {
    return add_header(cname,
                      std::string{cvalue.data(), cvalue.length()},
                      overwrite);
  }

  /**
   * Remove the header from JWT.
   * NOTE: Special handling for removing type field
   * from header. The typ_ is set to NONE when removed.
   */
  bool remove_header(const jwt::string_view hname)
  {
    if (!strcasecmp(hname.data(), "typ")) {
      typ_ = type::NONE;
      payload_.erase(hname.data());
      return true;
    }

    auto itr = headers_.find(hname);
    if (itr == std::end(headers_)) {
      return false;
    }
    payload_.erase(hname.data());
    headers_.erase(hname.data());

    return true;
  }

  /**
   * Checks if header with the given name
   * is present or not.
   */
  bool has_header(const jwt::string_view hname)
  {
    if (!strcasecmp(hname.data(), "typ")) return typ_ != type::NONE;
    return headers_.find(hname) != std::end(headers_);
  }


  /**
   * Get the URL safe base64 encoded string
   * of the header.
   */
  //TODO: error code ?
  std::string encode(bool pprint = false)
  {
    return base64_encode(pprint);
  }

  /**
   * Decodes the base64 encoded string to JWT header.
   * @note: Overwrites the data member of this instance
   * with the decoded values.
   *
   * This API takes an error_code to set the error instead
   * of throwing an exception.
   *
   * @note: Exceptions related to memory allocation failures
   * are not translated to an error_code. The API would
   * still throw an exception in those cases.
   */
  void decode(const jwt::string_view enc_str, std::error_code& ec);

  /**
   * Exception throwing API version of decode.
   * Throws `DecodeError` exception.
   * Could also throw memory allocation failure
   * exceptions.
   */
  void decode(const jwt::string_view enc_str);

  /**
   * Creates a `json_t` object this class instance.
   * @note: Presence of this member function is a requirement
   * for some interfaces (Eg: `write_interface`).
   */
  const json_t& create_json_obj() const
  {
    return payload_;
  }

private: // Data members
  /// The Algorithm to use for signature creation
  SCOPED_ENUM algorithm alg_ = algorithm::NONE;

  /// The type of header
  SCOPED_ENUM type      typ_ = type::JWT;

  // The JSON payload object
  json_t payload_;

  //Extra headers for JWS
  jwt_set::header_claim_set_t headers_; 
};


/**
 * Component class representing JWT Payload.
 * The payload is nothing but a set of claims
 * which are directly written into a JSON object.
 */
struct jwt_payload: write_interface
                  , base64_enc_dec<jwt_payload>
{
public: // 'tors
  /**
   * Default constructor.
   */
  jwt_payload() = default;

  /**
   * Construct the payload from an encoded string.
   * TODO: Throw an exception in case of error.
   */
  jwt_payload(const jwt::string_view enc_str)
  {
    this->decode(enc_str);
  }

  /// Default copy and assignment operations
  jwt_payload(const jwt_payload&) = default;
  jwt_payload& operator=(const jwt_payload&) = default;

  ~jwt_payload() = default;

public: // Exposed APIs
  /**
   * Add a claim to the set.
   * Parameters:
   * cname - The name of the claim.
   * cvalue - Value of the claim.
   * overwrite - Over write the value if already present.
   *
   * @note: This overload works for all value types which
   * are:
   * a) _not_ an instance of type system_time_t.
   * b) _not_ an instance of type jwt::string_view.
   * c) can be written to `json_t` object.
   */
  template <typename T,
            typename=typename std::enable_if_t<
              !std::is_same<system_time_t, std::decay_t<T>>::value ||
              !std::is_same<jwt::string_view, std::decay_t<T>>::value
              >
           >
  bool add_claim(const jwt::string_view cname, T&& cvalue, bool overwrite=false)
  {
    // Duplicate claim names not allowed
    // if overwrite flag is set to true.
    auto itr = claim_names_.find(cname);
    if (itr != claim_names_.end() && !overwrite) {
      return false;
    }

    // Add it to the known set of claims
    claim_names_.emplace(cname.data(), cname.length());

    //Add it to the json payload
    payload_[cname.data()] = std::forward<T>(cvalue);

    return true;
  }

  /**
   * Adds a claim.
   * This overload takes string claim value.
   */
  bool add_claim(const jwt::string_view cname, const jwt::string_view cvalue, bool overwrite=false)
  {
    return add_claim(cname, std::string{cvalue.data(), cvalue.length()}, overwrite);
  }

  /**
   * Adds a claim.
   * This overload takes system_time_t claim value.
   * @note: Useful for providing timestamp as the claim value.
   */
  bool add_claim(const jwt::string_view cname, system_time_t tp, bool overwrite=false)
  {
    return add_claim(
        cname,
        std::chrono::duration_cast<
          std::chrono::seconds>(tp.time_since_epoch()).count(),
        overwrite
        );
  }

  /**
   * Adds a claim.
   * This overload takes `registered_claims` as the claim name.
   */
  template <typename T,
            typename=std::enable_if_t<
                      !std::is_same<std::decay_t<T>, system_time_t>::value ||
                      !std::is_same<std::decay_t<T>, jwt::string_view>::value
                     >>
  bool add_claim(SCOPED_ENUM registered_claims cname, T&& cvalue, bool overwrite=false)
  {
    return add_claim(
        reg_claims_to_str(cname),
        std::forward<T>(cvalue),
        overwrite
        );
  }

  /**
   * Adds a claim.
   * This overload takes `registered_claims` as the claim name and
   * `system_time_t` as the claim value type.
   */
  bool add_claim(SCOPED_ENUM registered_claims cname, system_time_t tp, bool overwrite=false)
  {
    return add_claim(
        reg_claims_to_str(cname),
        std::chrono::duration_cast<
          std::chrono::seconds>(tp.time_since_epoch()).count(),
        overwrite
        );
  }

  /**
   * Adds a claim.
   * This overload takes `registered_claims` as the claim name and
   * `jwt::string_view` as the claim value type.
   */
  bool add_claim(SCOPED_ENUM registered_claims cname, jwt::string_view cvalue, bool overwrite=false)
  {
    return add_claim(
          reg_claims_to_str(cname),
          std::string{cvalue.data(), cvalue.length()},
          overwrite
        );
  }

  /**
   * Gets the claim value provided the claim value name.
   * @note: The claim name used here is Case Sensitive.
   *
   * The template type `T` is what the user expects the value
   * type to be. If the type provided is incompatible the underlying
   * JSON library will throw an exception.
   */
  template <typename T>
  decltype(auto) get_claim_value(const jwt::string_view cname) const
  {
    return payload_[cname.data()].get<T>();
  }

  /**
   * Gets the claim value provided the claim value name.
   * This overload takes the claim name as an instance of 
   * type `registered_claims`.
   *
   * The template type `T` is what the user expects the value
   * type to be. If the type provided is incompatible the underlying
   * JSON library will throw an exception.
   */
  template <typename T>
  decltype(auto) get_claim_value(SCOPED_ENUM registered_claims cname) const
  {
    return get_claim_value<T>(reg_claims_to_str(cname));
  }

  /**
   * Remove a claim identified by a claim name.
   */
  bool remove_claim(const jwt::string_view cname)
  {
    auto itr = claim_names_.find(cname);
    if (itr == claim_names_.end()) return false;

    claim_names_.erase(itr);
    payload_.erase(cname.data());

    return true;
  }

  /**
   * Remove a claim.
   * Overload which takes the claim name as an instance 
   * of `registered_claims` type.
   */
  bool remove_claim(SCOPED_ENUM registered_claims cname)
  {
    return remove_claim(reg_claims_to_str(cname));
  }

  /**
   * Checks whether a claim is present in the payload 
   * or not.
   * @note: Claim name is case sensitive for this API.
   */
  //TODO: Not all libc++ version agrees with this
  //because count() is not made const for is_transparent
  //based overload
  bool has_claim(const jwt::string_view cname) const noexcept
  {
    return claim_names_.find(cname) != std::end(claim_names_);
  }

  /**
   * Checks whether a claim is present in the payload or 
   * not.
   * Overload which takes the claim name as an instance
   * of `registered_claims` type.
   */
  bool has_claim(SCOPED_ENUM registered_claims cname) const noexcept
  {
    return has_claim(reg_claims_to_str(cname));
  }

  /**
   * Checks whether there is claim with a specific
   * value in the payload.
   */
  template <typename T>
  bool has_claim_with_value(const jwt::string_view cname, T&& cvalue) const
  {
    auto itr = claim_names_.find(cname);
    if (itr == claim_names_.end()) return false;

    return (cvalue == payload_[cname.data()]);
  }

  /**
   * Checks whether there is claim with a specific 
   * value in the payload.
   * Overload which takes the claim name as an instance of
   * type `registered_claims`.
   */
  template <typename T>
  bool has_claim_with_value(const SCOPED_ENUM registered_claims cname, T&& value) const
  {
    return has_claim_with_value(reg_claims_to_str(cname), std::forward<T>(value));
  }

  /**
   * Encodes the payload as URL safe Base64 encoded
   * string.
   */
  std::string encode(bool pprint = false)
  {
    return base64_encode(pprint);
  }

  /**
   * Decodes an encoded string and overwrites the payload
   * as per the encoded information.
   *
   * This version of API reports error via std::error_code.
   *
   * @note: Allocation failures are still thrown out
   * as exceptions.
   */
  void decode(const jwt::string_view enc_str, std::error_code& ec);

  /**
   * Overload of decode API which throws exception
   * on any failure.
   *
   * Throws DecodeError on failure.
   */
  void decode(const jwt::string_view enc_str);

  /**
   * Creates a JSON object of the payload.
   *
   * The presence of this API is required for 
   * making it work with `write_interface`.
   */
  const json_t& create_json_obj() const
  {
    return payload_;
  }

private:

  /// JSON object containing payload
  json_t payload_;
  /// The set of claim names in the payload
  jwt_set::header_claim_set_t claim_names_;
};

/**
 * Component class for representing JWT signature.
 *
 * Provides APIs for:
 * a) Encoding header and payload to JWS string parts.
 * b) Verifying the signature by matching it with header and payload
 * signature.
 */
struct jwt_signature
{
public: // 'tors
  /// Default constructor
  jwt_signature() = default;

  /**
   * Constructor which takes the key.
   */
  jwt_signature(const jwt::string_view key)
    : key_(key.data(), key.length())
  {
  }

  /// Default copy and assignment operator
  jwt_signature(const jwt_signature&) = default;
  jwt_signature& operator=(const jwt_signature&) = default;

  ~jwt_signature() = default;

public: // Exposed APIs
  /**
   * Encodes the header and payload to get the
   * three part JWS signature.
   */
  std::string encode(const jwt_header& header, 
                     const jwt_payload& payload,
                     std::error_code& ec);

  /**
   * Verifies the JWS signature.
   * Returns `verify_result_t` which is a pair
   * of bool and error_code.
   */
  verify_result_t verify(const jwt_header& header,
              const jwt::string_view hdr_pld_sign,
              const jwt::string_view jwt_sign);

private: // Private implementation
  /*!
   */
  sign_func_t get_sign_algorithm_impl(const jwt_header& hdr) const noexcept;

  /*!
   */
  verify_func_t get_verify_algorithm_impl(const jwt_header& hdr) const noexcept;

private: // Data members;

  /// The key for creating the JWS
  std::string key_;
};


/**
 * The main class representing the JWT object.
 * It is a composition of all JWT composition classes.
 *
 * @note: This class does not provide all the required
 * APIs in its public interface. Instead the class provides 
 * `header()` and `payload()` APIs. Those can be used to 
 * access more public APIs specific to those components.
 */
class jwt_object
{
public: // 'tors
  /**
   * Default constructor.
   */
  jwt_object() = default;

  /**
   * Takes a variadic set of parameters.
   * Each type must satisfy the
   * `ParameterConcept` concept.
   *
   * The parameters that can be passed:
   * 1. payload : Can pass a initializer list of pairs or any associative
   * containers which models `MappingConcept` (see `meta::is_mapping_concept`) 
   * to populate claims. Use `add_claim` for more controlled additions.
   *
   * 2. secret : The secret to be used for generating and verification
   * of JWT signature. Not required for NONE algorithm.
   *
   * 3. algorithm : The algorithm to be used for signing and decoding.
   *
   * 4. headers : Can pass a initializer list of pairs or any associative
   * containers which models `MappingConcept` (see `meta::is_mapping_concept`)
   * to populate header. Not much useful unless JWE is supported.
   */
  template <typename First, typename... Rest,
            typename=std::enable_if_t<detail::meta::is_parameter_concept<First>::value>>
  jwt_object(First&& first, Rest&&... rest);

public: // Exposed static APIs
  /**
   * Splitsa JWT string into its three parts
   * using dot('.') as the delimiter.
   *
   * @note: Instead of actually splitting the API
   * simply provides an array of view.
   */
  static std::array<jwt::string_view, 3>
  three_parts(const jwt::string_view enc_str);

public: // Exposed APIs
  /**
   * Returns the payload component object by reference.
   */
  jwt_payload& payload() noexcept
  {
    return payload_;
  }

  /**
   * Returns the payload component object by const-reference.
   */
  const jwt_payload& payload() const noexcept
  {
    return payload_;
  }

  /**
   * Sets the payload component object.
   */
  void payload(const jwt_payload& p)
  {
    payload_ = p;
  }

  /**
   * Sets the payload component object.
   * Takes the payload object as rvalue-reference.
   */
  void payload(jwt_payload&& p)
  {
    payload_ = std::move(p);
  }

  /**
   * Sets the header component object.
   */
  void header(const jwt_header& h)
  {
    header_ = h;
  }

  /**
   * Sets the header component object.
   * Takes the header object as rvalue-reference.
   */
  void header(jwt_header&& h)
  {
    header_ = std::move(h);
  }

  /**
   * Get the header component object as reference.
   */
  jwt_header& header() noexcept
  {
    return header_;
  }

  /**
   * Get the header component object as const-reference.
   */
  const jwt_header& header() const noexcept
  {
    return header_;
  }

  /**
   * Get the secret to be used for signing.
   */
  std::string secret() const
  {
    return secret_;
  }

  /**
   * Set the secret to be used for signing.
   */
  void secret(const jwt::string_view sv)
  {
    secret_.assign(sv.data(), sv.length());
  }

  /**
   * Provides the glue interface for adding claim.
   * @note: See `jwt_payload::add_claim` for more details.
   */
  template <typename T,
            typename=typename std::enable_if_t<
              !std::is_same<system_time_t, std::decay_t<T>>::value>>
  jwt_object& add_claim(const jwt::string_view name, T&& value)
  {
    payload_.add_claim(name, std::forward<T>(value));
    return *this;
  }

  /**
   * Provides the glue interface for adding claim.
   *
   * @note: See `jwt_payload::add_claim` for more details.
   *
   * Specialization for time points.
   * Eg: Users can set `exp` claim to `chrono::system_clock::now()`.
   */
  jwt_object& add_claim(const jwt::string_view name, system_time_t time_point);

  /**
   * Provides the glue interface for adding claim.
   * Overload for taking claim name as `registered_claims` instance.
   *
   * @note: See `jwt_payload::add_claim` for more details.
   */
  template <typename T>
  jwt_object& add_claim(SCOPED_ENUM registered_claims cname, T&& value)
  {
    return add_claim(reg_claims_to_str(cname), std::forward<T>(value));
  }

  /**
   * Provides the glue interface for removing claim.
   *
   * @note: See `jwt_payload::remove_claim` for more details.
   */
  jwt_object& remove_claim(const jwt::string_view name);

  /**
   * Provides the glue interface for removing claim.
   *
   * @note: See `jwt_payload::remove_claim` for more details.
   */
  jwt_object& remove_claim(SCOPED_ENUM registered_claims cname)
  {
    return remove_claim(reg_claims_to_str(cname));
  }

  /**
   * Provides the glue interface for checking if a claim is present
   * or not.
   *
   * @note: See `jwt_payload::has_claim` for more details.
   */
  bool has_claim(const jwt::string_view cname) const noexcept
  {
    return payload().has_claim(cname);
  }

  /**
   * Provides the glue interface for checking if a claim is present
   * or not.
   *
   * @note: See `jwt_payload::has_claim` for more details.
   */
  bool has_claim(SCOPED_ENUM registered_claims cname) const noexcept
  {
    return payload().has_claim(cname);
  }

  /**
   * Generate the JWS for the header + payload using the secret.
   * This version takes the error_code for reporting errors.
   *
   * @note: The API would still throw for memory allocation exceptions
   * (`std::bad_alloc` or `jwt::MemoryAllocationException`)
   *  or exceptions thrown by user types.
   */
  std::string signature(std::error_code& ec) const;

  /**
   * Generate the JWS for the header + payload using the secret.
   * Exception throwing version.
   */
  std::string signature() const;

  /**
   * Verify the signature.
   * TODO: Returns an error_code instead of taking
   * by reference.
   */
  template <typename Params, typename SequenceT>
  std::error_code verify(
      const Params& dparams,
      const params::detail::algorithms_param<SequenceT>& algos) const;

private: // private APIs
  /**
   */
  template <typename... Args>
  void set_parameters(Args&&... args);

  /**
   */
  template <typename M, typename... Rest>
  void set_parameters(params::detail::payload_param<M>&&, Rest&&...);

  /**
   */
  template <typename... Rest>
  void set_parameters(params::detail::secret_param, Rest&&...);

  /**
   */
  template <typename... Rest>
  void set_parameters(params::detail::algorithm_param, Rest&&...);

  /**
   */
  template <typename M, typename... Rest>
  void set_parameters(params::detail::headers_param<M>&&, Rest&&...);

  /**
   */
  void set_parameters();

public: //TODO: Not good
  /// Decode parameters
  template <typename DecodeParams, typename... Rest>
  static void set_decode_params(DecodeParams& dparams, params::detail::secret_param s, Rest&&... args);

  template <typename DecodeParams, typename T, typename... Rest>
  static void set_decode_params(DecodeParams& dparams, params::detail::secret_function_param<T>&& s, Rest&&... args);

  template <typename DecodeParams, typename... Rest>
  static void set_decode_params(DecodeParams& dparams, params::detail::leeway_param l, Rest&&... args);

  template <typename DecodeParams, typename... Rest>
  static void set_decode_params(DecodeParams& dparams, params::detail::verify_param v, Rest&&... args);

  template <typename DecodeParams, typename... Rest>
  static void set_decode_params(DecodeParams& dparams, params::detail::issuer_param i, Rest&&... args);

  template <typename DecodeParams, typename... Rest>
  static void set_decode_params(DecodeParams& dparams, params::detail::audience_param a, Rest&&... args);

  template <typename DecodeParams, typename... Rest>
  static void set_decode_params(DecodeParams& dparams, params::detail::subject_param a, Rest&&... args);

  template <typename DecodeParams, typename... Rest>
  static void set_decode_params(DecodeParams& dparams, params::detail::validate_iat_param v, Rest&&... args);

  template <typename DecodeParams, typename... Rest>
  static void set_decode_params(DecodeParams& dparams, params::detail::validate_jti_param v, Rest&&... args);

  template <typename DecodeParams>
  static void set_decode_params(DecodeParams& dparams);

private: // Data Members

  /// JWT header section
  jwt_header header_;

  /// JWT payload section
  jwt_payload payload_;

  /// The secret key
  std::string secret_;
};

/**
 * Decode the JWT signature to create the `jwt_object`.
 * This version reports error back using `std::error_code`.
 *
 * If any of the registered claims are found in wrong format
 * then sets TypeConversion error in the error_code.
 *
 * NOTE: Memory allocation exceptions are not caught.
 *
 * Optional parameters that can be passed:
 * 1. verify : A boolean flag to indicate whether
 * the signature should be verified or not.
 * Set to `true` by default.
 *
 * 2. leeway : Number of seconds that can be added (in case of exp)
 * or subtracted (in case of nbf) to be more lenient.
 * Set to `0` by default.
 *
 * 3. algorithms : Takes in a sequence of algorithms which the client
 * expects the signature to be decoded with.
 *
 * 4. aud : The audience the client expects to be in the claim.
 * NOTE: It is case-sensitive.
 *
 * 5. issuer: The issuer the client expects to be in the claim.
 * NOTE: It is case-sensitive
 *
 * 6. sub: The subject the client expects to be in the claim.
 *
 * 7. validate_iat: Checks if IAT claim is present or not
 * and the type is uint64_t or not. If claim is not present
 * then set InvalidIAT error.
 *
 * 8. validate_jti: Checks if jti claim is present or not.
 */
template <typename SequenceT, typename... Args>
jwt_object decode(const jwt::string_view enc_str, 
                  const params::detail::algorithms_param<SequenceT>& algos, 
                  std::error_code& ec,
                  Args&&... args);

/**
 * Decode the JWT signature to create the `jwt_object`.
 * This version reports error back by throwing exceptions.
 */
template <typename SequenceT, typename... Args>
jwt_object decode(const jwt::string_view enc_str,
                  const params::detail::algorithms_param<SequenceT>& algos,
                  Args&&... args);


} // END namespace jwt


#include "jwt/impl/jwt.ipp"

#endif
