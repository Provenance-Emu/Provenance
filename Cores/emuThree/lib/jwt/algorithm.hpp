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

#ifndef CPP_JWT_ALGORITHM_HPP
#define CPP_JWT_ALGORITHM_HPP

/*!
 * Most of the signing and verification code has been taken
 * and modified for C++ specific use from the C implementation
 * JWT library, libjwt.
 * https://github.com/benmcollins/libjwt/tree/master/libjwt
 */

#include <cassert>
#include <memory>
#include <system_error>

#include <openssl/bn.h>
#include <openssl/bio.h>
#include <openssl/pem.h>
#include <openssl/evp.h>
#include <openssl/hmac.h>
#include <openssl/ecdsa.h>
#include <openssl/buffer.h>
#include <openssl/opensslv.h>

#include "jwt/assertions.hpp"
#include "jwt/exceptions.hpp"
#include "jwt/string_view.hpp"
#include "jwt/error_codes.hpp"
#include "jwt/base64.hpp"
#include "jwt/config.hpp"

namespace jwt {

/// The result type of the signing function
using sign_result_t = std::pair<std::string, std::error_code>;
/// The result type of verification function
using verify_result_t = std::pair<bool, std::error_code>;
/// The function pointer type for the signing function
using sign_func_t   = sign_result_t (*) (const jwt::string_view key,
                                         const jwt::string_view data);
/// The function pointer type for the verifying function
using verify_func_t = verify_result_t (*) (const jwt::string_view key,
                                           const jwt::string_view head,
                                           const jwt::string_view jwt_sign);

namespace algo {

//Me: TODO: All these can be done using code generaion.
//Me: NO. NEVER. I hate Macros.
//Me: You can use templates too.
//Me: No. I would rather prefer explicit.
//Me: Ok. You win.
//Me: Same to you.

/**
 * HS256 algorithm.
 */
struct HS256
{
  const EVP_MD* operator()() noexcept
  {
    return EVP_sha256();
  }
};

/**
 * HS384 algorithm.
 */
struct HS384
{
  const EVP_MD* operator()() noexcept
  {
    return EVP_sha384();
  }
};

/**
 * HS512 algorithm.
 */
struct HS512
{
  const EVP_MD* operator()() noexcept
  {
    return EVP_sha512();
  }
};

/**
 * NONE algorithm.
 */
struct NONE
{
  void operator()() noexcept
  {
    return;
  }
};

/**
 * RS256 algorithm.
 */
struct RS256
{
  static const int type = EVP_PKEY_RSA;

  const EVP_MD* operator()() noexcept
  {
    return EVP_sha256();
  }
};

/**
 * RS384 algorithm.
 */
struct RS384
{
  static const int type = EVP_PKEY_RSA;

  const EVP_MD* operator()() noexcept
  {
    return EVP_sha384();
  }
};

/**
 * RS512 algorithm.
 */
struct RS512
{
  static const int type = EVP_PKEY_RSA;

  const EVP_MD* operator()() noexcept
  {
    return EVP_sha512();
  }
};

/**
 * ES256 algorithm.
 */
struct ES256
{
  static const int type = EVP_PKEY_EC;

  const EVP_MD* operator()() noexcept
  {
    return EVP_sha256();
  }
};

/**
 * ES384 algorithm.
 */
struct ES384
{
  static const int type = EVP_PKEY_EC;

  const EVP_MD* operator()() noexcept
  {
    return EVP_sha384();
  }
};

/**
 * ES512 algorithm.
 */
struct ES512
{
  static const int type = EVP_PKEY_EC;

