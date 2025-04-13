// gzip.h - originally written and placed in the public domain by Wei Dai

/// \file gzip.h
/// \brief GZIP compression and decompression (RFC 1952)

#ifndef CRYPTOPP_GZIP_H
#define CRYPTOPP_GZIP_H

#include "cryptlib.h"
#include "zdeflate.h"
#include "zinflate.h"
#include "crc.h"

NAMESPACE_BEGIN(CryptoPP)

/// \brief GZIP Compression (RFC 1952)
class Gzip : public Deflator
{
public:
	/// \brief Construct a Gzip compressor
	/// \param attachment an attached transformation
	/// \param deflateLevel the deflate level
	/// \param log2WindowSize the window size
	/// \param detectUncompressible flag to detect if data is compressible
	/// \details detectUncompressible makes it faster to process uncompressible files, but
	///   if a file has both compressible and uncompressible parts, it may fail to compress
	///   some of the compressible parts.
	Gzip(BufferedTransformation *attachment=NULLPTR, unsigned int deflateLevel=DEFAULT_DEFLATE_LEVEL, unsigned int log2WindowSize=DEFAULT_LOG2_WINDOW_SIZE, bool detectUncompressible=true)
		: Deflator(attachment, deflateLevel, log2WindowSize, detectUncompressible), m_totalLen(0), m_filetime(0) { }

	/// \brief Construct a Gzip compressor
	/// \param parameters a set of NameValuePairs to initialize this object
	/// \param attachment an attached transformation
	/// \details Possible parameter names: Log2WindowSize, DeflateLevel, DetectUncompressible
	Gzip(const NameValuePairs &parameters, BufferedTransformation *attachment=NULLPTR)
		: Deflator(parameters, attachment), m_totalLen(0), m_filetime(0)
	{
		IsolatedInitialize(parameters);
	}

	/// \param filetime the filetime to set in the header. The application is responsible for setting it.
	void SetFiletime(word32 filetime) { m_filetime = filetime; }

	/// \param filename the original filename to set in the header. The application is responsible for setting it.
	///        RFC 1952 requires a ISO/IEC 8859-1 encoding.
	/// \param throwOnEncodingError if throwOnEncodingError is true, then the filename is checked to ensure it is
	///        ISO/IEC 8859-1 encoded. If the filename does not adhere to ISO/IEC 8859-1, then a InvalidDataFormat
	///        is thrown. If throwOnEncodingError is false then the filename is not checked.
	void SetFilename(const std::string& filename, bool throwOnEncodingError = false);

	/// \param comment the comment to set in the header. The application is responsible for setting it.
	///        RFC 1952 requires a ISO/IEC 8859-1 encoding.
	/// \param throwOnEncodingError if throwOnEncodingError is true, then the comment is checked to ensure it is
	///        ISO/IEC 8859-1 encoded. If the comment does not adhere to ISO/IEC 8859-1, then a InvalidDataFormat
	///        is thrown. If throwOnEncodingError is false then the comment is not checked.
	void SetComment(const std::string& comment, bool throwOnEncodingError = false);

	void IsolatedInitialize(const NameValuePairs &parameters);

protected:
	enum {MAGIC1=0x1f, MAGIC2=0x8b,   // flags for the header
		  DEFLATED=8, FAST=4, SLOW=2};

	enum FLAG_MASKS {
		FILENAME=8, COMMENTS=16};

	void WritePrestreamHeader();
	void ProcessUncompressedData(const byte *string, size_t length);
	void WritePoststreamTail();

	word32 m_totalLen;
	CRC32 m_crc;

	word32 m_filetime;
	std::string m_filename;
	std::string m_comment;
};

/// \brief GZIP Decompression (RFC 1952)
class Gunzip : public Inflator
{
public:
	typedef Inflator::Err Err;

	/// \brief Exception thrown when a header decoding error occurs
	class HeaderErr : public Err {public: HeaderErr() : Err(INVALID_DATA_FORMAT, "Gunzip: header decoding error") {}};
	/// \brief Exception thrown when the tail is too short
	class TailErr : public Err {public: TailErr() : Err(INVALID_DATA_FORMAT, "Gunzip: tail too short") {}};
	/// \brief Exception thrown when a CRC error occurs
	class CrcErr : public Err {public: CrcErr() : Err(DATA_INTEGRITY_CHECK_FAILED, "Gunzip: CRC check error") {}};
	/// \brief Exception thrown when a length error occurs
	class LengthErr : public Err {public: LengthErr() : Err(DATA_INTEGRITY_CHECK_FAILED, "Gunzip: length check error") {}};

	/// \brief Construct a Gunzip decompressor
	/// \param attachment an attached transformation
	/// \param repeat decompress multiple compressed streams in series
	/// \param autoSignalPropagation 0 to turn off MessageEnd signal
	Gunzip(BufferedTransformation *attachment = NULLPTR, bool repeat = false, int autoSignalPropagation = -1);

	/// \return the filetime of the stream as set in the header. The application is responsible for setting it on the decompressed file.
	word32 GetFiletime() const { return m_filetime; }

	/// \return the filename of the stream as set in the header. The application is responsible for setting it on the decompressed file.
	/// \param throwOnEncodingError if throwOnEncodingError is true, then the filename is checked to ensure it is
	///        ISO/IEC 8859-1 encoded. If the filename does not adhere to ISO/IEC 8859-1, then a InvalidDataFormat is thrown.
	///        If throwOnEncodingError is false then the filename is not checked.
	const std::string& GetFilename(bool throwOnEncodingError = false) const;

	/// \return the comment of the stream as set in the header.
	/// \param throwOnEncodingError if throwOnEncodingError is true, then the comment is checked to ensure it is
	///        ISO/IEC 8859-1 encoded. If the comment does not adhere to ISO/IEC 8859-1, then a InvalidDataFormat is thrown.
	///        If throwOnEncodingError is false then the comment is not checked.
	const std::string& GetComment(bool throwOnEncodingError = false) const;

protected:
	enum {
		/// \brief First header magic value
		MAGIC1=0x1f,
		/// \brief Second header magic value
		MAGIC2=0x8b,
		/// \brief Deflated flag
		DEFLATED=8
	};

	enum FLAG_MASKS {
		CONTINUED=2, EXTRA_FIELDS=4, FILENAME=8, COMMENTS=16, ENCRYPTED=32};

	unsigned int MaxPrestreamHeaderSize() const {return 1024;}
	void ProcessPrestreamHeader();
	void ProcessDecompressedData(const byte *string, size_t length);
	unsigned int MaxPoststreamTailSize() const {return 8;}
	void ProcessPoststreamTail();

	word32 m_length;
	CRC32 m_crc;

	word32 m_filetime;
	std::string m_filename;
	std::string m_comment;
};

NAMESPACE_END

#endif
