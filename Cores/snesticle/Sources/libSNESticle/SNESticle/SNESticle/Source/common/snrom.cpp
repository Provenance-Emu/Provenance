
#include <stdlib.h>
#include <stdio.h>
#include "types.h"
#include "snrom.h"
#include "dataio.h"


//
//
//


struct SNRomCountryT
{
	Char		*pName;
	SNRomVideoE eVideoType;
};

struct SNRomLicenseT
{
	Uint8	uCode;
	Char	*pName;
};


//
//
//

static SNRomCountryT _SNRom_Country[]=
{
    { "Japan"                                   ,   SNROM_VIDEO_NTSC    },
    { "USA"                                     ,   SNROM_VIDEO_NTSC    },
    { "Australia, Europe, Oceania and Asia"     ,   SNROM_VIDEO_PAL     },
    { "Sweden"                                  ,   SNROM_VIDEO_PAL     },
    { "Finland"                                 ,   SNROM_VIDEO_PAL     },
    { "Denmark"                                 ,   SNROM_VIDEO_PAL     },
    { "France"                                  ,   SNROM_VIDEO_PAL     },
    { "Holland"                                 ,   SNROM_VIDEO_PAL     },
    { "Spain"                                   ,   SNROM_VIDEO_PAL     },
    { "Germany, Austria and Switzerland"        ,   SNROM_VIDEO_PAL     },
    { "Italy"                                   ,   SNROM_VIDEO_PAL     },
    { "Hong Kong and China"                     ,   SNROM_VIDEO_PAL     },
    { "Indonesia"                               ,   SNROM_VIDEO_PAL     },
    { "Korea"                                   ,   SNROM_VIDEO_PAL     },
};

