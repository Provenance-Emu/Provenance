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

#ifndef CPP_JWT_ERROR_CODES_HPP
#define CPP_JWT_ERROR_CODES_HPP

#include <system_error>

namespace jwt {
/**
 * All the algorithm errors
 */
enum class AlgorithmErrc
{
  SigningErr = 1,
  VerificationErr,
  KeyNotFoundErr,
  InvalidKeyErr,
  NoneAlgorithmUsed, // Not an actual error!
};

/**
 * Algorithm error conditions
 * TODO: Remove it or use it!
 */
enum class AlgorithmFailureSource
{
};

/**
 * Decode error conditions
 */
enum class DecodeErrc
{
  // No algorithms provided in decode API
  EmptyAlgoList = 1,
  // The JWT signature has incorrect format
  SignatureFormatError,
  // The JSON library failed to parse 
  JsonParseError,
  // Algorithm field in header is missing
  AlgHeaderMiss,
  // Type field in header is missing
  TypHeaderMiss,
  // Unexpected type field value
  TypMismatch,
  // Found duplicate claims
  DuplClaims,
  // Key/Secret not passed as decode argument
  KeyNotPresent,
  // Key/secret passed as argument for NONE algorithm.
  // Not a hard error.
  KeyNotRequiredForNoneAlg,
};

/**
 * Errors handled during verification process.
 */
enum class VerificationErrc
{
  //Algorithms provided does not match with header
  InvalidAlgorithm = 1,
  //Token is expired at the time of decoding
  TokenExpired,
  //The issuer specified does not match with payload
  InvalidIssuer,
  //The subject specified does not match with payload
  InvalidSubject,
  //The field IAT is not present or is of invalid type
  InvalidIAT,
  //Checks for the existence of JTI
  //if validate_jti is passed in decode
  InvalidJTI,
  //The audience specified does not match with payload
  InvalidAudience,
  //Decoded before nbf time
  ImmatureSignature,
  //Signature match error
  InvalidSignature,
  // Invalid value type used for known claims
  TypeConversionError,
};

/**
 */
std::error_code make_error_code(AlgorithmErrc err);

/**
 */
std::error_code make_error_code(DecodeErrc err);

/**
 */
std::error_code make_error_code(VerificationErrc err);

} // END namespace jwt


/**
 * Make the custom enum classes as error code
 * adaptable.
 */
namespace std
{
  template <>
  struct is_error_code_enum<jwt::AlgorithmErrc> : true_type {};

  template <>
  struct is_error_code_enum<jwt::DecodeErrc>: true_type {};

  template <>
  struct is_error_code_enum<jwt::VerificationErrc>: true_type {};
}

#include "jwt/impl/error_codes.ipp"

#endif
