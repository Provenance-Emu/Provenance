#----------------------------------------------------------------
# Generated CMake target import file for configuration "RelWithDebInfo".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "SPIRV" for configuration "RelWithDebInfo"
set_property(TARGET SPIRV APPEND PROPERTY IMPORTED_CONFIGURATIONS RELWITHDEBINFO)
set_target_properties(SPIRV PROPERTIES
  IMPORTED_LINK_INTERFACE_LANGUAGES_RELWITHDEBINFO "CXX"
  IMPORTED_LOCATION_RELWITHDEBINFO "${_IMPORT_PREFIX}/lib/libSPIRV.a"
  )

list(APPEND _cmake_import_check_targets SPIRV )
list(APPEND _cmake_import_check_files_for_SPIRV "${_IMPORT_PREFIX}/lib/libSPIRV.a" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
