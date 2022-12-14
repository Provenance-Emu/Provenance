# CMake generated Testfile for 
# Source directory: /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/dolphin-ios/Source/UnitTests/VideoCommon
# Build directory: /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/cmake/Source/UnitTests/VideoCommon
# 
# This file includes the relevant testing commands required for 
# testing this directory and lists subdirectories to be tested as well.
if(CTEST_CONFIGURATION_TYPE MATCHES "^([Dd][Ee][Bb][Uu][Gg])$")
  add_test(VertexLoaderTest "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/cmake/Binaries/Tests/Debug/VertexLoaderTest.app/VertexLoaderTest")
  set_tests_properties(VertexLoaderTest PROPERTIES  _BACKTRACE_TRIPLES "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/dolphin-ios/Source/UnitTests/CMakeLists.txt;21;add_test;/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/dolphin-ios/Source/UnitTests/VideoCommon/CMakeLists.txt;1;add_dolphin_test;/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/dolphin-ios/Source/UnitTests/VideoCommon/CMakeLists.txt;0;")
elseif(CTEST_CONFIGURATION_TYPE MATCHES "^([Rr][Ee][Ll][Ee][Aa][Ss][Ee])$")
  add_test(VertexLoaderTest "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/cmake/Binaries/Tests/Release/VertexLoaderTest.app/VertexLoaderTest")
  set_tests_properties(VertexLoaderTest PROPERTIES  _BACKTRACE_TRIPLES "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/dolphin-ios/Source/UnitTests/CMakeLists.txt;21;add_test;/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/dolphin-ios/Source/UnitTests/VideoCommon/CMakeLists.txt;1;add_dolphin_test;/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/dolphin-ios/Source/UnitTests/VideoCommon/CMakeLists.txt;0;")
elseif(CTEST_CONFIGURATION_TYPE MATCHES "^([Mm][Ii][Nn][Ss][Ii][Zz][Ee][Rr][Ee][Ll])$")
  add_test(VertexLoaderTest "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/cmake/Binaries/Tests/MinSizeRel/VertexLoaderTest.app/VertexLoaderTest")
  set_tests_properties(VertexLoaderTest PROPERTIES  _BACKTRACE_TRIPLES "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/dolphin-ios/Source/UnitTests/CMakeLists.txt;21;add_test;/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/dolphin-ios/Source/UnitTests/VideoCommon/CMakeLists.txt;1;add_dolphin_test;/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/dolphin-ios/Source/UnitTests/VideoCommon/CMakeLists.txt;0;")
elseif(CTEST_CONFIGURATION_TYPE MATCHES "^([Rr][Ee][Ll][Ww][Ii][Tt][Hh][Dd][Ee][Bb][Ii][Nn][Ff][Oo])$")
  add_test(VertexLoaderTest "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/cmake/Binaries/Tests/RelWithDebInfo/VertexLoaderTest.app/VertexLoaderTest")
  set_tests_properties(VertexLoaderTest PROPERTIES  _BACKTRACE_TRIPLES "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/dolphin-ios/Source/UnitTests/CMakeLists.txt;21;add_test;/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/dolphin-ios/Source/UnitTests/VideoCommon/CMakeLists.txt;1;add_dolphin_test;/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/dolphin-ios/Source/UnitTests/VideoCommon/CMakeLists.txt;0;")
else()
  add_test(VertexLoaderTest NOT_AVAILABLE)
endif()
