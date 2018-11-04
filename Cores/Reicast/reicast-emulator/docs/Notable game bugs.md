Somehwat outdated. Imported from skmp's old dead blog, https://web.archive.org/web/20110809053548/http://drk.emudev.org/blog/?page_id=4

List of bugs and fixes
====

Its been a while since i wanted to make a list of known bugs with known fixes/hacks/debug states to keep as a reference for future bug checking/help other people  ;) After many delays here it is ! Most of these bugs are nullDC/Dreamcast emulation related, but they may apply to other emulators as well.If you know a bug that is not on the list contact me to add it (sources will be credited, unless otherwise mentioned i found/debugged em :) )

Also check PsyMan’s list, i don’t have his fixes duplicated here :)

Last update : 25/03/2009

- Thps2 locks with a black screen : Pending interrupt never gets a chance to raise.Thps2 enables interrupts on the status register, and shortly after disables em.Make sure to check for interrupts on writes to the status register.Also it uses Yuv decoder on TA, make sure its emulated.
- Echelon intros
-- The logo on the DOA2LE intro rotates wrongly : fpu double opcodes(used to build the sin/cos table on the intro) are wrong (remember, they are stored on hi:low order on register pairs).Check fabs.d and fneg.d.
-- Some intros abuse Cache, and expect it to maintain the mem data when mem is updated externaly (using the non cached mirror).Emulating the cache side effects or skiping the routines that do that fixes the problem.The values to patch are 0x8c01313a:0x490b=0×0009 and 0x8c0130f8:0x490b=0×0009 (thanks CaH4e3 for the patches !).Also, invalidating the code cache only on icache sync opcodes propably will fix the problem.
-- Framebuffer emulation doesn’t detect size properly: When interlacing is disabled, the screen height varies based on the video clock divider (iirc its on FB_R_*).
- Sonic Adventure 2,
-- Characters collide ‘oddly’ with the walls : fpu code doesnt properly handle nans/infinitives on compares.Check fcmp/eq/gt.
-- Random polygons appear all around : SA2 sends polygons with x/y/z +/- infintive.Different cards handle em differently.Checking manualy for em and removing em fixes the problem :)
- Ikaruga
-- Ika and Many newer jap games wont work : Newer versions of the katana sdk use mmu to remap the SQ write-back space.Thankfully, 1mb pages are used so the implementation is quite fast (i use an 64 entry remap table).Only SQ writes are mapped, mem accesses use the non-mmu mapped mirror.
-- (Some) Bullets are invisible on level 2 : The FSCA opcode is not accurate, it is expected to return 0 (exactly) for cos(90)/sin(180).Its a good idea to dump the fsca table from a dreamcast and use that, its just 128 kb :) .
- Some games have clicking on the streaming music (SA2, Crazy Taxi, thps1/2, more …) : The sound decompression code on the sh4 uses ftrc (float -> int) to convert the samples.Make sure you saturate the value when converting (x86 defaults to using 0×8000 0000 for values that dont fit).
- Test Drive Le Mans 24h, OVERLOAD shows up and game won’t progress : The game checks the power usage of maple devices.Make sure you return valid values for the current (mA) usage on the get device info command ;)
- Linux/dc locks after doing a lot work (including user space, i cant exactly remember where atm) .Also netbsd/dc locks after initing aica : Check the gdrom code, on nullDC a bug made read aborts to raise interrupts for ever.
- Netbsd crashes as soon as it boots: Make sure you have connected a keyboard, it needs it =P.
- Soul Reaver has no 3d ingame yet you can hear the sound and menus work : Check mac.w, clrmac(also check mac.l, C has a nasty habit of doing 32 bit muls unless you cast to 64 bits before the mul).
- Backgrounds on Soul Calibur seem to use wrong size textures/textures on SC seem to get only some colors right : Soul Calibur does varius tricks to optimise vram usage.It uses textures with different data fortmats ‘overlapping’ on memory (to take advantage of unused regions on a teuxtre and store other textures there).It also uses varius sizes of the same data.The fix is to identify a texture by the tcw:tsp pair , not just tcw/start address.
- Resident Evil 3 loops after starting a new game but doesnt hang : It uses rtc to time the intro text, emulate it =P.
- Sonic Shuffle locks after stating a new game : Emulate/Check PVR-DMA transfers & interrupt.
- Crazi Taxi locks after some time (~30 secs) of gameplay, music gets corrupted right before the lockup : Its AEG emulation on aica, fix/hack it to return proper values.
- Gauntlet Legends locks while loading first level, Mat Hoffman BMX locks on logo, more locks on places that loading happens : These games use multy trasnfer pio on gdrom to trasnfer > 64kb on one PIO request.Emulate that :)
- Many games run faster than normal, including RE:CV, Time Stalkers : Make sure to emulate the field register on SPG/Interlaced mode.
- Time Stalkers music is wrong , especialy when hi-pitched : This game does synth using adpcm sound bank(s).Make sure adpcm is decoded correctly on hi sample rates (all adpcm samples must be decoded no matter the pitch).
- Some capcom games(mvsc2,more) run slow using normal TMU timings : Capcom game engine expects pvr rendering to take a while(well, some versions of it at least).Make sure you have a delay betwen the StartRender write and the pvr end of render interrupts, that wll fix it.A common way to hack this is to edit tmu timings (like capcom hack on chankast).
- Sword of the Berserk, the ingame sfx stop working after a few seconds : When looping is disabled on an aica channel the loop end flag must still be set properly.SOTB ‘free’ channel detection code requires that to work.
- Resident Evil Code Veronica, the statue wont turn; Soul Calibur , Yoshimitsu exhibition mode crashing at fade out : The speed of gdrom transfers needs to be limited to about 1MB/s for these games to work
- Prince Of Persia 3D : the textures are totaly wrong: Check the dynamic shift opcodes, the game depends on only using the lower 5 bits.
- Skies Of Arcadia crashes “randomly” after exiting the ingame menu: For some reason, everytime that you exit it writes stuff to the flash.When the flash is full, it clears a sector.Make sure the flash clear command is handled properly.


