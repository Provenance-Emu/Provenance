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

#include <map>

#include "bspf.hxx"
#include "FSNode.hxx"
#include "DefProps.hxx"
#include "Props.hxx"
#include "PropsSet.hxx"
#include "repository/CompositeKeyValueRepositoryNoop.hxx"
#include "repository/KeyValueRepositoryPropertyFile.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PropertiesSet::PropertiesSet()
  : myRepository{make_shared<CompositeKeyValueRepositoryNoop>()}
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PropertiesSet::setRepository(shared_ptr<CompositeKeyValueRepository> repository)
{
  myRepository = std::move(repository);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool PropertiesSet::getMD5(string_view md5, Properties& properties,
                           bool useDefaults) const
{
  properties.setDefaults();
  bool found = false;

  // There are three lists to search when looking for a properties entry,
  // which must be done in the following order
  // If 'useDefaults' is specified, only use the built-in list
  //
  //  'save': entries previously inserted that are saved on program exit
  //  'temp': entries previously inserted that are discarded
  //  'builtin': the defaults compiled into the program

  // First check properties from external file
  if(!useDefaults)
  {
    if (myRepository->has(md5)) {
      properties.load(*myRepository->get(md5));

      found = true;
    }
    else  // Search temp list
    {
      const auto tmp = myTempProps.find(md5);
      if(tmp != myTempProps.end())
      {
        properties = tmp->second;
        found = true;
      }
    }
  }

  // Otherwise, search the internal database using binary search
  if(!found)
  {
    int low = 0, high = DEF_PROPS_SIZE - 1;
    while(low <= high)
    {
      const int i = (low + high) / 2;
      const int cmp = BSPF::compareIgnoreCase(md5,
          DefProps[i][static_cast<uInt8>(PropType::Cart_MD5)]);

      if(cmp == 0)  // found it
      {
        for(uInt8 p = 0; p < static_cast<uInt8>(PropType::NumTypes); ++p)
          if(DefProps[i][p][0] != 0)
            properties.set(PropType{p}, DefProps[i][p]);

        found = true;
        break;
      }
      else if(cmp < 0)
        high = i - 1; // look at lower range
      else
        low = i + 1;  // look at upper range
    }
  }

  return found;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PropertiesSet::insert(const Properties& properties, bool save)
{
  // TODO
  // Note that the following code is optimized for insertion when an item
  // doesn't already exist, and when the external properties file is
  // relatively small (which is the case with current versions of Stella,
  // as the properties are built-in)
  // If an item does exist, it will be removed and insertion done again
  // This shouldn't be a speed issue, as insertions will only fail with
  // duplicates when you're changing the current ROM properties, which
  // most people tend not to do

  // Since the PropSet is keyed by md5, we can't insert without a valid one
  const string& md5 = properties.get(PropType::Cart_MD5);
  if(md5.empty())
    return;

  // Make sure the exact entry isn't already in any list
  Properties defaultProps;
  if(getMD5(md5, defaultProps, false) && defaultProps == properties)
    return;
  else if(getMD5(md5, defaultProps, true) && defaultProps == properties)
  {
    cerr << "DELETE" << '\n' << std::flush;
    myRepository->remove(md5);
    return;
  }

  if (save) {
    properties.save(*myRepository->get(md5));
  } else {
    const auto ret = myTempProps.emplace(md5, properties);
    if(!ret.second)
    {
      // Remove old item and insert again
      myTempProps.erase(ret.first);
      myTempProps.emplace(md5, properties);
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PropertiesSet::loadPerROM(const FSNode& rom, string_view md5)
{
  Properties props;

  // Handle ROM properties, do some error checking
  // Only add to the database when necessary
  bool toInsert = false;

  // First, does this ROM have a per-ROM properties entry?
  // If so, load it into the database
  const FSNode propsNode(rom.getPathWithExt(".pro"));
  if (propsNode.exists()) {
    KeyValueRepositoryPropertyFile repo(propsNode);
    props.load(repo);

    insert(props, false);
  }

  // Next, make sure we have a valid md5 and name
  if(!getMD5(md5, props))
  {
    props.set(PropType::Cart_MD5, md5);
    toInsert = true;
  }
  if(toInsert || props.get(PropType::Cart_Name) == EmptyString)
  {
    props.set(PropType::Cart_Name, rom.getNameWithExt(""));
    toInsert = true;
  }

  // Finally, insert properties if any info was missing
  if(toInsert)
    insert(props, false);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void PropertiesSet::print() const
{
  // We only look at the external properties and the built-in ones;
  // the temp properties are ignored
  // Also, any properties entries in the external file override the built-in
  // ones
  // The easiest way to merge the lists is to create another temporary one
  // This isn't fast, but I suspect this method isn't used too often (or at all)

  // First insert all external props
  PropsList list = myExternalProps;

  // Now insert all the built-in ones
  // Note that if we try to insert a duplicate, the insertion will fail
  // This is fine, since a duplicate in the built-in list means it should
  // be overrided anyway (and insertion shouldn't be done)
  Properties properties;
  for(uInt32 i = 0; i < DEF_PROPS_SIZE; ++i)
  {
    properties.setDefaults();
    for(uInt8 p = 0; p < static_cast<uInt8>(PropType::NumTypes); ++p)
      if(DefProps[i][p][0] != 0)
        properties.set(PropType{p}, DefProps[i][p]);

    list.emplace(DefProps[i][static_cast<uInt8>(PropType::Cart_MD5)], properties);
  }

  // Now, print the resulting list
  Properties::printHeader();
  for(const auto& i: list)
    i.second.print();
}
