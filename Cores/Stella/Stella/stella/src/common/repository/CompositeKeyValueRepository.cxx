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
// Copyright (c) 1995-2022 by Bradford W. Mott, Stephen Anthony
// and the Stella Team
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

#include "repository/CompositeKeyValueRepository.hxx"


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CompositeKeyValueRepositoryAtomic::get(const string& key1, const string& key2, Variant& value)
{
  return getAtomic(key1)->get(key2, value);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
shared_ptr<KeyValueRepositoryAtomic> CompositeKeyValueRepositoryAtomic::getAtomic(const string& key)
{
  auto repo = get(key);

  return shared_ptr<KeyValueRepositoryAtomic>(repo, repo->atomic());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CompositeKeyValueRepositoryAtomic::save(const string& key1, const string& key2, const Variant& value)
{
  return getAtomic(key1)->save(key2, value);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CompositeKeyValueRepositoryAtomic::has(const string& key1, const string& key2)
{
  return getAtomic(key1)->has(key2);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CompositeKeyValueRepositoryAtomic::remove(const string& key1, const string& key2)
{
  getAtomic(key1)->remove(key2);
}
