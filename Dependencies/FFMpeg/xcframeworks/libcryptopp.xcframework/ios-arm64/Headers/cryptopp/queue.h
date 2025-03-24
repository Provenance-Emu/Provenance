// queue.h - originally written and placed in the public domain by Wei Dai

/// \file
/// \brief Classes for an unlimited queue to store bytes

#ifndef CRYPTOPP_QUEUE_H
#define CRYPTOPP_QUEUE_H

#include "cryptlib.h"
#include "simple.h"

NAMESPACE_BEGIN(CryptoPP)

class ByteQueueNode;

/// \brief Data structure used to store byte strings
/// \details The queue is implemented as a linked list of byte arrays.
///  Each byte array is stored in a ByteQueueNode.
/// \sa <A HREF="https://www.cryptopp.com/wiki/ByteQueue">ByteQueue</A>
///  on the Crypto++ wiki.
/// \since Crypto++ 2.0
class CRYPTOPP_DLL ByteQueue : public Bufferless<BufferedTransformation>
{
public:
	virtual ~ByteQueue();

	/// \brief Construct a ByteQueue
	/// \param nodeSize the initial node size
	/// \details Internally, ByteQueue uses a ByteQueueNode to store bytes,
	///  and <tt>nodeSize</tt> determines the size of the ByteQueueNode. A value
	///  of 0 indicates the ByteQueueNode should be automatically sized,
	///  which means a value of 256 is used.
	ByteQueue(size_t nodeSize=0);

	/// \brief Copy construct a ByteQueue
	/// \param copy the other ByteQueue
	ByteQueue(const ByteQueue &copy);

	// BufferedTransformation
	lword MaxRetrievable() const
		{return CurrentSize();}
	bool AnyRetrievable() const
		{return !IsEmpty();}

	void IsolatedInitialize(const NameValuePairs &parameters);
	byte * CreatePutSpace(size_t &size);
	size_t Put2(const byte *inString, size_t length, int messageEnd, bool blocking);

	size_t Get(byte &outByte);
	size_t Get(byte *outString, size_t getMax);

	size_t Peek(byte &outByte) const;
	size_t Peek(byte *outString, size_t peekMax) const;

	size_t TransferTo2(BufferedTransformation &target, lword &transferBytes, const std::string &channel=DEFAULT_CHANNEL, bool blocking=true);
	size_t CopyRangeTo2(BufferedTransformation &target, lword &begin, lword end=LWORD_MAX, const std::string &channel=DEFAULT_CHANNEL, bool blocking=true) const;

	/// \brief Set node size
	/// \param nodeSize the new node size, in bytes
	/// \details The default node size is 256.
	void SetNodeSize(size_t nodeSize);

	/// \brief Determine data size
	/// \return the data size, in bytes
	lword CurrentSize() const;

	/// \brief Determine data availability
	/// \return true if the ByteQueue has data, false otherwise
	bool IsEmpty() const;

	/// \brief Empty the queue
	void Clear();

	/// \brief Insert data in the queue
	/// \param inByte a byte to insert
	/// \details Unget() inserts a byte at the head of the queue
	void Unget(byte inByte);

	/// \brief Insert data in the queue
	/// \param inString a byte array to insert
	/// \param length the size of the byte array
	/// \details Unget() inserts a byte array at the head of the queue
	void Unget(const byte *inString, size_t length);

	/// \brief Peek data in the queue
	/// \param contiguousSize the size of the data
	/// \details Spy() peeks at data at the head of the queue. Spy() does
	///  not remove data from the queue.
	/// \details The data's size is returned in <tt>contiguousSize</tt>.
	///  Spy() returns the size of the first byte array in the list. The
	///  entire data may be larger since the queue is a linked list of
	///  byte arrays.
	const byte * Spy(size_t &contiguousSize) const;

	/// \brief Insert data in the queue
	/// \param inString a byte array to insert
	/// \param size the length of the byte array
	/// \details LazyPut() inserts a byte array at the tail of the queue.
	///  The data may not be copied at this point. Rather, the pointer
	///  and size to external data are recorded.
	/// \details Another call to Put() or LazyPut() will force the data to
	///  be copied. When lazy puts are used, the data is copied when
	///  FinalizeLazyPut() is called.
	/// \sa LazyPutter
	void LazyPut(const byte *inString, size_t size);

	/// \brief Insert data in the queue
	/// \param inString a byte array to insert
	/// \param size the length of the byte array
	/// \details LazyPut() inserts a byte array at the tail of the queue.
	///  The data may not be copied at this point. Rather, the pointer
	///  and size to external data are recorded.
	/// \details Another call to Put() or LazyPut() will force the data to
	///  be copied. When lazy puts are used, the data is copied when
	///  FinalizeLazyPut() is called.
	/// \sa LazyPutter
	void LazyPutModifiable(byte *inString, size_t size);

	/// \brief Remove data from the queue
	/// \param size the length of the data
	/// \throw InvalidArgument if there is no lazy data in the queue or if
	///  size is larger than the lazy string
	/// \details UndoLazyPut() truncates data inserted using LazyPut() by
	///  modifying size.
	/// \sa LazyPutter
	void UndoLazyPut(size_t size);

