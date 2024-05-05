# CMake generated Testfile for 
# Source directory: /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/deps/Framework/build_cmake/Tests
# Build directory: /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/cmake/deps/Framework/build_cmake/Tests
# 
# This file includes the relevant testing commands required for 
# testing this directory and lists subdirectories to be tested as well.
if(CTEST_CONFIGURATION_TYPE MATCHES "^([Dd][Ee][Bb][Uu][Gg])$")
  add_test(FrameworkTests "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/cmake/deps/Framework/build_cmake/Tests/Debug\${EFFECTIVE_PLATFORM_NAME}/FrameworkTests.app/FrameworkTests")
  set_tests_properties(FrameworkTests PROPERTIES  _BACKTRACE_TRIPLES "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/deps/Framework/build_cmake/Tests/CMakeLists.txt;32;add_test;/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/deps/Framework/build_cmake/Tests/CMakeLists.txt;0;")
elseif(CTEST_CONFIGURATION_TYPE MATCHES "^([Rr][Ee][Ll][Ee][Aa][Ss][Ee])$")
  add_test(FrameworkTests "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/cmake/deps/Framework/build_cmake/Tests/Release\${EFFECTIVE_PLATFORM_NAME}/FrameworkTests.app/FrameworkTests")
  set_tests_properties(FrameworkTests PROPERTIES  _BACKTRACE_TRIPLES "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/deps/Framework/build_cmake/Tests/CMakeLists.txt;32;add_test;/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/deps/Framework/build_cmake/Tests/CMakeLists.txt;0;")
elseif(CTEST_CONFIGURATION_TYPE MATCHES "^([Mm][Ii][Nn][Ss][Ii][Zz][Ee][Rr][Ee][Ll])$")
  add_test(FrameworkTests "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/cmake/deps/Framework/build_cmake/Tests/MinSizeRel\${EFFECTIVE_PLATFORM_NAME}/FrameworkTests.app/FrameworkTests")
  set_tests_properties(FrameworkTests PROPERTIES  _BACKTRACE_TRIPLES "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/deps/Framework/build_cmake/Tests/CMakeLists.txt;32;add_test;/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/deps/Framework/build_cmake/Tests/CMakeLists.txt;0;")
elseif(CTEST_CONFIGURATION_TYPE MATCHES "^([Rr][Ee][Ll][Ww][Ii][Tt][Hh][Dd][Ee][Bb][Ii][Nn][Ff][Oo])$")
  add_test(FrameworkTests "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/cmake/deps/Framework/build_cmake/Tests/RelWithDebInfo\${EFFECTIVE_PLATFORM_NAME}/FrameworkTests.app/FrameworkTests")
  set_tests_properties(FrameworkTests PROPERTIES  _BACKTRACE_TRIPLES "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/deps/Framework/build_cmake/Tests/CMakeLists.txt;32;add_test;/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Play/Play-/deps/Framework/build_cmake/Tests/CMakeLists.txt;0;")
else()
  add_test(FrameworkTests NOT_AVAILABLE)
endif()
