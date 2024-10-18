#ifndef __MDFN_SASPLAY_SONGS_H
#define __MDFN_SASPLAY_SONGS_H

static const SongInfo HOTDSongs[] =
{
 { 0x00, "Attract" },
 { 0x01, "Tragedy (First Chapter)" },
 { 0x02, "Revenge (Second Chapter)" },
 { 0x08, "Truth (Third Chapter)" },
 { 0x0E, "The House of the Dead (Final Chapter)" },
 { 0x04, "Boss" },
 { 0x0B, "Magician" },
 { 0x05, "Clear" },
 { 0x03, "Game Over" },
 { 0x06, "Ending" },
 { 0x0D, "Name Entry" },

 { 0x07 },	// Unused?
 { 0x09 },	// Unused?

 { 0x0A },	// Alternate Attract?
 { 0x0C },	// Alternate Magician?
};

static const SongInfo LBSongs[] =
{
 { 0x06, "Character Select" },
 { 0x04, "Cross Street (Tommy)" },
 { 0x07, "Tears Bridge (Nagi)" },
 { 0x03, "Dark Rooftop (Joe)" },
 { 0x02, "Moonlight Garden (Lisa)" },
 { 0x01, "Lust Subway (Yoko)" },
 { 0x0A, "Nightmare Island (Zaimoku)" },
 { 0x05, "Naked Airport (Yusaku)" },
 { 0x0D, "Radical Parking Lot (Kurosawa)" },
 { 0x0B, "Boss Stage (Red Eye)" },
 { 0x0C, "Brilliant Room" },
 { 0x08, "Ending" },
 { 0x09, "Name Entry" },
 { 0x00, "Challenger Comes" },
 { 0x0E, "Rank In" },
 { 0x0F, "Out of Rank" },
};

static const SongInfo DOASongs[] =
{
 { 0x0A, "DOA Overture (Opening)" },
 { 0x0C, "Chopper's Final Moment (Unused)" },
 { 0x0B, "Show Down (Character Select)" },
 { 0x02, "No Money (Zack)" },
 { 0x20, "Stage Clear" },
 { 0x05, "The Fist of Taikyoku Blows Up (Lei-Fang)" },
 { 0x04, "Blade of Ryu (Ryu Hayabusa)" },
 { 0x06, "Lone Warrior (Jann Lee)" },
 { 0x01, "Power is Beauty (Tina)" },
 { 0x08, "Codename \"Bayman\" (Bayman)" },
 { 0x03, "The Secret Fist of Legend (Gen Fu)" },
 { 0x00, "Time of Determination (Kasumi)" },
 { 0x10, "Dead or Alive (Raidou)" },
 { 0x0D, "In Between Life and Death (Continue)" },
 { 0x11, "Show Must Go On! (Credits)" },
 { 0x0E, "Your Name Is... (Name Entry)" },
 { 0x21 },
};

static const SongInfo FVSongs[] =
{
 { 0x00, "Advertise" },
 { 0x01, "Character Select" },
 { 0x02, "Continue" },
 { 0x03, "Game Over" },
 { 0x04, "Name Entry" },
 { 0x05, "Armstone Town Day (Bahn)" },
 { 0x06, "Big Factory (Grace)" },
 { 0x07, "UFO Diner (Picky)" },
 { 0x08, "Armstone Airport (Tokio)" },
 { 0x09, "Armstone Town Night (Sanman)" },
 { 0x0A, "Bay Side (Honey)" },
 { 0x0B, "City Tower (Raxel)" },
 { 0x0C, "Observation Deck (Jane)" },
 { 0x0D, "Top of the City (B.M.)" },
 { 0x0E, "Staff Roll" },
};

static const SongInfo FV2Songs[] =
{
 { 0x07, "Beginning" },		// FM
 { 0x00, "As you choose (Character Select)" },
 { 0x0E, "Under the Sun (Charlie)" },
 { 0x01, "Burning Bear (Emi)" },
 { 0x05, "Inspire (Grace)" },
 { 0x03, "Ravin' (Raxel)" },	// FM
 { 0x0B, "Deeper (Honey)" },
 { 0x10, "Good Noise (Picky)" },
 { 0x0D, "3rd Signal (Bahn)" },
 { 0x0A, "Brain Creanser (Tokio)" },
 { 0x04, "L.S.D. (Jane)" },
 { 0x02, "Night Call (Sanman)" },
 { 0x0C, "Tripback (Mahler)" },
 { 0x13, "Poker Face" },
 { 0x12, "UFO Diner (B.M.)" },
 { 0x3001, "Don't forget first resolusion" },
 { 0x0F, "Be Cool (Staff Roll)" },
 { 0x06, "Non Stop Bass (Name Entry)" },
 { 0x08, "Insert Coin" },
 { 0x09, "Game Is Over" },
 { 0x11, "Master cat in naighborhood (Advertise)" },
 { 0x3000, "Service Games" },
};

static const SongInfo VF2Songs[] =
{
 { 0x01 },
 { 0x02 },
 { 0x03 },
 { 0x04 },
 { 0x05 },
 { 0x06 },
 { 0x07 },
 { 0x08 },
 { 0x09 },
 { 0x0A },
 { 0x0B },
 { 0x0C },
 { 0x0D },
 { 0x0E },
 { 0x0F },
 { 0x10 },
 { 0x11 },
 { 0x12 },
 { 0x13 },
 { 0x14 },
 { 0x15 },
 { 0x16 },
 { 0x17 },
 { 0x18 },
};

