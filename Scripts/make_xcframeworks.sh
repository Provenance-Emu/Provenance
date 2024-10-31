#!/bin/bash

# Function to print usage
print_usage() {
    echo "Usage: $0 <source_folder> [bundle_identifier_prefix] [output_folder]"
    echo "If bundle_identifier_prefix is not provided, it defaults to 'org.provenance-emu'"
    echo "If output_folder is not provided, it defaults to the current directory"
}

# Check if the minimum number of arguments is provided
if [ "$#" -lt 1 ]; then
    print_usage
    exit 1
fi

# Assign input arguments to variables
SOURCE_FOLDER="$1"
BUNDLE_ID_PREFIX="${2:-org.provenance-emu}"
OUTPUT_FOLDER="${3:-.}"

# Ensure output folder exists
mkdir -p "$OUTPUT_FOLDER"

# Function to create XCFramework for a project
create_xcframework() {
    local project_name="$1"
    local ios_dylib="$2"
    local tvos_dylib="$3"
    local xcframework_name="${project_name}.xcframework"

    echo "Creating XCFramework for $project_name..."

    # Prepare xcodebuild command
    local xcodebuild_cmd="xcodebuild -create-xcframework"

    # Add iOS dylib if it exists
    if [ -f "$ios_dylib" ]; then
        xcodebuild_cmd+=" -library $ios_dylib"
    fi

    # Add tvOS dylib if it exists
    if [ -f "$tvos_dylib" ]; then
        xcodebuild_cmd+=" -library $tvos_dylib"
    fi

    # Add output
    xcodebuild_cmd+=" -output $OUTPUT_FOLDER/$xcframework_name"

    # Execute xcodebuild command
    eval $xcodebuild_cmd

    # Check if XCFramework was created successfully
    if [ $? -eq 0 ]; then
        echo "XCFramework $xcframework_name created successfully."

        # Update Info.plist with bundle identifier
        plutil -replace CFBundleIdentifier -string "${BUNDLE_ID_PREFIX}.${project_name}" "$OUTPUT_FOLDER/$xcframework_name/Info.plist"
        echo "Updated bundle identifier to ${BUNDLE_ID_PREFIX}.${project_name}"
    else
        echo "Failed to create XCFramework for $project_name"
    fi
}

# Find all unique project names
project_names=$(find "$SOURCE_FOLDER" -name "*_libretro_*.dylib" | sed 's/.*\/\(.*\)_libretro_.*/\1/' | sort -u)

# Loop through each project and create XCFramework
for project in $project_names; do
    ios_dylib="$SOURCE_FOLDER/${project}_libretro_ios.dylib"
    tvos_dylib="$SOURCE_FOLDER/${project}_libretro_tvos.dylib"

    if [ -f "$ios_dylib" ] || [ -f "$tvos_dylib" ]; then
        create_xcframework "$project" "$ios_dylib" "$tvos_dylib"
    else
        echo "No dylib files found for project $project"
    fi
done

echo "All XCFrameworks have been created in $OUTPUT_FOLDER"
