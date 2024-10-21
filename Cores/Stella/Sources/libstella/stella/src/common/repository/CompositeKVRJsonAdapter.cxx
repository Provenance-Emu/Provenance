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

#include "CompositeKVRJsonAdapter.hxx"
#include "repository/KeyValueRepositoryJsonFile.hxx"

namespace {
  class ProxyRepository : public KeyValueRepository {
      public:
        ProxyRepository(KeyValueRepositoryAtomic& kvr, string_view key)
          : myKvr{kvr}, myKey{key}
        {}

        KVRMap load() override {
          if (!myKvr.has(myKey)) return {};

          Variant serialized;
          myKvr.get(myKey, serialized);

          stringstream in{serialized.toString()};

          return KeyValueRepositoryJsonFile::load(in);
        }

        bool save(const KVRMap& values) override {
          stringstream out;

          if (!KeyValueRepositoryJsonFile::save(out, values)) return false;

          return myKvr.save(myKey, out.str());
        }

      private:

        // NOLINT: cppcoreguidelines-avoid-const-or-ref-data-members
        KeyValueRepositoryAtomic& myKvr;  // NOLINT
        string myKey;
    };
} // namespace

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CompositeKVRJsonAdapter::CompositeKVRJsonAdapter(KeyValueRepositoryAtomic& kvr)
  : myKvr{kvr}
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
shared_ptr<KeyValueRepository> CompositeKVRJsonAdapter::get(string_view key)
{
  return make_shared<ProxyRepository>(myKvr, key);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CompositeKVRJsonAdapter::has(string_view key)
{
  return myKvr.has(key);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CompositeKVRJsonAdapter::remove(string_view key)
{
  myKvr.remove(key);
}
