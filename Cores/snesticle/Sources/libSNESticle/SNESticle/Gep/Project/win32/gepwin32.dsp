# Microsoft Developer Studio Project File - Name="gepwin32" - Package Owner=<4>
# Microsoft Developer Studio Generated Build File, Format Version 6.00
# ** DO NOT EDIT **

# TARGTYPE "Win32 (x86) Static Library" 0x0104

CFG=gepwin32 - Win32 Debug
!MESSAGE This is not a valid makefile. To build this project using NMAKE,
!MESSAGE use the Export Makefile command and run
!MESSAGE 
!MESSAGE NMAKE /f "gepwin32.mak".
!MESSAGE 
!MESSAGE You can specify a configuration when running NMAKE
!MESSAGE by defining the macro CFG on the command line. For example:
!MESSAGE 
!MESSAGE NMAKE /f "gepwin32.mak" CFG="gepwin32 - Win32 Debug"
!MESSAGE 
!MESSAGE Possible choices for configuration are:
!MESSAGE 
!MESSAGE "gepwin32 - Win32 Release" (based on "Win32 (x86) Static Library")
!MESSAGE "gepwin32 - Win32 Debug" (based on "Win32 (x86) Static Library")
!MESSAGE 

# Begin Project
# PROP AllowPerConfigDependencies 0
# PROP Scc_ProjName ""$/pureNes", BAAAAAAA"
# PROP Scc_LocalPath "..\..\..\purenes"
CPP=cl.exe
RSC=rc.exe

!IF  "$(CFG)" == "gepwin32 - Win32 Release"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 0
# PROP BASE Output_Dir "Release"
# PROP BASE Intermediate_Dir "Release"
# PROP BASE Target_Dir ""
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 0
# PROP Output_Dir "Release"
# PROP Intermediate_Dir "Release"
# PROP Target_Dir ""
# ADD BASE CPP /nologo /W3 /GX /O2 /D "WIN32" /D "NDEBUG" /D "_MBCS" /D "_LIB" /YX /FD /c
# ADD CPP /nologo /W3 /GX /O2 /I "..\..\Include\Common" /I "..\..\Include\Win32" /D "WIN32" /D "NDEBUG" /D "_MBCS" /D "_LIB" /YX /FD /c
# ADD BASE RSC /l 0x409 /d "NDEBUG"
# ADD RSC /l 0x409 /d "NDEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LIB32=link.exe -lib
# ADD BASE LIB32 /nologo
# ADD LIB32 /nologo

!ELSEIF  "$(CFG)" == "gepwin32 - Win32 Debug"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 1
# PROP BASE Output_Dir "Debug"
# PROP BASE Intermediate_Dir "Debug"
# PROP BASE Target_Dir ""
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 1
# PROP Output_Dir "Debug"
# PROP Intermediate_Dir "Debug"
# PROP Target_Dir ""
# ADD BASE CPP /nologo /W3 /Gm /GX /ZI /Od /D "WIN32" /D "_DEBUG" /D "_MBCS" /D "_LIB" /YX /FD /GZ /c
# ADD CPP /nologo /W3 /Gm /GX /ZI /Od /I "..\..\Include\Common" /I "..\..\Include\Win32" /D "WIN32" /D "_DEBUG" /D "_MBCS" /D "_LIB" /YX /FD /GZ /c
# ADD BASE RSC /l 0x409 /d "_DEBUG"
# ADD RSC /l 0x409 /d "_DEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LIB32=link.exe -lib
# ADD BASE LIB32 /nologo
# ADD LIB32 /nologo

!ENDIF 

# Begin Target

# Name "gepwin32 - Win32 Release"
# Name "gepwin32 - Win32 Debug"
# Begin Group "Source Files"

# PROP Default_Filter "cpp;c;cxx;rc;def;r;odl;idl;hpj;bat"
# Begin Group "Common"

# PROP Default_Filter ""
# Begin Group "Console"

# PROP Default_Filter ""
# Begin Source File

SOURCE=..\..\Source\common\console\linebuffer.cpp
# End Source File
# Begin Source File

SOURCE=..\..\Source\common\console\msgnode.cpp
# End Source File
# End Group
# Begin Source File

SOURCE=..\..\Source\common\array.cpp
# End Source File
# Begin Source File

SOURCE=..\..\Source\common\bmpfile.cpp
# End Source File
# Begin Source File

SOURCE=..\..\Source\common\file.cpp
# End Source File
# Begin Source File

SOURCE=..\..\Source\common\inputdevice.cpp
# End Source File
# Begin Source File