  const EVP_MD* operator()() noexcept
  {
    return EVP_sha512();
  }
};

} //END Namespace algo


/**
 * JWT signing algorithm types.
 */
enum class algorithm
{
  NONE = 0,
  HS256,
  HS384,
  HS512,
  RS256,
  RS384,
  RS512,
  ES256,
  ES384,
  ES512,
  UNKN,
  TERM,
};


/**
 * Convert the algorithm enum class type to
 * its stringified form.
 */
inline jwt::string_view alg_to_str(SCOPED_ENUM algorithm alg) noexcept
{
  switch (alg) {
    case algorithm::HS256: return "HS256";
    case algorithm::HS384: return "HS384";
    case algorithm::HS512: return "HS512";
    case algorithm::RS256: return "RS256";
    case algorithm::RS384: return "RS384";
    case algorithm::RS512: return "RS512";
    case algorithm::ES256: return "ES256";
    case algorithm::ES384: return "ES384";
    case algorithm::ES512: return "ES512";
    case algorithm::TERM:  return "TERM";
    case algorithm::NONE:  return "NONE";
    case algorithm::UNKN:  return "UNKN";
    default:               assert (0 && "Unknown Algorithm");
  };
  return "UNKN";
  JWT_NOT_REACHED("Code not reached");
}

/**
 * Convert stringified algorithm to enum class.
 * The string comparison is case insesitive.
 */
inline SCOPED_ENUM algorithm str_to_alg(const jwt::string_view alg) noexcept
{
  if (!alg.length()) return algorithm::UNKN;

  if (!strcasecmp(alg.data(), "NONE"))  return algorithm::NONE;
  if (!strcasecmp(alg.data(), "HS256")) return algorithm::HS256;
  if (!strcasecmp(alg.data(), "HS384")) return algorithm::HS384;
  if (!strcasecmp(alg.data(), "HS512")) return algorithm::HS512;
  if (!strcasecmp(alg.data(), "RS256")) return algorithm::RS256;
  if (!strcasecmp(alg.data(), "RS384")) return algorithm::RS384;
  if (!strcasecmp(alg.data(), "RS512")) return algorithm::RS512;
  if (!strcasecmp(alg.data(), "ES256")) return algorithm::ES256;
  if (!strcasecmp(alg.data(), "ES384")) return algorithm::ES384;
  if (!strcasecmp(alg.data(), "ES512")) return algorithm::ES512;

  return algorithm::UNKN;

  JWT_NOT_REACHED("Code not reached");
}

/**
 */
inline void bio_deletor(BIO* ptr)
{
  if (ptr) BIO_free_all(ptr);
}

/**
 */
inline void evp_md_ctx_deletor(EVP_MD_CTX* ptr)
{
  if (ptr) EVP_MD_CTX_destroy(ptr);
}

/**
 */
inline void ec_key_deletor(EC_KEY* ptr)
{
  if (ptr) EC_KEY_free(ptr);
}

/**
 */
inline void ec_sig_deletor(ECDSA_SIG* ptr)
{
  if (ptr) ECDSA_SIG_free(ptr);
}

/**
 */
inline void ev_pkey_deletor(EVP_PKEY* ptr)
{
  if (ptr) EVP_PKEY_free(ptr);
}

/// Useful typedefs
using bio_deletor_t = decltype(&bio_deletor);
using BIO_uptr = std::unique_ptr<BIO, bio_deletor_t>;

using evp_mdctx_deletor_t = decltype(&evp_md_ctx_deletor);
using EVP_MDCTX_uptr = std::unique_ptr<EVP_MD_CTX, evp_mdctx_deletor_t>;

using eckey_deletor_t = decltype(&ec_key_deletor);
using EC_KEY_uptr = std::unique_ptr<EC_KEY, eckey_deletor_t>;

using ecsig_deletor_t = decltype(&ec_sig_deletor);
using EC_SIG_uptr = std::unique_ptr<ECDSA_SIG, ecsig_deletor_t>;

using evpkey_deletor_t = decltype(&ev_pkey_deletor);
using EC_PKEY_uptr = std::unique_ptr<EVP_PKEY, evpkey_deletor_t>;



/**
 * OpenSSL HMAC based signature and verfication.
 *
 * The template type `Hasher` takes the type representing
 * the HMAC algorithm type from the `jwt::algo` namespace.
 *
 * The struct is specialized for NONE algorithm. See the
 * details of that class as well.
 */
template <typename Hasher>
struct HMACSign
{
  /// The type of Hashing algorithm
  using hasher_type = Hasher;

  /**
   * Signs the input using the HMAC algorithm using the
   * provided key.
   *
   * Arguments:
   *  @key : The secret/key to use for the signing.
   *         Cannot be empty string.
   *  @data : The data to be signed.
   *
   *  Exceptions:
   *    Any allocation failure will result in jwt::MemoryAllocationException
   *    being thrown.
   */
  static sign_result_t sign(const jwt::string_view key, const jwt::string_view data)
  {
    std::string sign;
    sign.resize(EVP_MAX_MD_SIZE);
    std::error_code ec{};

    uint32_t len = 0;

    unsigned char* res = HMAC(Hasher{}(),
                              key.data(),
                              static_cast<int>(key.length()),
                              reinterpret_cast<const unsigned char*>(data.data()),
                              data.length(),
                              reinterpret_cast<unsigned char*>(&sign[0]),
                              &len);
    if (!res) {
      ec = AlgorithmErrc::SigningErr;
    }

    sign.resize(len);
    return { std::move(sign), ec };
  }

