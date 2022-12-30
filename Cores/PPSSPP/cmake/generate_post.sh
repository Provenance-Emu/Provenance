#!/usr/bin/env bash
rm -fr build
rm -fr CMakeFiles/3.25.0/CompilerIdCXX/XCBuildData/
rm -fr CMakeFiles/3.25.0/CompilerIdC/XCBuildData/
rm -fr CMakeFiles/3.25.0/CompilerIdC/CompilerIdC.build/
rm -fr CMakeFiles/3.25.0/CompilerIdCXX/CompilerIdCXX.build/
rm -fr CMakeFiles/3.25.0/CompilerIdCXX/CompilerIdCXX.build/
rm -fr PPSSPP.xcodeproj/project.xcworkspace/xcuserdata/
python3 xcode_absolute_path_to_relative.py
