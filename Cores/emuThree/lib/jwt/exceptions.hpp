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

#ifndef CPP_JWT_EXCEPTIONS_HPP
#define CPP_JWT_EXCEPTIONS_HPP

#include <new>
#include <string>

namespace jwt {

/**
 * Exception for allocation related failures in the 
 * OpenSSL C APIs.
 */
class MemoryAllocationException final: public std::bad_alloc
{
public:
  /**
   * Construct MemoryAllocationException from a
   * string literal.
   */
  template <size_t N>
  MemoryAllocationException(const char(&msg)[N])
    : msg_(&msg[0])
  {
  }

  virtual const char* what() const noexcept override
  {
    return msg_;
  }

private:
  const char* msg_ = nullptr;
};

/**
 * Exception thrown for failures in OpenSSL
 * APIs while signing.
 */
class SigningError : public std::runtime_error
{
public:
  /**
   */
  SigningError(std::string msg)
    : std::runtime_error(std::move(msg))
  {
  }
};

/**
 * Exception thrown for decode related errors.
 */
class DecodeError: public std::runtime_error
{
public:
  /**
   */
  DecodeError(std::string msg)
    : std::runtime_error(std::move(msg))
  {
  }
};

/**
 * A derived decode error for signature format
 * error.
 */
class SignatureFormatError final : public DecodeError
{
public:
  /**
   */
  SignatureFormatError(std::string msg)
    : DecodeError(std::move(msg))
  {
  }
};

/**
 * A derived decode error for Key argument not present
 * error. Only thrown if the algorithm set is not NONE.
 */
class KeyNotPresentError final : public DecodeError
{
public:
  /**
   */
  KeyNotPresentError(std::string msg)
    : DecodeError(std::move(msg))
  {
  }
};


/**
 * Base class exception for all kinds of verification errors.
 * Verification errors are thrown only when the verify
 * decode parameter is set to true.
 */
class VerificationError : public std::runtime_error
{
public:
  /**
   */
  VerificationError(std::string msg)
    : std::runtime_error(std::move(msg))
  {
  }
};

/**
 * Derived from VerificationError.
 * Thrown when the algorithm decoded in the header
 * is incorrect.
 */
class InvalidAlgorithmError final: public VerificationError
{
public:
  /**
   */
  InvalidAlgorithmError(std::string msg)
    : VerificationError(std::move(msg))
  {
  }
};

/**
 * Derived from VerificationError.
 * Thrown when the token is expired at the
 * time of decoding.
 */
class TokenExpiredError final: public VerificationError
{
public:
  /**
   */
  TokenExpiredError(std::string msg)
    : VerificationError(std::move(msg))
  {
  }
};

/**
 * Derived from VerificationError.
 * Thrown when the issuer claim does not match
 * with the one provided as part of decode argument.
 */
class InvalidIssuerError final: public VerificationError
{
public:
  /**
   */
  InvalidIssuerError(std::string msg)
    : VerificationError(std::move(msg))
  {
  }
};

/**
 * Derived from VerificationError.
 * Thrown when the audience claim does not match
 * with the one provided as part of decode argument.
 */
class InvalidAudienceError final: public VerificationError
{
public:
  /**
   */
  InvalidAudienceError(std::string msg)
    : VerificationError(std::move(msg))
  {
  }
};

/**
 * Derived from VerificationError.
 * Thrown when the subject claim does not match
 * with the one provided as part of decode argument.
 */
class InvalidSubjectError final: public VerificationError
{
public:
  /**
   */
  InvalidSubjectError(std::string msg)
    : VerificationError(std::move(msg))
  {
  }
};

/**
 * Derived from VerificationError.
 * Thrown when verify_iat parameter is passed to
 * decode and IAT is not present.
 */
class InvalidIATError final: public VerificationError
{
public:
  /**
   */
  InvalidIATError(std::string msg)
    : VerificationError(std::move(msg))
  {
  }
};

/**
 * Derived from VerificationError.
 * Thrown when validate_jti is asked for
 * in decode and jti claim is not present.
 */
class InvalidJTIError final: public VerificationError
{
public:
  /**
   */
  InvalidJTIError(std::string msg)
    : VerificationError(std::move(msg))
  {
  }
};

/**
 * Derived from VerificationError.
 * Thrown when the token is decoded at a time before
 * as specified in the `nbf` claim.
 */
class ImmatureSignatureError final: public VerificationError
{
public:
  /**
   */
  ImmatureSignatureError(std::string msg)
    : VerificationError(std::move(msg))
  {
  }
};

/**
 * Derived from VerificationError.
 * Thrown when the signature does not match in the verification process.
 */
class InvalidSignatureError final: public VerificationError
{
public:
  /**
   */
  InvalidSignatureError(std::string msg)
    : VerificationError(std::move(msg))
  {
  }
};

class InvalidKeyError final: public VerificationError
{
public:
  /**
   */
  InvalidKeyError(std::string msg)
	: VerificationError(std::move(msg))
  {
  }
};

/**
 * Derived from VerificationError.
 * Thrown when there type expectation mismatch
 * while verifying the values of registered claim names.
 */
class TypeConversionError final: public VerificationError
{
public:
  /**
   */
  TypeConversionError(std::string msg)
    : VerificationError(std::move(msg))
  {
  }
};

} // END namespace jwt

#endif