  /**
   * Verifies the JWT string against the signature using
   * the provided key.
   *
   * Arguments:
   *  @key : The secret/key to use for the signing.
   *         Cannot be empty string.
   *  @head : The part of JWT encoded string representing header
   *          and the payload claims.
   *  @sign : The signature part of the JWT encoded string.
   *
   *  Returns:
   *    verify_result_t
   *    verify_result_t::first set to true if verification succeeds.
   *    false otherwise.
   *    verify_result_t::second set to relevant error if verification fails.
   *
   *  Exceptions:
   *    Any allocation failure will result in jwt::MemoryAllocationException
   *    being thrown.
   */
  static verify_result_t
  verify(const jwt::string_view key, const jwt::string_view head, const jwt::string_view sign);

};

/**
 * Specialization of `HMACSign` class
 * for NONE algorithm.
 *
 * This specialization is selected for even
 * PEM based algorithms.
 *
 * The signing and verification APIs are
 * basically no-op except that they would
 * set the relevant error code.
 *
 * NOTE: error_code would be set in the case
 * of usage of NONE algorithm.
 * Users of this API are expected to check for
 * the case explicitly.
 */
template <>
struct HMACSign<algo::NONE>
{
  using hasher_type = algo::NONE;

  /**
   * Basically a no-op. Sets the error code to NoneAlgorithmUsed.
   */
  static sign_result_t sign(const jwt::string_view key, const jwt::string_view data)
  {
    (void)key;
    (void)data;
    std::error_code ec{};
    ec = AlgorithmErrc::NoneAlgorithmUsed;

    return { std::string{}, ec };
  }

  /**
   * Basically a no-op. Sets the error code to NoneAlgorithmUsed.
   */
  static verify_result_t
  verify(const jwt::string_view key, const jwt::string_view head, const jwt::string_view sign)
  {
    (void)key;
    (void)head;
    (void)sign;
    std::error_code ec{};
    ec = AlgorithmErrc::NoneAlgorithmUsed;

    return { true, ec };
  }

};



/**
 * OpenSSL PEM based signature and verfication.
 *
 * The template type `Hasher` takes the type representing
 * the PEM algorithm type from the `jwt::algo` namespace.
 *
 * For NONE algorithm, HMACSign<> specialization is used.
 * See that for more details.
 */
template <typename Hasher>
struct PEMSign
{
public:
  /// The type of Hashing algorithm
  using hasher_type = Hasher;

  /**
   * Signs the input data using PEM encryption algorithm.
   *
   * Arguments:
   *  @key : The key/secret to be used for signing.
   *         Cannot be an empty string.
   *  @data: The data to be signed.
   *
   * Exceptions:
   *  Any allocation failure would be thrown out as
   *  jwt::MemoryAllocationException.
   */
  static sign_result_t sign(const jwt::string_view key, const jwt::string_view data)
  {
    std::error_code ec{};

    std::string ii{data.data(), data.length()};

    EC_PKEY_uptr pkey{load_key(key, ec), ev_pkey_deletor};
    if (ec) return { std::string{}, ec };

    //TODO: Use stack string here ?
    std::string sign = evp_digest(pkey.get(), data, ec);

    if (ec) return { std::string{}, ec };

    if (Hasher::type == EVP_PKEY_EC) {
      sign = public_key_ser(pkey.get(), sign, ec);
    }

    return { std::move(sign), ec };
  }

  /**
   */
  static verify_result_t
  verify(const jwt::string_view key, const jwt::string_view head, const jwt::string_view sign);

private:

  /*!
   */
  static EVP_PKEY* load_key(const jwt::string_view key, std::error_code& ec);

  /*!
   */
  static std::string evp_digest(EVP_PKEY* pkey, const jwt::string_view data, std::error_code& ec);

  /*!
   */
  static std::string public_key_ser(EVP_PKEY* pkey, jwt::string_view sign, std::error_code& ec);

#if defined(OPENSSL_VERSION_NUMBER) && OPENSSL_VERSION_NUMBER < 0x10100000L || defined(LIBRESSL_VERSION_NUMBER) && LIBRESSL_VERSION_NUMBER < 0x20700000L


  //ATTN: Below 2 functions
  //are Taken from https://github.com/nginnever/zogminer/issues/39

  /**
   */
  static void ECDSA_SIG_get0(const ECDSA_SIG* sig, const BIGNUM** pr, const BIGNUM** ps)
  {
    if (pr != nullptr) *pr = sig->r;
    if (ps != nullptr) *ps = sig->s;
  };

  /**
   */
  static int ECDSA_SIG_set0(ECDSA_SIG* sig, BIGNUM* r, BIGNUM* s)
  {
    if (r == nullptr || s == nullptr) return 0;

    BN_clear_free(sig->r);
    BN_clear_free(sig->s);

    sig->r = r;
    sig->s = s;
    return 1;
  }

#endif
};

} // END namespace jwt

#include "jwt/impl/algorithm.ipp"


#endif
