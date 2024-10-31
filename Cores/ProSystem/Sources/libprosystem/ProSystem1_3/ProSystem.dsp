# Microsoft Developer Studio Project File - Name="ProSystem" - Package Owner=<4>
# Microsoft Developer Studio Generated Build File, Format Version 6.00
# ** DO NOT EDIT **

# TARGTYPE "Win32 (x86) Application" 0x0101

CFG=ProSystem - Win32 Debug
!MESSAGE This is not a valid makefile. To build this project using NMAKE,
!MESSAGE use the Export Makefile command and run
!MESSAGE 
!MESSAGE NMAKE /f "ProSystem.mak".
!MESSAGE 
!MESSAGE You can specify a configuration when running NMAKE
!MESSAGE by defining the macro CFG on the command line. For example:
!MESSAGE 
!MESSAGE NMAKE /f "ProSystem.mak" CFG="ProSystem - Win32 Debug"
!MESSAGE 
!MESSAGE Possible choices for configuration are:
!MESSAGE 
!MESSAGE "ProSystem - Win32 Release" (based on "Win32 (x86) Application")
!MESSAGE "ProSystem - Win32 Debug" (based on "Win32 (x86) Application")
!MESSAGE 

# Begin Project
# PROP AllowPerConfigDependencies 0
# PROP Scc_ProjName ""
# PROP Scc_LocalPath ""
CPP=cl.exe
MTL=midl.exe
RSC=rc.exe

!IF  "$(CFG)" == "ProSystem - Win32 Release"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 0
# PROP BASE Output_Dir "Release"
# PROP BASE Intermediate_Dir "Release"
# PROP BASE Target_Dir ""
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 0
# PROP Output_Dir ".\Bin\Release"
# PROP Intermediate_Dir ".\Bin\Release"
# PROP Ignore_Export_Lib 0
# PROP Target_Dir ""
# ADD BASE CPP /nologo /W3 /GX /O2 /D "WIN32" /D "NDEBUG" /D "_WINDOWS" /D "_MBCS" /YX /FD /c
# ADD CPP /nologo /W3 /GX /O2 /Ob2 /I "Core" /I "Win" /I "Lib" /D "WIN32" /D "NDEBUG" /D "_WINDOWS" /D "_MBCS" /FR /FD /c
# SUBTRACT CPP /YX
# ADD BASE MTL /nologo /D "NDEBUG" /mktyplib203 /win32
# ADD MTL /nologo /D "NDEBUG" /mktyplib203 /win32
# ADD BASE RSC /l 0x409 /d "NDEBUG"
# ADD RSC /l 0x409 /d "NDEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LINK32=link.exe
# ADD BASE LINK32 kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib /nologo /subsystem:windows /machine:I386
# ADD LINK32 kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib ddraw.lib dinput.lib dxguid.lib winmm.lib dsound.lib htmlhelp.lib zlib.lib /nologo /subsystem:windows /machine:I386 /libpath:"Lib"

!ELSEIF  "$(CFG)" == "ProSystem - Win32 Debug"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 1
# PROP BASE Output_Dir "Debug"
# PROP BASE Intermediate_Dir "Debug"
# PROP BASE Target_Dir ""
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 1
# PROP Output_Dir ".\Bin\Debug"
# PROP Intermediate_Dir ".\Bin\Debug"
# PROP Ignore_Export_Lib 0
# PROP Target_Dir ""
# ADD BASE CPP /nologo /W3 /Gm /GX /ZI /Od /D "WIN32" /D "_DEBUG" /D "_WINDOWS" /D "_MBCS" /YX /FD /GZ /c
# ADD CPP /nologo /W3 /Gm /GX /ZI /Od /I "Core" /I "Win" /I "Lib" /D "WIN32" /D "_DEBUG" /D "_WINDOWS" /D "_MBCS" /FR /YX /FD /GZ /c
# ADD BASE MTL /nologo /D "_DEBUG" /mktyplib203 /win32
# ADD MTL /nologo /D "_DEBUG" /mktyplib203 /win32
# ADD BASE RSC /l 0x409 /d "_DEBUG"
# ADD RSC /l 0x409 /d "_DEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LINK32=link.exe
# ADD BASE LINK32 kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib /nologo /subsystem:windows /debug /machine:I386 /pdbtype:sept
# ADD LINK32 kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib ddraw.lib dinput.lib dxguid.lib winmm.lib dsound.lib htmlhelp.lib zlib.lib /nologo /subsystem:windows /debug /machine:I386 /pdbtype:sept /libpath:"Lib"

!ENDIF 

# Begin Target

# Name "ProSystem - Win32 Release"
# Name "ProSystem - Win32 Debug"
# Begin Group "Core"

# PROP Default_Filter ""
# Begin Source File

SOURCE=.\Core\Archive.cpp
# End Source File
# Begin Source File

SOURCE=.\Core\Archive.h
# End Source File
# Begin Source File

SOURCE=.\Core\Bios.cpp
# End Source File
# Begin Source File

SOURCE=.\Core\Bios.h
# End Source File
# Begin Source File

SOURCE=.\Core\Cartridge.cpp
# End Source File
# Begin Source File

