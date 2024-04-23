# CMake generated Testfile for 
# Source directory: /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/tools/SpuTest
# Build directory: /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/cmake/tools/SpuTest
# 
# This file includes the relevant testing commands required for 
# testing this directory and lists subdirectories to be tested as well.
if(CTEST_CONFIGURATION_TYPE MATCHES "^([Dd][Ee][Bb][Uu][Gg])$")
  add_test(SpuTest "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/cmake/tools/SpuTest/Debug\${EFFECTIVE_PLATFORM_NAME}/SpuTest.app/SpuTest")
  set_tests_properties(SpuTest PROPERTIES  _BACKTRACE_TRIPLES "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/tools/SpuTest/CMakeLists.txt;38;add_test;/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/tools/SpuTest/CMakeLists.txt;0;")
elseif(CTEST_CONFIGURATION_TYPE MATCHES "^([Rr][Ee][Ll][Ee][Aa][Ss][Ee])$")
  add_test(SpuTest "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/cmake/tools/SpuTest/Release\${EFFECTIVE_PLATFORM_NAME}/SpuTest.app/SpuTest")
  set_tests_properties(SpuTest PROPERTIES  _BACKTRACE_TRIPLES "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/tools/SpuTest/CMakeLists.txt;38;add_test;/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/tools/SpuTest/CMakeLists.txt;0;")
elseif(CTEST_CONFIGURATION_TYPE MATCHES "^([Mm][Ii][Nn][Ss][Ii][Zz][Ee][Rr][Ee][Ll])$")
  add_test(SpuTest "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/cmake/tools/SpuTest/MinSizeRel\${EFFECTIVE_PLATFORM_NAME}/SpuTest.app/SpuTest")
  set_tests_properties(SpuTest PROPERTIES  _BACKTRACE_TRIPLES "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/tools/SpuTest/CMakeLists.txt;38;add_test;/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/tools/SpuTest/CMakeLists.txt;0;")
elseif(CTEST_CONFIGURATION_TYPE MATCHES "^([Rr][Ee][Ll][Ww][Ii][Tt][Hh][Dd][Ee][Bb][Ii][Nn][Ff][Oo])$")
  add_test(SpuTest "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/cmake/tools/SpuTest/RelWithDebInfo\${EFFECTIVE_PLATFORM_NAME}/SpuTest.app/SpuTest")
  set_tests_properties(SpuTest PROPERTIES  _BACKTRACE_TRIPLES "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/tools/SpuTest/CMakeLists.txt;38;add_test;/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/tools/SpuTest/CMakeLists.txt;0;")
else()
  add_test(SpuTest NOT_AVAILABLE)
endif()