static SNRomLicenseT _SNRom_License[]=
{
    { 1   , "Nintendo"                                  },
    { 3   , "Imagineer-Zoom"                            },
    { 5   , "Zamuse"                                    },
    { 6   , "Falcom"                                    },
    { 8   , "Capcom"                                    },
    { 9   , "HOT-B"                                     },
    { 10  , "Jaleco"                                    },
    { 11  , "Coconuts"                                  },
    { 12  , "Rage Software"                             },
    { 14  , "Technos"                                   },
    { 15  , "Mebio Software"                            },
    { 18  , "Gremlin Graphics"                          },
    { 19  , "Electronic Arts"                           },
    { 21  , "COBRA Team"                                },
    { 22  , "Human/Field"                               },
    { 23  , "KOEI"                                      },
    { 24  , "Hudson Soft"                               },
    { 26  , "Yanoman"                                   },
    { 28  , "Tecmo"                                     },
    { 30  , "Open System"                               },
    { 31  , "Virgin Games"                              },
    { 32  , "KSS"                                       },
    { 33  , "Sunsoft"                                   },
    { 34  , "POW"                                       },
    { 35  , "Micro World"                               },
    { 38  , "Enix"                                      },
    { 39  , "Loriciel/Electro Brain"                    },
    { 40  , "Kemco"                                     },
    { 41  , "Seta Co.,Ltd."                             },
    { 45  , "Visit Co.,Ltd."                            },
    { 49  , "Carrozzeria"                               },
    { 50  , "Dynamic"                                   },
    { 51  , "Nintendo"                                  },
    { 52  , "Magifact"                                  },
    { 53  , "Hect"                                      },
    { 60  , "Empire Software"                           },
    { 61  , "Loriciel"                                  },
    { 64  , "Seika Corp."                               },
    { 65  , "UBI Soft"                                  },
    { 70  , "System 3"                                  },
    { 71  , "Spectrum Holobyte"                         },
    { 73  , "Irem"                                      },
    { 75  , "Raya Systems/Sculptured Software"          },
    { 76  , "Renovation Products"                       },
    { 77  , "Malibu Games/Black Pearl"                  },
    { 79  , "U.S. Gold"                                 },
    { 80  , "Absolute Entertainment"                    },
    { 81  , "Acclaim"                                   },
    { 82  , "Activision"                                },
    { 83  , "American Sammy"                            },
    { 84  , "GameTek"                                   },
    { 85  , "Hi Tech Expressions"                       },
    { 86  , "LJN Toys"                                  },
    { 90  , "Mindscape"                                 },
    { 93  , "Tradewest"                                 },
    { 95  , "American Softworks Corp."                  },
    { 96  , "Titus"                                     },
    { 97  , "Virgin Interactive Entertainment"          },
    { 98  , "Maxis"                                     },
    {103  , "Ocean"                                     },
    {105  , "Electronic Arts"                           },
    {107  , "Laser Beam"                                },
    {110  , "Elite"                                     },
    {111  , "Electro Brain"                             },
    {112  , "Infogrames"                                },
    {113  , "Interplay"                                 },
    {114  , "LucasArts"                                 },
    {115  , "Parker Brothers"                           },
    {117  , "STORM"                                     },
    {120  , "THQ Software"                              },
    {121  , "Accolade Inc."                             },
    {122  , "Triffix Entertainment"                     },
    {124  , "Microprose"                                },
    {127  , "Kemco"                                     },
    {128  , "Misawa"                                    },
    {129  , "Teichio"                                   },
    {130  , "Namco Ltd."                                },
    {131  , "Lozc"                                      },
    {132  , "Koei"                                      },
    {134  , "Tokuma Shoten Intermedia"                  },
    {136  , "DATAM-Polystar"                            },
    {139  , "Bullet-Proof Software"                     },
    {140  , "Vic Tokai"                                 },
    {142  , "Character Soft"                            },
    {143  , "I''Max"                                    },
    {144  , "Takara"                                    },
    {145  , "CHUN Soft"                                 },
    {146  , "Video System Co., Ltd."                    },
    {147  , "BEC"                                       },
    {149  , "Varie"                                     },
    {151  , "Kaneco"                                    },
    {153  , "Pack in Video"                             },
    {154  , "Nichibutsu"                                },
    {155  , "TECMO"                                     },
    {156  , "Imagineer Co."                             },
    {160  , "Telenet"                                   },
    {164  , "Konami"                                    },
    {165  , "K.Amusement Leasing Co."                   },
    {167  , "Takara"                                    },
    {169  , "Technos Jap."                              },
    {170  , "JVC"                                       },
    {172  , "Toei Animation"                            },
    {173  , "Toho"                                      },
    {175  , "Namco Ltd."                                },
    {177  , "ASCII Co. Activison"                       },
    {178  , "BanDai America"                            },
    {180  , "Enix"                                      },
    {182  , "Halken"                                    },
    {186  , "Culture Brain"                             },
    {187  , "Sunsoft"                                   },
    {188  , "Toshiba EMI"                               },
    {189  , "Sony Imagesoft"                            },
    {191  , "Sammy"                                     },
    {192  , "Taito"                                     },
    {194  , "Kemco"                                     },
    {195  , "Square"                                    },
    {196  , "Tokuma Soft"                               },
    {197  , "Data East"                                 },
    {198  , "Tonkin House"                              },
    {200  , "KOEI"                                      },
    {202  , "Konami USA"                                },
    {203  , "NTVIC"                                     },
    {205  , "Meldac"                                    },
    {206  , "Pony Canyon"                               },
    {207  , "Sotsu Agency/Sunrise"                      },
    {208  , "Disco/Taito"                               },
    {209  , "Sofel"                                     },
    {210  , "Quest Corp."                               },
    {211  , "Sigma"                                     },
    {214  , "Naxat"                                     },
    {216  , "Capcom Co., Ltd."                          },
    {217  , "Banpresto"                                 },
    {218  , "Tomy"                                      },
    {219  , "Acclaim"                                   },
    {221  , "NCS"                                       },
    {222  , "Human Entertainment"                       },
    {223  , "Altron"                                    },
    {224  , "Jaleco"                                    },
    {226  , "Yutaka"                                    },
    {228  , "T&ESoft"                                   },
    {229  , "EPOCH Co.,Ltd."                            },
    {231  , "Athena"                                    },
    {232  , "Asmik"                                     },
    {233  , "Natsume"                                   },
    {234  , "King Records"                              },
    {235  , "Atlus"                                     },
    {236  , "Sony Music Entertainment"                  },
    {238  , "IGS"                                       },
    {241  , "Motown Software"                           },
    {242  , "Left Field Entertainment"                  },
    {243  , "Beam Software"                             },
    {244  , "Tec Magik"                                 },
    {249  , "Cybersoft"                                 },
    {255  , "Hudson Soft"                               },
	{0  , NULL                               }
};



//
//
//

                                                        

static SNRomCountryT *_SNRomGetCountry(Uint8 uCode)
{
    if (uCode < sizeof(_SNRom_Country) / sizeof(_SNRom_Country[0]))
    {
        return &_SNRom_Country[uCode];
    }   
    else
    {
        // invalid country code
        return NULL;
    }
}

static SNRomLicenseT *_SNRomGetLicense(Uint8 uCode)
{
    SNRomLicenseT *pLicense = _SNRom_License;

    while (pLicense->pName)
    {
        if (pLicense->uCode == uCode) 
        {
            // found license
            return pLicense;
        }

        pLicense++;
    }

    // invalid license
    return NULL;
}


