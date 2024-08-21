<?php require("docgen.inc"); ?>

<?php BeginPage('nes', 'Nintendo Entertainment System/Famicom'); ?>

<?php BeginSection('Introduction', "Section_intro"); ?>
<p>
Mednafen's NES/Famicom emulation is based off of FCE Ultra.
</p>

<?php PrintCustomPalettes(); ?>

<?php BeginSection("Input", "Section_input"); ?>
 <p>
  Mednafen emulates the standard NES gamepad, the Four-Score multiplayer
  adapter, the Zapper, the Power Pad,  and the Arkanoid controller.  The 
  Famicom version of the Arkanoid controller, the "Space Shadow" gun, the 
  Famicom 4-player adapter, the Family Keyboard, the HyperShot controller, the Mahjong controller,
  the Oeka Kids tablet, the Party Tap, the Family Trainer, and the Barcode Battler II barcode
  reader are also emulated.
 </p>

<?php BeginSection("Zapper", "Section_input_zapper"); ?>
 <p>
        Most Zapper NES games expect the Zapper to be plugged into port 2.
        and most VS Unisystem games expect the Zapper to be plugged
        into port 1.
 </p><p>
        The left mouse button is the emulated trigger button for the
        Zapper.  The right mouse button is also emulated as the trigger,
        but as long as you have the right mouse button held down, no color
        detection will take place, which is effectively like pulling the
        trigger while the Zapper is pointed away from the television screen.
        Note that you must hold the right button down for a short
        time to have the desired effect.
 </p>
<?php EndSection(); ?>

<?php EndSection(); ?>

<?php BeginSection("File Formats", "Section_formats"); ?>
 <p>
 Mednafen supports the iNES, FDS(raw and with a header), UNIF, and NSF file
 formats.  FDS ROM images in the iNES format are not supported; it would
 be silly to do so and storing them in that format is nonsensical.
 </p>

