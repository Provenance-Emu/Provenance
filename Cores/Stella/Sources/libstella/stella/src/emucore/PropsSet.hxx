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

#ifndef PROPERTIES_SET_HXX
#define PROPERTIES_SET_HXX

#include <map>

class FSNode;
class OSystem;

#include "bspf.hxx"
#include "Props.hxx"
#include "repository/CompositeKeyValueRepository.hxx"

/**
  This class maintains an ordered collection of properties, maintained
  in a C++ map and accessible by ROM md5.  The md5 is used since this is
  the attribute which must be present in each entry in stella.pro
  and least likely to change.  A change in MD5 would mean a change in
  the game rom image (essentially a different game) and this would
  necessitate a new entry in the stella.pro file anyway.

  @author  Stephen Anthony
*/
class PropertiesSet
{
  public:

    PropertiesSet();

    void setRepository(shared_ptr<CompositeKeyValueRepository> repository);

    /**
      Get the property from the set with the given MD5.

      @param md5         The md5 of the property to get
      @param properties  The properties with the given MD5, or the default
                         properties if not found
      @param useDefaults  Use the built-in defaults, ignoring any properties
                          from an external file

      @return  True if the set with the specified md5 was found, else false
    */
    bool getMD5(string_view md5, Properties& properties,
                bool useDefaults = false) const;

    /**
      Insert the properties into the set.  If a duplicate is inserted
      the old properties are overwritten with the new ones.

      @param properties  The collection of properties
      @param save        Indicates whether the properties should be saved
                         when the program exits
    */
    void insert(const Properties& properties, bool save = true);

    /**
      Load properties for a specific ROM from a per-ROM properties file,
      if it exists.  In any event, also do some error checking, like making
      sure that the properties have a valid name, etc.

      NOTE: This method is meant to be called only when starting Stella
            and loading a ROM for the first time.  Currently, that means
            only from the ROM launcher or when actually opening the ROM.
            *** FOR ALL OTHER CASES, USE getMD5() ***

      @param rom  The node representing the rom file
      @param md5  The md5 of the property to get
    */
    void loadPerROM(const FSNode& rom, string_view md5);

    /**
      Prints the contents of the PropertiesSet as a flat file.
    */
    void print() const;

  private:
    using PropsList = std::map<string, Properties, std::less<>>;

    // The properties read from an external 'stella.pro' file
    PropsList myExternalProps;

    // The properties temporarily inserted by the program, which should
    // be discarded when the program ends
    PropsList myTempProps;

    shared_ptr<CompositeKeyValueRepository> myRepository;

  private:
    // Following constructors and assignment operators not supported
    PropertiesSet(const PropertiesSet&) = delete;
    PropertiesSet(PropertiesSet&&) = delete;
    PropertiesSet& operator=(const PropertiesSet&) = delete;
    PropertiesSet& operator=(PropertiesSet&&) = delete;
};

#endif
