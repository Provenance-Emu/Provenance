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

#include "repository/CompositeKeyValueRepository.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CompositeKeyValueRepositoryAtomic::get(string_view key1, string_view key2,
                                            Variant& value)
{
  return getAtomic(key1)->get(key2, value);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
shared_ptr<KeyValueRepositoryAtomic> CompositeKeyValueRepositoryAtomic::getAtomic(string_view key)
{
  auto repo = get(key);
  return {repo, repo->atomic()};
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CompositeKeyValueRepositoryAtomic::save(string_view key1, string_view key2,
                                             const Variant& value)
{
  return getAtomic(key1)->save(key2, value);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CompositeKeyValueRepositoryAtomic::has(string_view key1, string_view key2)
{
  return getAtomic(key1)->has(key2);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CompositeKeyValueRepositoryAtomic::remove(string_view key1, string_view key2)
{
  getAtomic(key1)->remove(key2);
}
