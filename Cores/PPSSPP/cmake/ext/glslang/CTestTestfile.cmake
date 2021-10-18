# CMake generated Testfile for 
# Source directory: /Users/jmattiello/Workspace/Provenance/Provenance/Cores/PPSSPP/ppsspp/ext/glslang
# Build directory: /Users/jmattiello/Workspace/Provenance/Provenance/Cores/PPSSPP/cmake/ext/glslang
# 
# This file includes the relevant testing commands required for 
# testing this directory and lists subdirectories to be tested as well.
if("${CTEST_CONFIGURATION_TYPE}" MATCHES "^([Dd][Ee][Bb][Uu][Gg])$")
  add_test(glslang-testsuite "bash" "runtests" "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/PPSSPP/cmake/ext/glslang/Debug/localResults" "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/PPSSPP/cmake/ext/glslang/StandAlone/Debug/glslangValidator" "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/PPSSPP/cmake/ext/glslang/StandAlone/Debug/spirv-remap")
  set_tests_properties(glslang-testsuite PROPERTIES  WORKING_DIRECTORY "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/PPSSPP/ppsspp/ext/glslang/Test/" _BACKTRACE_TRIPLES "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/PPSSPP/ppsspp/ext/glslang/CMakeLists.txt;348;add_test;/Users/jmattiello/Workspace/Provenance/Provenance/Cores/PPSSPP/ppsspp/ext/glslang/CMakeLists.txt;0;")
elseif("${CTEST_CONFIGURATION_TYPE}" MATCHES "^([Rr][Ee][Ll][Ee][Aa][Ss][Ee])$")
  add_test(glslang-testsuite "bash" "runtests" "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/PPSSPP/cmake/ext/glslang/Release/localResults" "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/PPSSPP/cmake/ext/glslang/StandAlone/Release/glslangValidator" "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/PPSSPP/cmake/ext/glslang/StandAlone/Release/spirv-remap")
  set_tests_properties(glslang-testsuite PROPERTIES  WORKING_DIRECTORY "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/PPSSPP/ppsspp/ext/glslang/Test/" _BACKTRACE_TRIPLES "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/PPSSPP/ppsspp/ext/glslang/CMakeLists.txt;348;add_test;/Users/jmattiello/Workspace/Provenance/Provenance/Cores/PPSSPP/ppsspp/ext/glslang/CMakeLists.txt;0;")
elseif("${CTEST_CONFIGURATION_TYPE}" MATCHES "^([Mm][Ii][Nn][Ss][Ii][Zz][Ee][Rr][Ee][Ll])$")
  add_test(glslang-testsuite "bash" "runtests" "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/PPSSPP/cmake/ext/glslang/MinSizeRel/localResults" "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/PPSSPP/cmake/ext/glslang/StandAlone/MinSizeRel/glslangValidator" "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/PPSSPP/cmake/ext/glslang/StandAlone/MinSizeRel/spirv-remap")
  set_tests_properties(glslang-testsuite PROPERTIES  WORKING_DIRECTORY "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/PPSSPP/ppsspp/ext/glslang/Test/" _BACKTRACE_TRIPLES "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/PPSSPP/ppsspp/ext/glslang/CMakeLists.txt;348;add_test;/Users/jmattiello/Workspace/Provenance/Provenance/Cores/PPSSPP/ppsspp/ext/glslang/CMakeLists.txt;0;")
elseif("${CTEST_CONFIGURATION_TYPE}" MATCHES "^([Rr][Ee][Ll][Ww][Ii][Tt][Hh][Dd][Ee][Bb][Ii][Nn][Ff][Oo])$")
  add_test(glslang-testsuite "bash" "runtests" "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/PPSSPP/cmake/ext/glslang/RelWithDebInfo/localResults" "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/PPSSPP/cmake/ext/glslang/StandAlone/RelWithDebInfo/glslangValidator" "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/PPSSPP/cmake/ext/glslang/StandAlone/RelWithDebInfo/spirv-remap")
  set_tests_properties(glslang-testsuite PROPERTIES  WORKING_DIRECTORY "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/PPSSPP/ppsspp/ext/glslang/Test/" _BACKTRACE_TRIPLES "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/PPSSPP/ppsspp/ext/glslang/CMakeLists.txt;348;add_test;/Users/jmattiello/Workspace/Provenance/Provenance/Cores/PPSSPP/ppsspp/ext/glslang/CMakeLists.txt;0;")
else()
  add_test(glslang-testsuite NOT_AVAILABLE)
endif()
subdirs("External")
subdirs("glslang")
subdirs("OGLCompilersDLL")
subdirs("SPIRV")
subdirs("hlsl")
subdirs("gtests")
