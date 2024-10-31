if NEED_BLIP_BUFFER
mednafen_SOURCES	+=	sound/Blip_Buffer.cpp sound/Stereo_Buffer.cpp
endif

mednafen_SOURCES	+=	sound/Fir_Resampler.cpp

mednafen_SOURCES	+=	sound/WAVRecord.cpp
mednafen_SOURCES	+=	sound/okiadpcm.cpp

mednafen_SOURCES	+=	sound/DSPUtility.cpp
mednafen_SOURCES	+=	sound/SwiftResampler.cpp sound/OwlResampler.cpp

