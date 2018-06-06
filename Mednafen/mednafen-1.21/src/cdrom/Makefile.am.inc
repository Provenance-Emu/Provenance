mednafen_SOURCES	+=	cdrom/cdromif.cpp cdrom/scsicd.cpp
mednafen_SOURCES	+=	cdrom/CDUtility.cpp cdrom/crc32.cpp cdrom/galois.cpp cdrom/l-ec.cpp cdrom/recover-raw.cpp
mednafen_SOURCES	+=	cdrom/lec.cpp cdrom/CDAccess.cpp cdrom/CDAccess_Image.cpp cdrom/CDAccess_CCD.cpp

mednafen_SOURCES	+=	cdrom/CDAFReader.cpp
mednafen_SOURCES	+=	cdrom/CDAFReader_Vorbis.cpp
mednafen_SOURCES	+=	cdrom/CDAFReader_MPC.cpp

if HAVE_LIBSNDFILE
mednafen_SOURCES	+=	cdrom/CDAFReader_SF.cpp
endif
