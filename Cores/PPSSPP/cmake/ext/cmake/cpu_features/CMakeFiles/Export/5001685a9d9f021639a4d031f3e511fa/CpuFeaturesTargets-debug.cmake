#----------------------------------------------------------------
# Generated CMake target import file for configuration "Debug".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "CpuFeatures::cpu_features" for configuration "Debug"
set_property(TARGET CpuFeatures::cpu_features APPEND PROPERTY IMPORTED_CONFIGURATIONS DEBUG)
set_target_properties(CpuFeatures::cpu_features PROPERTIES
  IMPORTED_LINK_INTERFACE_LANGUAGES_DEBUG "C"
  IMPORTED_LOCATION_DEBUG "${_IMPORT_PREFIX}/lib/libcpu_features.a"
  )

list(APPEND _cmake_import_check_targets CpuFeatures::cpu_features )
list(APPEND _cmake_import_check_files_for_CpuFeatures::cpu_features "${_IMPORT_PREFIX}/lib/libcpu_features.a" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