<?php BeginSection('iNES Format', "Section_formats_ines"); ?>
 <p>
 The battery-backed RAM, vertical/horizontal mirroring, four-screen
 name table layout, and 8-bit mapper number capabilities of the iNES
 format are supported.  The 512-byte trainer capability is also supported,
 but it is deprecated.  Common header corruption conditions are cleaned(let's
 go on a DiskDude hunt), though not all conditions can be automatically
 detected and fixed.  In addition, a few common header inaccuracies for
 games are also corrected(detected by CRC32 value).  Note that these
 fixes are not written back to the storage medium.
 </p>
 <p>
 Support for the recent VS System bit and "number of 8kB RAM banks" 
 is not implemented.  Too many iNES headers are corrupt where this new data
 is stored, causing problems for those games.
 </p>
 <p>
 The following table lists iNES-format "mappers" supported well in Mednafen.
 </p><p>
 <table width="100%" border>
 <tr><th>Number:</th><th>Description:</th><th>Game Examples:</th></tr>
 <tr><td>0</td><td>No bankswitching</td><td>Donkey Kong, Mario Bros</td></tr>
 <tr><td>1</td><td>Nintendo MMC1</td><td>MegaMan 2, Final Fantasy</td></tr>
 <tr><td>2</td><td>UNROM</td><td>MegaMan, Archon, 1944</td></tr>
 <tr><td>3</td><td>CNROM</td><td>Spy Hunter, Gradius</td></tr>
 <tr><td>4</td><td>Nintendo MMC3</td><td>Super Mario Bros. 3, Recca, Final Fantasy 3</td></tr>
 <tr><td>5</td><td>Nintendo MMC5</td><td>Castlevania 3, Just Breed, Bandit Kings of Ancient China</td></tr>
 <tr><td>6</td><td>FFE F4 Series(hacked, bootleg)</td><td></td></tr>
 <tr><td>7</td><td>AOROM</td><td>Battle Toads, Time Lord</td></tr>
 <tr><td>8</td><td>FFE F3 Series(hacked, bootleg)</td><td></td></tr>
 <tr><td>9</td><td>Nintendo MMC2</td><td>Punchout!</td></tr>
 <tr><td>10</td><td>Nintendo MMC4</td><td>Fire Emblem, Fire Emblem Gaiden</td></tr>
 <tr><td>11</td><td>Color Dreams</td><td>Crystal Mines, Bible Adventures</td></tr>
 <tr><td>12</td><td>??</td><td>Dragon Ball Z 5 ("bootleg" original)</td></tr>
 <tr><td>13</td><td>CPROM</td><td>Videomation</td></tr>
 <tr><td>15</td><td>Multi-cart(bootleg)</td><td>100-in-1: Contra Function 16</td></tr>
 <tr><td>16</td><td>Bandai ??(X24C02P EEPROM)</td><td>Dragon Ball Z 3</td></tr>
 <tr><td>17</td><td>FFE F8 Series(hacked, bootleg)</td><td></td></tr>
 <tr><td>18</td><td>Jaleco SS806</td><td>Pizza Pop, Plasma Ball</td></tr>
 <tr><td>19</td><td>Namco 106</td><td>Splatter House, Mappy Kids</td></tr>
 <tr><td>21</td><td>Konami VRC4 2A</td><td>WaiWai World 2, Ganbare Goemon Gaiden 2</td></tr>
 <tr><td>22</td><td>Konami VRC4 1B</td><td>Twinbee 3</td></tr>
 <tr><td>23</td><td>Konami VRC2B</td><td>WaiWai World, Crisis Force</td></tr>
 <tr><td>24</td><td>Konami VRC6</td><td>Akumajou Densetsu</td></tr>
 <tr><td>25<td>Konami VRC4</td><td>Gradius 2, Bio Miracle:Boku tte Upa</td></tr>
 <tr><td>26</td><td>Konami VRC6 A0-A1 Swap</td><td>Esper Dream 2, Madara</td></tr>
 <tr><td>32</td><td>IREM G-101</td><td>Image Fight 2, Perman</td></tr>
 <tr><td>33</td><td>Taito TC0190/TC0350</td><td>Don Doko Don</td></tr>
 <tr><td>34</td><td>NINA-001 and BNROM</td><td>Impossible Mission 2, Deadly Towers, Bug Honey</td></tr>
 <tr><td>37</td><td>??</td><td>Super Mario Bros/Tetris/Nintendo World Cup</td></tr>
 <tr><td>38</td><td>??</td><td>Crime Busters</td></tr>
 <tr><td>40</td><td>??</td><td>Super Mario Bros. 2j bootleg</td></tr>
 <tr><td>41</td><td>Caltron 6-in-1</td><td>Caltron 6-in-1</td></tr>
 <tr><td>42</td><td>(bootleg)</td><td>Mario Baby</td></tr>
 <tr><td>44</td><td>Multi-cart(bootleg)</td><td>Super HiK 7 in 1</td></tr>
 <tr><td>45</td><td>Multi-cart(bootleg)</td><td>Super 1000000 in 1</td></tr>
 <tr><td>46</td><td>Game Station</td><td>Rumble Station</td></tr>
 <tr><td>47</td><td>NES-QJ</td><td>Nintendo World Cup/Super Spike V-Ball</td></tr>
 <tr><td>48</td><td>Taito TC190V</td><td>Flintstones</td></tr>
 <tr><td>49</td><td>Multi-cart(bootleg)</td><td>Super HiK 4 in 1</td></tr>
 <tr><td>51</td><td>Multi-cart(bootleg)</td><td>11 in 1 Ball Games</td></tr>
 <tr><td>52</td><td>Multi-cart(bootleg)</td><td>Mario Party 7 in 1</td></tr>
 <tr><td>64</td><td>Tengen RAMBO 1</td><td>Klax, Rolling Thunder, Skull and Crossbones</td></tr>
 <tr><td>65</td><td>IREM H-3001</td><td>Daiku no Gensan 2</td></tr>
 <tr><td>66</td><td>GNROM</td><td>SMB/Duck Hunt</td></tr>
 <tr><td>67</td><td>Sunsoft ??</td><td>Fantasy Zone 2</td></tr>
 <tr><td>68</td><td>Sunsoft ??</td><td>After Burner 2, Nantetta Baseball</td></tr>
 <tr><td>69</td><td>Sunsoft FME-7</td><td>Batman: Return of the Joker, Hebereke</td>
 <tr><td>70</td><td>??</td><td>Kamen Rider Club</td></tr>
 <tr><td>71</td><td>Camerica</td><td>Fire Hawk, Linus Spacehead</td></tr>
 <tr><td>72</td><td>Jaleco ??</td><td>Pinball Quest</td></tr>
 <tr><td>73</td><td>Konami VRC3</td><td>Salamander</td></tr>
 <tr><td>74</td><td>Taiwanese MMC3 CHR ROM w/ VRAM</td><td>Super Robot Wars 2</td></tr>
 <tr><td>75</td><td>Jaleco SS8805/Konami VRC1</td><td>Tetsuwan Atom, King Kong 2</td></tr>
 <tr><td>76</td><td>Namco 109</td><td>Megami Tensei</td></tr>
 <tr><td>77</td><td>IREM ??</td><td>Napoleon Senki</td></tr>
 <tr><td>78</td><td>Irem 74HC161/32</td><td>Holy Diver</td></tr>
 <tr><td>79</td><td>NINA-06/NINA-03</td><td>F15 City War, Krazy Kreatures, Tiles of Fate</td></tr>
 <tr><td>80</td><td>Taito X-005</td><td>Minelvation Saga</td></tr>
 <tr><td>82</td><td>Taito ??</td><td>Kyuukyoku Harikiri Stadium - Heisei Gannen Ban</td><tr/>
 <tr><td>85</td><td>Konami VRC7</td><td>Lagrange Point</td></tr>
 <tr><td>86</td><td>Jaleco JF-13</td><td>More Pro Baseball</td></tr>
 <tr><td>87</td><td>??</td><td>Argus</td></tr>
 <tr><td>88</td><td>Namco 118</td><td>Dragon Spirit</td></tr>
 <tr><td>89</td><td>Sunsoft ??</td><td>Mito Koumon</td></tr>
 <tr><td>90</td><td>??</td><td>Super Mario World, Mortal Kombat 3, Tekken 2</td></tr>
 <tr><td>92</td><td>Jaleco ??</td><td>MOERO Pro Soccer</td></tr>
 <tr><td>93</td><td>??</td><td>Fantasy Zone</td></tr>
 <tr><td>94</td><td>??</td><td>Senjou no Ookami</td></tr>
 <tr><td>95</td><td>Namco 118</td><td>Dragon Buster</td></tr>
 <tr><td>96</td><td>Bandai ??</td><td>Oeka Kids</td></tr>
 <tr><td>97</td><td>??</td><td>Kaiketsu Yanchamaru</td></tr>
 <tr><td>99</td><td>VS System 8KB VROM Switch</td><td>VS SMB, VS Excite Bike</td></tr>
 <tr><td>101</td><td>Jaleco JF-10</td><td>Urusei Yatsura</td></tr>
 <tr><td>105</td><td>NES-EVENT</td><td>Nintendo World Championships</td></tr>
 <tr><td>107</td><td>??</td><td>Magic Dragon</td></tr>
 <tr><td>112</td><td>Asder</td><td>Sango Fighter, Hwang Di</td></tr>
 <tr><td>113</td><td>MB-91</td><td>Deathbots</td></tr>
 <tr><td>114</td><td>??</td><td>The Lion King</td></tr>
 <tr><td>115</td><td>??</td><td>Yuu Yuu Hakusho Final, Thunderbolt 2, Shisen Mahjian 2</td></tr>
 <tr><td>117</td><td>??</td><td>San Guo Zhi 4</td></tr>
 <tr><td>118</td><td>MMC3-TLSROM/TKSROM Board</td><td>Ys 3, Goal! 2, NES Play Action Football</td></tr>
 <tr><td>119</td><td>MMC3-TQROM Board</td><td>High Speed, Pin*Bot</td></tr>
 <tr><td>133</td><td>Sachen SA72008</td><td>Jovial Race</td></tr>
 <tr><td>134</td><td>Sachen 74LS374N</td><td>Olympic IQ</td></tr>
 <tr><td>135</td><td>Sachen 8259A</td><td>Super Pang</td></tr>
 <tr><td>140</td><td>Jaleco ??</td><td>Bio Senshi Dan</td></tr>
 <tr><td>144</td><td>AGCI 50282</td><td>Death Race</td></tr>
 <tr><td>150</td><td>Camerica BF9097</td><td>FireHawk</td></tr>
 <tr><td>151</td><td>Konami VS System Expansion</td><td>VS The Goonies, VS Gradius</td></tr>
 <tr><td>152</td><td>??</td><td>Arkanoid 2, Saint Seiya Ougon Densetsu</td></tr>
 <tr><td>153</td><td>Bandai ??</td><td>Famicom Jump 2</td></tr>
 <tr><td>154</td><td>Namco ??</td><td>Devil Man</td></tr>
 <tr><td>155</td><td>MMC1 w/o normal WRAM disable</td><td>The Money Game, Tatakae!! Rahmen Man</td></tr>
 <tr><td>156</td><td>??</td><td>Buzz and Waldog</td></tr>
 <tr><td>157</td><td>Bandai Datach ??</td><td>Datach DBZ, Datach SD Gundam Wars, **EEPROM is not emulated</td></tr>
 <tr><td>158</td><td nowrap>RAMBO 1 Derivative</td><td>Alien Syndrome</td></tr>
 <tr><td>159</td><td>Bandai ??(X24C01P EEPROM)</td><td>Magical Taruruuto-kun</td></tr>
 <tr><td>160</td><td>(same as mapper 90)</td><td>(same as mapper 90)</td></tr>
 <tr><td>180</td><td>??</td><td>Crazy Climber</td></tr>
 <tr><td>182</td><td>??</td><td>Super Donkey Kong</td></tr>
 <tr><td>184</td><td>??</td><td>Wing of Madoola, The</td></tr>
 <tr><td>185</td><td>CNROM w/ CHR ROM unmapping</td><td>Banana, Mighty Bomb Jack, Spy vs Spy(Japanese)</td></tr>
 <tr><td>189</td><td>??</td><td>Thunder Warrior, Street Fighter 2 (Yoko)</td></tr>
 <tr><td>190</td><td>??</td><td>Magic Kid Googoo</td></tr>
 <tr><td>193</td><td>Mega Soft</td><td>Fighting Hero</td></tr>
 <tr><td>206</td><td>DEIROM</td><td>Karnov</td></tr>
 <tr><td>207</td><td>Taito ??</td><td>Fudou Myouou Den</td></tr>
 <tr><td>208</td><td>??</td><td>Street Fighter IV (by Gouder)</td></tr>
 <tr><td>209</td><td>(mapper 90 w/ name-table control mode enabled)</td><td>Shin Samurai Spirits 2, Power Rangers III</td></tr>
 <tr><td>210</td><td>Namco ??</td><td>Famista '92, Famista '93, Wagyan Land 2</td></tr>
 <tr><td>215</td><td>Bootleg multi-cart ??</td><td>Super 308 3-in-1</td></tr>
 <tr><td>217</td><td>Bootleg multi-cart ??</td><td>Golden Card 6-in-1</td></tr>
 <tr><td>222</td><td>Bootleg ??</td><td>Dragon Ninja</td></tr>
 <tr><td>228</td><td>Action 52</td><td>Action 52, Cheetahmen 2</td></tr>
 <tr><td>232</td><td>BIC-48</td><td>Quattro Arcade, Quattro Sports</td></tr>
 <tr><td>234</td><td>Multi-cart ??</td><td>Maxi-15</td></tr>
 <tr><td>240</td><td>??</td><td>Gen Ke Le Zhuan, Shen Huo Le Zhuan</td></tr>
 <tr><td>241</td><td>??</td><td>Journey to the West</td></tr>
 <tr><td>242</td><td>??</td><td>Wai Xing Zhan Shi</td></tr>
 <tr><td>244</td><td>??</td><td>Decathalon</td></tr>
 <tr><td>246</td><td>??</td><td>Fong Shen Ban</td></tr>
 <tr><td>248</td><td>??</td><td>Bao Qing Tian</td></tr>
 <tr><td>249</td><td>Waixing ??</td><td>??</td></tr>
 <tr><td>250</td><td>??</td><td>Time Diver Avenger</td></tr>
 </table>
 </p>
