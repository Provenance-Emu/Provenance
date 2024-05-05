# CMake generated Testfile for 
# Source directory: /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/tools/McServTest
# Build directory: /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/cmake/tools/McServTest
# 
# This file includes the relevant testing commands required for 
# testing this directory and lists subdirectories to be tested as well.
if(CTEST_CONFIGURATION_TYPE MATCHES "^([Dd][Ee][Bb][Uu][Gg])$")
  add_test(McServTest "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/cmake/tools/McServTest/Debug\${EFFECTIVE_PLATFORM_NAME}/McServTest.app/McServTest")
  set_tests_properties(McServTest PROPERTIES  WORKING_DIRECTORY "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/tools/McServTest" _BACKTRACE_TRIPLES "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/tools/McServTest/CMakeLists.txt;27;add_test;/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/tools/McServTest/CMakeLists.txt;0;")
elseif(CTEST_CONFIGURATION_TYPE MATCHES "^([Rr][Ee][Ll][Ee][Aa][Ss][Ee])$")
  add_test(McServTest "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/cmake/tools/McServTest/Release\${EFFECTIVE_PLATFORM_NAME}/McServTest.app/McServTest")
  set_tests_properties(McServTest PROPERTIES  WORKING_DIRECTORY "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/tools/McServTest" _BACKTRACE_TRIPLES "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/tools/McServTest/CMakeLists.txt;27;add_test;/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/tools/McServTest/CMakeLists.txt;0;")
elseif(CTEST_CONFIGURATION_TYPE MATCHES "^([Mm][Ii][Nn][Ss][Ii][Zz][Ee][Rr][Ee][Ll])$")
  add_test(McServTest "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/cmake/tools/McServTest/MinSizeRel\${EFFECTIVE_PLATFORM_NAME}/McServTest.app/McServTest")
  set_tests_properties(McServTest PROPERTIES  WORKING_DIRECTORY "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/tools/McServTest" _BACKTRACE_TRIPLES "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/tools/McServTest/CMakeLists.txt;27;add_test;/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/tools/McServTest/CMakeLists.txt;0;")
elseif(CTEST_CONFIGURATION_TYPE MATCHES "^([Rr][Ee][Ll][Ww][Ii][Tt][Hh][Dd][Ee][Bb][Ii][Nn][Ff][Oo])$")
  add_test(McServTest "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/cmake/tools/McServTest/RelWithDebInfo\${EFFECTIVE_PLATFORM_NAME}/McServTest.app/McServTest")
  set_tests_properties(McServTest PROPERTIES  WORKING_DIRECTORY "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/tools/McServTest" _BACKTRACE_TRIPLES "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/tools/McServTest/CMakeLists.txt;27;add_test;/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/tools/McServTest/CMakeLists.txt;0;")
else()
  add_test(McServTest NOT_AVAILABLE)
endif()
