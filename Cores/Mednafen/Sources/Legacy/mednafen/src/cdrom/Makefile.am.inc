mednafen_SOURCES	+=	cdrom/crc32.cpp cdrom/galois.cpp cdrom/l-ec.cpp cdrom/recover-raw.cpp cdrom/lec.cpp
mednafen_SOURCES	+=	cdrom/CDUtility.cpp
mednafen_SOURCES	+=	cdrom/CDInterface.cpp cdrom/CDInterface_MT.cpp cdrom/CDInterface_ST.cpp
mednafen_SOURCES	+=	cdrom/CDAccess.cpp cdrom/CDAccess_Image.cpp cdrom/CDAccess_CCD.cpp

mednafen_SOURCES	+=	cdrom/CDAFReader.cpp
mednafen_SOURCES	+=	cdrom/CDAFReader_Vorbis.cpp
mednafen_SOURCES	+=	cdrom/CDAFReader_MPC.cpp
if HAVE_LIBFLAC
mednafen_SOURCES	+=	cdrom/CDAFReader_FLAC.cpp
endif
mednafen_SOURCES	+=	cdrom/CDAFReader_PCM.cpp

mednafen_SOURCES	+=	cdrom/scsicd.cpp

