//============================================================================
//
//   SSSS    tt          lll  lll
//  SS  SS   tt           ll   ll
//  SS     tttttt  eeee   ll   ll   aaaa
//   SSSS    tt   ee  ee  ll   ll      aa
//      SS   tt   eeeeee  ll   ll   aaaaa  --  "An Atari 2600 VCS Emulator"
//  SS  SS   tt   ee      ll   ll  aa  aa
//   SSSS     ttt  eeeee llll llll  aaaaa
//
// Copyright (c) 1995-2024 by Bradford W. Mott, Stephen Anthony
// and the Stella Team
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

#include <regex>
#include <atomic>
#include <thread>

#include "bspf.hxx"
#include "PlusROM.hxx"
#include "Logger.hxx"
#include "Version.hxx"
#include "Settings.hxx"
#include "CartDetector.hxx"

#if defined(HTTP_LIB_SUPPORT)
  #include "http_lib.hxx"

namespace {
  constexpr int MAX_CONCURRENT_REQUESTS = 5;
  constexpr int CONNECTION_TIMEOUT_MSEC = 3000;
  constexpr int READ_TIMEOUT_MSEC       = 3000;
  constexpr int WRITE_TIMEOUT_MSEC      = 3000;

  constexpr uInt16 WRITE_TO_BUFFER      = 0x1FF0;
  constexpr uInt16 WRITE_SEND_BUFFER    = 0x1FF1;
  constexpr uInt16 RECEIVE_BUFFER       = 0x1FF2;
  constexpr uInt16 RECEIVE_BUFFER_SIZE  = 0x1FF3;
} // namespace
#endif

using std::chrono::milliseconds;

class PlusROMRequest {
  public:
    struct Destination {
      Destination(string_view _host, string_view _path)
        : host{_host}, path{_path} {}

      string host;
      string path;
    };

    struct PlusStoreId {
      PlusStoreId(string_view _nick, string_view _id)
        : nick{_nick}, id{_id} {}

      string nick;
      string id;
    };

    enum class State : uInt8 {
      created,
      pending,
      done,
      failed
    };

  public:
    PlusROMRequest(const Destination& destination, const PlusStoreId& id,
                   const uInt8* request, uInt8 requestSize)
      : myState{State::created}, myDestination{destination},
        myId{id}, myRequestSize{requestSize}
    {
      memcpy(myRequest.data(), request, myRequestSize);
    }
    ~PlusROMRequest() = default;

  #if defined(HTTP_LIB_SUPPORT)
    void execute() {
      myState = State::pending;

      ostringstream content;
      content << "agent=Stella; "
        << "ver=" << STELLA_VERSION << "; "
        << "id=" << myId.id << "; "
        << "nick=" << myId.nick;

      httplib::Client client(myDestination.host);
      const httplib::Headers headers = {
        {"PlusROM-Info", content.str()}
      };

      client.set_connection_timeout(milliseconds(CONNECTION_TIMEOUT_MSEC));
      client.set_read_timeout(milliseconds(READ_TIMEOUT_MSEC));
      client.set_write_timeout(milliseconds(WRITE_TIMEOUT_MSEC));

      auto response = client.Post(
        myDestination.path,
        headers,
        reinterpret_cast<const char*>(myRequest.data()),
        myRequestSize,
        "application/octet-stream"
      );

      if (!response) {
        ostringstream ss;
        ss
          << "PlusCart: request to "
          << myDestination.host
          << "/"
          << myDestination.path
          << ": failed";

        Logger::error(ss.str());

        myState = State::failed;

        return;
      }

      if (response->status != 200) {
        ostringstream ss;
        ss
          << "PlusCart: request to "
          << myDestination.host
          << "/"
          << myDestination.path
          << ": failed with HTTP status "
          << response->status;

        Logger::error(ss.str());

        myState = State::failed;

        return;
      }

      if (response->body.empty() || static_cast<unsigned char>(response->body[0]) != (response->body.size() - 1)) {
        ostringstream ss;
        ss << "PlusCart: request to " << myDestination.host << "/" << myDestination.path << ": invalid response";

        Logger::error(ss.str());

        myState = State::failed;

        return;
      }

      myResponse = response->body;
      myState = State::done;
    }

    [[nodiscard]] State getState() const {
      return myState;
    }

    [[nodiscard]] const Destination& getDestination() const
    {
      return myDestination;
    }

    [[nodiscard]] const PlusStoreId& getPlusStoreId() const
    {
      return myId;
    }

