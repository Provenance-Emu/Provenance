// mqueue.h - originally written and placed in the public domain by Wei Dai

/// \file
/// \brief Classes for an unlimited queue to store messages

#ifndef CRYPTOPP_MQUEUE_H
#define CRYPTOPP_MQUEUE_H

#include "cryptlib.h"
#include "queue.h"
#include "filters.h"
#include "misc.h"

#include <deque>

NAMESPACE_BEGIN(CryptoPP)

/// \brief Data structure used to store messages
/// \details The queue is implemented with a ByteQueue.
/// \sa <A HREF="https://www.cryptopp.com/wiki/MessageQueue">MessageQueue</A>
///  on the Crypto++ wiki.
/// \since Crypto++ 2.0
class CRYPTOPP_DLL MessageQueue : public AutoSignaling<BufferedTransformation>
{
public:
	virtual ~MessageQueue() {}

	/// \brief Construct a MessageQueue
	/// \param nodeSize the initial node size
	MessageQueue(unsigned int nodeSize=256);

	// BufferedTransformation
	void IsolatedInitialize(const NameValuePairs &parameters)
		{m_queue.IsolatedInitialize(parameters); m_lengths.assign(1, 0U); m_messageCounts.assign(1, 0U);}
	size_t Put2(const byte *begin, size_t length, int messageEnd, bool blocking)
	{
		CRYPTOPP_UNUSED(blocking);
		m_queue.Put(begin, length);
		m_lengths.back() += length;
		if (messageEnd)
		{
			m_lengths.push_back(0);
			m_messageCounts.back()++;
		}
		return 0;
	}
	bool IsolatedFlush(bool hardFlush, bool blocking)
		{CRYPTOPP_UNUSED(hardFlush), CRYPTOPP_UNUSED(blocking); return false;}
	bool IsolatedMessageSeriesEnd(bool blocking)
		{CRYPTOPP_UNUSED(blocking); m_messageCounts.push_back(0); return false;}

	lword MaxRetrievable() const
		{return m_lengths.front();}
	bool AnyRetrievable() const
		{return m_lengths.front() > 0;}

	size_t TransferTo2(BufferedTransformation &target, lword &transferBytes, const std::string &channel=DEFAULT_CHANNEL, bool blocking=true);
	size_t CopyRangeTo2(BufferedTransformation &target, lword &begin, lword end=LWORD_MAX, const std::string &channel=DEFAULT_CHANNEL, bool blocking=true) const;

	lword TotalBytesRetrievable() const
		{return m_queue.MaxRetrievable();}
	unsigned int NumberOfMessages() const
		{return (unsigned int)m_lengths.size()-1;}
	bool GetNextMessage();

	unsigned int NumberOfMessagesInThisSeries() const
		{return m_messageCounts[0];}
	unsigned int NumberOfMessageSeries() const
		{return (unsigned int)m_messageCounts.size()-1;}

	/// \brief Copy messages from this object to another BufferedTransformation.
	/// \param target the destination BufferedTransformation
	/// \param count the number of messages to copy
	/// \param channel the channel on which the transfer should occur
	/// \return the number of messages that remain in the copy (i.e., messages not copied)
	unsigned int CopyMessagesTo(BufferedTransformation &target, unsigned int count=UINT_MAX, const std::string &channel=DEFAULT_CHANNEL) const;

	/// \brief Peek data in the queue
	/// \param contiguousSize the size of the data
	/// \details Spy() peeks at data at the head of the queue. Spy() does
	///  not remove data from the queue.
	/// \details The data's size is returned in <tt>contiguousSize</tt>.
	///  Spy() returns the size of the first message in the list.
	const byte * Spy(size_t &contiguousSize) const;

	/// \brief Swap contents with another MessageQueue
	/// \param rhs the other MessageQueue
	void swap(MessageQueue &rhs);

private:
	ByteQueue m_queue;
	std::deque<lword> m_lengths;
	std::deque<unsigned int> m_messageCounts;
};

/// \brief Filter that checks messages on two channels for equality
class CRYPTOPP_DLL EqualityComparisonFilter : public Unflushable<Multichannel<Filter> >
{
public:
	/// \brief Different messages were detected
	struct MismatchDetected : public Exception
	{
		/// \brief Construct a MismatchDetected exception
		MismatchDetected() : Exception(DATA_INTEGRITY_CHECK_FAILED, "EqualityComparisonFilter: did not receive the same data on two channels") {}
	};

	/// \brief Construct an EqualityComparisonFilter
	/// \param attachment an attached transformation
	/// \param throwIfNotEqual flag indicating whether the objects throws
	/// \param firstChannel string naming the first channel
	/// \param secondChannel string naming the second channel
	/// \throw MismatchDetected if throwIfNotEqual is true and not equal
	/// \details If throwIfNotEqual is false, this filter will output a '\\0'
	///  byte when it detects a mismatch, '\\1' otherwise.
	EqualityComparisonFilter(BufferedTransformation *attachment=NULLPTR, bool throwIfNotEqual=true, const std::string &firstChannel="0", const std::string &secondChannel="1")
		: m_throwIfNotEqual(throwIfNotEqual), m_mismatchDetected(false)
		, m_firstChannel(firstChannel), m_secondChannel(secondChannel)
		{Detach(attachment);}

	// BufferedTransformation
	size_t ChannelPut2(const std::string &channel, const byte *begin, size_t length, int messageEnd, bool blocking);
	bool ChannelMessageSeriesEnd(const std::string &channel, int propagation=-1, bool blocking=true);

protected:
	unsigned int MapChannel(const std::string &channel) const;
	bool HandleMismatchDetected(bool blocking);

private:
	bool m_throwIfNotEqual, m_mismatchDetected;
	std::string m_firstChannel, m_secondChannel;
	MessageQueue m_q[2];
};

NAMESPACE_END

#ifndef __BORLANDC__
NAMESPACE_BEGIN(std)
template<> inline void swap(CryptoPP::MessageQueue &a, CryptoPP::MessageQueue &b)
{
	a.swap(b);
}
NAMESPACE_END
#endif

#endif
