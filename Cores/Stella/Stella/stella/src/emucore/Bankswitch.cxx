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

#include "Bankswitch.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string Bankswitch::typeToName(Bankswitch::Type type)
{
  return BSList[static_cast<int>(type)].name;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Bankswitch::Type Bankswitch::nameToType(const string& name)
{
  const auto it = ourNameToTypes.find(name);
  if(it != ourNameToTypes.end())
    return it->second;

  return Bankswitch::Type::_AUTO;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string Bankswitch::typeToDesc(Bankswitch::Type type)
{
  return BSList[static_cast<int>(type)].desc;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Bankswitch::Type Bankswitch::typeFromExtension(const FSNode& file)
{
  const string& name = file.getPath();
  const string::size_type idx = name.find_last_of('.');
  if(idx != string::npos)
  {
    const auto it = ourExtensions.find(name.c_str() + idx + 1);
    if(it != ourExtensions.end())
      return it->second;
  }

  return Bankswitch::Type::_AUTO;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Bankswitch::isValidRomName(const string& name, string& ext)
{
  const string::size_type idx = name.find_last_of('.');
  if(idx != string::npos)
  {
    const char* const e = name.c_str() + idx + 1;
    const auto it = ourExtensions.find(e);
    if(it != ourExtensions.end())
    {
      ext = e;
      return true;
    }
  }
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Bankswitch::isValidRomName(const FSNode& name, string& ext)
{
  return isValidRomName(name.getPath(), ext);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Bankswitch::isValidRomName(const FSNode& name)
{
  string ext;  // extension not used
  return isValidRomName(name.getPath(), ext);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Bankswitch::isValidRomName(const string& name)
{
  string ext;  // extension not used
  return isValidRomName(name, ext);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const std::array<Bankswitch::Description, static_cast<int>(Bankswitch::Type::NumSchemes)>
Bankswitch::BSList = {{
  { "AUTO"    , "Auto-detect"                 },
  { "0840"    , "0840 (8K EconoBanking)"      },
  { "0FA0"    , "0FA0 (8K Fotomania)"         },
  { "2IN1"    , "2IN1 Multicart (4-64K)"      },
  { "4IN1"    , "4IN1 Multicart (8-64K)"      },
  { "8IN1"    , "8IN1 Multicart (16-64K)"     },
  { "16IN1"   , "16IN1 Multicart (32-128K)"   },
  { "32IN1"   , "32IN1 Multicart (64/128K)"   },
  { "64IN1"   , "64IN1 Multicart (128/256K)"  },
  { "128IN1"  , "128IN1 Multicart (256/512K)" },
  { "2K"      , "2K (32-2048 bytes Atari)"    },
  { "3E"      , "3E (Tigervision, 32K RAM)"   },
  { "3EX"     , "3EX (Tigervision, 256K RAM)" },
  { "3E+"     , "3E+ (TJ modified 3E)"        },
  { "3F"      , "3F (512K Tigervision)"       },
  { "4A50"    , "4A50 (64K 4A50 + RAM)"       },
  { "4K"      , "4K (4K Atari)"               },
  { "4KSC"    , "4KSC (CPUWIZ 4K + RAM)"      },
  { "AR"      , "AR (Supercharger)"           },
  { "BF"      , "BF (CPUWIZ 256K)"            },
  { "BFSC"    , "BFSC (CPUWIZ 256K + RAM)"    },
  { "BUS"     , "BUS (Experimental)"          },
  { "CDF"     , "CDF (Chris, Darrell, Fred)"  },
  { "CM"      , "CM (SpectraVideo CompuMate)" },
  { "CTY"     , "CTY (CDW - Chetiry)"         },
  { "CV"      , "CV (Commavid extra RAM)"     },
  { "DF"      , "DF (CPUWIZ 128K)"            },
  { "DFSC"    , "DFSC (CPUWIZ 128K + RAM)"    },
  { "DPC"     , "DPC (Pitfall II)"            },
  { "DPC+"    , "DPC+ (Enhanced DPC)"         },
  { "E0"      , "E0 (8K Parker Bros)"         },
  { "E7"      , "E7 (8-16K M Network)"        },
  { "EF"      , "EF (64K H. Runner)"          },
  { "EFSC"    , "EFSC (64K H. Runner + RAM)"  },
  { "F0"      , "F0 (Dynacom Megaboy)"        },
  { "F4"      , "F4 (32K Atari)"              },
  { "F4SC"    , "F4SC (32K Atari + RAM)"      },
  { "F6"      , "F6 (16K Atari)"              },
  { "F6SC"    , "F6SC (16K Atari + RAM)"      },
  { "F8"      , "F8 (8K Atari)"               },
  { "F8SC"    , "F8SC (8K Atari + RAM)"       },
  { "FA"      , "FA (CBS RAM Plus)"           },
  { "FA2"     , "FA2 (CBS RAM Plus 24/28K)"   },
  { "FC"      , "FC (32K Amiga)"              },
  { "FE"      , "FE (8K Activision)"          },
  { "MDM"     , "MDM (Menu Driven Megacart)"  },
  { "MVC"     , "MVC (Movie Cart)"            },
  { "SB"      , "SB (128-256K SUPERbank)"     },
  { "TVBOY"   , "TV Boy (512K)"               },
  { "UA"      , "UA (8K UA Ltd.)"             },
  { "UASW"    , "UASW (8K UA swapped banks)"  },
  { "WD"      , "WD (Pink Panther)"           },
  { "WDSW"    , "WDSW (Pink Panther, bad)"    },
  { "X07"     , "X07 (64K AtariAge)"          },
#if defined(CUSTOM_ARM)
  { "CUSTOM"  ,   "CUSTOM (ARM)"                  }
#endif
}};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Bankswitch::ExtensionMap Bankswitch::ourExtensions = {
  // Normal file extensions that don't actually tell us anything
  // about the bankswitch type to use
  { "a26"   , Bankswitch::Type::_AUTO   },
  { "bin"   , Bankswitch::Type::_AUTO   },
  { "rom"   , Bankswitch::Type::_AUTO   },
#if defined(ZIP_SUPPORT)
  { "zip"   , Bankswitch::Type::_AUTO   },
#endif
  { "cu"    , Bankswitch::Type::_AUTO   },

  // All bankswitch types (those that UnoCart and HarmonyCart support have the same name)
  { "084"   , Bankswitch::Type::_0840   },
  { "0840"  , Bankswitch::Type::_0840   },
  { "0FA"   , Bankswitch::Type::_0FA0   },
  { "0FA0"  , Bankswitch::Type::_0FA0   },
  { "2N1"   , Bankswitch::Type::_2IN1   },
  { "4N1"   , Bankswitch::Type::_4IN1   },
  { "8N1"   , Bankswitch::Type::_8IN1   },
  { "16N"   , Bankswitch::Type::_16IN1  },
  { "16N1"  , Bankswitch::Type::_16IN1  },
  { "32N"   , Bankswitch::Type::_32IN1  },
  { "32N1"  , Bankswitch::Type::_32IN1  },
  { "64N"   , Bankswitch::Type::_64IN1  },
  { "64N1"  , Bankswitch::Type::_64IN1  },
  { "128"   , Bankswitch::Type::_128IN1 },
  { "128N1" , Bankswitch::Type::_128IN1 },
  { "2K"    , Bankswitch::Type::_2K     },
  { "3E"    , Bankswitch::Type::_3E     },
  { "3EX"   , Bankswitch::Type::_3EX    },
  { "3EP"   , Bankswitch::Type::_3EP    },
  { "3E+"   , Bankswitch::Type::_3EP    },
  { "3F"    , Bankswitch::Type::_3F     },
  { "4A5"   , Bankswitch::Type::_4A50   },
  { "4A50"  , Bankswitch::Type::_4A50   },
  { "4K"    , Bankswitch::Type::_4K     },
  { "4KS"   , Bankswitch::Type::_4KSC   },
  { "4KSC"  , Bankswitch::Type::_4KSC   },
  { "AR"    , Bankswitch::Type::_AR     },
  { "BF"    , Bankswitch::Type::_BF     },
  { "BFS"   , Bankswitch::Type::_BFSC   },
  { "BFSC"  , Bankswitch::Type::_BFSC   },
  { "BUS"   , Bankswitch::Type::_BUS    },
  { "CDF"   , Bankswitch::Type::_CDF    },
  { "CM"    , Bankswitch::Type::_CM     },
  { "CTY"   , Bankswitch::Type::_CTY    },
  { "CV"    , Bankswitch::Type::_CV     },
  { "DF"    , Bankswitch::Type::_DF     },
  { "DFS"   , Bankswitch::Type::_DFSC   },
  { "DFSC"  , Bankswitch::Type::_DFSC   },
  { "DPC"   , Bankswitch::Type::_DPC    },
  { "DPP"   , Bankswitch::Type::_DPCP   },
  { "DPCP"  , Bankswitch::Type::_DPCP   },
  { "E0"    , Bankswitch::Type::_E0     },
  { "E7"    , Bankswitch::Type::_E7     },
  { "E78"   , Bankswitch::Type::_E7     },
  { "E78K"  , Bankswitch::Type::_E7     },
  { "EF"    , Bankswitch::Type::_EF     },
  { "EFS"   , Bankswitch::Type::_EFSC   },
  { "EFSC"  , Bankswitch::Type::_EFSC   },
  { "F0"    , Bankswitch::Type::_F0     },
  { "F4"    , Bankswitch::Type::_F4     },
  { "F4S"   , Bankswitch::Type::_F4SC   },
  { "F4SC"  , Bankswitch::Type::_F4SC   },
  { "F6"    , Bankswitch::Type::_F6     },
  { "F6S"   , Bankswitch::Type::_F6SC   },
  { "F6SC"  , Bankswitch::Type::_F6SC   },
  { "F8"    , Bankswitch::Type::_F8     },
  { "F8S"   , Bankswitch::Type::_F8SC   },
  { "F8SC"  , Bankswitch::Type::_F8SC   },
  { "FA"    , Bankswitch::Type::_FA     },
  { "FA2"   , Bankswitch::Type::_FA2    },
  { "FC"    , Bankswitch::Type::_FC     },
  { "FE"    , Bankswitch::Type::_FE     },
  { "MDM"   , Bankswitch::Type::_MDM    },
  { "MVC"   , Bankswitch::Type::_MVC    },
  { "SB"    , Bankswitch::Type::_SB     },
  { "TVB"   , Bankswitch::Type::_TVBOY  },
  { "TVBOY" , Bankswitch::Type::_TVBOY  },
  { "UA"    , Bankswitch::Type::_UA     },
  { "UASW"  , Bankswitch::Type::_UASW   },
  { "WD"    , Bankswitch::Type::_WD     },
  { "WDSW"  , Bankswitch::Type::_WDSW   },
  { "X07"   , Bankswitch::Type::_X07    }
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Bankswitch::NameToTypeMap Bankswitch::ourNameToTypes = {
  { "AUTO"    , Bankswitch::Type::_AUTO   },
  { "0840"    , Bankswitch::Type::_0840   },
  { "0FA0"    , Bankswitch::Type::_0FA0   },
  { "2IN1"    , Bankswitch::Type::_2IN1   },
  { "4IN1"    , Bankswitch::Type::_4IN1   },
  { "8IN1"    , Bankswitch::Type::_8IN1   },
  { "16IN1"   , Bankswitch::Type::_16IN1  },
  { "32IN1"   , Bankswitch::Type::_32IN1  },
  { "64IN1"   , Bankswitch::Type::_64IN1  },
  { "128IN1"  , Bankswitch::Type::_128IN1 },
  { "2K"      , Bankswitch::Type::_2K     },
  { "3E"      , Bankswitch::Type::_3E     },
  { "3E+"     , Bankswitch::Type::_3EP    },
  { "3EX"     , Bankswitch::Type::_3EX    },
  { "3F"      , Bankswitch::Type::_3F     },
  { "4A50"    , Bankswitch::Type::_4A50   },
  { "4K"      , Bankswitch::Type::_4K     },
  { "4KSC"    , Bankswitch::Type::_4KSC   },
  { "AR"      , Bankswitch::Type::_AR     },
  { "BF"      , Bankswitch::Type::_BF     },
  { "BFSC"    , Bankswitch::Type::_BFSC   },
  { "BUS"     , Bankswitch::Type::_BUS    },
  { "CDF"     , Bankswitch::Type::_CDF    },
  { "CM"      , Bankswitch::Type::_CM     },
  { "CTY"     , Bankswitch::Type::_CTY    },
  { "CV"      , Bankswitch::Type::_CV     },
  { "DF"      , Bankswitch::Type::_DF     },
  { "DFSC"    , Bankswitch::Type::_DFSC   },
  { "DPC"     , Bankswitch::Type::_DPC    },
  { "DPC+"    , Bankswitch::Type::_DPCP   },
  { "E0"      , Bankswitch::Type::_E0     },
  { "E7"      , Bankswitch::Type::_E7     },
  { "EF"      , Bankswitch::Type::_EF     },
  { "EFSC"    , Bankswitch::Type::_EFSC   },
  { "F0"      , Bankswitch::Type::_F0     },
  { "F4"      , Bankswitch::Type::_F4     },
  { "F4SC"    , Bankswitch::Type::_F4SC   },
  { "F6"      , Bankswitch::Type::_F6     },
  { "F6SC"    , Bankswitch::Type::_F6SC   },
  { "F8"      , Bankswitch::Type::_F8     },
  { "F8SC"    , Bankswitch::Type::_F8SC   },
  { "FA"      , Bankswitch::Type::_FA     },
  { "FA2"     , Bankswitch::Type::_FA2    },
  { "FC"      , Bankswitch::Type::_FC     },
  { "FE"      , Bankswitch::Type::_FE     },
  { "MDM"     , Bankswitch::Type::_MDM    },
  { "MVC"     , Bankswitch::Type::_MVC    },
  { "SB"      , Bankswitch::Type::_SB     },
  { "TVBOY"   , Bankswitch::Type::_TVBOY  },
  { "UA"      , Bankswitch::Type::_UA     },
  { "UASW"    , Bankswitch::Type::_UASW   },
  { "WD"      , Bankswitch::Type::_WD     },
  { "WDSW"    , Bankswitch::Type::_WDSW   },
  { "X07"     , Bankswitch::Type::_X07    }
};