SNRomHdrTypeE SnesRom::SNRomGetHdrType(SNRomHdrU *pRomHdr)
{
	// check SWC tag
	if (pRomHdr->SWC.Tag[0] == 0xAA && pRomHdr->SWC.Tag[1] == 0xBB && pRomHdr->SWC.Tag[2] == 0x04)
	{
		return SNROM_HDRTYPE_SWC;
	}

	// ???

	return SNROM_HDRTYPE_UNKNOWN;
}

//
//
//

static Bool _SNRomIsValidCartInfo(SNRomInfoT *pCartInfo)
{
	return pCartInfo && ((pCartInfo->InverseChecksum ^ pCartInfo->Checksum) == 0xFFFF);
}

//
//
//


SnesRom::SnesRom()
{
	m_bLoaded	= false;
	m_pRomMem	= NULL;
	m_pRomData	= NULL;
	m_pCartInfo = NULL;
	m_uRomBytes	= 0;
}

SnesRom::~SnesRom()
{
	Unload();
}

SNRomInfoT *SnesRom::GetCartInfo(Uint32 uOffset)
{
	if (m_pRomData)
	{
		// make sure offset doest go past end of rom data
		if ((uOffset + sizeof(SNRomInfoT)) <= m_uRomBytes)
		{
			// return cartinfo at offset
			return (SNRomInfoT *)(m_pRomData + uOffset);
		}
	} 
	return NULL;
}

void SnesRom::SetCartInfo(SNRomInfoT *pCartInfo)
{
	SNRomLicenseT *pLicense;
	SNRomCountryT *pCountry;

	m_pCartInfo = pCartInfo;
	if (pCartInfo)
	{
		pCountry = _SNRomGetCountry(pCartInfo->Country);
		pLicense = _SNRomGetLicense(pCartInfo->License);

		m_eVideoType = pCountry ? pCountry->eVideoType : SNROM_VIDEO_NTSC;
		m_uROMSize	  = 1 << (pCartInfo->RomSize - 7);
		switch (pCartInfo->SRAMSize)
		{
		default:
		case 0:
			m_uSRAMSize = 0;
			break;
		case 1:
			m_uSRAMSize = 16;
			break;
		case 2:
			m_uSRAMSize = 32;
			break;
		case 3:
			m_uSRAMSize = 64;
			break;
		}
		switch (pCartInfo->RomType)
		{
		case 0:
			m_Flags		 = SNROM_FLAG_ROM;
			break;
		case 1:
			m_Flags		 = SNROM_FLAG_ROM | SNROM_FLAG_RAM;
			break;
		case 2:
			m_Flags		 = SNROM_FLAG_ROM | SNROM_FLAG_SAVERAM;
			break;
		case 3:
			m_Flags		 = SNROM_FLAG_ROM | SNROM_FLAG_DSP1;
			break;
		case 4:
			m_Flags		 = SNROM_FLAG_ROM | SNROM_FLAG_RAM | SNROM_FLAG_DSP1;
			break;
		case 5:
			m_Flags		 = SNROM_FLAG_ROM | SNROM_FLAG_SAVERAM | SNROM_FLAG_DSP1;
			break;
		case 19:
			m_Flags		 = SNROM_FLAG_ROM | SNROM_FLAG_SUPERFX;
			break;
		case 227:
			m_Flags		 = SNROM_FLAG_ROM | SNROM_FLAG_RAM | SNROM_FLAG_GAMEBOY;
			break;
		case 246:
			m_Flags		 = SNROM_FLAG_ROM | SNROM_FLAG_DSP2;
			break;
		}
	} else
	{
		m_eVideoType = SNROM_VIDEO_NTSC;
		m_Flags		 = SNROM_FLAG_ROM;
		m_uROMSize   = 0;
		m_uSRAMSize  = 0;
	}
}

Uint32	SnesRom::GetNumRomRegions()
{
	return 1;
}

Char   *SnesRom::GetRomRegionName(Uint32 eRegion)
{
	switch (eRegion)
	{
		case 0:
			return "ROM";
		default:
			return NULL;
	}

}
Uint32 	SnesRom::GetRomRegionSize(Uint32 eRegion)
{
	switch (eRegion)
	{
		case 0:
			return m_uRomBytes;
		default:
			return 0;
	}
}



Char   *SnesRom::GetRomTitle()
{
    SNRomInfoT *pInfo;
    pInfo = m_pCartInfo;
	if (pInfo)
		return (Char *)pInfo->Title;
	return NULL;
}