<?php EndSection(); ?>


<?php BeginSection('UNIF', "Section_formats_unif"); ?>
 <p>
 Mednafen supports the following UNIF boards.  The prefixes HVC-, NES-, BTL-, and BMC- are omitted, since they are currently ignored in Mednafen's UNIF loader.
 </p>
 <p>
 <table border width="100%">
 <tr><th colspan="2">Group:</th></tr>
 <tr><th>Name:</th><th>Game Examples:</th></tr>
 <tr><th colspan="2">Bootleg:</th></tr>
 <tr><td>BioMiracleA</td><td>Mario Baby</td></tr>
 <tr><td>MARIO1-MALEE2</td><td>Super Mario Bros. Malee 2</td></tr>
 <tr><td>NovelDiamond9999999in1</td><td>Novel Diamond 999999 in 1</td></tr>
 <tr><td>Super24in1SC03</td><td>Super 24 in 1</td></tr>
 <tr><td>Supervision16in1</td><td>Supervision 16-in-1</td></tr>
 <tr><th colspan="2">Unlicensed:</th></tr>
 <tr><td>UNL-603-5052</td><td>Contra Fighter</td></tr>
 <tr><td>NINA-06</td><td>F-15 City War</td></tr>
 <tr><td>Sachen-8259A</td><td>Super Cartridge Version 1</td></tr>
 <tr><td>Sachen-8259B</td><td>Silver Eagle</td></tr>
 <tr><td>Sachen-74LS374N</td><td>Auto Upturn</td></tr>
 <tr><td>SA-016-1M</td><td>Master Chu and the Drunkard Hu</td></tr>
 <tr><td>SA-72007</td><td>Sidewinder</td></tr>
 <tr><td>SA-72008</td><td>Jovial Race</td></tr>
 <tr><td>SA-0036</td><td>Mahjong 16</td></tr>
 <tr><td>SA-0037</td><td>Mahjong Trap</td></tr>
 <tr><td>TC-U01-1.5M</td><td>Challenge of the Dragon</td></tr>
 <tr><td>8237</td><td>Pocahontas Part 2</td></tr>
 <tr><th colspan="2">MMC1:</th></tr>
 <tr><td>SAROM</td><td>Dragon Warrior</td></tr>
 <tr><td>SBROM</td><td>Dance Aerobics</td></tr>
 <tr><td>SCROM</td><td>Orb 3D</td></tr>
 <tr><td>SEROM</td><td>Boulderdash</td></tr>
 <tr><td>SGROM</td><td>Defender of the Crown</td></tr>
 <tr><td>SKROM</td><td>Dungeon Magic</td></tr>
 <tr><td>SLROM</td><td>Castlevania 2</td></tr>
 <tr><td>SL1ROM</td><td>Sky Shark</td></tr>
 <tr><td>SNROM</td><td>Shingen the Ruler</td></tr>
 <tr><td>SOROM</td><td>Nobunaga's Ambition</td></tr>
 <tr><th colspan="2">MMC2:</th></tr>
 <tr><td>PEEOROM</td><td>Mike Tyson's Punch Out</td></tr>
 <tr><td>PNROM</td><td>Punch Out</td></tr>
 <tr><th colspan="2">MMC3:</th></tr>
 <tr><td>TFROM</td><td>Legacy of the Wizard</td></tr>
 <tr><td>TGROM</td><td>Megaman 4</td></tr>
 <tr><td>TKROM</td><td>Kirby's Adventure</td></tr>
 <tr><td>TKSROM</td><td>Ys 3</td></tr>
 <tr><td>TLROM</td><td>Super Spike V'Ball</td></tr>
 <tr><td>TLSROM</td><td>Goal! 2</td></tr>
 <tr><td>TR1ROM</td><td>Gauntlet</td></tr>
 <tr><td>TQROM</td><td>Pinbot</td></tr>
 <tr><td>TSROM</td><td>Super Mario Bros. 3</td></tr>
 <tr><td>TVROM</td><td>Rad Racer 2</td></tr>
 <tr><th colspan="2">MMC5:</th></tr>
 <tr><td>EKROM</td><td>Gemfire</td></tr>
 <tr><td>ELROM</td><td>Castlevania 3</td></tr>
 <tr><td>ETROM</td><td>Nobunaga's Ambition 2</td></tr>
 <tr><td>EWROM</td><td>Romance of the Three Kingdoms 2</td></tr>
 <tr><th colspan="2">MMC6:</th></tr>
 <tr><td>HKROM</td><td>Star Tropics</td></tr>
 <tr><th colspan="2">FME7:</th></tr>
 <tr><td>BTR</td><td>Batman: Return of the Joker</td></tr>
 <tr><th colspan="2">Nintendo Discrete Logic:</th></tr>
 <tr><td>CNROM</td><td>Gotcha</td></tr>
 <tr><td>CPROM</td><td>Videomation</td></tr>
 <tr><td>GNROM</td><td>Super Mario Bros./Duck Hunt</td></tr>
 <tr><td>MHROM</td><td></td></tr>
 <tr><td>NROM-128</td><td>Mario Bros.</td></tr>
 <tr><td>NROM-256</td><td>Super Mario Bros.</td></tr>
 <tr><td>RROM-128</td><td></td></tr>
 <tr><td>UNROM</td><td>Megaman</td></tr>
 </table>
 </p>
