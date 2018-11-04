package com.reicast.emulator.config;

public class Compat {
    public int isVGACompatible(String gameId) {
        int vgaMode; // 0 = VGA, 1 = Patchable, 3 = TV
        switch (gameId) {
            // VGA Compatible
            case "T36803N": //102 Dalmatians puppies to the Rescue
            case "T36813D05": //102 Dalmatians puppies to the Rescue
            case "51064": // 18 Wheeler American Pro Trucker
            case "MK51064": // 18 Wheeler American Pro Trucker
            case "T9708N": // 4 Wheel Thunder
            case "T9706D": // 4 Wheel Thunder
            case "T41903N": // 4x4 Evolution
            case "MK51190": // 90 Minutes Championship Football
            case "T40201N": // Aerowings
            case "T40202D50": // Aerowings
            case "T40210N": // Aerowings 2
            case "MK51171": // Alien Front Online
            case "T15117N": // Alone in the Dark The New Nightmare
            case "T15112D05": // Alone in the Dark The New Nightmare
            case "T40301N": // Armada
            case "T15130N": // Atari Aniversary Edition
            case "T44102N": // Bang! Gunship Elite
            case "T13001N": // Blue Stinger
            case "T13001D58": // Blue Stinger
            case "51065": // Bomberman Online
            case "T13007N": // Buzz Lightyear of Star Command
            case "T13005D05": // Buzz Lightyear of Star Command
            case "T1215N": // Cannon Spike
            case "T46601D50": // Cannon Spike
            case "T1218N": // Capcom Vs. SNK
            case "T5701N": // Carrier
            case "T44901D50": // Carrier
            case "T40602N": // Centepede
            case "T41403N": // Championship Surfer
            case "T41402D50": // Championship Surfer
            case "T15127N": // Charge'N Blast
            case "T44902D50": // Charge'N Blast
            case "T36811N": // Chicken Run
            case "T36814D05": // Chicken Run
            case "51049": // ChuChu Rocket!
            case "MK5104950": // ChuChu Rocket!
            case "51160": // Confidential Mission
            case "MK5116050": // Confidential Mission
            case "51035": // Crazy Taxi
            case "MK5103550": // Crazy Taxi
            case "51136": // Crazy Taxi 2
            case "MK5113650": // Crazy Taxi 2
            case "51036": // D-2
            case "T8120N": // Dave Mirra BMX
            case "T8120D59": // Dave Mirra BMX
            case "51037": // Daytona USA
            case "MK5103750": // Daytona USA 2001
            case "T3601N": // Dead or Alive 2
            case "T8116D05": // Dead or Alive 2 & ECW Hardcore Revolution
            case "T2401N": // Death Crimson OX
            case "T15112N": // Demolition Racer
            case "T17717N": // Dinosaur
            case "T17714D05": // Donald Duck: Quack Attack
            case "T40203N": // Draconus: Cult of the Wyrm
            case "T17720N": // Dragon Riders: Chronicles of Pern
            case "T17716D91": // Dragon Riders: Chronicles of Pern
            case "T8113N": // Ducati World Racing Challenge
            case "T8121D05": // Ducati World
            case "51013": // Dynamite Cop!
            case "MK5101350": // Dynamite Cop!
            case "51033": // Ecco the Dolphin: Defender of the Future
            case "MK5103350": // Ecco the Dolphin: Defender of the Future
            case "T41601N": // Elemental Gimmick Gear
            case "T9504D50": // ESPN International Track n Field
            case "T9505N": // ESPN NBA2Night
            case "T7015D50": // European Super League
            case "T46605D71": // Evil Twin Cyprien's Chronicles
            case "T17706N": // Evolution: The World of Sacred Device
            case "T17711N": // Evolution 2: Far Off Promise
            case "T45005D50": // Evolution 2: Far Off Promise
            case "T22903D50": // Exhibition of Speed
            case "T17706D50": // F1 Racing Championship
            case "T3001N": // F1 World Grand Prix
            case "T3001D50": // F1 World Grand Prix
            case "T3002D50": // F1 World Grand Prix II
            case "T8119N": // F355 Challenge: Passione Rossa
            case "T8118D05": // F355 Challenge: Passione Rossa
            case "T44306N": // Fatal Fury: Mark of the Wolf
            case "T35801N": // Fighting Force 2
            case "T36802D05": // Fighting Force 2
            case "MK5115450": // Fighting Vipers 2
            case "51007": // Flag to Flag
            case "51114": // Floigan Brothers Episode 1
            case "MK5111450": // Floigan Brothers Episode 1
            case "T40604N": // Frogger 2 Swampies Revenge
            case "T8107N": // Fur Fighters
            case "T8113D05": // Fur Fighters
            case "T9710N": // Gauntlet Legends
            case "T9707D51": // Gauntlet Legends
            case "T1209N": // Giga Wing
            case "T7008D50": // Giga Wing
            case "T1222N": // Giga Wing 2
            case "T42102N": // Grand Theft Auto II
            case "T40502D61": // Grand Theft Auto II
            case "T17716N": // Grandia II
            case "T17715D05": // Grandia II
            case "T9512N": // Grintch, The
            case "T9503D76": // Grintch, The
            case "T13301N": // Gundam Side Story 0079
            case "51041": // Headhunter
            case "T1223N": // Heavy Metal: Geomatrix
            case "MK5104550": // House of the Dead 2
            case "T11008N": // Hoyle Casino
            case "T46001N": // Illbleed
            case "T12503N": // Incoming
            case "T40701D50": // Incoming
            case "T41302N": // Industrial Spy: Operation Espionage
            case "T8104N": // Jeremy McGrath Supercross 2000
            case "T8114D05": // Jeremy McGrath Supercross 2000
            case "BKL8317601ENG": // Jeremy McGrath Supercross 2000
            case "51058": // Jet Grind Radio
            case "MK5105850": // Jet Set Radio
            case "T7001D": // Jimmy White's 2: Cueball
            case "T22903N": // Kao the Kangeroo
            case "T22902D50": // Kao the Kangeroo
            case "T41901N": // KISS: Psycho Circus: The Nightmare Child
            case "T40506D50": // KISS: Psycho Circus: The Nightmare Child
            case "T36802N": // Legacy of Kain: Soul Reaver
            case "T36803D05": // Legacy of Kain: Soul Reaver
            case "T15108D50": // Loony Toons Space Race
            case "T40208N": // Mag Force Racing
            case "T40207D50": // Mag Force Racing
            case "T36804N": // Magical Racing Tour
            case "T36809D50": // Magical Racing Tour
            case "51050": // Maken X
            case "MK5105050": // Maken X
            case "T1221N": // Mars Matrix
            case "T1202N": // Marvel vs. Capcom: Clash of Super Heroes
            case "T7002D61": // Marvel vs. Capcom: Clash of Super Heroes
            case "T1212N": // Marvel vs. Capcom 2
            case "T7010D50": // Marvel vs. Capcom 2: New Age of Heroes
            case "T13005N": // Mat Hoffman's Pro BMX
            case "T41402N": // Max Steel Covert Missions
            case "T11002N": // Maximum Pool
            case "T12502N": // MDK2
            case "T12501D61": // MDK2
            case "51012": // Metropolis Street Racer
            case "MK5102250": // Metropolis Street Racer
            case "T9713N": // Midway Greatest Arcade Hits Volume 1
            case "T9714N": // Midway Greatest Arcade Hits Volume 2
            case "T40508D": // Moho (Ball Breakers)
            case "T17701N": // Monaco Grand Prix
            case "T45006D50": // Racing Simulation 2: On-line Monaco Grand Prix
            case "T9701D61": // Mortal Kombat Gold
            case "T1402N": // Mr Driller
            case "T7020D50": // Mr Driller
            case "T1403N": // Namco Museum
            case "51004": // NBA 2K
            case "MK5100453": // NBA 2K
            case "51063": // NBA 2K1
            case "51178": // NBA 2K2
            case "MK5117850": // NBA 2K2
            case "T9709N": // NBA Hoopz
            case "51176": // NCAA College Football 2K2
            case "51003": // NFL 2K
            case "51062": // NFL 2K1
            case "51168": // NFL 2K2
            case "T9703N": // NFL Blitz 2000
            case "T9712N": // NFL Blitz 2001
            case "T8101N": // NFL Quarterback Club 2000
            case "T8102D05": // NFL Quarterback Club 2000
            case "T8115N": // NFL Quarterback Club 2001
            case "MK5102589": // NHL 2K
            case "51182": // NHL 2K2
            case "T9504N": // Nightmare Creatures II
            case "T9502D76": // Nightmare Creatures II
            case "T36807N": // Omikron The Nomad Soul
            case "T36805D09": // Nomad Soul, The
            case "51140": // Ooga Booga
            case "51102": // OutTrigger: International Counter Terrorism Special Force
            case "MK5110250": // OutTrigger: International Counter Terrorism Special Force
            case "T15105N": // Pen Pen TriIcelon
            case "51100": // Phantasy Star Online
            case "MK5110050": // Phantasy Star Online
            case "51193": // Phantasy Star Online Ver.2
            case "MK5119350": // Phantasy Star Online Ver.2
            case "MK5114864": // Planet Ring
            case "T17713N": // POD: Speedzone
            case "T17710D50": // Pod 2 Multiplayer Online
            case "T1201N": // Power Stone
            case "T36801D64": // Power Stone
            case "T1211N": // Power Stone 2
            case "T36812D61": // Power Stone 2
            case "T41405N": // Prince of Persia Arabian Nights
            case "T30701D": // Pro Pinball Trilogy
            case "T1219N": // Project Justice
            case "T7022D50": // Project Justice: Rival Schools 2
            case "51061": // Quake III Arena
            case "MK5106150": // Quake III Arena
            case "T41902N": // Railroad Tycoon II: Gold Edition
            case "T17704N": // Rayman 2
            case "T17707D50": // Rayman 2
            case "T40219N": // Razor Freestyle Scooter
            case "T8109N": // Re-Volt
            case "T8107D05": // Re-Volt
            case "T9704N": // Ready 2 Rumble Boxing
            case "T9704D50": // Ready 2 Rumble Boxing
            case "T9717N": // Ready 2 Rumble Boxing Round 2
            case "T9711D50": // Ready 2 Rumble Boxing Round 2
            case "T7012D97": // Record of Lodoss War
            case "T40215N": // Red Dog: Superior Firepower
            case "MK5102150": // Red Dog: Superior Firepower
            case "T1205N": // Resident Evil 2
            case "T7004D61": // Resident Evil 2
            case "T1220N": // Resident Evil 3: Nemesis
            case "T7021D56": // Resident Evil 3: Nemesis
            case "T1204N": // Resident Evil Code: Veronica
            case "MK5119250": // REZ
            case "T22901D05": // Roadsters
            case "51092": // Samba De Amigo
            case "MK5109250": // Samba De Amigo
            case "51048": // SeaMan
            case "MK5100605": // Sega Bass Fishing
            case "51166": // Sega Bass Fishing 2
            case "51053": // Sega GT
            case "MK5105350": // Sega GT
            case "51096": // Sega Marine Fishing
            case "MK5101950": // Sega Rally 2
            case "51146": // Sega Smash Pack 1
            case "MK5108350": // Sega Worldwide Soccer 2000 Euro Edition
            case "T41301N": // Seventh Cross Evolution
            case "T8106N": // Shadowman
            case "51059": // Shenmue
            case "MK5105950": // Shenmue
            case "MK5118450": // Shenmue 2
            case "T9505D76": // Silent Scope
            case "T15108N": // Silver
            case "T15109D91": // Silver
            case "51052": // Skies of Arcadia
            case "T15106N": // Slave Zero
            case "T15104D59": // Slave Zero
            case "T40207N": // Sno-Cross Championship Racing
            case "T40212N": // Soldier of Fortune
            case "T17726D50": // Soldier of Fortune
            case "51000": // Sonic Adventure
            case "MK5100053": // Sonic Adventure
            case "51014": // Sonic Adventure (Limited Edition)
            case "51117": // Sonic Adventure 2
            case "MK5111750": // Sonic Adventure 2
            case "51060": // Sonic Shuffle
            case "MK5106050": // Sonic Shuffle
            case "T1401D50": // SoulCalibur
            case "T8112D05": // South Park Rally
            case "T8105N": // South Park: Chef's Luv Shack
            case "51051": // Space Channel 5
            case "MK5105150": // Space Channel 5
            case "T1216N": // Spawn: In the Demon's Hand
            case "T41704N": // Spec Ops II: Omega Squad
            case "T45004D50": // Spec Ops II: Omega Squad
            case "T17702N": // Speed Devils
            case "T17702D50": // Speed Devils
            case "T17718N": // Speed Devils Online Racing
            case "T13008N": // Spider-man
            case "T13011D05": // Spider-man
            case "T8118N": // Spirit of Speed 1937
            case "T8117D59": // Spirit of Speed 1937
            case "T44304N": // Sports Jam
            case "T23003N": // Star Wars: Demolition
            case "T23002N": // Star Wars: Episode 1 Jedi Power Battles
            case "T23001N": // Star Wars: Episode 1 Racer
            case "T40209N": // StarLancer
            case "T17723D50": // StarLancer
            case "T1203N": // Street Fighter Alpha3
            case "T7005D50": // Street Fighter Alpha3
            case "T1213N": // Street Fighter III: 3rd Strike
            case "T1210N": // Street Fighter III: Double Impact
            case "T7006D50": // Street Fighter III: Double Impact
            case "T15111N": // Striker Pro 2000
            case "T15102D50": // UEFA Striker
            case "T22904D": // Stunt GP
            case "T17708N": // Stupid Invaders
            case "T17711D71": // Stupid Invaders
            case "T40206N": // Super Magnetic Neo
            case "T40206D50": // Super Magnetic Neo
            case "T12511N": // Super Runabout: San Francisco Edition
            case "T7014D50": // Super Runabout: The Golden State
            case "T40216N": // Surf Rocket Racers
            case "T17721D50": // Surf Rocket Racers
            case "T17703N": // Suzuki Alstare Extreme Racing
            case "T36805N": // Sword of the Berserk: Guts' Rage
            case "T36807D05": // Sword of the Berserk: Guts' Rage
            case "T17708D": // Taxi 2
            case "T1208N": // Tech Romancer
            case "T8108N": // Tee Off
            case "51186": // Tennis 2K2
            case "MK5118650": // Virtua Tennis 2
            case "T15102N": // Test Drive 6
            case "T15123N": // Test Drive Le Mans
            case "T15111D91": // Le Mans 24 Hours
            case "T15110N": // Test Drive V-Rally
            case "T15105D05": // V-Rally 2: Expert Edition
            case "51011": // Time Stalkers
            case "MK5101153": // Time Stalkers
            case "T13701N": // TNN Motorsports HardCore Heat
            case "T40202N": // Tokyo Extreme Racer
            case "T40201D50": // Tokyo Highway Challenge
            case "T40211N": // Tokyo Extreme Racer 2
            case "T17724D50": // Tokyo Highway Challenge 2
            case "T40402N": // Tom Clancy's Rainbow Six Rouge Spear
            case "T45002D61": // Tom Clancy's Rainbow Six Rouge Spear
            case "T36812N": // Tomb Raider: Chronicles
            case "T36815D05": // Tomb Raider: Chronicles
            case "T36806N": // Tomb Raider: The Last Revelation
            case "T36804D05": // Tomb Raider: The Last Revelation
            case "T40205N": // Tony Hawks Pro Skater
            case "T40204D50": // Tony Hawk's Skateboarding
            case "T13006N": // Tony Hawks Pro Skater 2
            case "T13008D05": // Tony Hawks Pro Skater 2
            case "MK5102050": // Toy Comander
            case "51149": // Toy Racer
            case "T13003D05": // Toy Story 2: Buzz Lightyear to the Rescue!
            case "T8102N": // TrickStyle
            case "51144": // Typing of the Dead
            case "MK5109505": // UEFA Dream Soccer
            case "T40204N": // Ultimate Fighting Championship
            case "T40203D50": // Ultimate Fighting Championship
            case "T15125N": // Unreal Tornament
            case "T36801D50": // Unreal Tornament
            case "T36810N": // Urban Chaos
            case "T8110N": // Vanishing Point
            case "T8110D05": // Vanishing Point
            case "T13002D71": // Vigilante 8: 2nd Offense
            case "T44301N": // Virtua Athlete 2000
            case "MK5109450": // Virtua Athlete 2K
            case "51001": // Virtua Fighter 3tb
            case "MK5100153": // Virtua Fighter 3tb
            case "51028": // Virtua Striker 2
            case "MK5102850": // Virtua Striker 2 Ver. 2000.1
            case "51054": // Virtua Tennis
            case "MK5105450": // Virtua Tennis
            case "T13004N": // Virtual On: Oratorio Tangram
            case "T15113N": // Wacky Races
            case "T15106D05": // Wacky Races
            case "T40504D64": // Wetrix+
            case "T36811D": // Who Wants To Be A Millianare
            case "T42101N": // Wild Metal
            case "T40501D64": // Wild Metal
            case "51055": // World Series Baseball 2K1
            case "51152": // World Series Baseball 2K2
            case "T40601N": // Worms Armageddon
            case "T40601D79": // Worms Armageddon
            case "T22904N": // Worms World Party
            case "T7016D50": // Worms World Party
            case "T10005N": // WWF Royal Rumble
            case "T10003D50": // WWF Royal Rumble
            case "MK5108150": // Sega Extreme Sports
            case "MK5103850": // Zombie Revenge
                // Unreleased Games
            case "T26702N": // PBA Tour Bowling 2001
                // Unlicensed Games
            case "43011": // Bleem!Cast - Gran Turismo 2
            case "43021": // Bleem!Cast - Metal Gear Solid
            case "43031": // Bleem!Cast - Tekken 3
            case "DUX-SE-1": // DUX Special Edition
            case "DXCE-15": // DUX Collector's Edition
            case "DXJC-1": // DUX Jewel Case
            case "RRRR-RE": // Rush Rush Rally Racing
            case "RRRR-DX": // Rush Rush Rally Racing (Deluxe Edition)
            case "YW-015DC": // Wind and Water: Puzzle Battles
                // Other Software
                /*case "T?": // Codebreaker & Loader */
            case "T0000": // DC VCD Player (Joy Pad hack)
                // Published by "The GOAT Store" (No IDs)
                vgaMode = 0;

                // VGA Patchable
            case "T40509D50": // Aqua GT
            case "T9715N": // Army Men Sarges Heroes
            case "T9708D61": // Army Men Sarges Heroes
            case "T8117N": // BusTA-Move 4
            case "T8109D05": // BusTA-Move 4
            case "T44903D50": // Coaster Works
            case "T17721N": // Conflict Zone
            case "T1217N": // Dino Crisis
            case "T7019D05": // Dino Crisis
            case "T12503D61": // Dragon's Blood
            case "T10003N": // Evil Dead Hail to the King
            case "T10005D05": // Evil Dead Hail to the King
            case "T17705SD50": // Evolution: The World of Sacred Device
            case "T15104N": // Expendable
            case "T45401D50": // Giant Killers
            case "T1214N": // Gun Bird 2
            case "T7018D50": // Gun Bird 2
            case "T40502N": // Hidden and Dangerous
            case "T40503D64": // Hidden and Dangerous
            case "T9702D61": // Hydro Thunder
            case "T1404N": // Ms Pacman Maze Madness
            case "T10001D50": //  MTV Sports: Skateboarding feat. Andy McDonald
            case "T9706N": // NBA Showdown: NBA on NBC
            case "T9705D50": // NBA Showdown: NBA on NBC
            case "T40214N": // Next Tetris, The
            case "T9703D50": // NFL Blitz 2000
            case "T40403N": // Q*bert
            case "T44303N": // Reel Fishing: Wild
            case "51010": // Rippin' Riders
            case "T9707N": // San Fransisco Rush 2049
            case "MK5103150": // Sega Worldwide Soccer 2000
            case "T8104D05": // Shadowman
            case "MK5105250": // Skies of Arcadia
            case "T17722D50": // Sno-Cross Championship Racing
            case "T1401N": // SoulCalibur
            case "T8116N": // South Park Rally
            case "T8105D50": // South Park: Chef's Luv Shack
            case "T36816D05": // Spawn: In the Demon's Hand
            case "T36808D05": // Sydney 2000
            case "T8108D05": // Tee Off
            case "MK5404050": // TNN Motorsports Buggy Heat
            case "T40401N": // Tom Clancy's Rainbow Six
            case "T45001D05": // Tom Clancy's Rainbow Six
            case "T11011N": // Who Wants To Beat Up A Millianare
                vgaMode = 1;

                // VGA Incompatible
            case "T40209D50": // Aerowings 2
            case "T9501N": // Air Force Delta
            case "T9501D76": // Air Force Delta
            case "T40217N": // Bangai-O
            case "T7011D": // Bangai-O
            case "T12504N": // Ceasars Palace 2000: Millennium Gold Edition
            case "T12502D61": // Ceasars Palace 2000: Millennium Gold Edition
            case "T7017D50": // Capcom Vs. SNK
            case "T15128N": // Coaster Works
            case "T17718D84": // Dinosaur
            case "T8114N": // ECW Anarchy Rulz
            case "T8119D59": // ECW Anarchy Rulz
            case "T8112N": // ECW Hardcore Revolution
            case "BKL8320301ENG": // ECW Hardcore Revolution
            case "T9702N": // Hydro Thunder
            case "T15129N": // Iron Aces
            case "T44904D50": // Iron Aces
            case "T1206N": // Jojo's Bizarre Adventure
            case "T7007D50": // Jojo's Bizarre Adventure
            case "T44302N": // The King of Fighters '99 Evolution
            case "T3101N": // The King of Fighters: Dream Match 1999
            case "T44305N": // Last Blade II Heart of a Samarai
            case "T10004N": // MTV Sports: Skateboarding feat. Andy McDonald
            case "T17717D50": // Next Tetris, The
            case "T15103D61": // Pen Pen
            case "T1207N": // Plasma Sword
            case "T7003D50": // Plasma Sword
            case "T31101N": // Psychic Force 2012
            case "T8106D05": // Psychic Force 2012
            case "T40505D50": // Railroad Tycoon II: Gold Edition
            case "T36806D05": // Resident Evil Code: Veronica
            case "T15122N": //  Ring, The: Terror's Realm
            case "MK5101050": // Rippin' Riders
            case "T41401N": // Soul Fighter
            case "T41401D61": // Soul Fighter
            case "T36808N": // Sydney 2000
            case "T8103N": // WWF Attitude
            case "T8103D50": // WWF Attitude
                vgaMode = 3;

                // VGA Unverified
            case "T46603D71": // Conflict Zone
            case "T17719N": // Donald Duck: Goin' Quackers
            case "T9509N": // ESPN International Track n Field
            case "T15101D05": // Millenium Soldier: Expendable
            case "T46602D50": // Heavy Metal: Geomatrix
            case "51002": // House of the Dead 2
            case "T15116N": // Loony Toons Space Race
            case "T9710D50": // Midway Greatest Arcade Hits Volume 1
            case "T9701N": // Mortal Kombat Gold
            case "T9713D61": // NBA Hoopz
            case "51025": // NHL 2K
            case "T46604D50": // Freestyle Scooter
            case "T40218N": // Record of Lodoss War
            case "T22901N": // Roadsters
            case "T9709D61": // San Fransisco Rush 2049
            case "51006": // Sega Bass Fishing
            case "51019": // Sega Rally Championship 2
            case "T9507N": // Silent Scope
            case "T17713D50": // Speed Devils Online Racing
            case "T13010D50": // Star Wars: Demolition
            case "T23002D50": // Star Wars: Episode 1 Jedi Power Battles
            case "T13006D50": // Star Wars: Episode 1 Racer
            case "T7013D50": // Street Fighter III: 3rd Strike
            case "T17703D05": // Suzuki Alstare Extreme Racing
            case "T7009D50": // Tech Romancer
            case "51020": // Toy Comander
            case "T13003N": // Toy Story 2: Buzz Lightyear to the Rescue!
            case "T8101D05": // TrickStyle
            case "T36810D50": // Urban Chaos
            case "T13002N": // Vigilante 8: 2nd Offense
            case "T8111N": // Wetrix+
            case "T15126N": //  Xtreme Sports
            case "51038": // Zombie Revenge

            default:
                vgaMode = 3; // Emulator default
        }
        return vgaMode;
    }

    public boolean useSafeMode(String gameId) {
        switch (gameId) {
            case "T40218N": // Record of Lodoss War
            case "T7012D": // Record of Lodoss War
            case "T23001D" : // Star Wars Episode I: Racer
            case "T30701D" : // Pro Pinball Trilogy
            case "T15112N" : // Demolition Racer
            case "T40216N" : // Surf Rocket Racers

            default:
                return false;
        }
    }
}
