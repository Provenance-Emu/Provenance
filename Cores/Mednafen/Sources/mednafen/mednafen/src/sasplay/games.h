#ifndef __MDFN_SASPLAY_GAMES_H
#define __MDFN_SASPLAY_GAMES_H

static SMXGameInfo SMXGI[] =
{
 {
  "Air Walkers",
  "",
  "",
  nullptr, 40,
  1000,
  SYSTEM_MODEL2,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "10-18_ic30_30f2.30" },

   { SPACE_SAMPLES, 0x800000, 0x200000, "mpr-19243.31" },
   { SPACE_SAMPLES, 0xA00000, 0x200000, "mpr-19242.32" },
   { SPACE_SAMPLES, 0xC00000, 0x200000, "mpr-19241.36" },
   { SPACE_SAMPLES, 0xE00000, 0x200000, "mpr-19240.37" },
  }
 },

 {
  "Behind Enemy Lines",
  "",
  "",
  nullptr, 24,
  1000,
  SYSTEM_MODEL2,
  {
   { SPACE_PROGRAM, 0x000000, 0x020000, "mpr-20249.31" },

   { SPACE_SAMPLES, 0x800000, 0x200000, "mpr-20250.32" },
   { SPACE_SAMPLES, 0xA00000, 0x200000, "mpr-20251.33" },
   { SPACE_SAMPLES, 0xC00000, 0x200000, "mpr-20252.34" },
   { SPACE_SAMPLES, 0xE00000, 0x200000, "mpr-20253.35" },

   { SPACE_ALIEN, 0, 0, "mpr-20240.21" },
  }
 },

 {
  "Dead or Alive",
  "Hideyuki Suzuki, Hiroaki Takahashi, Yutaka Fujishima",
  "",
  DOASongs, sizeof(DOASongs) / sizeof(DOASongs[0]),
  1000,
  SYSTEM_MODEL2,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "epr-19328.30" },

   { SPACE_SAMPLES, 0x800000, 0x200000, "mpr-19329.31" },
   { SPACE_SAMPLES, 0xA00000, 0x200000, "mpr-19330.32" },
   { SPACE_SAMPLES, 0xC00000, 0x200000, "mpr-19331.33" },
   { SPACE_SAMPLES, 0xE00000, 0x200000, "mpr-19332.34" },

   { SPACE_ALIEN, 0, 0, "mpr-19325.21" },
  }
 },

 {
  "Dynamite Baseball '97",
  "",
  "",
  nullptr, 31,
  1000,
  SYSTEM_MODEL2,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "epr-19849.31" },

   { SPACE_SAMPLES, 0x800000, 0x200000, "mpr-19850.32" },
   { SPACE_SAMPLES, 0xA00000, 0x200000, "mpr-19851.33" },
   { SPACE_SAMPLES, 0xC00000, 0x200000, "mpr-19852.34" },
   { SPACE_SAMPLES, 0xE00000, 0x200000, "mpr-19853.35" },

   { SPACE_ALIEN, 0, 0, "mpr-19845.21" },
  }
 },

 {
  "Dynamite Dekka 2",
  "",
  "",
  nullptr, 30,
  1000,
  SYSTEM_MODEL2,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "epr-20811.30" },

   { SPACE_SAMPLES, 0x000000, 0x200000, "mpr-20812.31" },
   { SPACE_SAMPLES, 0x200000, 0x200000, "mpr-20813.32" },
   { SPACE_SAMPLES, 0x400000, 0x200000, "mpr-20814.36" },
   { SPACE_SAMPLES, 0x600000, 0x200000, "mpr-20815.37" },

   { SPACE_ALIEN, 0, 0, "mpr-20804.21" },
  }
 },

 {
  "Fighting Vipers",
  "David Leytze",
  "",
  FVSongs, sizeof(FVSongs) / sizeof(FVSongs[0]),
  1000,
  SYSTEM_MODEL2,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "epr-18628.31" },

   { SPACE_SAMPLES, 0x800000, 0x200000, "mpr-18629.32" },
   { SPACE_SAMPLES, 0xA00000, 0x200000, "mpr-18630.33" },
   { SPACE_SAMPLES, 0xC00000, 0x200000, "mpr-18631.34" },
   { SPACE_SAMPLES, 0xE00000, 0x200000, "mpr-18632.35" },

   { SPACE_ALIEN, 0, 0, "mpr-18619.21" },
  }
 },

 {
  "Gunblade NY",
  "",
  "",
  nullptr, 23,
  1000,
  SYSTEM_MODEL2,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "epr-18990.31" },
   { SPACE_SAMPLES, 0x000000, 0x400000, "mpr-18978.32" },
   { SPACE_SAMPLES, 0x400000, 0x400000, "mpr-18979.34" },

   { SPACE_ALIEN, 0, 0, "mpr-18981.21" },
  }
 },

 {
  "The House of the Dead",
  "Tetsuya Kawauchi",
  "",
  HOTDSongs, sizeof(HOTDSongs) / sizeof(HOTDSongs[0]),
  1500,
  SYSTEM_MODEL2,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "epr-19720.31" },
   { SPACE_SAMPLES, 0x000000, 0x400000, "mpr-19721.32" },
   { SPACE_SAMPLES, 0x400000, 0x400000, "mpr-19722.34" },

   { SPACE_ALIEN, 0, 0, "mpr-19711.21" },
  }
 },

 {
  "Indy 500",
  "",
  "",
  I500Songs, sizeof(I500Songs) / sizeof(I500Songs[0]),
  1700,
  SYSTEM_MODEL2,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000 / 2, "epr-18391.31" },

   { SPACE_SAMPLES, 0x000000, 0x200000, "mpr-18241.32" },
   { SPACE_SAMPLES, 0x200000, 0x200000, "mpr-18242.33" },
   { SPACE_SAMPLES, 0x400000, 0x200000, "mpr-18243.34" },
   { SPACE_SAMPLES, 0x600000, 0x200000, "mpr-18244.35" },

   { SPACE_ALIEN, 0, 0, "mpr-18234.21" },
  }
 },

 {
  "Last Bronx",
  "",
  "",
  LBSongs, sizeof(LBSongs) / sizeof(LBSongs[0]),
  1000,
  SYSTEM_MODEL2,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "mpr-19056.31" },

   { SPACE_SAMPLES, 0x000000, 0x400000, "mpr-19057.32" },
   { SPACE_SAMPLES, 0x400000, 0x400000, "mpr-19058.34" },

   { SPACE_ALIEN, 0, 0, "mpr-19053.21" },
  }
 },

 {
  "Manx TT Superbike",
  "",
  "",
  nullptr, 26,
  1000,
  SYSTEM_MODEL2,
  {
   { SPACE_PROGRAM, 0x000000, 0x040000, "epr-18824a.30" },

   { SPACE_SAMPLES, 0x200000, 0x200000, "mpr-18764.32" },
   { SPACE_SAMPLES, 0x400000, 0x200000, "mpr-18765.36" },
   { SPACE_SAMPLES, 0x600000, 0x200000, "mpr-18766.37" },

   { SPACE_ALIEN, 0, 0, "mpr-18757.21" },
  }
 },

 {
  "Manx TT Superbike ()",
  "",
  "",
  nullptr, 26,
  1000,
  SYSTEM_MODEL2,
  {
   { SPACE_PROGRAM, 0x000000, 0x040000, "epr-18826.30" },

   { SPACE_SAMPLES, 0x200000, 0x200000, "mpr-18764.32" },
   { SPACE_SAMPLES, 0x400000, 0x200000, "mpr-18765.36" },
   { SPACE_SAMPLES, 0x600000, 0x200000, "mpr-18766.37" },

   { SPACE_ALIEN, 0, 0, "mpr-18757.21" },
  }
 },

 {
  "Motor Raid",
  "",
  "",
  nullptr, 18,
  1300,
  SYSTEM_MODEL2,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "epr-20029.30" },

   { SPACE_SAMPLES, 0x000000, 0x200000, "mpr-20030.31" },
   { SPACE_SAMPLES, 0x200000, 0x200000, "mpr-20031.32" },
   { SPACE_SAMPLES, 0x400000, 0x200000, "mpr-20032.36" },
   { SPACE_SAMPLES, 0x600000, 0x200000, "mpr-20033.37" },

   { SPACE_ALIEN, 0, 0, "mpr-20027.21" },
  }
 },

 {
  "Over Rev",
  "",
  "",
  nullptr, 7,
  3000,
  SYSTEM_MODEL2,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "epr-20002.31" },

   { SPACE_SAMPLES, 0x000000, 0x400000, "mpr-20003.32" },
   { SPACE_SAMPLES, 0x400000, 0x400000, "mpr-20004.34" },

   { SPACE_ALIEN, 0, 0, "mpr-19999.21" },
  }
 },

 {
  "Pilot Kids",
  "",
  "",
  nullptr, 15,
  2000,
  SYSTEM_MODEL2,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "epr-21276.sd0" },

   { SPACE_SAMPLES, 0x800000, 0x200000, "mpr-21277.sd1" },
   { SPACE_SAMPLES, 0xA00000, 0x200000, "mpr-21278.sd2" },
   { SPACE_SAMPLES, 0xC00000, 0x200000, "mpr-21279.sd3" },
   { SPACE_SAMPLES, 0xE00000, 0x200000, "mpr-21280.sd4" },
  }
 },

 {
  "Rail Chase 2",
  "",
  "",
  nullptr, 23,
  1000,
  SYSTEM_MODEL2,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "epr-18047.31" },

   { SPACE_SAMPLES, 0x000000, 0x200000, "mpr-18029.32" },
   { SPACE_SAMPLES, 0x200000, 0x200000, "mpr-18030.34" },

   { SPACE_ALIEN, 0, 0, "mpr-18032.21" },
  }
 },

 {
  "Sega Ski Super G",
  "",
  "",
  nullptr, 18,
  1000,
  SYSTEM_MODEL2,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "epr-19491.31" },
   { SPACE_SAMPLES, 0x000000, 0x400000, "mpr-19504.32" },
   { SPACE_SAMPLES, 0x400000, 0x400000, "mpr-19505.34" },

   { SPACE_ALIEN, 0, 0, "mpr-19497.21" },
  }
 },

 {
  "Sega Water Ski",
  "",
  "",
  nullptr, 18,
  1600,
  SYSTEM_MODEL2,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "epr-19967.31" },
   { SPACE_SAMPLES, 0x000000, 0x400000, "mpr-19988.32" },
   { SPACE_SAMPLES, 0x400000, 0x400000, "mpr-19989.34" },

   { SPACE_ALIEN, 0, 0, "mpr-19973.21" },
  }
 },

 {
  "Sega Rally Championship",
  "",
  "",
  SRCSongs, sizeof(SRCSongs) / sizeof(SRCSongs[0]),
  3000,
  SYSTEM_MODEL2,
  {
   { SPACE_PROGRAM, 0x000000, 0x040000, "epr-17890.30" },

   { SPACE_SAMPLES, 0x800000, 0x200000, "mpr-17756.31" },
   { SPACE_SAMPLES, 0xA00000, 0x200000, "mpr-17757.32" },
   { SPACE_SAMPLES, 0xC00000, 0x200000, "mpr-17886.36" },
   { SPACE_SAMPLES, 0xE00000, 0x200000, "mpr-17887.37" },

   { SPACE_ALIEN, 0, 0, "mpr-17751.21" },
  }
 },

 {
  "Sega Touring Car Championship",
  "",
  "",
  nullptr, 256,
  1000,
  SYSTEM_MODEL2,
  {
   { SPACE_PROGRAM, 0x000000, 0x020000, "epr-19274.31" },

   { SPACE_SAMPLES, 0x000000, 0x400000, "mpr-19259.32" },
   { SPACE_SAMPLES, 0x400000, 0x400000, "mpr-19261.34" },

   { SPACE_ALIEN, 0, 0, "mpr-19252.21" },
  }
 },

 {
  "Sky Target",
  "",
  "",
  nullptr, 39,
  1000,
  SYSTEM_MODEL2,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "epr-18408.30" },

   { SPACE_SAMPLES, 0x000000, 0x200000, "mpr-18424.31" },
   { SPACE_SAMPLES, 0x200000, 0x200000, "mpr-18423.32" },
   { SPACE_SAMPLES, 0x400000, 0x200000, "mpr-18422.36" },
   { SPACE_SAMPLES, 0x600000, 0x200000, "mpr-18421.37" },

   { SPACE_ALIEN, 0, 0, "mpr-18410.21" },
  }
 },

 {
  "Sonic the Fighters",
  "",
  "",
  nullptr, 25,
  1000,
  SYSTEM_MODEL2,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "epr-19021.31" },

   { SPACE_SAMPLES, 0x800000, 0x200000, "mpr-19022.32" },
   { SPACE_SAMPLES, 0xA00000, 0x200000, "mpr-19023.33" },
   { SPACE_SAMPLES, 0xC00000, 0x200000, "mpr-19024.34" },
   { SPACE_SAMPLES, 0xE00000, 0x200000, "mpr-19025.35" },

   { SPACE_ALIEN, 0, 0, "mpr-19012.21" },
  }
 },

 {
  "Super GT 24h",
  "",
  "",
  nullptr, 7,
  2000,
  SYSTEM_MODEL2,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "epr-19157.31" },
   { SPACE_SAMPLES, 0x000000, 0x400000, "mpr-19154.32" },

   { SPACE_ALIEN, 0, 0, "mpr-19151.21" },
  }
 },

 {
  "Top Skater",
  "",
  "",
  nullptr, 256,
  1000,
  SYSTEM_MODEL2,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "mpr-19759.31" },

   { SPACE_SAMPLES, 0x000000, 0x400000, "mpr-19745.32" },
   { SPACE_SAMPLES, 0x400000, 0x400000, "mpr-19746.34" },

   { SPACE_ALIEN, 0, 0, "mpr-19742.21" },
  }
 },

 {
  "Virtua Cop 2",
  "",
  "",
  nullptr, 24,
  1300,
  SYSTEM_MODEL2,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "epr-18530.30" },

   { SPACE_SAMPLES, 0x800000, 0x200000, "mpr-18529.31" },
   { SPACE_SAMPLES, 0xA00000, 0x200000, "mpr-18528.32" },
   { SPACE_SAMPLES, 0xC00000, 0x200000, "mpr-18527.36" },
   { SPACE_SAMPLES, 0xE00000, 0x200000, "mpr-18526.37" },
  }
 },

 {
  "Virtua Fighter 2",
  "",
  "",
  VF2Songs, sizeof(VF2Songs) / sizeof(VF2Songs[0]),
  1000,
  SYSTEM_MODEL2,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "epr-17574.30" },

   { SPACE_SAMPLES, 0x800000, 0x200000, "mpr-17573.31" },
   { SPACE_SAMPLES, 0xA00000, 0x200000, "mpr-17572.32" },
   { SPACE_SAMPLES, 0xC00000, 0x200000, "mpr-17571.36" },
   { SPACE_SAMPLES, 0xE00000, 0x200000, "mpr-17570.37" },

   { SPACE_ALIEN, 0, 0, "mpr-17549.21" },
  }
 },

 {
  "Virtua Striker",
  "",
  "",
  VSSongs, sizeof(VSSongs) / sizeof(VSSongs[0]),
  1000,
  SYSTEM_MODEL2,
  {
   { SPACE_PROGRAM, 0x000000, 0x020000, "ep18072.31" },

   { SPACE_SAMPLES, 0x000000, 0x200000, "mp18063.32" },
   { SPACE_SAMPLES, 0x200000, 0x200000, "mp18064.33" },
   { SPACE_SAMPLES, 0x400000, 0x200000, "mp18065.34" },

   { SPACE_ALIEN, 0, 0, "mp18059.21" },
  }
 },

 {
  "Virtual On: Cyber Troopers",
  "",
  "",
  nullptr, 35,
  1000,
  SYSTEM_MODEL2,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "epr-18670.31" },

   { SPACE_SAMPLES, 0x000000, 0x400000, "mpr-18652.32" },
   { SPACE_SAMPLES, 0x400000, 0x400000, "mpr-18653.34" },

   { SPACE_ALIEN, 0, 0, "mpr-18655.21" },
  }
 },

 {
  "Wave Runner",
  "",
  "",
  nullptr, 14,
  1000,
  SYSTEM_MODEL2,
  {
   { SPACE_PROGRAM, 0x000000, 0x040000, "epr-19284.31" },

   { SPACE_SAMPLES, 0x000000, 0x400000, "mpr-19295.32" },
   { SPACE_SAMPLES, 0x400000, 0x400000, "mpr-19296.34" },

   { SPACE_ALIEN, 0, 0, "mpr-19288.21" },
  }
 },

 {
  "Zero Gunner",
  "",
  "",
  nullptr, 16,
  1300,
  SYSTEM_MODEL2,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "epr-20302.31" },

   { SPACE_SAMPLES, 0x000000, 0x200000, "mpr-20303.32" },
   { SPACE_SAMPLES, 0x200000, 0x200000, "mpr-20304.33" },

   { SPACE_ALIEN, 0, 0, "mpr-20299.21" },
  }
 },
 //
 //
 //
 //
 //
 //
 {
  "Daytona USA 2",
  "",
  "",
  DU2Songs, sizeof(DU2Songs) / sizeof(DU2Songs[0]),
  1000,
  SYSTEM_MODEL3,
  {
   { SPACE_PROGRAM, 0x000000, 0x020000, "epr-20865.21" },

   { SPACE_SAMPLES, 0x000000, 0x400000, "mpr-20866.22" },
   { SPACE_SAMPLES, 0x400000, 0x400000, "mpr-20868.24" },
   { SPACE_SAMPLES, 0x800000, 0x400000, "mpr-20867.23" },
   { SPACE_SAMPLES, 0xC00000, 0x400000, "mpr-20869.25" },
  }
 },

 {
  "Dirt Devils",
  "",
  "",
  nullptr, 17,
  1000,
  SYSTEM_MODEL3,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "epr-21066.21" },

   { SPACE_SAMPLES, 0x000000, 0x400000, "mpr-21031.22" },
   { SPACE_SAMPLES, 0x400000, 0x400000, "mpr-21033.24" },
   { SPACE_SAMPLES, 0x800000, 0x400000, "mpr-21032.23" },
   //{ SPACE_SAMPLES, 0xC00000, 0x400000, "mpr-21034.25" },
  }
 },

 {
  "Emergency Call Ambulance",
  "",
  "",
  nullptr, 23,
  1000,
  SYSTEM_MODEL3,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "epr-22886.21" },

   { SPACE_SAMPLES, 0x000000, 0x400000, "mpr-22887.22" },
   { SPACE_SAMPLES, 0x400000, 0x400000, "mpr-22889.24" },
   { SPACE_SAMPLES, 0x800000, 0x400000, "mpr-22888.23" },
   { SPACE_SAMPLES, 0xC00000, 0x400000, "mpr-22890.25" },
  }
 },

 {
  "Fighting Vipers 2",
  "Hidenori Shoji",
  "",
  FV2Songs, sizeof(FV2Songs) / sizeof(FV2Songs[0]),
  1000,
  SYSTEM_MODEL3,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "epr-20600a.21" },

   { SPACE_SAMPLES, 0x000000, 0x400000, "mpr-20576" },
   { SPACE_SAMPLES, 0x400000, 0x400000, "mpr-20578" },
   { SPACE_SAMPLES, 0x800000, 0x400000, "mpr-20577" },
   { SPACE_SAMPLES, 0xC00000, 0x400000, "mpr-20579" },
  }
 },

 {
  "Get Bass",
  "",
  "",
  nullptr, 256,
  1000,
  SYSTEM_MODEL3,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "epr-20313.21" },

   { SPACE_SAMPLES, 0x000000, 0x400000, "mpr-20268.22" },
   { SPACE_SAMPLES, 0x400000, 0x400000, "mpr-20269.24" },
  }
 },

 {
  "Harley-Davidson & L.A. Riders",
  "",
  "",
  nullptr, 17,
  1000,
  SYSTEM_MODEL3,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "epr-20397.21" },

   { SPACE_SAMPLES, 0x000000, 0x400000, "mpr-20373.22" },
   { SPACE_SAMPLES, 0x400000, 0x400000, "mpr-20375.24" },
   { SPACE_SAMPLES, 0x800000, 0x400000, "mpr-20374.23" },
   { SPACE_SAMPLES, 0xC00000, 0x400000, "mpr-20376.25" },
  }
 },

 {
  "L.A. Machineguns",
  "",
  "",
  nullptr, 17,
  1000,
  SYSTEM_MODEL3,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "epr-21487.21" },

   { SPACE_SAMPLES, 0x000000, 0x400000, "mpr-21463.22" },
   { SPACE_SAMPLES, 0x400000, 0x400000, "mpr-21465.24" },
   { SPACE_SAMPLES, 0x800000, 0x400000, "mpr-21464.23" },
   { SPACE_SAMPLES, 0xC00000, 0x400000, "mpr-21466.25" },
  }
 },

 {
  "Le Mans 24",
  "",
  "",
  nullptr, 256,
  1000,
  SYSTEM_MODEL3,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "epr-19891.21" },

   { SPACE_SAMPLES, 0x000000, 0x400000, "mpr-19869.22" },
   { SPACE_SAMPLES, 0x400000, 0x400000, "mpr-19870.24" },
  }
 },

 {
  "The Lost World: Jurassic Park",
  "",
  "",
  nullptr, 256,
  1000,
  SYSTEM_MODEL3,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "epr-19940.21" },

   { SPACE_SAMPLES, 0x000000, 0x400000, "mpr-19934.22" },
   { SPACE_SAMPLES, 0x400000, 0x400000, "mpr-19935.24" },
  }
 },

 {
  "Magic Truck",
  "",
  "",
  nullptr, 256,
  1000,
  SYSTEM_MODEL3,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "epr-21438.21" },

   { SPACE_SAMPLES, 0x000000, 0x400000, "mpr-21427.22" },
   { SPACE_SAMPLES, 0x400000, 0x400000, "mpr-21428.24" },
   { SPACE_SAMPLES, 0x800000, 0x400000, "mpr-21431.23" },
   { SPACE_SAMPLES, 0xC00000, 0x400000, "mpr-21432.25" },
  }
 },

 {
  "Scud Race",
  "",
  "",
  nullptr, 3,
  1000,
  SYSTEM_MODEL3,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "epr-19692.21" },

   { SPACE_SAMPLES, 0x000000, 0x400000, "mpr-19670.22" },
   { SPACE_SAMPLES, 0x400000, 0x400000, "mpr-19671.24" },
  }
 },

 {
  "Sega Rally 2",
  "",
  "",
  nullptr, 256,
  1000,
  SYSTEM_MODEL3,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "epr-20636.21" },

   { SPACE_SAMPLES, 0x000000, 0x400000, "mpr-20614.22" },
   { SPACE_SAMPLES, 0x400000, 0x400000, "mpr-20615.24" },
  }
 },

 {
  "Ski Champ",
  "",
  "",
  nullptr, 20,
  2000,
  SYSTEM_MODEL3,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "epr-20356.21" },

   { SPACE_SAMPLES, 0x000000, 0x400000, "mpr-20334.22" },
   { SPACE_SAMPLES, 0x400000, 0x400000, "mpr-20335.24" },
  }
 },

 {
  "Spikeout",
  "",
  "",
  SOSongs, sizeof(SOSongs) / sizeof(SOSongs[0]),
  1000,
  SYSTEM_MODEL3,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "epr-21218.21" },

   { SPACE_SAMPLES, 0x000000, 0x400000, "mpr-21150.22" },
   { SPACE_SAMPLES, 0x400000, 0x400000, "mpr-21152.24" },
   { SPACE_SAMPLES, 0x800000, 0x400000, "mpr-21151.23" },
   { SPACE_SAMPLES, 0xC00000, 0x400000, "mpr-21153.25" },
  }
 },

 {
  "The Ocean Hunter",
  "",
  "",
  nullptr, 23,
  6000,
  SYSTEM_MODEL3,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "epr-21118.21" },

   { SPACE_SAMPLES, 0x000000, 0x400000, "mpr-21094.22" },
   { SPACE_SAMPLES, 0x400000, 0x400000, "mpr-21096.24" },
   { SPACE_SAMPLES, 0x800000, 0x400000, "mpr-21095.23" },
   { SPACE_SAMPLES, 0xC00000, 0x400000, "mpr-21097.25" },
  }
 },

 {
  "Star Wars Trilogy",
  "",
  "",
  SWTSongs, sizeof(SWTSongs) / sizeof(SWTSongs[0]),
  1000,
  SYSTEM_MODEL3,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "epr-21383.21" },

   { SPACE_SAMPLES, 0x000000, 0x400000, "mpr-21355.22" },
   { SPACE_SAMPLES, 0x400000, 0x400000, "mpr-21357.24" },
  }
 },

 {
  "Virtua Fighter 3",
  "Takenobu Mitsuyoshi, Fumio Ito, Takayuki Nakamura",
  "",
  VF3Songs, sizeof(VF3Songs) / sizeof(VF3Songs[0]),
  1000,
  SYSTEM_MODEL3,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "epr19231.21" },

   { SPACE_SAMPLES, 0x000000, 0x400000, "mpr-19209.22" },
   { SPACE_SAMPLES, 0x400000, 0x400000, "mpr-19210.24" },
  }
 },

 {
  "Virtua Striker 2",
  "",
  "",
  nullptr, 30,
  1000,
  SYSTEM_MODEL3,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "epr-19807.21" },

   { SPACE_SAMPLES, 0x000000, 0x400000, "mpr-19785.22" },
   { SPACE_SAMPLES, 0x400000, 0x400000, "mpr-19786.24" },
  }
 },

 {
  "Virtua Striker 2 Version '98",
  "",
  "",
  nullptr, 40,
  1000,
  SYSTEM_MODEL3,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "epr-20921.21" },

   { SPACE_SAMPLES, 0x000000, 0x400000, "mpr-20903.22" },
   { SPACE_SAMPLES, 0x400000, 0x400000, "mpr-20904.24" },
  }
 },

 {
  "Virtua Striker 2 Version '99",
  "",
  "",
  nullptr, 45,
  1000,
  SYSTEM_MODEL3,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "epr-21539.21" },

   { SPACE_SAMPLES, 0x000000, 0x400000, "mpr-21513.22" },
   { SPACE_SAMPLES, 0x400000, 0x400000, "mpr-21514.24" },
  }
 },

 {
  "Virtual On: Cyber Troopers Oratorio Tangram",
  "",
  "",
  VOn2Songs, sizeof(VOn2Songs) / sizeof(VOn2Songs[0]),
  1000,
  SYSTEM_MODEL3,
  {
   { SPACE_PROGRAM, 0x000000, 0x080000, "epr-20687.21" },

   { SPACE_SAMPLES, 0x000000, 0x400000, "mpr-20663.22" },
   { SPACE_SAMPLES, 0x400000, 0x400000, "mpr-20665.24" },
   { SPACE_SAMPLES, 0x800000, 0x400000, "mpr-20664.23" },
   { SPACE_SAMPLES, 0xC00000, 0x400000, "mpr-20666.25" },
  }
 },
};


#endif
