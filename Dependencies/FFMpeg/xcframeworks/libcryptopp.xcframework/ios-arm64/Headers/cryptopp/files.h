// files.h - originally written and placed in the public domain by Wei Dai

/// \file files.h
/// \brief Classes providing file-based library services
/// \since Crypto++ 1.0

#ifndef CRYPTOPP_FILES_H
#define CRYPTOPP_FILES_H

#include "cryptlib.h"
#include "filters.h"
#include "argnames.h"
#include "smartptr.h"

#include <iostream>
#include <fstream>

NAMESPACE_BEGIN(CryptoPP)

/// \brief Implementation of Store interface
/// \details file-based implementation of Store interface
class CRYPTOPP_DLL FileStore : public Store, private FilterPutSpaceHelper, public NotCopyable
{
public:
	/// \brief Exception thrown when file-based error is encountered
	class Err : public Exception
	{
	public:
		Err(const std::string &s) : Exception(IO_ERROR, s) {}
	};
	/// \brief Exception thrown when file-based open error is encountered
	class OpenErr : public Err {public: OpenErr(const std::string &filename) : Err("FileStore: error opening file for reading: " + filename) {}};
	/// \brief Exception thrown when file-based read error is encountered
	class ReadErr : public Err {public: ReadErr() : Err("FileStore: error reading file") {}};

	/// \brief Construct a FileStore
	FileStore() : m_stream(NULLPTR), m_space(NULLPTR), m_len(0), m_waiting(0) {}

	/// \brief Construct a FileStore
	/// \param in an existing stream
	FileStore(std::istream &in) : m_stream(NULLPTR), m_space(NULLPTR), m_len(0), m_waiting(0)
		{StoreInitialize(MakeParameters(Name::InputStreamPointer(), &in));}

	/// \brief Construct a FileStore
	/// \param filename the narrow name of the file to open
	FileStore(const char *filename) : m_stream(NULLPTR), m_space(NULLPTR), m_len(0), m_waiting(0)
		{StoreInitialize(MakeParameters(Name::InputFileName(), filename ? filename : ""));}

#if defined(CRYPTOPP_UNIX_AVAILABLE) || defined(CRYPTOPP_DOXYGEN_PROCESSING) || (CRYPTOPP_MSC_VERSION >= 1400)
	/// \brief Construct a FileStore
	/// \param filename the Unicode name of the file to open
	/// \details On non-Windows OS, this function assumes that setlocale() has been called.
	FileStore(const wchar_t *filename)
		{StoreInitialize(MakeParameters(Name::InputFileNameWide(), filename));}
#endif

	/// \brief Retrieves the internal stream
	/// \return the internal stream pointer
	std::istream* GetStream() {return m_stream;}

	/// \brief Retrieves the internal stream
	/// \return the internal stream pointer
	const std::istream* GetStream() const {return m_stream;}

	/// \brief Provides the number of bytes ready for retrieval
	/// \return the number of bytes ready for retrieval
	/// \details All retrieval functions return the actual number of bytes retrieved, which is
	///  the lesser of the request number and  MaxRetrievable()
	lword MaxRetrievable() const;
	size_t TransferTo2(BufferedTransformation &target, lword &transferBytes, const std::string &channel=DEFAULT_CHANNEL, bool blocking=true);
	size_t CopyRangeTo2(BufferedTransformation &target, lword &begin, lword end=LWORD_MAX, const std::string &channel=DEFAULT_CHANNEL, bool blocking=true) const;
	lword Skip(lword skipMax=ULONG_MAX);

private:
	void StoreInitialize(const NameValuePairs &parameters);

	member_ptr<std::ifstream> m_file;
	std::istream *m_stream;
	byte *m_space;
	size_t m_len;
	bool m_waiting;
};

/// \brief Implementation of Store interface
/// \details file-based implementation of Store interface
class CRYPTOPP_DLL FileSource : public SourceTemplate<FileStore>
{
public:
	typedef FileStore::Err Err;
	typedef FileStore::OpenErr OpenErr;
	typedef FileStore::ReadErr ReadErr;

	/// \brief Construct a FileSource
	FileSource(BufferedTransformation *attachment = NULLPTR)
		: SourceTemplate<FileStore>(attachment) {}