PsyMan's List

Last update 9/22/09

» Beats of Rage:

Problem: Code execution seems to loop after the Sega license screen. Game appears to be frozen.

Cause: It starts multiple maple DMA transfers before the previous ones end.

Solution: Make sure to allow that instead of ending each DMA before starting the other.

» Record of Lodoss War:

Problem: Code execution seems to loop after beating certain enemies or getting certain items, etc. Game appears to be frozen.

Cause: Division by zero.

Solution: Handle division by zero on the related Div μcode.

» D2:

Problem: Disc swapping does not work on this game.

Cause: GD-ROM error control is missing.

Solution: Implement GD-ROM error control. Another option is to hack things up to generate an error and return the appropriate sense key (6h) and sense code (28h) when error info is requested.

» Dreamcast BIOS:

Problem: Dreamcast logo appears as if the tray is open when the tray is closed while the emulators starts and there is no disc in the drive. It should appear as when there is a disc in the drive.

Cause: GD-ROM error control is missing.

Solution: Implement GD-ROM error control. Another option is to hack things up to generate an error and return the appropriate sense key (6h) and sense code (29h) when error info is requested.

» Various games, VMU/Memory card:

Problem: Various games fail to detect the connected memory card(s).

Cause: There can be various causes for that.

Some games (ie: Dynamite Cop) expect that an LCD and/or a real time clock is present on the storage device (”simple” memory cards lack those two, VMUs have them).

Some games (ie: Spawn) look for a very specific device name for the connected VMUs (”Visual Memory”, padded with spaces having a specific string length) and will fail to detect the connected memory cards if the name is different.

Some WinCE games seem to do VMU detection using a timer. More on that later.

Solution: Be sure to give correct VMU device information.  More on the timer thing some other time. :p

» Various games/Disc Swapping:

Problem: Disc swapping fails for some games, “fixing” it breaks other games (ie: Swapping on Utopia Boot Disc works but fails on Xploder DC, or works for Xploder DC and fails on Utopia Boot Disc).

Cause: The state of the drive is wrong, it seems that after the command 71h the drive state ends up being set to “pause” for GD-ROMs and to “standby” for the rest disc types.

Solution: Be sure to set the drive state accordingly. Figuring out how the responses on command 71h are generated and why the drive state ends up like that is a plus. :p

More to come…
