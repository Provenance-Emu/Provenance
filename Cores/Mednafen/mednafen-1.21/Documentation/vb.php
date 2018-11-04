<?php require("docgen.inc"); ?>

<?php BeginPage('vb', 'Virtual Boy'); ?>

<?php BeginSection('Introduction', 'Section_intro'); ?>

<p>
Virtual Boy emulation in Mednafen is original code, except for an extremely modified(optimizations, bug fixes, and better all-around emulation) V810 emulator core taken from Reality Boy years
ago for PC-FX emulation.
</p>

<p>
Virtual Boy ROM images must each have an extension of ".vb" or ".vboy" to be recognized as such.  Mednafen versions prior to 0.9.13 allowed ".bin" as well, but this conflicts with the Sega Megadrive emulation module.
</p>

<p>
Due to how the left+right views are transformed into a single image, enabling most of the image filter effects(bilinear interpolation, OpenGL pixel shaders, special scalers, etc.) is not recommended.  However, they will work properly with the "cscope" and "sidebyside" 3D modes, and may work tolerably with the "anaglyph" 3D mode.  This limitation may be corrected in the future by refactoring the 3D mode mixing out to the driver side, post individual filtering for each left/right view; however, this would significantly negatively impact performance.
</p>

<p>
To use the "hli" mode with a "Line Interlaced 3D" monitor, you'll want to set "vb.yscale(fs)" to 1, "vb.liprescale" appropriately, and "vb.xscale(fs)" to 2 multiplied by the value of "vb.liprescale".
</p>

<p>
<b>NOTE:</b> The "hli" and "vli" modes will not work properly in windowed video output mode; you may need to adjust the window's position to get the lines to line up correctly for the 3D effect to work.
</p>

<?php EndSection(); ?>

<?php PrintCustomPalettes(); ?>

<?php PrintSettings(); ?>

<?php EndPage(); ?>

