# CMake generated Testfile for 
# Source directory: /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/tools/GsAreaTest
# Build directory: /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/cmake/tools/GsAreaTest
# 
# This file includes the relevant testing commands required for 
# testing this directory and lists subdirectories to be tested as well.
if(CTEST_CONFIGURATION_TYPE MATCHES "^([Dd][Ee][Bb][Uu][Gg])$")
  add_test(GsAreaTest "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/cmake/tools/GsAreaTest/Debug\${EFFECTIVE_PLATFORM_NAME}/GsAreaTest.app/GsAreaTest")
  set_tests_properties(GsAreaTest PROPERTIES  _BACKTRACE_TRIPLES "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/tools/GsAreaTest/CMakeLists.txt;31;add_test;/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/tools/GsAreaTest/CMakeLists.txt;0;")
elseif(CTEST_CONFIGURATION_TYPE MATCHES "^([Rr][Ee][Ll][Ee][Aa][Ss][Ee])$")
  add_test(GsAreaTest "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/cmake/tools/GsAreaTest/Release\${EFFECTIVE_PLATFORM_NAME}/GsAreaTest.app/GsAreaTest")
  set_tests_properties(GsAreaTest PROPERTIES  _BACKTRACE_TRIPLES "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/tools/GsAreaTest/CMakeLists.txt;31;add_test;/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/tools/GsAreaTest/CMakeLists.txt;0;")
elseif(CTEST_CONFIGURATION_TYPE MATCHES "^([Mm][Ii][Nn][Ss][Ii][Zz][Ee][Rr][Ee][Ll])$")
  add_test(GsAreaTest "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/cmake/tools/GsAreaTest/MinSizeRel\${EFFECTIVE_PLATFORM_NAME}/GsAreaTest.app/GsAreaTest")
  set_tests_properties(GsAreaTest PROPERTIES  _BACKTRACE_TRIPLES "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/tools/GsAreaTest/CMakeLists.txt;31;add_test;/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/tools/GsAreaTest/CMakeLists.txt;0;")
elseif(CTEST_CONFIGURATION_TYPE MATCHES "^([Rr][Ee][Ll][Ww][Ii][Tt][Hh][Dd][Ee][Bb][Ii][Nn][Ff][Oo])$")
  add_test(GsAreaTest "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/cmake/tools/GsAreaTest/RelWithDebInfo\${EFFECTIVE_PLATFORM_NAME}/GsAreaTest.app/GsAreaTest")
  set_tests_properties(GsAreaTest PROPERTIES  _BACKTRACE_TRIPLES "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/tools/GsAreaTest/CMakeLists.txt;31;add_test;/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/tools/GsAreaTest/CMakeLists.txt;0;")
else()
  add_test(GsAreaTest NOT_AVAILABLE)
endif()
