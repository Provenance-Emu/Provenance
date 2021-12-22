#----------------------------------------------------------------
# Generated CMake target import file for configuration "RelWithDebInfo".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "OSDependent" for configuration "RelWithDebInfo"
set_property(TARGET OSDependent APPEND PROPERTY IMPORTED_CONFIGURATIONS RELWITHDEBINFO)
set_target_properties(OSDependent PROPERTIES
  IMPORTED_LINK_INTERFACE_LANGUAGES_RELWITHDEBINFO "CXX"
  IMPORTED_LOCATION_RELWITHDEBINFO "${_IMPORT_PREFIX}/lib/libOSDependent.a"
  )

list(APPEND _IMPORT_CHECK_TARGETS OSDependent )
list(APPEND _IMPORT_CHECK_FILES_FOR_OSDependent "${_IMPORT_PREFIX}/lib/libOSDependent.a" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