Emu::Rom::LoadErrorE SnesRom::LoadRom(CDataIO *pFileIO, Uint8 *pBuffer, Uint32 nBufferBytes)
{
	SNRomHdrU		RomHdr;
	SNRomHdrTypeE	eRomHdrType;
	size_t nBytesRead;
	Uint32 nFileBytes;
	Uint32 nHeaderBytes;
	Uint32 nRomBytes;

	// determine file size
	pFileIO->Seek(0, SEEK_END);
	nFileBytes= (Uint32)pFileIO->GetPos();
	pFileIO->Seek(0, SEEK_SET);
	if (nFileBytes <= 0)
	{
		return LOADERROR_BADHEADERSIZE;
	}

//	printf("%d file size\n", nFileBytes);

	// determine header size
	nHeaderBytes = (nFileBytes & 0x1FFF);
	nRomBytes    = nFileBytes - nHeaderBytes;

	// is header size valid?
	if (nHeaderBytes!=0 && nHeaderBytes!=sizeof(SNRomHdrU))
	{
		nHeaderBytes = 0;
//		return LOADERROR_BADHEADERSIZE;
	}

	m_eMapping = SNROM_MAPPING_LOROM;

	// does header exist?
	if (nHeaderBytes== sizeof(SNRomHdrU))
	{
		// header exists!

		// read rom header from file
		pFileIO->Read(&RomHdr, sizeof(RomHdr));

		// determine type of file (if possible)
		eRomHdrType = SNRomGetHdrType(&RomHdr);

		switch (eRomHdrType)
		{
		case SNROM_HDRTYPE_SWC:
			nRomBytes = RomHdr.SWC.uSize * 1024 * 1024 / 8 / 16;
			m_eMapping = (RomHdr.SWC.uImageInfo & 0x10)  ? SNROM_MAPPING_HIROM : SNROM_MAPPING_LOROM;
			break;
		default:
		case SNROM_HDRTYPE_UNKNOWN:
			m_eMapping = SNROM_MAPPING_LOROM;
			break;
		}
	} 

	// set size of ROM
	m_uRomBytes = nRomBytes;
	if (m_uRomBytes == 0)
	{
		return LOADERROR_BADROMSIZE;
	}

	// try to get data pointer from file
	m_pRomMem = NULL;
	m_pRomData = pFileIO->ReadPtr(m_uRomBytes);

	if (m_pRomData == NULL)
	{
		if (pBuffer)
		{
			if (m_uRomBytes < nBufferBytes)
			{	// use provided buffer space
				m_pRomMem = NULL;
				m_pRomData = pBuffer;
			} else
			{
				// not enough buffer space provided
				return LOADERROR_OUTOFSPACE;
			}
		} else
		{

			// allocate memory for rom
			m_pRomMem = 
			m_pRomData = (Uint8 *)malloc(m_uRomBytes);
			if (!m_pRomData)
			{
				return LOADERROR_OUTOFSPACE;
			}
		}

		// read rom data
		nBytesRead = pFileIO->Read(m_pRomData, m_uRomBytes);
		if (nBytesRead != m_uRomBytes)
		{
			Unload();
			return LOADERROR_READFILE;
		}
	}

	SNRomInfoT *pCartInfo;	

	// get cart info for rom
	pCartInfo = GetCartInfo(32704);
	if (_SNRomIsValidCartInfo(pCartInfo))
	{
		// cart mapping found in lo-rom
		m_eMapping = SNROM_MAPPING_LOROM;
	} else
	{
		// try to get cart info for hi-rom
		pCartInfo = GetCartInfo(65472);
		if (_SNRomIsValidCartInfo(pCartInfo))
		{
			// cart mapping found in hi-rom
			m_eMapping = SNROM_MAPPING_HIROM;
		} else
		{
			// cart info not found
			pCartInfo = NULL;
		}
	}

	SetCartInfo(pCartInfo);

	m_bLoaded   = true;
	return LOADERROR_NONE;
}

void SnesRom::Unload()
{
	if (m_pRomMem)
	{
		free(m_pRomMem);
		m_pRomMem = NULL;
	}

	m_pCartInfo = NULL;
	m_pRomData = NULL;
	m_uRomBytes = 0;
	m_bLoaded   = false;
}



Uint32 SnesRom::GetNumExts()
{
	return 2;
}

Char *SnesRom::GetExtName(Uint32 uExt)
{
	switch (uExt)
	{
		case 0:
			return "smc";
		case 1:
			return "fig";
		default:
			return NULL;
	}
}

/* virtual */
Char   *SnesRom::GetMapperName()
{
	return NULL;
}