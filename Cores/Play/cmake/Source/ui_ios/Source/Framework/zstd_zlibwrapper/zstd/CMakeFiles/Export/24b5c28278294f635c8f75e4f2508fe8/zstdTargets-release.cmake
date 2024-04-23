#----------------------------------------------------------------
# Generated CMake target import file for configuration "Release".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "zstd::libzstd_static" for configuration "Release"
set_property(TARGET zstd::libzstd_static APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
set_target_properties(zstd::libzstd_static PROPERTIES
  IMPORTED_LINK_INTERFACE_LANGUAGES_RELEASE "ASM;C"
  IMPORTED_LOCATION_RELEASE "${_IMPORT_PREFIX}/lib/libzstd.a"
  )

list(APPEND _cmake_import_check_targets zstd::libzstd_static )
list(APPEND _cmake_import_check_files_for_zstd::libzstd_static "${_IMPORT_PREFIX}/lib/libzstd.a" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
