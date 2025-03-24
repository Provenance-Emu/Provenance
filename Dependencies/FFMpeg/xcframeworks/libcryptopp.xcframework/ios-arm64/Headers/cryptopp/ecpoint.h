// ecpoint.h - written and placed in the public domain by Jeffrey Walton
//             Data structures moved from ecp.h and ec2n.h. Added EncodedPoint interface

/// \file ecpoint.h
/// \brief Classes for Elliptic Curve points
/// \since Crypto++ 6.0

#ifndef CRYPTOPP_ECPOINT_H
#define CRYPTOPP_ECPOINT_H

#include "cryptlib.h"
#include "integer.h"
#include "algebra.h"
#include "gf2n.h"

NAMESPACE_BEGIN(CryptoPP)

/// \brief Elliptical Curve Point over GF(p), where p is prime
/// \since Crypto++ 2.0
struct CRYPTOPP_DLL ECPPoint
{
	virtual ~ECPPoint() {}

	/// \brief Construct an ECPPoint
	/// \details identity is set to <tt>true</tt>
	ECPPoint() : identity(true) {}

	/// \brief Construct an ECPPoint from coordinates
	/// \details identity is set to <tt>false</tt>
	ECPPoint(const Integer &x, const Integer &y)
		: x(x), y(y), identity(false) {}

	/// \brief Tests points for equality
	/// \param t the other point
	/// \return true if the points are equal, false otherwise
	bool operator==(const ECPPoint &t) const
		{return (identity && t.identity) || (!identity && !t.identity && x==t.x && y==t.y);}

	/// \brief Tests points for ordering
	/// \param t the other point
	/// \return true if this point is less than other, false otherwise
	bool operator< (const ECPPoint &t) const
		{return identity ? !t.identity : (!t.identity && (x<t.x || (x==t.x && y<t.y)));}

	Integer x, y;
	bool identity;
};

CRYPTOPP_DLL_TEMPLATE_CLASS AbstractGroup<ECPPoint>;

/// \brief Elliptical Curve Point over GF(2^n)
/// \since Crypto++ 2.0
struct CRYPTOPP_DLL EC2NPoint
{
	virtual ~EC2NPoint() {}

	/// \brief Construct an EC2NPoint
	/// \details identity is set to <tt>true</tt>
	EC2NPoint() : identity(true) {}

	/// \brief Construct an EC2NPoint from coordinates
	/// \details identity is set to <tt>false</tt>
	EC2NPoint(const PolynomialMod2 &x, const PolynomialMod2 &y)
		: x(x), y(y), identity(false) {}

	/// \brief Tests points for equality
	/// \param t the other point
	/// \return true if the points are equal, false otherwise
	bool operator==(const EC2NPoint &t) const
		{return (identity && t.identity) || (!identity && !t.identity && x==t.x && y==t.y);}

	/// \brief Tests points for ordering
	/// \param t the other point
	/// \return true if this point is less than other, false otherwise
	bool operator< (const EC2NPoint &t) const
		{return identity ? !t.identity : (!t.identity && (x<t.x || (x==t.x && y<t.y)));}

	PolynomialMod2 x, y;
	bool identity;
};

CRYPTOPP_DLL_TEMPLATE_CLASS AbstractGroup<EC2NPoint>;

/// \brief Abstract class for encoding and decoding ellicptic curve points
/// \tparam Point ellicptic curve point
/// \details EncodedPoint is an interface for encoding and decoding elliptic curve points.
///   The template parameter <tt>Point</tt> should be a class like ECP or EC2N.
/// \since Crypto++ 6.0
template <class Point>
class EncodedPoint
{
public:
	virtual ~EncodedPoint() {}

	/// \brief Decodes an elliptic curve point
	/// \param P point which is decoded
	/// \param bt source BufferedTransformation
	/// \param len number of bytes to read from the BufferedTransformation
	/// \return true if a point was decoded, false otherwise
	virtual bool DecodePoint(Point &P, BufferedTransformation &bt, size_t len) const =0;

	/// \brief Decodes an elliptic curve point
	/// \param P point which is decoded
	/// \param encodedPoint byte array with the encoded point
	/// \param len the size of the array
	/// \return true if a point was decoded, false otherwise
	virtual bool DecodePoint(Point &P, const byte *encodedPoint, size_t len) const =0;

	/// \brief Verifies points on elliptic curve
	/// \param P point to verify
	/// \return true if the point is valid, false otherwise
	virtual bool VerifyPoint(const Point &P) const =0;

	/// \brief Determines encoded point size
	/// \param compressed flag indicating if the point is compressed
	/// \return the minimum number of bytes required to encode the point
	virtual unsigned int EncodedPointSize(bool compressed = false) const =0;

	/// \brief Encodes an elliptic curve point
	/// \param P point which is decoded
	/// \param encodedPoint byte array for the encoded point
	/// \param compressed flag indicating if the point is compressed
	/// \details <tt>encodedPoint</tt> must be at least EncodedPointSize() in length
	virtual void EncodePoint(byte *encodedPoint, const Point &P, bool compressed) const =0;

	/// \brief Encodes an elliptic curve point
	/// \param bt target BufferedTransformation
	/// \param P point which is encoded
	/// \param compressed flag indicating if the point is compressed
	virtual void EncodePoint(BufferedTransformation &bt, const Point &P, bool compressed) const =0;

	/// \brief BER Decodes an elliptic curve point
	/// \param bt source BufferedTransformation
	/// \return the decoded elliptic curve point
	virtual Point BERDecodePoint(BufferedTransformation &bt) const =0;

	/// \brief DER Encodes an elliptic curve point
	/// \param bt target BufferedTransformation
	/// \param P point which is encoded
	/// \param compressed flag indicating if the point is compressed
	virtual void DEREncodePoint(BufferedTransformation &bt, const Point &P, bool compressed) const =0;
};

NAMESPACE_END

#endif  // CRYPTOPP_ECPOINT_H
