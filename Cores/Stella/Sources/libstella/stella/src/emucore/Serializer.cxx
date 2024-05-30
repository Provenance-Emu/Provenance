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

#include "FSNode.hxx"
#include "Serializer.hxx"

using std::ios;
using std::ios_base;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Serializer::Serializer(string_view filename, Mode m)
{
  if(m == Mode::ReadOnly)
  {
    const FSNode node(filename);
    if(node.isFile() && node.isReadable())
    {
      unique_ptr<fstream> str = make_unique<fstream>(
          string{filename}, ios::in | ios::binary);
      if(str && str->is_open())
      {
        myStream = std::move(str);
        rewind();
        myStream->exceptions( ios_base::failbit | ios_base::badbit |
                              ios_base::eofbit );
      }
    }
  }
  else
  {
    // When using fstreams, we need to manually create the file first
    // if we want to use it in read/write mode, since it won't be created
    // if it doesn't already exist
    // However, if it *does* exist, we don't want to overwrite it
    // So we open in write and append mode - the write creates the file
    // when necessary, and the append doesn't delete any data if it
    // already exists
    const string f{filename};
    fstream temp(f, ios::out | ios::app);
    temp.close();

    ios_base::openmode stream_mode = ios::in | ios::out | ios::binary;
    if(m == Mode::ReadWriteTrunc)
      stream_mode |= ios::trunc;
    unique_ptr<fstream> str = make_unique<fstream>(f, stream_mode);
    if(str && str->is_open())
    {
      myStream = std::move(str);
      rewind();
      myStream->exceptions( ios_base::failbit | ios_base::badbit |
                            ios_base::eofbit );
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Serializer::Serializer()
  : myStream{make_unique<stringstream>(ios::in | ios::out | ios::binary)}
{
  // For some reason, Windows and possibly macOS needs to store something in
  // the stream before it is used for the first time
  if(myStream)
  {
    putBool(true);
    rewind();
    myStream->exceptions( ios_base::failbit | ios_base::badbit | ios_base::eofbit );
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Serializer::setPosition(size_t pos)
{
  myStream->clear();
  myStream->seekg(pos);
  myStream->seekp(pos);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Serializer::rewind()
{
  myStream->clear();
  myStream->seekg(ios_base::beg);
  myStream->seekp(ios_base::beg);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
size_t Serializer::size()
{
  const std::streampos oldPos = myStream->tellp();

  myStream->seekp(0, std::ios::end);
  const size_t s = myStream->tellp();
  myStream->seekp(oldPos);

  return s;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 Serializer::getByte() const
{
  char buf{0};
  myStream->read(&buf, 1);

  return buf;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Serializer::getByteArray(uInt8* array, size_t size) const
{
  myStream->read(reinterpret_cast<char*>(array), size);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt16 Serializer::getShort() const
{
  uInt16 val{0};
  myStream->read(reinterpret_cast<char*>(&val), sizeof(uInt16));

  return val;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Serializer::getShortArray(uInt16* array, size_t size) const
{
  myStream->read(reinterpret_cast<char*>(array), sizeof(uInt16)*size);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt32 Serializer::getInt() const
{
  uInt32 val{0};
  myStream->read(reinterpret_cast<char*>(&val), sizeof(uInt32));

  return val;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Serializer::getIntArray(uInt32* array, size_t size) const
{
  myStream->read(reinterpret_cast<char*>(array), sizeof(uInt32)*size);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt64 Serializer::getLong() const
{
  uInt64 val{0};
  myStream->read(reinterpret_cast<char*>(&val), sizeof(uInt64));

  return val;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
double Serializer::getDouble() const
{
  double val{0.0};
  myStream->read(reinterpret_cast<char*>(&val), sizeof(double));

  return val;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string Serializer::getString() const
{
  const int len = getInt();
  string str;
  str.resize(len);
  myStream->read(str.data(), len);

  return str;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Serializer::getBool() const
{
  return getByte() == TruePattern;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Serializer::putByte(uInt8 value)
{
  myStream->write(reinterpret_cast<char*>(&value), 1);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Serializer::putByteArray(const uInt8* array, size_t size)
{
  myStream->write(reinterpret_cast<const char*>(array), size);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Serializer::putShort(uInt16 value)
{
  myStream->write(reinterpret_cast<char*>(&value), sizeof(uInt16));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Serializer::putShortArray(const uInt16* array, size_t size)
{
  myStream->write(reinterpret_cast<const char*>(array), sizeof(uInt16)*size);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Serializer::putInt(uInt32 value)
{
  myStream->write(reinterpret_cast<char*>(&value), sizeof(uInt32));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Serializer::putIntArray(const uInt32* array, size_t size)
{
  myStream->write(reinterpret_cast<const char*>(array), sizeof(uInt32)*size);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Serializer::putLong(uInt64 value)
{
  myStream->write(reinterpret_cast<char*>(&value), sizeof(uInt64));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Serializer::putDouble(double value)
{
  myStream->write(reinterpret_cast<char*>(&value), sizeof(double));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Serializer::putString(string_view str)
{
  putInt(static_cast<uInt32>(str.size()));
  myStream->write(str.data(), str.size());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Serializer::putBool(bool b)
{
  putByte(b ? TruePattern: FalsePattern);
}
