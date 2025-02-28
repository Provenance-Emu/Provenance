//
//  SystemIdentifier+TheGamesDB.swift
//  PVPrimitives
//
//  Created by Joseph Mattiello on 12/17/24.
//


public extension SystemIdentifier {
    /// Initialize a SystemIdentifier from TheGamesDB's platform ID
    /// Reference: https://api.thegamesdb.net/v1/Platforms
    init?(theGamesDBID: Int?) {
        guard let id = theGamesDBID else { return nil }

        switch id {
        // Nintendo Systems
        case 7:   self = .NES          // Nintendo Entertainment System (NES)
        case 3:   self = .N64          // Nintendo 64
        case 4:   self = .GB           // Nintendo Game Boy
        case 41:  self = .GBC          // Nintendo Game Boy Color
        case 5:   self = .GBA          // Nintendo Game Boy Advance
        case 2:   self = .GameCube     // Nintendo GameCube
        case 8:   self = .DS           // Nintendo DS (was NDS)
        case 4912: self = ._3DS        // Nintendo 3DS (was N3DS)
        case 6:   self = .SNES         // Super Nintendo (SNES)
        case 4936: self = .FDS         // Famicom Disk System
        case 4918: self = .VirtualBoy  // Nintendo Virtual Boy
        case 4957: self = .PokemonMini // Nintendo Pokémon Mini
        case 9:   self = .Wii          // Nintendo Wii

        // Sega Systems
        case 18, 36: self = .Genesis   // Sega Genesis/Mega Drive (same system, different regions)
        case 21:  self = .SegaCD       // Sega CD
        case 33:  self = .Sega32X      // Sega 32X
        case 17:  self = .Saturn       // Sega Saturn
        case 16:  self = .Dreamcast    // Sega Dreamcast
        case 20:  self = .GameGear     // Sega Game Gear
        case 35:  self = .MasterSystem // Sega Master System
        case 4949: self = .SG1000      // Sega SG-1000

        // 3DO
        case 25: self = ._3DO         // 3DO Interactive Multiplayer

        // Sony Systems
        case 10:  self = .PSX          // Sony PlayStation
        case 11:  self = .PS2          // Sony PlayStation 2
        case 12:  self = .PS3          // Sony PlayStation 3
        case 13:  self = .PSP          // Sony PlayStation Portable

        // NEC Systems
        case 34:  self = .PCE          // TurboGrafx-16/PC Engine
        case 4955: self = .PCECD       // TurboGrafx CD/PC Engine CD
        case 4930: self = .PCFX        // PC-FX

        // SNK Systems
        case 24:  self = .NeoGeo       // Neo Geo
        case 4922: self = .NGP         // Neo Geo Pocket
        case 4923: self = .NGPC        // Neo Geo Pocket Color

        // Atari Systems
        case 22:  self = .Atari2600    // Atari 2600
        case 26:  self = .Atari5200    // Atari 5200
        case 27:  self = .Atari7800    // Atari 7800
        case 28:  self = .AtariJaguar  // Atari Jaguar
        case 4924: self = .Lynx        // Atari Lynx
        case 4937: self = .AtariST     // Atari ST
        case 4943: self = .Atari8bit

        // Bandai Systems
        case 4925: self = .WonderSwan  // WonderSwan
        case 4926: self = .WonderSwanColor // WonderSwan Color

        // Philips Systems
        case 4917: self = .CDi

        // Apple Systems
        case 4942: self = .AppleII
        case 37:  self = .Macintosh

        // NEC Systems
        case 24: self = .NeoGeo
        case 4922: self = .NGP
        case 4923: self = .NGPC

        // Watara Systems
        case 32: self = .Intellivision // Watara Intellivision

        // Other Systems
        case 1:     self = .DOS            // DOS (also used for DOOM, Quake, etc.)
        case 29:    self = .AtariJaguarCD  // Atari Jaguar CD
        case 31:  self = .ColecoVision // ColecoVision
        case 40:  self = .C64          // Commodore 64
        case 4913: self = .ZXSpectrum  // Sinclair ZX Spectrum
        case 4927: self = .Odyssey2    // Magnavox Odyssey 2
        case 4929: self = .MSX         // MSX
        case 4939: self = .Vectrex
        case 4948:  self = .MegaDuck       // Mega Duck
        case 4959:  self = .Supervision    // Supervision

        // Arcade Systems
        case 23: self = .MAME

        default: return nil
        }
    }

