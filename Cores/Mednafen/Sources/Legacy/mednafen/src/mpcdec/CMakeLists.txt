SET(mpcdec_VERSION_MAJOR 7)
SET(mpcdec_VERSION_MINOR 0)
SET(mpcdec_VERSION_PATCH 1)

set(mpcdec_VERSION ${mpcdec_VERSION_MAJOR}.${mpcdec_VERSION_MINOR}.${mpcdec_VERSION_PATCH})

include_directories(${libmpc_SOURCE_DIR}/include)
install(FILES
	${libmpc_SOURCE_DIR}/include/mpc/mpcdec.h
	${libmpc_SOURCE_DIR}/include/mpc/reader.h
	${libmpc_SOURCE_DIR}/include/mpc/streaminfo.h
	${libmpc_SOURCE_DIR}/include/mpc/mpc_types.h
	DESTINATION include/mpc COMPONENT headers)

if(SHARED)
  add_library(mpcdec SHARED huffman mpc_decoder mpc_reader streaminfo mpc_bits_reader mpc_demux requant synth_filter ${libmpc_SOURCE_DIR}/common/crc32)
  set_target_properties(mpcdec PROPERTIES VERSION ${mpcdec_VERSION} SOVERSION ${mpcdec_VERSION_MAJOR})
  install(TARGETS mpcdec LIBRARY DESTINATION "lib" COMPONENT libraries)
else(SHARED)
  add_library(mpcdec_static STATIC huffman mpc_decoder mpc_reader streaminfo mpc_bits_reader mpc_demux requant synth_filter ${libmpc_SOURCE_DIR}/common/crc32)
  install(TARGETS mpcdec_static ARCHIVE DESTINATION "lib/static" COMPONENT libraries)
endif(SHARED)

