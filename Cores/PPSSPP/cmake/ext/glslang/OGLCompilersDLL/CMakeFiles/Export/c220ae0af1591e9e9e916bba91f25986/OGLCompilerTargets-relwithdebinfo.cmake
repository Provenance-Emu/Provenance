#----------------------------------------------------------------
# Generated CMake target import file for configuration "RelWithDebInfo".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "OGLCompiler" for configuration "RelWithDebInfo"
set_property(TARGET OGLCompiler APPEND PROPERTY IMPORTED_CONFIGURATIONS RELWITHDEBINFO)
set_target_properties(OGLCompiler PROPERTIES
  IMPORTED_LINK_INTERFACE_LANGUAGES_RELWITHDEBINFO "CXX"
  IMPORTED_LOCATION_RELWITHDEBINFO "${_IMPORT_PREFIX}/lib/libOGLCompiler.a"
  )

list(APPEND _cmake_import_check_targets OGLCompiler )
list(APPEND _cmake_import_check_files_for_OGLCompiler "${_IMPORT_PREFIX}/lib/libOGLCompiler.a" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