    std::pair<size_t, const uInt8*> getResponse() {
      if (myState != State::done) throw runtime_error("invalid access to response");

      return {
        myResponse.size() - 1,
        myResponse.size() > 1 ? reinterpret_cast<const uInt8*>(myResponse.data() + 1) : nullptr
      };
    }
  #endif

  private:
    std::atomic<State> myState{State::failed};

    Destination myDestination;
    PlusStoreId myId;

    std::array<uInt8, 256> myRequest;
    uInt8 myRequestSize{0};

    string myResponse;

  private:
    PlusROMRequest(const PlusROMRequest&) = delete;
    PlusROMRequest(PlusROMRequest&&) = delete;
    PlusROMRequest& operator=(const PlusROMRequest&) = delete;
    PlusROMRequest& operator=(PlusROMRequest&&) = delete;
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PlusROM::PlusROM(const Settings& settings, const Cartridge& cart)
  : mySettings{settings},
    myCart{cart}
{
  myRxBuffer.fill(0);
  myTxBuffer.fill(0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool PlusROM::initialize(const ByteBuffer& image, size_t size)
{
#if defined(HTTP_LIB_SUPPORT)
  // Host and path are stored at the NMI vector
  size_t i = ((image[size - 5] - 16) << 8) | image[size - 6];  // NMI @ $FFFA
  if(i >= size)
    return myIsPlusROM = false;  // Invalid NMI

  // Path stored first, 0-terminated
  string path;
  while(i < size && image[i] != 0)
    path += static_cast<char>(image[i++]);

  // Did we get a valid, 0-terminated path?
  if(i >= size || image[i] != 0 || !isValidPath(path))
    return myIsPlusROM = false;  // Invalid path

  i++;  // advance past 0 terminator

  // Host stored next, 0-terminated
  string host;
  while(i < size && image[i] != 0)
    host += static_cast<char>(image[i++]);

  // Did we get a valid, 0-terminated host?
  if(i >= size || image[i] != 0 || !isValidHost(host))
    return myIsPlusROM = false;  // Invalid host

  myHost = host;
  myPath = path;

  reset();

  return myIsPlusROM = CartDetector::isProbablyPlusROM(image, size);
#else
  return myIsPlusROM = false;
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool PlusROM::peekHotspot(uInt16 address, uInt8& value)
{
#if defined(HTTP_LIB_SUPPORT)
  if(myCart.hotspotsLocked()) return false;

  switch(address & 0x1FFF)
  {
    // invalid reads from write addresses
    case WRITE_TO_BUFFER:     // Write byte to Tx buffer
      myTxBuffer[myTxPos++] = address & 0xff; // TODO: value is undetermined
      break;

    case WRITE_SEND_BUFFER:   // Write byte to Tx buffer and send to backend
                              // (and receive into Rx buffer)
      myTxBuffer[myTxPos++] = address & 0xff; // TODO: value is undetermined
      send();
      break;

    // valid reads
    case RECEIVE_BUFFER:      // Read next byte from Rx buffer
      receive();
      value = myRxBuffer[myRxReadPos];
      if (myRxReadPos != myRxWritePos) myRxReadPos++;
      return true;

    case RECEIVE_BUFFER_SIZE: // Get number of unread bytes in Rx buffer
      receive();
      value = myRxWritePos - myRxReadPos;
      return true;

    default:  // satisfy compiler
      break;
  }
#endif
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool PlusROM::pokeHotspot(uInt16 address, uInt8 value)
{
#if defined(HTTP_LIB_SUPPORT)
  if(myCart.hotspotsLocked()) return false;

  switch(address & 0x1FFF)
  {
    // valid writes
    case WRITE_TO_BUFFER:     // Write byte to Tx buffer
      myTxBuffer[myTxPos++] = value;
      return true;

    case WRITE_SEND_BUFFER:   // Write byte to Tx buffer and send to backend
                              // (and receive into Rx buffer)
      myTxBuffer[myTxPos++] = value;
      send();
      return true;

    // invalid writes to read addresses
    case RECEIVE_BUFFER:      // Read next byte from Rx buffer
      receive();
      if(myRxReadPos != myRxWritePos) myRxReadPos++;
      break;

    case RECEIVE_BUFFER_SIZE: // Get number of unread bytes in Rx buffer
      receive();
      break;

    default:  // satisfy compiler
      break;
  }
#endif
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool PlusROM::save(Serializer& out) const
{
  try
  {
    out.putByteArray(myRxBuffer.data(), myRxBuffer.size());
    out.putByteArray(myTxBuffer.data(), myTxBuffer.size());
    out.putInt(myRxReadPos);
    out.putInt(myRxWritePos);
    out.putInt(myTxPos);
  }
  catch(...)
  {
    cerr << "ERROR: PlusROM::save\n";
    return false;
  }

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool PlusROM::load(Serializer& in)
{
  myPendingRequests.clear();

  try
  {
    in.getByteArray(myRxBuffer.data(), myRxBuffer.size());
    in.getByteArray(myTxBuffer.data(), myTxBuffer.size());
    myRxReadPos = in.getInt();
    myRxWritePos = in.getInt();
    myTxPos = in.getInt();
  }
  catch(...)
  {
    cerr << "ERROR: PlusROM::load\n";
    return false;
  }

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PlusROM::reset()
{
  myRxReadPos = myRxWritePos = myTxPos = 0;
  myPendingRequests.clear();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool PlusROM::isValidHost(string_view host)
{
  // TODO: This isn't 100% either, as we're supposed to check for the length
  //       of each part between '.' in the range 1 .. 63
  //  Perhaps a better function will be included with whatever network
  //  library we decide to use
  static const std::regex rgx(R"(^(([a-z0-9]|[a-z0-9][a-z0-9\-]*[a-z0-9])\.)*([a-z0-9]|[a-z0-9][a-z0-9\-]*[a-z0-9])$)", std::regex_constants::icase);

  return std::regex_match(host.cbegin(), host.cend(), rgx);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool PlusROM::isValidPath(string_view path)
{
  // TODO: This isn't 100%
  //  Perhaps a better function will be included with whatever network
  //  library we decide to use
  for(auto c: path)
    if(!((c > 44 && c < 58) || (c > 64 && c < 91) || (c > 96 && c < 122)))
      return false;

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PlusROM::send()
{
#if defined(HTTP_LIB_SUPPORT)
  if (myPendingRequests.size() >= MAX_CONCURRENT_REQUESTS) {
    // Try to make room by consuming any requests that have completed.
    receive();
  }

  if (myPendingRequests.size() >= MAX_CONCURRENT_REQUESTS) {
    Logger::error("PlusCart: max number of concurrent requests exceeded");

    myTxPos = 0;
    return;
  }

  string id = mySettings.getString("plusroms.id");

  if(id == EmptyString)
    id = mySettings.getString("plusroms.fixedid");

  if(id != EmptyString)
  {
    const string nick = mySettings.getString("plusroms.nick");
    auto request = make_shared<PlusROMRequest>(
      PlusROMRequest::Destination(myHost, "/" + myPath),
      PlusROMRequest::PlusStoreId(nick, id),
      myTxBuffer.data(),
      myTxPos
      );

    myTxPos = 0;

    // We push to the back in order to avoid reverse_iterator in receive()
    myPendingRequests.push_back(request);

    // The lambda will retain a copy of the shared_ptr that is alive as long
    // as the thread is running. Thus, the request can only be destructed once
    // the thread has finished, and we can safely evict it from the deque at
    // any time.
    std::thread thread([=]() // NOLINT (cppcoreguidelines-misleading-capture-default-by-value)
    {
      request->execute();
      switch(request->getState())
      {
        case PlusROMRequest::State::failed:
          myMsgCallback("PlusROM data sending failed!");
          break;

        case PlusROMRequest::State::done:
          myMsgCallback("PlusROM data sent successfully");
          break;

        default:
          break;
      }
    });

    thread.detach();
  }
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PlusROM::receive()
{
#if defined(HTTP_LIB_SUPPORT)
  auto iter = myPendingRequests.begin();

  while(iter != myPendingRequests.end()) {
    switch((*iter)->getState()) {
      case PlusROMRequest::State::failed:
        myMsgCallback("PlusROM data receiving failed!");
        // Request has failed? -> remove it and start over
        myPendingRequests.erase(iter);
        iter = myPendingRequests.begin();
        continue;

      case PlusROMRequest::State::done:
      {
        myMsgCallback("PlusROM data received successfully");
        // Request has finished sucessfully? -> consume the response, remove it
        // and start over
        const auto [responseSize, response] = (*iter)->getResponse();

        for(uInt8 i = 0; i < responseSize; i++)
          myRxBuffer[myRxWritePos++] = response[i];

        myPendingRequests.erase(iter);
        iter = myPendingRequests.begin();
        continue;
      }

      default:
        iter++;
    }
  }
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
ByteArray PlusROM::getSend() const
{
  ByteArray arr;

  for(int i = 0; i < myTxPos; ++i)
    arr.push_back(myTxBuffer[i]);

  return arr;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
ByteArray PlusROM::getReceive() const
{
  ByteArray arr;

  for(uInt8 i = myRxReadPos; i != myRxWritePos; ++i)
    arr.push_back(myRxBuffer[i]);

  return arr;
}
