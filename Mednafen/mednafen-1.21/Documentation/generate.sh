#!/bin/bash

../src/mednafen -dump_settings_def settings.def -dump_modules_def modules.def

# TODO: Dump to settings.def.tmp, and move to settings.def if different for more useful "last modified" time.

php cdplay.php > cdplay.html
php gba.php > gba.html
php gb.php > gb.html
php gg.php > gg.html
php lynx.php > lynx.html
php md.php > md.html
php nes.php > nes.html
php ngp.php > ngp.html
php pce.php > pce.html
php pce_fast.php > pce_fast.html
php pcfx.php > pcfx.html
php psx.php > psx.html
php sms.php > sms.html
php snes.php > snes.html
php snes_faust.php > snes_faust.html
php ss.php > ss.html
php ssfplay.php > ssfplay.html
php vb.php > vb.html
php wswan.php > wswan.html

php netplay.php > netplay.html

php mednafen.php > mednafen.html
