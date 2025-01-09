@echo off
set "SCRIPT_DIRECTORY=%~dp0"

for /f "delims=" %%A in ('git rev-parse --short HEAD') do set "rev=%%A"
echo current revision %rev%
echo #define PLUGIN_REVISION "%rev%">%SCRIPT_DIRECTORY%/Revision.h
echo #define PLUGIN_REVISION_W L"%rev%">>%SCRIPT_DIRECTORY%/Revision.h