<?php EndSection(); ?>

<?php EndSection(); ?>

<?php BeginSection('Famicom Disk System', "Section_fds"); ?>
 <p>
        You will need the FDS BIOS ROM image in the base Mednafen directory.
        It must be named "disksys.rom".  Mednafen will not load FDS games
	without this file.
 </p>
        Two types of FDS disk images are supported:  disk images with the
        FWNES-style header, and disk images with no header.  The number
	of sides on headerless disk images is calculated by the total file
	size, so don't put extraneous data at the end of the file.
 <p>
	If a loaded disk image is written to during emulation, Mednafen will store the modified 
	disk image in the save games directory, which is by default "sav" under the base 
	directory.
 </p>
<?php EndSection(); ?>

<?php BeginSection('Game Genie', "Section_game_genie"); ?>

 <p>
        The Game Genie ROM image is loaded from the path specified by the setting "nes.ggrom", or, if that string is not set, the file "gg.rom" in the
        base directory when Game Genie emulation is enabled.
</p><p>
        The ROM image may either be the 24592 byte iNES-format image, or
        the 4352 byte raw ROM image.
</p>
<?php EndSection(); ?>


<?php BeginSection('VS Unisystem', "Section_vs_unisystem"); ?>
 <p>
Mednafen currently only supports VS Unisystem ROM images in the
iNES format.  DIP switches and coin insertion are both emulated.  
The following games are supported, and have palettes provided(though not 
necessarily 100% accurate or complete):
	<ul>
	 <li />Battle City
         <li />Castlevania
	 <li />Clu Clu Land
	 <li />Dr. Mario
	 <li />Duck Hunt
	 <li />Excitebike
	 <li />Excitebike (Japanese)
	 <li />Freedom Force
         <li />Goonies, The
         <li />Gradius
         <li />Gumshoe
	 <li />Hogan's Alley
	 <li />Ice Climber
	 <li />Ladies Golf
	 <li />Mach Rider
	 <li />Mach Rider (Japanese)
	 <li />Mighty Bomb Jack	(Japanese)
	 <li />Ninja Jajamaru Kun (Japanese)
	 <li />Pinball
	 <li />Pinball (Japanese)
	 <li />Platoon
	 <li />RBI Baseball
         <li />Slalom
	 <li />Soccer
	 <li />Star Luster
         <li />Stroke and Match Golf
         <li />Stroke and Match Golf - Ladies
         <li />Stroke and Match Golf (Japanese)
         <li />Super Mario Bros.
	 <li />Super Sky Kid
	 <li />Super Xevious
	 <li />Tetris
         <li />TKO Boxing
	 <li />Top Gun
	</ul>
 </p>
