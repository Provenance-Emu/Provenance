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

#ifndef PROPERTIES_HXX
#define PROPERTIES_HXX

#include "repository/KeyValueRepository.hxx"
#include "bspf.hxx"

enum class PropType : uInt8 {
  Cart_MD5,
  Cart_Manufacturer,
  Cart_ModelNo,
  Cart_Name,
  Cart_Note,
  Cart_Rarity,
  Cart_Sound,
  Cart_StartBank,
  Cart_Type,
  Cart_Highscore,
  Cart_Url,
  Console_LeftDiff,
  Console_RightDiff,
  Console_TVType,
  Console_SwapPorts,
  Controller_Left,
  Controller_Left1,
  Controller_Left2,
  Controller_Right,
  Controller_Right1,
  Controller_Right2,
  Controller_SwapPaddles,
  Controller_PaddlesXCenter,
  Controller_PaddlesYCenter,
  Controller_MouseAxis,
  Display_Format,
  Display_VCenter,
  Display_Phosphor,
  Display_PPBlend,
  Bezel_Name,
  NumTypes
};

/**
  This class represents objects which maintain a collection of
  properties.  A property is a key and its corresponding value.

  A properties object can contain a reference to another properties
  object as its "defaults"; this second properties object is searched
  if the property key is not found in the original property list.

  @author  Bradford W. Mott
*/
class Properties
{
  friend class PropertiesSet;

  public:
    /**
      Creates an empty properties object with the specified defaults.  The
      new properties object does not claim ownership of the defaults.
    */
    Properties();
    ~Properties() = default;

    /**
      Creates a properties list by copying another one

      @param properties The properties to copy
    */
    Properties(const Properties& properties);

  public:
    void load(KeyValueRepository& repo);

    bool save(KeyValueRepository& repo) const;

    /**
      Get the value assigned to the specified key.  If the key does
      not exist then the empty string is returned.

      @param key  The key of the property to lookup
      @return     The value of the property
    */
    const string& get(PropType key) const {
      const uInt8 pos = static_cast<uInt8>(key);
      return pos < static_cast<uInt8>(PropType::NumTypes) ? myProperties[pos] : EmptyString;
    }

    /**
      Set the value associated with key to the given value.

      @param key      The key of the property to set
      @param value    The value to assign to the property
    */
    void set(PropType key, string_view value);

    /**
      Print the attributes of this properties object
    */
    void print() const;

    /**
      Resets all properties to their defaults
    */
    void setDefaults();

    /**
      Resets the property of the given key to its default

      @param key      The key of the property to set
    */
    void reset(PropType key);

    /**
      Overloaded equality operator(s)

      @param properties The properties object to compare to
      @return True if the properties are equal, else false
    */
    bool operator == (const Properties& properties) const;
    bool operator != (const Properties& properties) const;

    /**
      Overloaded assignment operator

      @param properties The properties object to set myself equal to
      @return Myself after assignment has taken place
    */
    Properties& operator = (const Properties& properties);

    /**
      Set the default value associated with key to the given value.

      @param key      The key of the property to set
      @param value    The value to assign to the property
    */
    static void setDefault(PropType key, string_view value);

  private:
    /**
      Helper function to perform a deep copy of the specified
      properties.  Assumes that old properties have already been
      freed.

      @param properties The properties object to copy myself from
    */
    void copy(const Properties& properties);

    /**
      Get the property type associated with the named property

      @param name  The PropType key associated with the given string
    */
    static PropType getPropType(string_view name);

    /**
      When printing each collection of ROM properties, it is useful to
      see which columns correspond to the output fields; this method
      provides that output.
    */
    static void printHeader();

  private:
    static constexpr size_t NUM_PROPS = static_cast<size_t>(PropType::NumTypes);

    // The array of properties
    std::array<string, NUM_PROPS> myProperties;

    // List of default properties to use when none have been provided
    static std::array<string, NUM_PROPS> ourDefaultProperties;

    // The text strings associated with each property type
    static std::array<string, NUM_PROPS> ourPropertyNames;

  private:
    // Following constructors and assignment operators not supported
    Properties(Properties&&) = delete;
    Properties& operator=(Properties&&) = delete;
};

#endif