	/// \brief Insert data in the queue
	/// \details FinalizeLazyPut() copies external data inserted using
	///  LazyPut() or LazyPutModifiable() into the tail of the queue.
	/// \sa LazyPutter
	void FinalizeLazyPut();

	/// \brief Assign contents from another ByteQueue
	/// \param rhs the other ByteQueue
	/// \return reference to this ByteQueue
	ByteQueue & operator=(const ByteQueue &rhs);

	/// \brief Bitwise compare two ByteQueue
	/// \param rhs the other ByteQueue
	/// \return true if the size and bits are equal, false otherwise
	/// \details operator==() walks each ByteQueue comparing bytes in
	///  each queue. operator==() is not constant time.
	bool operator==(const ByteQueue &rhs) const;

	/// \brief Bitwise compare two ByteQueue
	/// \param rhs the other ByteQueue
	/// \return true if the size and bits are not equal, false otherwise
	/// \details operator!=() is implemented in terms of operator==().
	///  operator==() is not constant time.
	bool operator!=(const ByteQueue &rhs) const {return !operator==(rhs);}

	/// \brief Retrieve data from the queue
	/// \param index of byte to retrieve
	/// \return byte at the specified index
	/// \details operator[]() does not perform bounds checking.
	byte operator[](lword index) const;

	/// \brief Swap contents with another ByteQueue
	/// \param rhs the other ByteQueue
	void swap(ByteQueue &rhs);

	/// \brief A ByteQueue iterator
	class Walker : public InputRejecting<BufferedTransformation>
	{
	public:
		/// \brief Construct a ByteQueue Walker
		/// \param queue a ByteQueue
		Walker(const ByteQueue &queue)
			: m_queue(queue), m_node(NULLPTR), m_position(0), m_offset(0), m_lazyString(NULLPTR), m_lazyLength(0)
				{Initialize();}

		lword GetCurrentPosition() {return m_position;}

		lword MaxRetrievable() const
			{return m_queue.CurrentSize() - m_position;}

		void IsolatedInitialize(const NameValuePairs &parameters);

		size_t Get(byte &outByte);
		size_t Get(byte *outString, size_t getMax);

		size_t Peek(byte &outByte) const;
		size_t Peek(byte *outString, size_t peekMax) const;

		size_t TransferTo2(BufferedTransformation &target, lword &transferBytes, const std::string &channel=DEFAULT_CHANNEL, bool blocking=true);
		size_t CopyRangeTo2(BufferedTransformation &target, lword &begin, lword end=LWORD_MAX, const std::string &channel=DEFAULT_CHANNEL, bool blocking=true) const;

	private:
		const ByteQueue &m_queue;
		const ByteQueueNode *m_node;
		lword m_position;
		size_t m_offset;
		const byte *m_lazyString;
		size_t m_lazyLength;
	};

	friend class Walker;

protected:
	void CleanupUsedNodes();
	void CopyFrom(const ByteQueue &copy);
	void Destroy();

private:
	ByteQueueNode *m_head, *m_tail;
	byte *m_lazyString;
	size_t m_lazyLength;
	size_t m_nodeSize;
	bool m_lazyStringModifiable;
	bool m_autoNodeSize;
};

/// \brief Helper class to finalize Puts on ByteQueue
/// \details LazyPutter ensures LazyPut is committed to the ByteQueue
///  in event of exception. During destruction, the LazyPutter class
///  calls FinalizeLazyPut.
class CRYPTOPP_DLL LazyPutter
{
public:
	virtual ~LazyPutter() {
		try {m_bq.FinalizeLazyPut();}
		catch(const Exception&) {CRYPTOPP_ASSERT(0);}
	}

	/// \brief Construct a LazyPutter
	/// \param bq the ByteQueue
	/// \param inString a byte array to insert
	/// \param size the length of the byte array
	/// \details LazyPutter ensures LazyPut is committed to the ByteQueue
	///  in event of exception. During destruction, the LazyPutter class
	///  calls FinalizeLazyPut.
	LazyPutter(ByteQueue &bq, const byte *inString, size_t size)
		: m_bq(bq) {bq.LazyPut(inString, size);}

protected:
	LazyPutter(ByteQueue &bq) : m_bq(bq) {}

private:
	ByteQueue &m_bq;
};

/// \brief Helper class to finalize Puts on ByteQueue
/// \details LazyPutterModifiable ensures LazyPut is committed to the
///  ByteQueue in event of exception. During destruction, the
///  LazyPutterModifiable class calls FinalizeLazyPut.
class LazyPutterModifiable : public LazyPutter
{
public:
	/// \brief Construct a LazyPutterModifiable
	/// \param bq the ByteQueue
	/// \param inString a byte array to insert
	/// \param size the length of the byte array
	/// \details LazyPutterModifiable ensures LazyPut is committed to the
	///  ByteQueue in event of exception. During destruction, the
	///  LazyPutterModifiable class calls FinalizeLazyPut.
	LazyPutterModifiable(ByteQueue &bq, byte *inString, size_t size)
		: LazyPutter(bq) {bq.LazyPutModifiable(inString, size);}
};

NAMESPACE_END

#ifndef __BORLANDC__
NAMESPACE_BEGIN(std)
template<> inline void swap(CryptoPP::ByteQueue &a, CryptoPP::ByteQueue &b)
{
	a.swap(b);
}
NAMESPACE_END
#endif

#endif