<?php EndSection(); ?>

<?php EndSection(); ?>


<?php BeginSection('Default Key Assignments', "Section_default_keys"); ?>

 <table border>
 <tr><th>Key(s):</th><th>Action:</th><th>Configuration String:</th></tr>
 <tr><td>ALT + SHIFT + 1</td><td>Activate in-game input configuration process for input port 1.</td><td>input_config1</td></tr>
 <tr><td>ALT + SHIFT + 2</td><td>Activate in-game input configuration process for input port 2.</td><td>input_config2</td></tr>
 <tr><td>ALT + SHIFT + 3</td><td>Activate in-game input configuration process for input port 3.</td><td>input_config3</td></tr>
 <tr><td>ALT + SHIFT + 4</td><td>Activate in-game input configuration process for input port 4.</td><td>input_config4</td></tr>
 <tr><td>ALT + SHIFT + 5</td><td>Activate in-game input configuration process for the Famicom expansion port.</td><td>input_config5</td></tr>
 </table>

<?php BeginSection('VS Unisystem', "Section_default_keys_vsuni"); ?>
 <table border>
 <tr><th>Key:</th><th>Action:</th><th>Configuration String:</th></tr>
 <tr><td>F8</td><td>Insert coin.</td><td>insert_coin</td></tr>
 <tr><td>F6</td><td>Show/Hide dip switches.</td><td>toggle_dipview</td></tr>
 <tr><td>1-8</td><td>Toggle dip switches(when dip switches are shown).</td><td>"1" through "8"</td></tr>
 </table>
