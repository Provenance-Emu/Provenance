#----------------------------------------------------------------
# Generated CMake target import file for configuration "MinSizeRel".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "glslang" for configuration "MinSizeRel"
set_property(TARGET glslang APPEND PROPERTY IMPORTED_CONFIGURATIONS MINSIZEREL)
set_target_properties(glslang PROPERTIES
  IMPORTED_LINK_INTERFACE_LANGUAGES_MINSIZEREL "CXX"
  IMPORTED_LOCATION_MINSIZEREL "${_IMPORT_PREFIX}/lib/libglslang.a"
  )

list(APPEND _cmake_import_check_targets glslang )
list(APPEND _cmake_import_check_files_for_glslang "${_IMPORT_PREFIX}/lib/libglslang.a" )

# Import target "MachineIndependent" for configuration "MinSizeRel"
set_property(TARGET MachineIndependent APPEND PROPERTY IMPORTED_CONFIGURATIONS MINSIZEREL)
set_target_properties(MachineIndependent PROPERTIES
  IMPORTED_LINK_INTERFACE_LANGUAGES_MINSIZEREL "CXX"
  IMPORTED_LOCATION_MINSIZEREL "${_IMPORT_PREFIX}/lib/libMachineIndependent.a"
  )

list(APPEND _cmake_import_check_targets MachineIndependent )
list(APPEND _cmake_import_check_files_for_MachineIndependent "${_IMPORT_PREFIX}/lib/libMachineIndependent.a" )

# Import target "GenericCodeGen" for configuration "MinSizeRel"
set_property(TARGET GenericCodeGen APPEND PROPERTY IMPORTED_CONFIGURATIONS MINSIZEREL)
set_target_properties(GenericCodeGen PROPERTIES
  IMPORTED_LINK_INTERFACE_LANGUAGES_MINSIZEREL "CXX"
  IMPORTED_LOCATION_MINSIZEREL "${_IMPORT_PREFIX}/lib/libGenericCodeGen.a"
  )

list(APPEND _cmake_import_check_targets GenericCodeGen )
list(APPEND _cmake_import_check_files_for_GenericCodeGen "${_IMPORT_PREFIX}/lib/libGenericCodeGen.a" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
