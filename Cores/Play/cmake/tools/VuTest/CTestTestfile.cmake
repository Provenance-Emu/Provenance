# CMake generated Testfile for 
# Source directory: /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/tools/VuTest
# Build directory: /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/cmake/tools/VuTest
# 
# This file includes the relevant testing commands required for 
# testing this directory and lists subdirectories to be tested as well.
if(CTEST_CONFIGURATION_TYPE MATCHES "^([Dd][Ee][Bb][Uu][Gg])$")
  add_test(VuTest "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/cmake/tools/VuTest/Debug\${EFFECTIVE_PLATFORM_NAME}/VuTest.app/VuTest")
  set_tests_properties(VuTest PROPERTIES  _BACKTRACE_TRIPLES "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/tools/VuTest/CMakeLists.txt;68;add_test;/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/tools/VuTest/CMakeLists.txt;0;")
elseif(CTEST_CONFIGURATION_TYPE MATCHES "^([Rr][Ee][Ll][Ee][Aa][Ss][Ee])$")
  add_test(VuTest "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/cmake/tools/VuTest/Release\${EFFECTIVE_PLATFORM_NAME}/VuTest.app/VuTest")
  set_tests_properties(VuTest PROPERTIES  _BACKTRACE_TRIPLES "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/tools/VuTest/CMakeLists.txt;68;add_test;/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/tools/VuTest/CMakeLists.txt;0;")
elseif(CTEST_CONFIGURATION_TYPE MATCHES "^([Mm][Ii][Nn][Ss][Ii][Zz][Ee][Rr][Ee][Ll])$")
  add_test(VuTest "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/cmake/tools/VuTest/MinSizeRel\${EFFECTIVE_PLATFORM_NAME}/VuTest.app/VuTest")
  set_tests_properties(VuTest PROPERTIES  _BACKTRACE_TRIPLES "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/tools/VuTest/CMakeLists.txt;68;add_test;/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/tools/VuTest/CMakeLists.txt;0;")
elseif(CTEST_CONFIGURATION_TYPE MATCHES "^([Rr][Ee][Ll][Ww][Ii][Tt][Hh][Dd][Ee][Bb][Ii][Nn][Ff][Oo])$")
  add_test(VuTest "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/cmake/tools/VuTest/RelWithDebInfo\${EFFECTIVE_PLATFORM_NAME}/VuTest.app/VuTest")
  set_tests_properties(VuTest PROPERTIES  _BACKTRACE_TRIPLES "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/tools/VuTest/CMakeLists.txt;68;add_test;/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/tools/VuTest/CMakeLists.txt;0;")
else()
  add_test(VuTest NOT_AVAILABLE)
endif()