	/// \brief Construct a FileSource
	/// \param in an existing stream
	/// \param pumpAll flag indicating if source data should be pumped to its attached transformation
	/// \param attachment an optional attached transformation
	FileSource(std::istream &in, bool pumpAll, BufferedTransformation *attachment = NULLPTR)
		: SourceTemplate<FileStore>(attachment) {SourceInitialize(pumpAll, MakeParameters(Name::InputStreamPointer(), &in));}

	/// \brief Construct a FileSource
	/// \param filename the narrow name of the file to open
	/// \param pumpAll flag indicating if source data should be pumped to its attached transformation
	/// \param attachment an optional attached transformation
	/// \param binary flag indicating if the file is binary
	FileSource(const char *filename, bool pumpAll, BufferedTransformation *attachment = NULLPTR, bool binary=true)
		: SourceTemplate<FileStore>(attachment) {SourceInitialize(pumpAll, MakeParameters(Name::InputFileName(), filename)(Name::InputBinaryMode(), binary));}

#if defined(CRYPTOPP_UNIX_AVAILABLE) || defined(CRYPTOPP_DOXYGEN_PROCESSING) || (CRYPTOPP_MSC_VERSION >= 1400)
	/// \brief Construct a FileSource
	/// \param filename the Unicode name of the file to open
	/// \param pumpAll flag indicating if source data should be pumped to its attached transformation
	/// \param attachment an optional attached transformation
	/// \param binary flag indicating if the file is binary
	/// \details On non-Windows OS, this function assumes that setlocale() has been called.
	FileSource(const wchar_t *filename, bool pumpAll, BufferedTransformation *attachment = NULLPTR, bool binary=true)
		: SourceTemplate<FileStore>(attachment) {SourceInitialize(pumpAll, MakeParameters(Name::InputFileNameWide(), filename)(Name::InputBinaryMode(), binary));}
#endif

	/// \brief Retrieves the internal stream
	/// \return the internal stream pointer
	std::istream* GetStream() {return m_store.GetStream();}
};

/// \brief Implementation of Store interface
/// \details file-based implementation of Sink interface
class CRYPTOPP_DLL FileSink : public Sink, public NotCopyable
{
public:
	/// \brief Exception thrown when file-based error is encountered
	class Err : public Exception
	{
	public:
		Err(const std::string &s) : Exception(IO_ERROR, s) {}
	};
	/// \brief Exception thrown when file-based open error is encountered
	class OpenErr : public Err {public: OpenErr(const std::string &filename) : Err("FileSink: error opening file for writing: " + filename) {}};
	/// \brief Exception thrown when file-based write error is encountered
	class WriteErr : public Err {public: WriteErr() : Err("FileSink: error writing file") {}};

	/// \brief Construct a FileSink
	FileSink() : m_stream(NULLPTR) {}

	/// \brief Construct a FileSink
	/// \param out an existing stream
	FileSink(std::ostream &out)
		{IsolatedInitialize(MakeParameters(Name::OutputStreamPointer(), &out));}

	/// \brief Construct a FileSink
	/// \param filename the narrow name of the file to open
	/// \param binary flag indicating if the file is binary
	FileSink(const char *filename, bool binary=true)
		{IsolatedInitialize(MakeParameters(Name::OutputFileName(), filename)(Name::OutputBinaryMode(), binary));}

#if defined(CRYPTOPP_UNIX_AVAILABLE) || (CRYPTOPP_MSC_VERSION >= 1400)
	/// \brief Construct a FileSink
	/// \param filename the Unicode name of the file to open
	/// \details On non-Windows OS, this function assumes that setlocale() has been called.
	FileSink(const wchar_t *filename, bool binary=true)
		{IsolatedInitialize(MakeParameters(Name::OutputFileNameWide(), filename)(Name::OutputBinaryMode(), binary));}
#endif

	/// \brief Retrieves the internal stream
	/// \return the internal stream pointer
	std::ostream* GetStream() {return m_stream;}

	void IsolatedInitialize(const NameValuePairs &parameters);
	size_t Put2(const byte *inString, size_t length, int messageEnd, bool blocking);
	bool IsolatedFlush(bool hardFlush, bool blocking);

private:
	member_ptr<std::ofstream> m_file;
	std::ostream *m_stream;
};

NAMESPACE_END

#endif