<?php EndSection(); ?>


<?php BeginSection('Famicom Disk System', "Section_default_keys_fds"); ?>
 <table border>
 <tr><th>Key:</th><th>Action:</th><th>Configuration String:</th></tr>
 <tr><td>F6</td><td>Select disk and disk side.</td><td>select_disk</td></tr>
 <tr><td>F8</td><td>Eject or Insert disk.</td><td>insert_eject_disk</td></tr>
 </table>
<?php EndSection(); ?>


<?php BeginSection('Barcode Readers', "Section_default_keys_barcode"); ?>
 <table border>
 <tr><th>Key:</th><th>Action:</th><th>Configuration String:</th></tr>
 <tr><td>0-9</td><td>Barcode digits(after activating barcode input).</td><td>"0" through "9"</tr>
 <tr><td>F8</td><td>Activate barcode input/scan barcode.</td><td>activate_barcode</td></tr>
 </table>
<?php EndSection(); ?>


<?php BeginSection('Game Pad', "Section_default_keys_gamepad"); ?>
<table border>
 <tr><th>Key:</th><th nowrap>Button on Emulated Gamepad:</th></tr>
 <tr><td>Keypad 2</td><td>B</td></tr>
 <tr><td>Keypad 3</td><td>A</td></tr>
 <tr><td>Enter/Return</td><td>Start</td></tr>
 <tr><td>Tab</td><td>Select</td></tr>
 <tr><td>S</td><td>Down</td></tr>
 <tr><td>W</td><td>Up</td></tr>
 <tr><td>A</td><td>Left</td></tr>
 <tr><td>D</td><td>Right</td></tr>
 </table>