static const SongInfo VF3Songs[] =
{
 { 0x1B, "Rowdy", 500 }, // Loud
 { 0x08, "Virtua Fighter 3 (Select)", 500 }, // Loud, FM
 { 0x1A, "Next Challenger", 500 }, // Loud

 { 0x01, "Keen Head (Jacky)" },
 { 0x18, "Tedium (Lion)" },
 { 0x04, "Dance (Aoi)" },
 { 0x06, "Coral Groove (Jeffry)" },
 { 0x03, "Underground (Sarah)" },
 { 0x19, "Gostroptosis" },
 { 0x12, "Hiding (Kage-Maru)" },	// FM
 { 0x09, "Open The Deadgate (Pai)" },	// FM
 { 0x0A, "Drunkman in Hong Kong (Shun)" },
 { 0x05, "Raging Wind (Lau)" },
 { 0x0C, "Ancient Times (Wolf)" },
 { 0x11, "On the Circle (Taka-Arashi)" }, // FM
 { 0x0D, "The Hall (Akira)" },	// FM
 { 0x20, "Tender Steel (Dural)" },
 { 0x1D, "After Image 2", 500 },  // Loud(delayed)
 { 0x1E, "Tell Me Your Memories" },
 { 0x0B, "Game Over", 500 }, // Loud
 { 0x07, "Stage Clear", 500 },			// Loud
 { 0x14, "Try To Next Level" },

 { 0x21, "Modesty" },
 { 0x15, "Impudence" },
 { 0x02, "The Killer Mantis" }, // FM
 { 0x10, "Blandish Fist" },
 { 0x1F, "Persevering" },
 { 0x0E, "Cool Bell" },
 { 0x0F, "Tears of Falling" },
 { 0x17, "For You", 500 }, // Loud

 { 0x16, nullptr, 500 }, // Loud
 { 0x13, nullptr },
 { 0x1C, nullptr, 700 }, // Loudish, unused alternate opening?
 { 0x00, "Song 0", 500 }, // Wonky
};

static const SongInfo I500Songs[] =
{
 { 0x0100 },
 { 0x0101 },
 { 0x0102 },
 { 0x0103 },
 { 0x0104 },
 { 0x0105 },
 { 0x0106 },
 { 0x0107 },
 { 0x0108 },
};

static const SongInfo VSSongs[] =
{
 { 0x0101 },
 { 0x0102 },
 { 0x0103 },
 { 0x0104 },
 { 0x0105 },
 { 0x0106 },
 { 0x0107 },
 { 0x0108 },
 { 0x0109 },
 { 0x010A },
 { 0x010B },
 { 0x010C },
 { 0x010D },
 { 0x010E },
 { 0x010F },
 { 0x0110 },
 { 0x0111 },
};

static const SongInfo SRCSongs[] =
{
 { 0x01 },
 { 0x02 },
 { 0x03 },
 { 0x04 },
 { 0x05 },
 { 0x06 },
 { 0x07 },
 { 0x08 },
 { 0x09 },
 { 0x0A },
 { 0x0B },
 { 0x0C },
 { 0x0D },
 { 0x0E },
 { 0x0F },
 { 0x10 },
 { 0x11 },
};

static const SongInfo SOSongs[] =
{
 { 0x1900 },
 { 0x2800 },
 { 0x2801 },
 { 0x2803 },
};

static const SongInfo DU2Songs[] =
{
 { 0x143E, "Whoops" },
 { 0x161E, nullptr, 2000 },
 { 0x1616, nullptr, 1500 },
 { 0x1617, nullptr, 1500 },

 { 0x1615, nullptr, 1500 },
 { 0x1618, nullptr, 1500 },
 { 0x161A, nullptr, 1500 },
 { 0x161B, nullptr, 1500 },
 { 0x161D, nullptr, 1500 }
};

static const SongInfo SWTSongs[] =
{
 { 0x2E00 },
};

static const SongInfo VOn2Songs[] =
{
 { 0x00 },
 { 0x01 },
 { 0x02 },
 { 0x03, nullptr, 750 },
 { 0x04 },
 { 0x05, nullptr, 750 },
 { 0x06 },
 { 0x07 },
 { 0x08 },
 { 0x09 },
 { 0x0A },
 { 0x0B },
 { 0x0C },
 { 0x0D },
 { 0x0E },
 { 0x0F },
 { 0x10 },
 { 0x11 },
 { 0x12 },
 { 0x13 },
 { 0x14 },
 { 0x15 },
 { 0x16 },
 { 0x17 },
 { 0x18 },
 { 0x19 },
 { 0x1A },
 { 0x1B },
 { 0x1C },
 { 0x1D },
 { 0x1E },
 { 0x1F },
 { 0x20 },
 { 0x21 },
 { 0x22 },
 { 0x23 },
 { 0x24 },
 { 0x25 },
 { 0x26 },
 { 0x27 },
 { 0x28 },
 { 0x29 },
 { 0x2A, nullptr, 600 },
 { 0x2B },
 { 0x2C },
 { 0x2D },
 { 0x2E },
 { 0x2F },
 { 0x30 },
 { 0x31 },
};

#endif
