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

#ifndef PLUSROM_HXX
#define PLUSROM_HXX

class Settings;

#include <deque>

#include "bspf.hxx"
#include "Serializable.hxx"
#include "Cart.hxx"

/**
  Class used to emulate the 'PlusROM' meta-scheme, documented at
    http://pluscart.firmaplus.de/pico/?PlusROM

  This scheme basically wraps a normal bankswitching scheme, but includes
  network functionality.

  Host and path names are stored as 0-terminated strings, located at the
  NMI vector, stored path first and then host next.

  PlusROMs functions use 4 hotspot addresses (before the bankswitching area):
    $1FF0 is for writing a byte to the send buffer (max 256 bytes)
    $1FF1 is for writing a byte to the send buffer and submit the buffer
      to the back end API
    $1FF2 contains the next byte of the response from the host, every read will
      increment the receive buffer pointer (receive buffer is max 256 bytes also!)
    $1FF3 contains the number of (unread) bytes left in the receive buffer
      (these bytes can be from multiple responses)

  @author  Stephen Anthony
*/

class PlusROMRequest;

class PlusROM : public Serializable
{
  public:
    PlusROM(const Settings& settings, const Cartridge& cart);
    ~PlusROM() override = default;

  public:
    /**
      Determine whether this is actually a PlusROM cart, and if so create
      and initialize all state variables it will use.  This includes
      whether there is a valid hostname and path embedded in the ROM.

      @param image  Pointer to the ROM image
      @param size   The size of the ROM image

      @return  Whether this is actually a valid PlusROM cart
    */
    bool initialize(const ByteBuffer& image, size_t size);

    /**
      Answer whether this is a PlusROM cart.  Note that until the
      initialize method has been called, this will always return false.

      @return  Whether this is actually a PlusROM cart
    */
    bool isValid() const { return myIsPlusROM; }

    /**
      Read from hotspot addresses ($1FF2 and $1FF3).

      @param address  The hotspot where the value should be read
      @param value    The value read from the hotspot

      @return  Indicates whether the peek succeeded or failed
               (ie, whether it hit a hotspot)
               On failure, 'value' is not considered valid
    */
    bool peekHotspot(uInt16 address, uInt8& value);

    /**
      Write to hotspot addresses ($1FF0 and $1FF1).

      @param address  The hotspot where the value should be written
      @param value    The value to be stored at the hotspot

      @return  Indicates whether the poke succeeded or failed
               (ie, whether it hit a hotspot)
    */
    bool pokeHotspot(uInt16 address, uInt8 value);

    /**
      Save the current state of this device to the given Serializer.

      @param out  The Serializer object to use
      @return  False on any errors, else true
    */
    bool save(Serializer& out) const override;

    /**
      Load the current state of this device from the given Serializer.

      @param in  The Serializer object to use
      @return  False on any errors, else true
    */
    bool load(Serializer& in) override;

    /**
      Reset.
    */
    void reset();

    /**
      Retrieve host.

      @return The host string
    */
    const string& getHost() const { return myHost; }

    /**
      Retrieve path.

      @return The path string
    */
    const string& getPath() const { return myPath; }

    /**
      Retrieve send data.

      @return The send data
    */
    ByteArray getSend() const;
    /**
      Retrieve receive data.

      @return The receive data
    */
    ByteArray getReceive() const;

    /**
      Set the callback for displaying messages
    */
    void setMessageCallback(const Cartridge::messageCallback& callback)
    {
      myMsgCallback = callback;
    }

  private:
    static bool isValidHost(string_view host);
    static bool isValidPath(string_view path);

    /**
      Receive data from all requests that have completed.
    */
    void receive();

    /**
      Send pending data to the backend on a thread.
    */
    void send();

  private:
    const Settings& mySettings;
    const Cartridge& myCart;

    bool myIsPlusROM{false};
    string myHost;
    string myPath;

    std::array<uInt8, 256> myRxBuffer, myTxBuffer;
    uInt8 myRxReadPos{0}, myRxWritePos{0}, myTxPos{0};

    std::deque<shared_ptr<PlusROMRequest>> myPendingRequests;

    // Callback to output messages
    Cartridge::messageCallback myMsgCallback{nullptr};

  private:
    // Following constructors and assignment operators not supported
    PlusROM(const PlusROM&) = delete;
    PlusROM(PlusROM&&) = delete;
    PlusROM& operator=(const PlusROM&) = delete;
    PlusROM& operator=(PlusROM&&) = delete;
};

#endif
