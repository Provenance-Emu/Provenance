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

#ifndef SERIALIZER_HXX
#define SERIALIZER_HXX

#include "bspf.hxx"

/**
  This class implements a Serializer device, whereby data is serialized and
  read from/written to a binary stream in a system-independent way.  The
  stream can be either an actual file, or an in-memory structure.

  Bytes are written as characters, shorts as 2 characters (16-bits),
  integers as 4 characters (32-bits), long integers as 8 bytes (64-bits),
  strings are written as characters prepended by the length of the string,
  boolean values are written using a special character pattern.

  @author  Stephen Anthony
*/
class Serializer
{
  public:
    enum class Mode { ReadOnly, ReadWrite, ReadWriteTrunc };

  public:
    /**
      Creates a new Serializer device for streaming binary data.

      If a filename is provided, the stream will be to the given
      filename.  Otherwise, the stream will be in memory.

      If a file is opened readonly, we can never write to it.

      The valid() method must immediately be called to verify the stream
      was correctly initialized.
    */
    explicit Serializer(string_view filename, Mode m = Mode::ReadWrite);
    Serializer();

  public:
    /**
      Answers whether the serializer is currently initialized for reading
      and writing.
    */
    explicit operator bool() const { return myStream != nullptr; }

    /**
      Sets the read/write location to the given offset in the stream.
    */
    void setPosition(size_t pos);

    /**
      Resets the read/write location to the beginning of the stream.
    */
    void rewind();

    /**
      Returns the current total size of the stream.
    */
    size_t size();

    /**
      Reads a byte value (unsigned 8-bit) from the current input stream.

      @result The byte value which has been read from the stream.
    */
    uInt8 getByte() const;

    /**
      Reads a byte array (unsigned 8-bit) from the current input stream.

      @param array  The location to store the bytes read
      @param size   The size of the array (number of bytes to read)
    */
    void getByteArray(uInt8* array, size_t size) const;

    /**
      Reads a short value (unsigned 16-bit) from the current input stream.

      @result The short value which has been read from the stream.
    */
    uInt16 getShort() const;

    /**
      Reads a short array (unsigned 16-bit) from the current input stream.

      @param array  The location to store the shorts read
      @param size   The size of the array (number of shorts to read)
    */
    void getShortArray(uInt16* array, size_t size) const;

    /**
      Reads an int value (unsigned 32-bit) from the current input stream.

      @result The int value which has been read from the stream.
    */
    uInt32 getInt() const;

    /**
      Reads an integer array (unsigned 32-bit) from the current input stream.

      @param array  The location to store the integers read
      @param size   The size of the array (number of integers to read)
    */
    void getIntArray(uInt32* array, size_t size) const;

    /**
      Reads a long int value (unsigned 64-bit) from the current input stream.

      @result The long int value which has been read from the stream.
    */
    uInt64 getLong() const;

    /**
      Reads a double value (signed 64-bit) from the current input stream.

      @result The double value which has been read from the stream.
    */
    double getDouble() const;

    /**
      Reads a string from the current input stream.

      @result The string which has been read from the stream.
    */
    string getString() const;

    /**
      Reads a boolean value from the current input stream.

      @result The boolean value which has been read from the stream.
    */
    bool getBool() const;

    /**
      Writes an byte value (unsigned 8-bit) to the current output stream.

      @param value The byte value to write to the output stream.
    */
    void putByte(uInt8 value);

    /**
      Writes a byte array (unsigned 8-bit) to the current output stream.

      @param array  The bytes to write
      @param size   The size of the array (number of bytes to write)
    */
    void putByteArray(const uInt8* array, size_t size);

    /**
      Writes a short value (unsigned 16-bit) to the current output stream.

      @param value The short value to write to the output stream.
    */
    void putShort(uInt16 value);

    /**
      Writes a short array (unsigned 16-bit) to the current output stream.

      @param array  The short to write
      @param size   The size of the array (number of shorts to write)
    */
    void putShortArray(const uInt16* array, size_t size);

    /**
      Writes an int value (unsigned 32-bit) to the current output stream.

      @param value The int value to write to the output stream.
    */
    void putInt(uInt32 value);

    /**
      Writes an integer array (unsigned 32-bit) to the current output stream.

      @param array  The integers to write
      @param size   The size of the array (number of integers to write)
    */
    void putIntArray(const uInt32* array, size_t size);

    /**
      Writes a long int value (unsigned 64-bit) to the current output stream.

      @param value The long int value to write to the output stream.
    */
    void putLong(uInt64 value);

    /**
      Writes a double value (signed 64-bit) to the current output stream.

      @param value The double value to write to the output stream.
    */
    void putDouble(double value);

    /**
      Writes a string(view) to the current output stream.

      @param str The string to write to the output stream.
    */
    void putString(string_view str);

    /**
      Writes a boolean value to the current output stream.

      @param b The boolean value to write to the output stream.
    */
    void putBool(bool b);

  private:
    // The stream to send the serialized data to.
    unique_ptr<iostream> myStream;

    static constexpr uInt8 TruePattern = 0xfe, FalsePattern = 0x01;
};

#endif
