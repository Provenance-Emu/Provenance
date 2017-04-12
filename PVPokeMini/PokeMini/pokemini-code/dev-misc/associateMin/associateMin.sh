#!/bin/bash
if [ -z "$1" ] || [ "$1" == "-?" ] || [ "$1" == "--help" ]; then
	echo "Linux file association script for PokeMini by Wa (logicplace.com)"
	echo "Usage: ${0##*/} [un/register] pokemini"
	echo " register    Literal word, registers associations"
	echo " unregister  Literal word, unregisters associations"
	echo " pokemini    PokeMini executable with full path"
	exit 1
elif [ -z "$2" ]; then
	act="register"
	emu="$1"
else
	act=$1
	emu="$2"
fi
colormapper=$(dirname $emu)/color_mapper

if [ "$act" == "register" ]; then

mkdir -p ~/.local/share/mime/packages/
mkdir -p ~/.local/share/icons/hicolor/16x16/apps/
mkdir -p ~/.local/share/icons/hicolor/32x32/apps/

cat <<EOF >~/.local/share/mime/packages/x-pokemon-mini.xml
<?xml version="1.0" encoding="UTF-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="application/x-pokemon-mini">
    <comment>Pokémon Mini ROM</comment>
    <glob pattern="*.min"/>
    <magic priority="50">
      <match value="MN" type="string" offset="8448"/>
    </magic>
  </mime-type>
</mime-info>
EOF
if [ "$?" != "0" ]; then
	zenity --error --title="PokeMini" \
	--text="Unable to write to file ~/.local/share/mime/packages/x-pokemon-mini.xml"
	exit 1
fi

cat <<EOF >~/.local/share/mime/packages/x-pokemon-mini-color.xml
<?xml version="1.0" encoding="UTF-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="application/x-pokemon-mini-color">
    <comment>Pokémon Mini Color Info</comment>
    <glob pattern="*.minc"/>
    <magic priority="50">
      <match value="MINc" type="string" offset="0"/>
    </magic>
  </mime-type>
</mime-info>
EOF
if [ "$?" != "0" ]; then
	zenity --error --title="PokeMini" \
	--text="Unable to write to file ~/.local/share/mime/packages/x-pokemon-mini-color.xml"
	exit 1
fi

update-mime-database ~/.local/share/mime/
if [ "$?" != "0" ]; then
	zenity --error --title="PokeMini" \
	--text="Error when updating mime database ~/.local/share/mime/"
	exit 1
fi

cperr() {
	cp $1 $2
	if [ "$?" != "0" ]; then
		zenity --error --title="PokeMini" \
		--text="Unable to write to file $2"
		exit 1
	fi
}

cperr min16.png ~/.local/share/icons/hicolor/16x16/apps/application-x-pokemon-mini.png
cperr minc16.png ~/.local/share/icons/hicolor/16x16/apps/application-x-pokemon-mini-color.png
cperr min32.png ~/.local/share/icons/hicolor/32x32/apps/application-x-pokemon-mini.png
cperr minc32.png ~/.local/share/icons/hicolor/32x32/apps/application-x-pokemon-mini-color.png
cperr pokemini16.png ~/.local/share/icons/hicolor/16x16/apps/pokemini_debugger.png
cperr pokemini32.png ~/.local/share/icons/hicolor/32x32/apps/pokemini_debugger.png
cperr colormapper16.png ~/.local/share/icons/hicolor/16x16/apps/pokemini_colormapper.png
cperr colormapper32.png ~/.local/share/icons/hicolor/32x32/apps/pokemini_colormapper.png

#~/.local/share/applications/
cat <<EOF >/tmp/pokemini_debugger.desktop
#!/usr/bin/env xdg-open
[Desktop Entry]
Version=1.0
Type=Application
Name=PokeMini Debugger
Comment=Pokémon-Mini emulator with debugging capabilities
Exec="$emu" %f
Categories=Game;
Icon=pokemini_debugger
MimeType=application/x-pokemon-mini;application/x-pokemon-mini-color;
EOF
if [ "$?" != "0" ]; then
	zenity --error --title="PokeMini" \
	--text="Unable to write to file pokemini_debugger.desktop"
	exit 1
fi

desktop-file-install --dir=$HOME/.local/share/applications/ --rebuild-mime-info-cache /tmp/pokemini_debugger.desktop
if [ "$?" != "0" ]; then
	zenity --error --title="PokeMini" \
	--text="Error when installing pokemini_debugger.desktop"
	exit 1
fi
rm /tmp/pokemini_debugger.desktop

if [ -f "$colormapper" ]; then
	cat <<EOF >/tmp/pokemini_colormapper.desktop
#!/usr/bin/env xdg-open
[Desktop Entry]
Version=1.0
Type=Application
Name=PokeMini Color Mapper
Comment=Colorize your Pokémon-Mini ROMs
Exec="$colormapper" %f
Categories=Game;
Icon=pokemini_colormapper
MimeType=application/x-pokemon-mini-color;
EOF
	if [ "$?" != "0" ]; then
		zenity --error --title="PokeMini" \
		--text="Unable to write to file pokemini_colormapper.desktop"
		exit 1
	fi

	desktop-file-install --dir=$HOME/.local/share/applications/ --rebuild-mime-info-cache /tmp/pokemini_colormapper.desktop
	if [ "$?" != "0" ]; then
		zenity --error --title="PokeMini" \
		--text="Error when installing pokemini_colormapper.desktop"
		exit 1
	fi
	rm /tmp/pokemini_colormapper.desktop
fi

zenity --info --title="PokeMini" --text="Associations were successful.\nPlease relog to apply changes."

elif [ "$act" == "unregister" ]; then

	rm ~/.local/share/mime/packages/x-pokemon-mini.xml \
	~/.local/share/mime/packages/x-pokemon-mini-color.xml \
	~/.local/share/applications/pokemini_debugger.desktop \
	~/.local/share/applications/pokemini_colormapper.desktop \
	~/.local/share/icons/hicolor/16x16/apps/application-x-pokemon-mini*.png \
	~/.local/share/icons/hicolor/32x32/apps/application-x-pokemon-mini*.png \
	~/.local/share/icons/hicolor/16x16/apps/pokemini*.png \
	~/.local/share/icons/hicolor/32x32/apps/pokemini*.png

	update-mime-database ~/.local/share/mime/
	if [ "$?" != "0" ]; then
		zenity --error --title="PokeMini" \
		--text="Error when updating mime database ~/.local/share/mime/"
	exit 1
	fi
	update-desktop-database ~/.local/share/applications/
	if [ "$?" != "0" ]; then
		zenity --error --title="PokeMini" \
		--text="Error when updating desktop database ~/.local/share/applications/"
	exit 1
	fi

	zenity --info --title="PokeMini" --text="Unassociations were successful.\nPlease relog to apply changes."

fi
exit 0
