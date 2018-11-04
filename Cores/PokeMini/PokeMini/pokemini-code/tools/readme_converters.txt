----------------------------
PokeMini Image Converter 1.4
----------------------------

Dependencies: FreeImage

Latest version can be found in:
http://pokemini.sourceforge.net/


Changes from 1.3 to 1.4:
------------------------
Dark threhold is now lower

Changes from 1.2 to 1.3:
------------------------
Added "Dark threhold" and "Light threhold" switches
Check correct width and height with metatiles (prevents crash for sprites with invalid image)
Error messages now output to stderr

Changes from 1.1 to 1.2:
------------------------
Filename is now parsed as a valid symbol

Changes from 1.0 to 1.1:
------------------------
Added new gfx format that allow to build a map from a tileset
Better header generation
Minor fixes


----------------------------
PokeMini Music Converter 1.4
----------------------------

Dependencies: OpenAL

Latest version can be found in:
http://pokemini.sourceforge.net/


Changes from 1.3 to 1.4:
------------------------
Added new directives
Fixed crash on exit with BGM using multiple copies of the same pattern
Using 2nd loop mark on BGM list now throw error as it should

Changes from 1.2 to 1.3:
------------------------
If is saving WAV while playing, pressing Ctrl+C will no longer generate an invalid WAV file
Added new effect to play random frequencies between 2 notes
Added pulse-width by percentage
Sound now play with the correct octave
Sound stop will now works properly
Error messages now output to stderr

Changes from 1.1 to 1.2:
------------------------
Filename is now parsed as a valid symbol

Changes from 1.0 to 1.1:
------------------------
Added new directives: MBPM, OUTFILE, VARHEADER and OUTHEADER
Better header generation
Minor fixes
