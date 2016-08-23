
bin_to_cso_mp3
Originally written by Exophase as "bin_to_iso_ogg"
updated for cso/mp3 by notaz


About
-----

This is a tool to convert cue/bin CD image to cue/cso/mp3 form, useful to use
with emulators. It can also create ISO instead of CSO and WAV instead of MP3.
Note that input must be .cue file, along with single .bin file.


Easy/Windows usage
------------------

1. Download LAME from http://lame.sourceforge.net/links.php#Binaries
   You need an archive or "LAME Bundle" with lame.exe inside. Extract lame.exe
   to the same directory as bin_to_cso_mp3.exe
2. Find ciso.exe . It usually comes with ISO->CSO converters, for example yacc
   (http://yacc.pspgen.com/). Extract ciso.exe to the directory from previous
   step.
3. Drag the .cue file you want to convert onto bin_to_cso_mp3.exe . It should
   pop up console window with some scrolling text, which should close by itself
   when done. After that you should see new directory with converted files.

In case it complains about missing lame.exe even after you copied it, try
copying lame.exe and ciso.exe somewhere in your PATH, i.e. Windows directory.

If it crashes ("this program needs to close blabla"), you probably have bad
.cue or missing .bin file.


Advanced usage
--------------

Just run bin_to_cso_mp3.exe from console terminal (or "command prompt") without
any parameters to see usage.


Linux
-----

You will need to compile bin_to_cso_mp3.c yourself using gcc:
$ gcc bin_to_cso_mp3.c -o bin_to_cso_mp3

You will also need to have lame and ciso binaries in PATH. Those can sometimes
be installed using packet manager from the distribution, or you can compile
them from sources:
lame: http://lame.sourceforge.net/
ciso: http://ciso.tenshu.fr/