    /// Get TheGamesDB platform ID for this system
    var theGamesDBID: Int? {
        switch self {
        // Nintendo Systems
        case .NES: return 7            // Nintendo Entertainment System (NES)
        case .N64: return 3            // Nintendo 64
        case .GB: return 4             // Nintendo Game Boy
        case .GBC: return 41           // Nintendo Game Boy Color
        case .GBA: return 5            // Nintendo Game Boy Advance
        case .GameCube: return 2       // Nintendo GameCube
        case .DS: return 8             // Nintendo DS
        case ._3DS: return 4912        // Nintendo 3DS
        case .SNES: return 6           // Super Nintendo (SNES)
        case .FDS: return 4936         // Famicom Disk System
        case .VirtualBoy: return 4918  // Nintendo Virtual Boy
        case .PokemonMini: return 4957 // Nintendo Pokémon Mini
        case .Wii: return 9            // Nintendo Wii

        // Sega Systems
        case .Genesis: return 18       // Sega Genesis (using US ID)
        case .SegaCD: return 21        // Sega CD
        case .Sega32X: return 33       // Sega 32X
        case .Saturn: return 17        // Sega Saturn
        case .Dreamcast: return 16     // Sega Dreamcast
        case .GameGear: return 20      // Sega Game Gear
        case .MasterSystem: return 35  // Sega Master System
        case .SG1000: return 4949      // Sega SG-1000

        // 3DO
        case ._3DO: return 25         // 3DO Interactive Multiplayer

        // Sony Systems
        case .PSX: return 10           // Sony PlayStation
        case .PS2: return 11           // Sony PlayStation 2
        case .PS3: return 12           // Sony PlayStation 3
        case .PSP: return 13           // Sony PlayStation Portable

        // NEC Systems
        case .PCE: return 34           // TurboGrafx-16/PC Engine
        case .PCECD: return 4955       // TurboGrafx CD/PC Engine CD
        case .PCFX: return 4930        // PC-FX

        // SNK Systems
        case .NeoGeo: return 24        // Neo Geo
        case .NGP: return 4922         // Neo Geo Pocket
        case .NGPC: return 4923        // Neo Geo Pocket Color

        // Atari Systems
        case .Atari2600: return 22     // Atari 2600
        case .Atari5200: return 26     // Atari 5200
        case .Atari7800: return 27     // Atari 7800
        case .AtariJaguar: return 28   // Atari Jaguar
        case .Lynx: return 4924        // Atari Lynx
        case .AtariST: return 4937     // Atari ST

        // Bandai Systems
        case .WonderSwan: return 4925  // WonderSwan
        case .WonderSwanColor: return 4926 // WonderSwan Color

        // Philips Systems
        case .CDi: return 4917

        // Other Systems
        case .ColecoVision: return 31  // ColecoVision
        case .Odyssey2: return 4927    // Magnavox Odyssey 2
        case .C64: return 40           // Commodore 64
        case .MSX: return 4929         // MSX
        case .ZXSpectrum: return 4913  // Sinclair ZX Spectrum
        case .MAME: return 23
        case .CPS1: return 23
        case .CPS2: return 23
        case .CPS3: return 23


//        default: return nil
        case .AppleII: return 4942
        case .Atari8bit: return 4943 // Atari-800
        case .AtariJaguarCD: return 29
        case .DOS: return 1
        case .DOOM: return 1
        case .Quake: return 1
        case .Quake2: return 1
        case .Wolf3D: return 1

//        case .EP128:
        case .Intellivision: return 32
        case .Macintosh: return 37
        case .MegaDuck: return 4948
        case .MSX2: return 4929
//        case .Music:
//        case .PalmOS:
//        case .RetroArch:
//        case .SGFX:
        case .Supervision: return 4959
//        case .TIC80:
        case .Vectrex: return 4939
        case .Unknown: return nil
        default: return nil
        }
    }
}

