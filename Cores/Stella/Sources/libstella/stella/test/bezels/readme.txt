The bezels test some features of Stella's bezel code:

- Combat uses a rounded bezel, this should be autodetected and the bezel rendered each frame
- River Raid uses a non-rounded bezel, this should be autodetected and the bezel rendered only when loading it
- default should be used a fallback for all games, it has wide borders and tests the correct window position and the scaling