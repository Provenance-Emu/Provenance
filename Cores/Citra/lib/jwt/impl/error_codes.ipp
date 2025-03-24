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

#ifndef CPP_JWT_ERROR_CODES_IPP
#define CPP_JWT_ERROR_CODES_IPP

namespace jwt {
// Anonymous namespace
namespace {

/**
 */
struct AlgorithmErrCategory: std::error_category
{
  const char* name() const noexcept override
  {
    return "algorithms";
  }

  std::string message(int ev) const override
  {
    switch (static_cast<AlgorithmErrc>(ev))
    {
    case AlgorithmErrc::SigningErr:
      return "signing failed";
    case AlgorithmErrc::VerificationErr:
      return "verification failed";
    case AlgorithmErrc::KeyNotFoundErr:
      return "key not provided";
    case AlgorithmErrc::NoneAlgorithmUsed:
      return "none algorithm used";
    case AlgorithmErrc::InvalidKeyErr:
      return "invalid key";
    };
    return "unknown algorithm error";
  }
};

/**
 */
struct DecodeErrorCategory: std::error_category
{
  const char* name() const noexcept override
  {
    return "decode";
  }

  std::string message(int ev) const override
  {
    switch (static_cast<DecodeErrc>(ev))
    {
    case DecodeErrc::EmptyAlgoList:
      return "empty algorithm list";
    case DecodeErrc::SignatureFormatError:
      return "signature format is incorrect";
    case DecodeErrc::AlgHeaderMiss:
      return "missing algorithm header";
    case DecodeErrc::TypHeaderMiss:
      return "missing type header";
    case DecodeErrc::TypMismatch:
      return "type mismatch";
    case DecodeErrc::JsonParseError:
      return "json parse failed";
    case DecodeErrc::DuplClaims:
      return "duplicate claims";
    case DecodeErrc::KeyNotPresent:
      return "key not present";
    case DecodeErrc::KeyNotRequiredForNoneAlg:
      return "key not required for NONE algorithm";
    };
    return "unknown decode error";
  }
};

/**
 */
struct VerificationErrorCategory: std::error_category
{
  const char* name() const noexcept override
  {
    return "verification";
  }

  std::string message(int ev) const override
  {
    switch (static_cast<VerificationErrc>(ev))
    {
    case VerificationErrc::InvalidAlgorithm:
      return "invalid algorithm";
    case VerificationErrc::TokenExpired:
      return "token expired";
    case VerificationErrc::InvalidIssuer:
      return "invalid issuer";
    case VerificationErrc::InvalidSubject:
      return "invalid subject";
    case VerificationErrc::InvalidAudience:
      return "invalid audience";
    case VerificationErrc::InvalidIAT:
      return "invalid iat";
    case VerificationErrc::InvalidJTI:
      return "invalid jti";
    case VerificationErrc::ImmatureSignature:
      return "immature signature";
    case VerificationErrc::InvalidSignature:
      return "invalid signature";
    case VerificationErrc::TypeConversionError:
      return "type conversion error";
    };
    return "unknown verification error";
  }
};

// Create global object for the error categories
const AlgorithmErrCategory theAlgorithmErrCategory {};

const DecodeErrorCategory theDecodeErrorCategory {};

const VerificationErrorCategory theVerificationErrorCategory {};

}


// Create the AlgorithmErrc error code
inline std::error_code make_error_code(AlgorithmErrc err)
{
  return { static_cast<int>(err), theAlgorithmErrCategory };
}

inline std::error_code make_error_code(DecodeErrc err)
{
  return { static_cast<int>(err), theDecodeErrorCategory };
}

inline std::error_code make_error_code(VerificationErrc err)
{
  return { static_cast<int>(err), theVerificationErrorCategory };
}

} // END namespace jwt

#endif