/*
  All systems by TheGamesDB.net

 ```json
 {"code":200,"status":"Success","data":{"count":150,"platforms":{"25":{"id":25,"name":"3DO","alias":"3do"},"4944":{"id":4944,"name":"Acorn Archimedes","alias":"acorn-archimedes"},"5014":{"id":5014,"name":"Acorn Atom","alias":"acorn-atom"},"4954":{"id":4954,"name":"Acorn Electron","alias":"acorn-electron"},"4976":{"id":4976,"name":"Action Max","alias":"action-max"},"4911":{"id":4911,"name":"Amiga","alias":"amiga"},"4947":{"id":4947,"name":"Amiga CD32","alias":"amiga-cd32"},"4914":{"id":4914,"name":"Amstrad CPC","alias":"amstrad-cpc"},"4999":{"id":4999,"name":"Amstrad GX4000","alias":"amstrad-gx4000"},"4916":{"id":4916,"name":"Android","alias":"android"},"4969":{"id":4969,"name":"APF MP-1000","alias":"apf-mp-1000"},"4942":{"id":4942,"name":"Apple II","alias":"apple2"},"5001":{"id":5001,"name":"Apple Pippin","alias":"apple-pippin"},"23":{"id":23,"name":"Arcade","alias":"arcade"},"22":{"id":22,"name":"Atari 2600","alias":"atari-2600"},"26":{"id":26,"name":"Atari 5200","alias":"atari-5200"},"27":{"id":27,"name":"Atari 7800","alias":"atari-7800"},"4943":{"id":4943,"name":"Atari 800","alias":"atari800"},"28":{"id":28,"name":"Atari Jaguar","alias":"atari-jaguar"},"29":{"id":29,"name":"Atari Jaguar CD","alias":"atari-jaguar-cd"},"4924":{"id":4924,"name":"Atari Lynx","alias":"atari-lynx"},"4937":{"id":4937,"name":"Atari ST","alias":"atari-st"},"30":{"id":30,"name":"Atari XE","alias":"atari-xe"},"4968":{"id":4968,"name":"Bally Astrocade","alias":"bally-astrocade"},"4995":{"id":4995,"name":"Bandai TV Jack 5000","alias":"bandai-tv-jack-5000"},"4997":{"id":4997,"name":"BBC Bridge Companion","alias":"bbc-bridge-companion"},"5013":{"id":5013,"name":"BBC Micro","alias":"bbc-micro"},"4991":{"id":4991,"name":"Casio Loopy","alias":"casio-loopy"},"4964":{"id":4964,"name":"Casio PV-1000","alias":"casio-pv-1000"},"4970":{"id":4970,"name":"Coleco Telstar Arcade","alias":"coleco-telstar-arcade"},"31":{"id":31,"name":"Colecovision","alias":"colecovision"},"4946":{"id":4946,"name":"Commodore 128","alias":"c128"},"5006":{"id":5006,"name":"Commodore 16","alias":"commodore-16"},"40":{"id":40,"name":"Commodore 64","alias":"commodore-64"},"5008":{"id":5008,"name":"Commodore PET","alias":"commodore-pet"},"5007":{"id":5007,"name":"Commodore Plus\/4","alias":"commodore-plus\/4"},"4945":{"id":4945,"name":"Commodore VIC-20","alias":"commodore-vic20"},"5012":{"id":5012,"name":"Didj","alias":"didj"},"4952":{"id":4952,"name":"Dragon 32\/64","alias":"dragon32-64"},"4963":{"id":4963,"name":"Emerson Arcadia 2001","alias":"emerson-arcadia-2001"},"4974":{"id":4974,"name":"Entex Adventure Vision","alias":"entex-adventure-vision"},"4973":{"id":4973,"name":"Entex Select-a-Game","alias":"entex-select-a-game"},"4965":{"id":4965,"name":"Epoch Cassette Vision","alias":"epoch-cassette-vision"},"4966":{"id":4966,"name":"Epoch Super Cassette Vision","alias":"epoch-super-cassette-vision"},"4985":{"id":4985,"name":"Evercade","alias":"evercade"},"4928":{"id":4928,"name":"Fairchild Channel F","alias":"fairchild"},"4936":{"id":4936,"name":"Famicom Disk System","alias":"fds"},"4932":{"id":4932,"name":"FM Towns Marty","alias":"fmtowns"},"4978":{"id":4978,"name":"Fujitsu FM-7","alias":"fujitsu-fm-7"},"4962":{"id":4962,"name":"Gakken Compact Vision","alias":"gakken-compact-vision"},"5004":{"id":5004,"name":"Gamate","alias":"gamate"},"4950":{"id":4950,"name":"Game & Watch","alias":"game-and-watch"},"5002":{"id":5002,"name":"Game Wave","alias":"game-wave"},"4940":{"id":4940,"name":"Game.com","alias":"game-com"},"4992":{"id":4992,"name":"Gizmondo","alias":"gizmondo"},"5015":{"id":5015,"name":"GP32","alias":"gp32"},"4951":{"id":4951,"name":"Handheld Electronic Games (LCD)","alias":"lcd"},"4987":{"id":4987,"name":"HyperScan","alias":"hyperscan"},"32":{"id":32,"name":"Intellivision","alias":"intellivision"},"4994":{"id":4994,"name":"Interton VC 4000","alias":"interton-vc-4000"},"4915":{"id":4915,"name":"iOS","alias":"ios"},"5018":{"id":5018,"name":"J2ME (Java Platform, Micro Edition)","alias":"j2me-(java-platform,-micro-edition)"},"5019":{"id":5019,"name":"Jupiter Ace","alias":"jupiter-ace"},"37":{"id":37,"name":"Mac OS","alias":"mac-os"},"4961":{"id":4961,"name":"Magnavox Odyssey 1","alias":"magnavox-odyssey"},"4927":{"id":4927,"name":"Magnavox Odyssey 2","alias":"magnavox-odyssey-2"},"4989":{"id":4989,"name":"Mattel Aquarius","alias":"mattel-aquarius"},"4948":{"id":4948,"name":"Mega Duck","alias":"megaduck"},"14":{"id":14,"name":"Microsoft Xbox","alias":"microsoft-xbox"},"15":{"id":15,"name":"Microsoft Xbox 360","alias":"microsoft-xbox-360"},"4920":{"id":4920,"name":"Microsoft Xbox One","alias":"microsoft-xbox-one"},"4981":{"id":4981,"name":"Microsoft Xbox Series X","alias":"microsoft-xbox-series-x"},"4972":{"id":4972,"name":"Milton Bradley Microvision","alias":"milton-bradley-microvision"},"4929":{"id":4929,"name":"MSX","alias":"msx"},"4938":{"id":4938,"name":"N-Gage","alias":"ngage"},"24":{"id":24,"name":"Neo Geo","alias":"neogeo"},"4956":{"id":4956,"name":"Neo Geo CD","alias":"neo-geo-cd"},"4922":{"id":4922,"name":"Neo Geo Pocket","alias":"neo-geo-pocket"},"4923":{"id":4923,"name":"Neo Geo Pocket Color","alias":"neo-geo-pocket-color"},"4912":{"id":4912,"name":"Nintendo 3DS","alias":"nintendo-3ds"},"3":{"id":3,"name":"Nintendo 64","alias":"nintendo-64"},"8":{"id":8,"name":"Nintendo DS","alias":"nintendo-ds"},"7":{"id":7,"name":"Nintendo Entertainment System (NES)","alias":"nintendo-entertainment-system-nes"},"4":{"id":4,"name":"Nintendo Game Boy","alias":"nintendo-gameboy"},"5":{"id":5,"name":"Nintendo Game Boy Advance","alias":"nintendo-gameboy-advance"},"41":{"id":41,"name":"Nintendo Game Boy Color","alias":"nintendo-gameboy-color"},"2":{"id":2,"name":"Nintendo GameCube","alias":"nintendo-gamecube"},"4957":{"id":4957,"name":"Nintendo Pok\u00e9mon Mini","alias":"nintendo-pokmon-mini"},"4971":{"id":4971,"name":"Nintendo Switch","alias":"nintendo-switch"},"4918":{"id":4918,"name":"Nintendo Virtual Boy","alias":"nintendo-virtual-boy"},"9":{"id":9,"name":"Nintendo Wii","alias":"nintendo-wii"},"38":{"id":38,"name":"Nintendo Wii U","alias":"nintendo-wii-u"},"4935":{"id":4935,"name":"Nuon","alias":"nuon"},"4990":{"id":4990,"name":"Oculus Quest","alias":"oculus-quest"},"4986":{"id":4986,"name":"Oric-1","alias":"oric-1"},"4921":{"id":4921,"name":"Ouya","alias":"ouya"},"5003":{"id":5003,"name":"Palmtex Super Micro","alias":"palmtex-super-micro"},"1":{"id":1,"name":"PC","alias":"pc"},"4933":{"id":4933,"name":"PC-88","alias":"pc88"},"4934":{"id":4934,"name":"PC-98","alias":"pc98"},"4930":{"id":4930,"name":"PC-FX","alias":"pcfx"},"4917":{"id":4917,"name":"Philips CD-i","alias":"philips-cd-i"},"4993":{"id":4993,"name":"Philips Tele-Spiel ES-2201","alias":"philips-tele-spiel-es-2201"},"4975":{"id":4975,"name":"Pioneer LaserActive","alias":""},"5016":{"id":5016,"name":"Playdate","alias":"playdate"},"5000":{"id":5000,"name":"Playdia","alias":"playdia"},"4983":{"id":4983,"name":"R-Zone","alias":"r-zone"},"4967":{"id":4967,"name":"RCA Studio II","alias":"rca-studio-ii"},"4979":{"id":4979,"name":"SAM Coup\u00e9","alias":"sam-coupe"},"33":{"id":33,"name":"Sega 32X","alias":"sega-32x"},"21":{"id":21,"name":"Sega CD","alias":"sega-cd"},"16":{"id":16,"name":"Sega Dreamcast","alias":"sega-dreamcast"},"20":{"id":20,"name":"Sega Game Gear","alias":"sega-game-gear"},"18":{"id":18,"name":"Sega Genesis","alias":"sega-genesis"},"35":{"id":35,"name":"Sega Master System","alias":"sega-master-system"},"36":{"id":36,"name":"Sega Mega Drive","alias":"sega-mega-drive"},"4958":{"id":4958,"name":"Sega Pico","alias":"sega-pico"},"17":{"id":17,"name":"Sega Saturn","alias":"sega-saturn"},"4949":{"id":4949,"name":"SEGA SG-1000","alias":"sg1000"},"4977":{"id":4977,"name":"Sharp X1","alias":"sharp-x1"},"4931":{"id":4931,"name":"Sharp X68000","alias":"x68"},"4996":{"id":4996,"name":"SHG Black Point","alias":"shg-black-point"},"5020":{"id":5020,"name":"Sinclair QL","alias":"sinclair-ql"},"4913":{"id":4913,"name":"Sinclair ZX Spectrum","alias":"sinclair-zx-spectrum"},"5009":{"id":5009,"name":"Sinclair ZX80","alias":"sinclair-zx80"},"5010":{"id":5010,"name":"Sinclair ZX81","alias":"sinclair-zx81"},"10":{"id":10,"name":"Sony Playstation","alias":"sony-playstation"},"11":{"id":11,"name":"Sony Playstation 2","alias":"sony-playstation-2"},"12":{"id":12,"name":"Sony Playstation 3","alias":"sony-playstation-3"},"4919":{"id":4919,"name":"Sony Playstation 4","alias":"sony-playstation-4"},"4980":{"id":4980,"name":"Sony Playstation 5","alias":"sony-playstation-5"},"13":{"id":13,"name":"Sony Playstation Portable","alias":"sony-psp"},"39":{"id":39,"name":"Sony Playstation Vita","alias":"sony-playstation-vita"},"5011":{"id":5011,"name":"Stadia","alias":"stadia"},"6":{"id":6,"name":"Super Nintendo (SNES)","alias":"super-nintendo-snes"},"4982":{"id":4982,"name":"Tandy Visual Interactive System","alias":"tandy-vis"},"5017":{"id":5017,"name":"Tapwave Zodiac","alias":"tapwave-zodiac"},"4953":{"id":4953,"name":"Texas Instruments TI-99\/4A","alias":"texas-instruments-ti-99-4a"},"4960":{"id":4960,"name":"Tomy Tutor","alias":"tomy-pyta"},"4941":{"id":4941,"name":"TRS-80 Color Computer","alias":"trs80-color"},"34":{"id":34,"name":"TurboGrafx 16","alias":"turbografx-16"},"4955":{"id":4955,"name":"TurboGrafx CD","alias":"turbo-grafx-cd"},"4988":{"id":4988,"name":"V.Smile","alias":"v-smile"},"4939":{"id":4939,"name":"Vectrex","alias":"vectrex"},"5005":{"id":5005,"name":"VTech CreatiVision","alias":"vtech-creativision"},"4998":{"id":4998,"name":"VTech Socrates","alias":"vtech-socrates"},"4959":{"id":4959,"name":"Watara Supervision","alias":"watara-supervision"},"4925":{"id":4925,"name":"WonderSwan","alias":"wonderswan"},"4926":{"id":4926,"name":"WonderSwan Color","alias":"wonderswan-color"},"4984":{"id":4984,"name":"Xavix Port","alias":"xavix-port"}}},"remaining_monthly_allowance":1434,"extra_allowance":0,"allowance_refresh_timer":1826422}
 ```

 */
