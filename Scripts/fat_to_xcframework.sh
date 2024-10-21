#!/bin/bash

# Function to print colorful info messages
print_info() {
    echo -e "\033[1;34m[INFO]\033[0m $1"
}

# Function to print error messages
print_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
}

# Function to process a single framework
process_framework() {
    local FRAMEWORK_PATH="$1"
    local FRAMEWORK_NAME=$(basename "$FRAMEWORK_PATH" .framework)

    print_info "Processing framework: $FRAMEWORK_NAME"

    # Check if the framework exists
    if [ ! -d "$FRAMEWORK_PATH" ]; then
        print_error "Framework not found at $FRAMEWORK_PATH"
        return 1
    fi

    # Find the binary inside the framework
    local FRAMEWORK_BINARY=$(find "$FRAMEWORK_PATH" -name "$FRAMEWORK_NAME" -type f)

    if [ -z "$FRAMEWORK_BINARY" ]; then
        print_error "Binary not found inside the framework"
        return 1
    fi

    print_info "Found framework binary at: $FRAMEWORK_BINARY"

    # Create a temporary directory for intermediate files
    local TEMP_DIR=$(mktemp -d)
    print_info "Created temporary directory: $TEMP_DIR"

    # Function to create a framework for a specific platform
    create_framework_for_platform() {
        local PLATFORM=$1
        shift
        local ARCHS=("$@")
        local FRAMEWORK_PLATFORM_PATH="$TEMP_DIR/$PLATFORM/$FRAMEWORK_NAME.framework"

        print_info "Creating framework for platform: $PLATFORM"
        mkdir -p "$FRAMEWORK_PLATFORM_PATH"
        cp -R "$FRAMEWORK_PATH/" "$FRAMEWORK_PLATFORM_PATH/"

        print_info "Extracting $PLATFORM slices from fat binary"
        local LIPO_COMMAND="lipo \"$FRAMEWORK_BINARY\""
        for ARCH in "${ARCHS[@]}"; do
            LIPO_COMMAND+=" -extract $ARCH"
        done
        LIPO_COMMAND+=" -output \"$FRAMEWORK_PLATFORM_PATH/$FRAMEWORK_NAME\""
        print_info "Running command: $LIPO_COMMAND"
        if ! eval $LIPO_COMMAND; then
            print_error "Failed to extract $PLATFORM slices. Skipping this platform."
            rm -rf "$FRAMEWORK_PLATFORM_PATH"
            return 1
        fi
    }

    # Extract architectures from the fat binary
    print_info "Extracting architectures from fat binary"
    print_info "Running command: lipo -info \"$FRAMEWORK_BINARY\""
    local ARCHS=$(lipo -info "$FRAMEWORK_BINARY" | sed -e 's/.*are: //g')
    print_info "Found architectures: $ARCHS"

    # Create frameworks for each platform
    local VALID_PLATFORMS=""
    if [[ $ARCHS == *"arm64"* || $ARCHS == *"armv7"* ]]; then
        local ARM_ARCHS=()
        [[ $ARCHS == *"arm64"* ]] && ARM_ARCHS+=("arm64")
        [[ $ARCHS == *"armv7"* ]] && ARM_ARCHS+=("armv7")
        if create_framework_for_platform "ios-arm64_armv7" "${ARM_ARCHS[@]}"; then
            VALID_PLATFORMS="$VALID_PLATFORMS ios-arm64_armv7"
        fi
    fi
    if [[ $ARCHS == *"x86_64"* || $ARCHS == *"i386"* ]]; then
        local SIM_ARCHS=()
        [[ $ARCHS == *"x86_64"* ]] && SIM_ARCHS+=("x86_64")
        [[ $ARCHS == *"i386"* ]] && SIM_ARCHS+=("i386")
        if create_framework_for_platform "ios-x86_64_i386-simulator" "${SIM_ARCHS[@]}"; then
            VALID_PLATFORMS="$VALID_PLATFORMS ios-x86_64_i386-simulator"
        fi
    fi

    # Create XCFramework
    local XCFRAMEWORK_PATH="./$FRAMEWORK_NAME.xcframework"
    print_info "Removing existing XCFramework if present"
    rm -rf "$XCFRAMEWORK_PATH"

    local XCFRAMEWORK_ARGS=""
    for PLATFORM in $VALID_PLATFORMS; do
        XCFRAMEWORK_ARGS+=" -framework $TEMP_DIR/$PLATFORM/$FRAMEWORK_NAME.framework"
    done

    print_info "Creating XCFramework"
    print_info "Running command: xcodebuild -create-xcframework $XCFRAMEWORK_ARGS -output \"$XCFRAMEWORK_PATH\""
    if ! xcodebuild -create-xcframework $XCFRAMEWORK_ARGS -output "$XCFRAMEWORK_PATH"; then
        print_error "Failed to create XCFramework. Temporary files are preserved at $TEMP_DIR"
        open "$TEMP_DIR"
        return 1
    fi

    print_info "XCFramework created successfully at $XCFRAMEWORK_PATH"

    # Clean up
    print_info "Cleaning up temporary files"
    rm -rf "$TEMP_DIR"

    # Open the XCFramework in Finder as a directory
    osascript -e "tell application \"Finder\" to open (POSIX file \"$XCFRAMEWORK_PATH\") as alias"
}

# Check if at least one argument is provided
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <path_to_framework> [<path_to_framework> ...]"
    exit 1
fi

# Process each provided framework
for FRAMEWORK_PATH in "$@"; do
    if [[ "$FRAMEWORK_PATH" == *.framework ]]; then
        process_framework "$FRAMEWORK_PATH"
    elif [[ "$FRAMEWORK_PATH" == *.framework ]]; then
        for FOUND_FRAMEWORK in $FRAMEWORK_PATH; do
            process_framework "$FOUND_FRAMEWORK"
        done
    else
        print_error "Invalid framework path: $FRAMEWORK_PATH"
    fi
done