SOURCE=..\..\Source\common\memspace.cpp
# End Source File
# Begin Source File

SOURCE=..\..\Source\common\path.cpp
# End Source File
# Begin Source File

SOURCE=..\..\Source\common\pixelformat.cpp
# End Source File
# Begin Source File

SOURCE=..\..\Source\common\surface.cpp
# End Source File
# End Group
# Begin Group "Win32"

# PROP Default_Filter ""
# Begin Group "DDraw"

# PROP Default_Filter ""
# Begin Source File

SOURCE=..\..\Source\win32\ddraw\ddsurface.cpp
# End Source File
# Begin Source File

SOURCE=..\..\Source\win32\ddraw\winddraw.cpp
# End Source File
# End Group
# Begin Group "DInput"

# PROP Default_Filter ""
# Begin Source File

SOURCE=..\..\Source\win32\dinput\inputjoystick.cpp
# End Source File
# Begin Source File

SOURCE=..\..\Source\win32\dinput\inputkeyboard.cpp
# End Source File
# Begin Source File

SOURCE=..\..\Source\win32\dinput\inputmouse.cpp
# End Source File
# End Group
# Begin Group "DSound"

# PROP Default_Filter ""
# Begin Source File

SOURCE=..\..\Source\win32\dsound\dsbuffer.cpp
# End Source File
# Begin Source File

SOURCE=..\..\Source\win32\dsound\windsound.cpp
# End Source File
# End Group
# Begin Source File

SOURCE=..\..\Source\win32\console.cpp
# End Source File
# Begin Source File

SOURCE=..\..\Source\win32\msgnodewin.cpp
# End Source File
# Begin Source File

SOURCE=..\..\Source\win32\rendersurface.cpp
# End Source File
# Begin Source File

SOURCE=..\..\Source\win32\textoutput.cpp
# End Source File
# Begin Source File

SOURCE=..\..\Source\win32\window.cpp
# End Source File
# Begin Source File

SOURCE=..\..\Source\win32\winmain.cpp
# End Source File
# Begin Source File

SOURCE=..\..\Source\win32\winprintf.cpp
# End Source File
# End Group
# End Group
# Begin Group "Include"

# PROP Default_Filter ""
# Begin Source File

SOURCE=..\..\Include\common\array.h
# End Source File
# Begin Source File

SOURCE=..\..\Include\common\bmpfile.h
# End Source File
# Begin Source File

SOURCE=..\..\Include\common\console.h
# End Source File
# Begin Source File

SOURCE=..\..\Include\win32\ddsurface.h
# End Source File
# Begin Source File

SOURCE=..\..\Include\win32\dsbuffer.h
# End Source File
# Begin Source File

SOURCE=..\..\Include\common\file.h
# End Source File
# Begin Source File

SOURCE=..\..\Include\common\inputdevice.h
# End Source File
# Begin Source File

SOURCE=..\..\Include\win32\inputjoystick.h
# End Source File
# Begin Source File

SOURCE=..\..\Include\win32\inputkeyboard.h
# End Source File
# Begin Source File

SOURCE=..\..\Include\win32\inputmouse.h
# End Source File
# Begin Source File

SOURCE=..\..\Include\common\linebuffer.h
# End Source File
# Begin Source File

SOURCE=..\..\Include\common\memspace.h
# End Source File
# Begin Source File

SOURCE=..\..\Include\common\mixer.h
# End Source File
# Begin Source File

SOURCE=..\..\Include\common\msgnode.h
# End Source File
# Begin Source File

SOURCE=..\..\Include\common\palette.h
# End Source File
# Begin Source File

SOURCE=..\..\Include\common\path.h
# End Source File
# Begin Source File

SOURCE=..\..\Include\common\pixelformat.h
# End Source File
# Begin Source File

SOURCE=..\..\Include\common\surface.h
# End Source File
# Begin Source File

SOURCE=..\..\Include\win32\textoutput.h
# End Source File
# Begin Source File

SOURCE=..\..\Include\win32\types.h
# End Source File
# Begin Source File

SOURCE=..\..\Include\win32\winddraw.h
# End Source File
# Begin Source File

SOURCE=..\..\Include\win32\window.h
# End Source File
# Begin Source File

SOURCE=..\..\Include\win32\windsound.h
# End Source File
# Begin Source File

SOURCE=..\..\Include\win32\winmain.h
# End Source File
# Begin Source File

SOURCE=..\..\Include\win32\winprintf.h
# End Source File
# End Group
# End Target
# End Project
