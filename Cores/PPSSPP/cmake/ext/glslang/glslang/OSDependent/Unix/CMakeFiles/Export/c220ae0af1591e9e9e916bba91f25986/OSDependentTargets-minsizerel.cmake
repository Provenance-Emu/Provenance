#----------------------------------------------------------------
# Generated CMake target import file for configuration "MinSizeRel".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "OSDependent" for configuration "MinSizeRel"
set_property(TARGET OSDependent APPEND PROPERTY IMPORTED_CONFIGURATIONS MINSIZEREL)
set_target_properties(OSDependent PROPERTIES
  IMPORTED_LINK_INTERFACE_LANGUAGES_MINSIZEREL "CXX"
  IMPORTED_LOCATION_MINSIZEREL "${_IMPORT_PREFIX}/lib/libOSDependent.a"
  )

list(APPEND _cmake_import_check_targets OSDependent )
list(APPEND _cmake_import_check_files_for_OSDependent "${_IMPORT_PREFIX}/lib/libOSDependent.a" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
