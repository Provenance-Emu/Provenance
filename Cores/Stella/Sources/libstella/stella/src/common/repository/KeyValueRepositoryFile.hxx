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

#ifndef KEY_VALUE_REPOSITORY_FILE_HXX
#define KEY_VALUE_REPOSITORY_FILE_HXX

#include <sstream>

#include "KeyValueRepository.hxx"
#include "Logger.hxx"
#include "FSNode.hxx"
#include "bspf.hxx"

template<class T>
class KeyValueRepositoryFile : public KeyValueRepository {
  public:
    explicit KeyValueRepositoryFile(const FSNode& node);

    KVRMap load() override;

    bool save(const KVRMap& values) override;

  protected:

    const FSNode& myNode;
};

///////////////////////////////////////////////////////////////////////////////
// IMPLEMENTATION
///////////////////////////////////////////////////////////////////////////////

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
template<class T>
KeyValueRepositoryFile<T>::KeyValueRepositoryFile(const FSNode& node)
  : myNode{node}
{}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
template<class T>
KVRMap KeyValueRepositoryFile<T>::load()
{
  if (!myNode.exists()) return KVRMap();

  stringstream in;

  try {
    myNode.read(in);
    return T::load(in);
  }
  catch (const runtime_error& err) {
    Logger::error(err.what());

    return KVRMap();
  }
  catch (...) {
    return KVRMap();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
template<class T>
bool KeyValueRepositoryFile<T>::save(const KVRMap& values)
{
  if (values.size() == 0) return true;

  stringstream out;

  try {
    T::save(out, values);
    myNode.write(out);

    return true;
  }
  catch (const runtime_error& err) {
    Logger::error(err.what());

    return false;
  }
  catch (...)
  {
    return false;
  }
}

#endif // KEY_VALUE_REPOSITORY_FILE