SOURCE=.\Core\Cartridge.h
# End Source File
# Begin Source File

SOURCE=.\Core\Equates.h
# End Source File
# Begin Source File

SOURCE=.\Core\Hash.cpp
# End Source File
# Begin Source File

SOURCE=.\Core\Hash.h
# End Source File
# Begin Source File

SOURCE=.\Core\Logger.cpp
# End Source File
# Begin Source File

SOURCE=.\Core\Logger.h
# End Source File
# Begin Source File

SOURCE=.\Core\Maria.cpp
# End Source File
# Begin Source File

SOURCE=.\Core\Maria.h
# End Source File
# Begin Source File

SOURCE=.\Core\Memory.cpp
# End Source File
# Begin Source File

SOURCE=.\Core\Memory.h
# End Source File
# Begin Source File

SOURCE=.\Core\Pair.h
# End Source File
# Begin Source File

SOURCE=.\Core\Palette.cpp
# End Source File
# Begin Source File

SOURCE=.\Core\Palette.h
# End Source File
# Begin Source File

SOURCE=.\Core\Pokey.cpp
# End Source File
# Begin Source File

SOURCE=.\Core\Pokey.h
# End Source File
# Begin Source File

SOURCE=.\Core\ProSystem.cpp
# End Source File
# Begin Source File

SOURCE=.\Core\ProSystem.h
# End Source File
# Begin Source File

SOURCE=.\Core\Rect.h
# End Source File
# Begin Source File

SOURCE=.\Core\Region.cpp
# End Source File
# Begin Source File

SOURCE=.\Core\Region.h
# End Source File
# Begin Source File

SOURCE=.\Core\Riot.cpp
# End Source File
# Begin Source File

SOURCE=.\Core\Riot.h
# End Source File
# Begin Source File

SOURCE=.\Core\Sally.cpp
# End Source File
# Begin Source File

SOURCE=.\Core\Sally.h
# End Source File
# Begin Source File

SOURCE=.\Core\Tia.cpp
# End Source File
# Begin Source File

SOURCE=.\Core\Tia.h
# End Source File
# End Group
# Begin Group "Win"

# PROP Default_Filter ""
# Begin Source File

SOURCE=.\Win\About.cpp
# End Source File
# Begin Source File

SOURCE=.\Win\About.h
# End Source File
# Begin Source File

SOURCE=.\Win\Common.cpp
# End Source File
# Begin Source File

SOURCE=.\Win\Common.h
# End Source File
# Begin Source File

SOURCE=.\Win\Configuration.cpp
# End Source File
# Begin Source File

SOURCE=.\Win\Configuration.h
# End Source File
# Begin Source File

SOURCE=.\Win\Console.cpp
# End Source File
# Begin Source File

SOURCE=.\Win\Console.h
# End Source File
# Begin Source File

SOURCE=.\Win\Database.cpp
# End Source File
# Begin Source File

SOURCE=.\Win\Database.h
# End Source File
# Begin Source File

SOURCE=.\Win\Display.cpp
# End Source File
# Begin Source File

SOURCE=.\Win\Display.h
# End Source File
# Begin Source File

SOURCE=.\Win\Help.cpp
# End Source File
# Begin Source File

SOURCE=.\Win\Help.h
# End Source File
# Begin Source File

SOURCE=.\Win\Input.cpp
# End Source File
# Begin Source File

SOURCE=.\Win\Input.h
# End Source File
# Begin Source File

SOURCE=.\Win\Main.cpp
# End Source File
# Begin Source File

SOURCE=.\Win\Menu.cpp
# End Source File
# Begin Source File

SOURCE=.\Win\Menu.h
# End Source File
# Begin Source File

SOURCE=.\Win\ProSystem.ico
# End Source File
# Begin Source File

SOURCE=.\Win\ProSystem.rc
# End Source File
# Begin Source File

SOURCE=.\Win\Resource.h
# End Source File
# Begin Source File

SOURCE=.\Win\Sound.cpp
# End Source File
# Begin Source File

SOURCE=.\Win\Sound.h
# End Source File
# Begin Source File

SOURCE=.\Win\Timer.cpp
# End Source File
# Begin Source File

SOURCE=.\Win\Timer.h
# End Source File
# End Group
# Begin Group "Lib"

# PROP Default_Filter ""
# Begin Source File

SOURCE=.\Lib\Crypt.h
# End Source File
# Begin Source File

SOURCE=.\Lib\HtmlHelp.h
# End Source File
# Begin Source File

SOURCE=.\Lib\Ioapi.h
# End Source File
# Begin Source File

SOURCE=.\Lib\Unzip.h
# End Source File
# Begin Source File

SOURCE=.\Lib\Zconf.h
# End Source File
# Begin Source File

SOURCE=.\Lib\Zip.h
# End Source File
# Begin Source File

SOURCE=.\Lib\Zlib.h
# End Source File
# End Group
# Begin Group "Web"

# PROP Default_Filter ""
# Begin Source File

SOURCE=.\Web\index.html
# End Source File
# End Group
# Begin Source File

SOURCE=.\License.txt
# End Source File
# Begin Source File

SOURCE=.\ProSystem.dat
# End Source File
# End Target
# End Project
