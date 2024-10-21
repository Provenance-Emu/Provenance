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

#ifndef BANKSWITCH_HXX
#define BANKSWITCH_HXX

#include <map>

#include "FSNode.hxx"
#include "bspf.hxx"

/**
  This class contains all information about the bankswitch schemes supported
  by Stella, as well as convenience functions to map from scheme type to
  readable string, and vice-versa.

  It also includes all logic that determines what a 'valid' rom filename is.
  That is, all extensions that represent valid schemes.

  @author  Stephen Anthony
*/
class Bankswitch
{
  public:
    // Currently supported bankswitch schemes
    enum class Type {
      _AUTO,  _03E0,  _0840,   _0FA0, _2IN1, _4IN1, _8IN1, _16IN1,
      _32IN1, _64IN1, _128IN1, _2K,   _3E,   _3EX,  _3EP,  _3F,
      _4A50,  _4K,    _4KSC,   _AR,   _BF,   _BFSC, _BUS,  _CDF,
      _CM,    _CTY,   _CV,     _DF,   _DFSC, _DPC,  _DPCP, _E0,
      _E7,    _EF,    _EFSC,   _F0,   _F4,   _F4SC, _F6,   _F6SC,
      _F8,    _F8SC,  _FA,     _FA2,  _FC,   _FE,   _GL,   _MDM,
      _MVC,   _SB,    _TVBOY,  _UA,   _UASW, _WD,   _WDSW, _X07,
    #ifdef CUSTOM_ARM
      _CUSTOM,
    #endif
      NumSchemes,
      NumMulti = _128IN1 - _2IN1 + 1,
    };

    struct SizesType {
      size_t minSize{0};
      size_t maxSize{0};
    };
    static constexpr size_t any_KB = 0;

    static const std::array<SizesType,
                            static_cast<uInt32>(Type::NumSchemes)> Sizes;

    // Info about the various bankswitch schemes, useful for displaying
    // in GUI dropdown boxes, etc
    struct Description {
      string_view name;
      string_view desc;
    };
    static const std::array<Description,
                            static_cast<uInt32>(Type::NumSchemes)> BSList;

  public:
    // Convert BSType enum to string
    static string typeToName(Bankswitch::Type type);

    // Convert string to BSType enum
    static Bankswitch::Type nameToType(string_view name);

    // Convert BSType enum to description string
    static string typeToDesc(Bankswitch::Type type);

    // Determine bankswitch type by filename extension
    // Use '_AUTO' if unknown
    static Bankswitch::Type typeFromExtension(const FSNode& file);

    /**
      Is this a valid ROM filename (does it have a valid extension?).

      @param name  Filename of potential ROM file
      @param ext   The extension extracted from the given file
     */
    static bool isValidRomName(string_view name, string& ext);

    /**
      Convenience functions for different parameter types.
     */
    static inline bool isValidRomName(const FSNode& name, string& ext) {
      return isValidRomName(name.getPath(), ext);
    }
    static inline bool isValidRomName(const FSNode& name) {
      string ext;  // extension not used
      return isValidRomName(name.getPath(), ext);
    }
    static inline bool isValidRomName(string_view name) {
      string ext;  // extension not used
      return isValidRomName(name, ext);
    }

    // Output operator
    friend ostream& operator<<(ostream& os, const Bankswitch::Type& t) {
      return os << typeToName(t);
    }

  private:
    struct TypeComparator {
      bool operator() (string_view a, string_view b) const {
        return BSPF::compareIgnoreCase(a, b) < 0;
      }
    };
    using ExtensionMap = const std::map<string_view, Bankswitch::Type,
                                        TypeComparator>;
    static ExtensionMap ourExtensions;

    using NameToTypeMap = const std::map<string_view, Bankswitch::Type,
                                         TypeComparator>;
    static NameToTypeMap ourNameToTypes;

  private:
    // Following constructors and assignment operators not supported
    Bankswitch() = delete;
    Bankswitch(const Bankswitch&) = delete;
    Bankswitch(Bankswitch&&) = delete;
    Bankswitch& operator=(const Bankswitch&) = delete;
    Bankswitch& operator=(Bankswitch&&) = delete;
};

#endif