<?php EndSection(); ?>


<?php BeginSection('Power Pad', "Section_default_keys_powerpad"); ?>
 <table border>
  <tr><th colspan="4">Side B</th></tr>
  <tr><td width="25%">O</td><td width="25%">P</td>
	<td width="25%">[</td><td width="25%">]</td></tr>
  <tr><td>K</td><td>L</td><td>;</td><td>'</td></tr>
  <tr><td>M</td><td>,</td><td>.</td><td>/</td></tr>
 </table>
 <br />
 <table border>
  <tr><th colspan="4">Side A</th></tr>           
  <tr><td width="25%"></td><td width="25%">P</td>
        <td width="25%">[</td><td width="25%"></td></tr>
  <tr><td>K</td><td>L</td><td>;</td><td>'</td></tr>
  <tr><td></td><td>,</td><td>.</td><td></td></tr>
 </table>
<?php EndSection(); ?>

<?php BeginSection('Family Keyboard', "Section_default_keys_fkb"); ?>
 <p>
         All emulated keys are mapped to the closest open key on the PC
          keyboard, with a few exceptions.  The emulated "@" key is
          mapped to the "`"(grave) key, and the emulated "kana" key
          is mapped to the "Insert" key(in the 3x2 key block above the
          cursor keys).
 </p> 
 <p>
 To use the Family Keyboard emulation properly, press <b>SHIFT</b> + <b>Scroll Lock</b>, which
 will cause input to be grabbed from the window manager(if present) and disable Mednafen's other internal command processing.
 </p>
<?php EndSection(); ?>

<?php BeginSection('HyperShot Controller', "Section_default_keys_hypershot"); ?>
 <table border>
  <tr><td></td><th>Run</th><th>Jump</th></tr>
  <tr><th>Controller I</th><td>Q</td><td>W</td></tr>
  <tr><th>Controller II</th><td>E</td><td>R</td></tr>
 </table>
<?php EndSection(); ?>

<?php BeginSection('Mahjong Controller', "Section_default_keys_mahjong"); ?>
 <p>
  <table border>
   <tr><th>Emulated Mahjong Controller:</th><td>A</td><td>B</td><td>C</td><td>D</td><td>E</td><td>F</td><td>G</td><td>H</td><td>I</td><td>J</td><td>K</td><td>L</td><td>M</td><td>N</td></tr>
   <tr><th>PC Keyboard:</th><td>Q</td><td>W</td><td>E</td><td>R</td><td>T</td><td>A</td><td>S</td><td>D</td><td>F</td><td>G</td><td>H</td><td>J</td><td>K</td><td>L</td></tr>
  </table>
  <br />
  <table border>
   <tr><th>Emulated Mahjong Controller:</th><td>SEL</td><td>ST</td><td>?</td><td>?</td><td>?</td><td>?</td><td>?</td></tr>
   <tr><th>PC Keyboard:</th><td>Z</td><td>X</td><td>C</td><td>V</td><td>B</td><td>N</td><td>M</td>
  </table>
 </p>
<?php EndSection(); ?>

<?php BeginSection('Party Tap Controller', "Section_default_keys_partytap"); ?>
 <p>
  <table border>
   <tr><th>Emulated Buzzer:</th><td>1</td><td>2</td><td>3</td><td>4</td><td>5</td><td>6</td></tr>
   <tr><th>PC Keyboard:</th><td>Q</td><td>W</td><td>E</td><td>R</td><td>T</td><td>Y</td></tr>
  </table>
 </p>
<?php EndSection(); ?>

<?php EndSection(); ?>


<?php BeginSection('Game-specific Emulation Hacks', "Section_hax"); ?>
 <table border width="100%">
  <tr><th>Title:</th><th>Description:</th><th>Source code files affected:</th></tr>
  <tr><td>KickMaster</td>
  <td>KickMaster relies on the low-level behavior of the MMC3(PPU A12 low->high transition)
      to work properly in certain parts.  If an IRQ begins at the "normal" time on the
      last visible scanline(239), the game will crash after beating the second boss and retrieving
      the item.  The hack is simple, to clock the IRQ counter twice on scanline 238.
  </td>
  <td>src/nes/boards/mmc3.cpp</td></tr>
  <tr><td nowrap>Shougi Meikan '92<br>Shougin Meikan '93</td>
  <td>The hack for these games is identical to the hack for KickMaster.</td>
  <td>src/nes/boards/mmc3.cpp</td></tr>
  <tr><td>Star Wars (PAL/European Version)</td>
  <td>This game probably has the same(or similar) problem on Mednafen as KickMaster.  The
   hack is to clock the IRQ counter twice on the "dummy" scanline(scanline before the first
   visible scanline).</td><td>src/nes/boards/mmc3.c</td></tr>
  </table>
<?php EndSection(); ?>



<?php PrintSettings(); ?>

 <?php BeginSection("Credits", "Section_credits"); ?>
 <p>
  (This section is woefully outdated, being mostly copied from FCE Ultra)
 <table border width="100%">
  <tr><th>Name:</th><th>Contribution(s):</th></tr>
  <tr><td>\Firebug\</td><td>High-level mapper information.</td></tr>
  <tr><td>Bero</td><td>Original FCE source code.</td></tr>
  <tr><td>Brad Taylor</td><td>NES sound information.</td></tr>
  <tr><td>EFX</td><td>Testing.</td></tr>
  <tr><td>Fredrik Olson</td><td>NES four-player adapter information.</td></tr>
  <tr><td>goroh</td><td>Various documents.</td></tr>
  <tr><td>Jeremy Chadwick</td><td>General NES information.</td></tr>
  <tr><td>kevtris</td><td>Low-level NES information and sound information.</td></tr>
  <tr><td>Ki</td><td>Various technical information.</td></tr>
  <tr><td>Mark Knibbs</td><td>Various NES information.</td></tr>
  <tr><td>Marat Fayzullin</td><td>General NES information.</td></tr>
  <tr><td>Matthew Conte</td><td>Sound information.</td></tr>
  <tr><td>nori</td><td>FDS sound information.</td></tr>
  <tr><td>rahga</td><td>Famicom four-player adapter information.</td></tr>
  <tr><td>TheRedEye</td><td>ROM images, testing.</td></tr>
  <tr><th colspan="2" align="right">...and everyone whose name my mind has misplaced.</th></tr>
 </table>
 </p>
 <?php EndSection(); ?>

<?php EndPage(); ?>

