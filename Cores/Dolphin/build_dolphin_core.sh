#!/bin/bash

set -e

# Configuration
DOL_CORE_BUILD_TARGET="Release"
REPO_ROOT_DIR="$(pwd)/dolphin-ios"
XCFRAMEWORK_DIR="$(pwd)/build/xcframework"
FRAMEWORK_NAME="PVlibDolphin"
IPHONEOS_DEPLOYMENT_TARGET="16.4"
TVOS_DEPLOYMENT_TARGET="16.4"

# Global variables for parallel build tracking
BUILD_PIDS=()
BUILD_FAILED=false

# Signal handler for Ctrl+C (SIGINT) and SIGTERM
cleanup() {
    # Only cleanup if we're actually interrupted (not normal completion)
    if [ "${#BUILD_PIDS[@]}" -gt 0 ]; then
        echo ""
        echo "🛑 Build interrupted! Cleaning up parallel builds..."
        
        # Kill all background build processes
        for pid in "${BUILD_PIDS[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                echo "   Killing build process $pid"
                kill -TERM "$pid" 2>/dev/null || true
                # Give it a moment to terminate gracefully
                sleep 1
                # Force kill if still running
                if kill -0 "$pid" 2>/dev/null; then
                    kill -KILL "$pid" 2>/dev/null || true
                fi
            fi
        done
        
        echo "🧹 Cleanup complete"
        exit 130  # Standard exit code for Ctrl+C
    fi
}

# Set up signal handlers for interruptions only (not normal exit)
trap cleanup SIGINT SIGTERM

# Enable job control for better signal handling
set -m

# Function to handle build failure
handle_build_failure() {
    local failed_platform="$1"
    local exit_code="$2"

    echo ""
    echo "❌ Build failed for $failed_platform (exit code: $exit_code)"
    echo "🛑 Terminating all other parallel builds..."

    BUILD_FAILED=true

    # Kill all other background build processes
    for pid in "${BUILD_PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            echo "   Terminating build process $pid"
            kill -TERM "$pid" 2>/dev/null || true
            sleep 1
            if kill -0 "$pid" 2>/dev/null; then
                kill -KILL "$pid" 2>/dev/null || true
            fi
        fi
    done

    echo "💥 Build failed! Exiting with code $exit_code"
    exit "$exit_code"
}

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT_DIR="$SCRIPT_DIR/dolphin-ios"
BUILD_DIR="$SCRIPT_DIR/build"
XCFRAMEWORK_DIR="$BUILD_DIR/xcframework"

# Ensure necessary directories exist
mkdir -p "$BUILD_DIR"
mkdir -p "$XCFRAMEWORK_DIR"

# Check for required tools
if ! command -v ninja &> /dev/null; then
    echo "Error: Ninja build tool not found. Please install it with 'brew install ninja'."
    exit 1
fi

if ! command -v cmake &> /dev/null; then
    echo "Error: CMake not found. Please install it with 'brew install cmake'."
    exit 1
fi

# Set compiler paths explicitly
export CC="$(xcrun -find clang)"
export CXX="$(xcrun -find clang++)"

# Function to build for a specific platform
build_platform() {
    local platform=$1
    local deployment_target=$2
    local platform_name=$3
    local output_suffix=$4

    echo "Building for $platform_name..."

    CMAKE_BUILD_DIR="$REPO_ROOT_DIR/build-$platform_name-$DOL_CORE_BUILD_TARGET"
    mkdir -p "$CMAKE_BUILD_DIR"
    cd "$CMAKE_BUILD_DIR"

    # Define base optimization flags (universal for all architectures)
    OPTIMIZATION_FLAGS=""
    OPTIMIZATION_FLAGS="$OPTIMIZATION_FLAGS -ffast-math"                    # Fast floating-point math optimizations
    OPTIMIZATION_FLAGS="$OPTIMIZATION_FLAGS -fno-strict-aliasing"           # Allow more aggressive pointer optimizations
    OPTIMIZATION_FLAGS="$OPTIMIZATION_FLAGS -ftree-vectorize"               # Enable tree vectorization
    OPTIMIZATION_FLAGS="$OPTIMIZATION_FLAGS -flto=thin"                     # Thin Link Time Optimization
    OPTIMIZATION_FLAGS="$OPTIMIZATION_FLAGS -fomit-frame-pointer"           # Omit frame pointer for better performance
    OPTIMIZATION_FLAGS="$OPTIMIZATION_FLAGS -funsafe-math-optimizations"    # Unsafe math optimizations for speed
    OPTIMIZATION_FLAGS="$OPTIMIZATION_FLAGS -fvectorize"                    # Enable vectorization
    # Remove unsupported flags that cause warnings:
    # -frename-registers (not supported by clang)
    # -fsingle-precision-constant (not supported by clang)
    OPTIMIZATION_FLAGS="$OPTIMIZATION_FLAGS -w"                             # Suppress all warnings

    # Add curl-specific fixes for iOS cross-compilation
    CURL_FIXES=""
    CURL_FIXES="$CURL_FIXES -DSIZEOF_CURL_OFF_T=8"                          # Define curl_off_t size as 64-bit
    CURL_FIXES="$CURL_FIXES -DHAVE_SYS_SOCKET_H=1"                          # Enable socket headers
    CURL_FIXES="$CURL_FIXES -DHAVE_NETINET_IN_H=1"                          # Enable network headers
    CURL_FIXES="$CURL_FIXES -DHAVE_ARPA_INET_H=1"                           # Enable inet headers
    CURL_FIXES="$CURL_FIXES -DHAVE_NETDB_H=1"                               # Enable netdb headers (hostent, gethostbyname)
    CURL_FIXES="$CURL_FIXES -DHAVE_SYS_TIME_H=1"                            # Enable time headers
    CURL_FIXES="$CURL_FIXES -DHAVE_SYS_STAT_H=1"                            # Enable stat headers (struct stat, fstat, S_ISREG)
    CURL_FIXES="$CURL_FIXES -DHAVE_UNISTD_H=1"                              # Enable unistd headers
    CURL_FIXES="$CURL_FIXES -DHAVE_FCNTL_H=1"                               # Enable fcntl headers
    CURL_FIXES="$CURL_FIXES -DHAVE_STRUCT_TIMEVAL=1"                        # Tell curl system already has timeval
    CURL_FIXES="$CURL_FIXES -DHAVE_SYS_SELECT_H=1"                          # Enable select headers
    CURL_FIXES="$CURL_FIXES -DHAVE_GETHOSTBYNAME=1"                         # Enable gethostbyname function
    CURL_FIXES="$CURL_FIXES -DHAVE_GETHOSTBYNAME_R=0"                       # Disable thread-safe version
    CURL_FIXES="$CURL_FIXES -DHAVE_STRUCT_HOSTENT=1"                        # Enable hostent struct
    CURL_FIXES="$CURL_FIXES -DHAVE_FSTAT=1"                                 # Enable fstat function
    CURL_FIXES="$CURL_FIXES -DHAVE_STRUCT_STAT=1"                           # Enable struct stat
    CURL_FIXES="$CURL_FIXES -DHAVE_SELECT=1"                                # Enable select function
    CURL_FIXES="$CURL_FIXES -DHAVE_POLL=1"                                  # Enable poll function
    CURL_FIXES="$CURL_FIXES -DHAVE_POLL_H=1"                                # Enable poll.h header
    CURL_FIXES="$CURL_FIXES -DHAVE_SOCKET=1"                                # Enable socket function
    CURL_FIXES="$CURL_FIXES -DHAVE_CONNECT=1"                               # Enable connect function
    CURL_FIXES="$CURL_FIXES -DHAVE_RECV=1"                                  # Enable recv function
    CURL_FIXES="$CURL_FIXES -DHAVE_SEND=1"                                  # Enable send function
    CURL_FIXES="$CURL_FIXES -DHAVE_BIND=1"                                  # Enable bind function
    CURL_FIXES="$CURL_FIXES -DHAVE_LISTEN=1"                                # Enable listen function
    CURL_FIXES="$CURL_FIXES -DHAVE_ACCEPT=1"                                # Enable accept function
    CURL_FIXES="$CURL_FIXES -DHAVE_SOCKADDR_IN6=1"                          # Enable IPv6 sockaddr
    CURL_FIXES="$CURL_FIXES -DHAVE_FCNTL_O_NONBLOCK=1"                      # Enable O_NONBLOCK for fcntl
    CURL_FIXES="$CURL_FIXES -Dsread=read"                                  # Required by curl
    CURL_FIXES="$CURL_FIXES -Dswrite=write"                                # Required by curl
    OPTIMIZATION_FLAGS="$OPTIMIZATION_FLAGS $CURL_FIXES"

    # Clear any existing architecture flags to prevent conflicts
    # Set base optimization flags (non-architecture specific)
    BASE_OPTIMIZATION_FLAGS="-ffast-math -fno-strict-aliasing -ftree-vectorize -flto=thin -fomit-frame-pointer -funsafe-math-optimizations -fvectorize -w"
    
    # Add curl fixes to base optimization flags
    BASE_OPTIMIZATION_FLAGS="$BASE_OPTIMIZATION_FLAGS $CURL_FIXES"
    
    # Create separate architecture flags for each target
    ARM64_FLAGS="-mcpu=apple-a10 -mtune=apple-a15 -march=armv8-a+simd+crc+crypto"
    X86_64_FLAGS="-march=x86-64-v3 -mtune=haswell"
    
    # Set platform-specific architecture flags based on actual architecture
    if [[ "$arch" == "x86_64" || "$platform" == *"simulator"* ]]; then
        # Simulator builds (x86_64)
        echo "   Setting x86_64 optimizations for $platform (arch: $arch)"
        ARCH_FLAGS="$X86_64_FLAGS"
    elif [[ "$arch" == "arm64" || "$platform" == *"os"* ]]; then
        # Device builds (ARM64)
        echo "   Setting ARM64 optimizations for $platform (arch: $arch)"
        ARCH_FLAGS="$ARM64_FLAGS"
    else
        # Fallback - no architecture-specific flags
        echo "   WARNING: Unknown architecture '$arch' for platform '$platform', using generic flags"
        ARCH_FLAGS=""
    fi

    # Additional linker optimizations
    LINKER_FLAGS=""
    LINKER_FLAGS="$LINKER_FLAGS -Wl,-dead_strip"                           # Remove unused sections (macOS/iOS linker)

    # Configure platform-specific CMake flags
    if [[ "$platform" == *"simulator"* ]]; then
        # Simulator builds (x86_64) - use only x86_64 flags
        C_FLAGS="-fPIC $BASE_OPTIMIZATION_FLAGS $X86_64_FLAGS"
        CXX_FLAGS="-fPIC -fpermissive -std=c++20 $BASE_OPTIMIZATION_FLAGS $X86_64_FLAGS"
        echo "Using x86_64 flags for $platform: $X86_64_FLAGS"
    else
        # Device builds (ARM64) - use only ARM64 flags
        C_FLAGS="-fPIC $BASE_OPTIMIZATION_FLAGS $ARM64_FLAGS"
        CXX_FLAGS="-fPIC -fpermissive -std=c++20 $BASE_OPTIMIZATION_FLAGS $ARM64_FLAGS"
        echo "Using ARM64 flags for $platform: $ARM64_FLAGS"
    fi
    
    # Configure CMake
    cmake "$REPO_ROOT_DIR" \
        -G Ninja \
        -DCMAKE_BUILD_TYPE=$DOL_CORE_BUILD_TARGET \
        -DCMAKE_TOOLCHAIN_FILE="$REPO_ROOT_DIR/Externals/ios-cmake/ios.toolchain.cmake" \
        -DPLATFORM=$platform \
        -DDEPLOYMENT_TARGET=$deployment_target \
        -DENABLE_VISIBILITY=ON \
        -DENABLE_BITCODE=OFF \
        -DENABLE_ARC=ON \
        -DUSE_SYSTEM_ZSTD=OFF \
        -DUSE_SYSTEM_MINIZIP=OFF \
        -DUSE_SYSTEM_LZMA=OFF \
        -DUSE_SYSTEM_BZIP2=OFF \
        -DCMAKE_C_FLAGS="$C_FLAGS" \
        -DCMAKE_CXX_FLAGS="$CXX_FLAGS" \
        -DCMAKE_EXE_LINKER_FLAGS="$LINKER_FLAGS" \
        -DCMAKE_SHARED_LINKER_FLAGS="$LINKER_FLAGS" \
        -DIOS=ON \
        -DENABLE_ANALYTICS=NO \
        -DUSE_SYSTEM_LIBS=OFF \
        -DENABLE_TESTS=OFF \
        -DCMAKE_POLICY_DEFAULT_CMP0080=NEW \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.19 \
        -DCMAKE_POLICY_VERSION=3.19 \
        -DBUILD_SHARED_LIBS=OFF

    # Build
    ninja

    echo "Build completed for $platform_name"
}

# Build for each platform in parallel
echo "Starting parallel builds for all platforms..."
echo "💡 Press Ctrl+C to cancel all builds"

# Start all builds in parallel using background processes
build_platform "OS64" "$IPHONEOS_DEPLOYMENT_TARGET" "iphoneos" "-ios" &
PID_IOS=$!
BUILD_PIDS+=("$PID_IOS")

if [ "$(arch)" = "arm64" ]; then
    build_platform "SIMULATORARM64" "$IPHONEOS_DEPLOYMENT_TARGET" "iphonesimulator" "-ios-sim" &
else
    build_platform "SIMULATOR64" "$IPHONEOS_DEPLOYMENT_TARGET" "iphonesimulator" "-ios-sim" &
fi
PID_IOS_SIM=$!
BUILD_PIDS+=("$PID_IOS_SIM")

build_platform "TVOS" "$TVOS_DEPLOYMENT_TARGET" "appletvos" "-tvos" &
PID_TVOS=$!
BUILD_PIDS+=("$PID_TVOS")

build_platform "SIMULATOR_TVOS" "$TVOS_DEPLOYMENT_TARGET" "appletvsimulator" "-tvos-sim" &
PID_TVOS_SIM=$!
BUILD_PIDS+=("$PID_TVOS_SIM")

# Wait for all parallel builds to complete
echo "Waiting for all parallel builds to complete..."
echo "📱 iOS build PID: $PID_IOS"
echo "🔧 iOS Simulator build PID: $PID_IOS_SIM"
echo "📺 tvOS build PID: $PID_TVOS"
echo "🔧 tvOS Simulator build PID: $PID_TVOS_SIM"

# Wait for each build and check exit status (fail fast on any failure)
wait $PID_IOS
IOS_EXIT_CODE=$?
if [ $IOS_EXIT_CODE -ne 0 ] && [ "$BUILD_FAILED" = false ]; then
    handle_build_failure "iOS" $IOS_EXIT_CODE
fi
echo "✅ iOS build completed successfully"

wait $PID_IOS_SIM
IOS_SIM_EXIT_CODE=$?
if [ $IOS_SIM_EXIT_CODE -ne 0 ] && [ "$BUILD_FAILED" = false ]; then
    handle_build_failure "iOS Simulator" $IOS_SIM_EXIT_CODE
fi
echo "✅ iOS Simulator build completed successfully"

wait $PID_TVOS
TVOS_EXIT_CODE=$?
if [ $TVOS_EXIT_CODE -ne 0 ] && [ "$BUILD_FAILED" = false ]; then
    handle_build_failure "tvOS" $TVOS_EXIT_CODE
fi
echo "✅ tvOS build completed successfully"

wait $PID_TVOS_SIM
TVOS_SIM_EXIT_CODE=$?
if [ $TVOS_SIM_EXIT_CODE -ne 0 ] && [ "$BUILD_FAILED" = false ]; then
    handle_build_failure "tvOS Simulator" $TVOS_SIM_EXIT_CODE
fi
echo "✅ tvOS Simulator build completed successfully"

# Clear PID tracking since all builds completed successfully
BUILD_PIDS=()
echo "🎉 All parallel builds completed successfully!"

# Explicit synchronization barrier - ensure all background processes are truly finished
echo "⏳ Ensuring all build processes have fully completed..."
sleep 2  # Give any remaining file operations time to complete

# Verify no background jobs are still running
if jobs -r | grep -q .; then
    echo "⚠️  Warning: Background jobs still running, waiting for completion..."
    wait  # Wait for any remaining background jobs
fi

echo "✅ All build processes confirmed complete"
echo ""
echo "📦 Starting XCFramework creation process..."
echo "==========================================="
echo "🔍 DEBUG: Script execution reached XCFramework creation section"
echo "🔍 DEBUG: Current working directory: $(pwd)"
echo "🔍 DEBUG: REPO_ROOT_DIR: $REPO_ROOT_DIR"
echo "🔍 DEBUG: XCFRAMEWORK_DIR: $XCFRAMEWORK_DIR"

# Create output directory
mkdir -p "$XCFRAMEWORK_DIR"

# Find the built dylibs
echo "🔍 Searching for dolphin dylibs..."
IOS_DYLIB=$(find "$REPO_ROOT_DIR" -path "*/build-iphoneos-$DOL_CORE_BUILD_TARGET/*" -name "libdolphin-ios*.dylib" | head -n 1)
IOS_SIM_DYLIB=$(find "$REPO_ROOT_DIR" -path "*/build-iphonesimulator-$DOL_CORE_BUILD_TARGET/*" -name "libdolphin-ios*.dylib" | head -n 1)
TVOS_DYLIB=$(find "$REPO_ROOT_DIR" -path "*/build-appletvos-$DOL_CORE_BUILD_TARGET/*" -name "libdolphin-tvos*.dylib" | head -n 1)
TVOS_SIM_DYLIB=$(find "$REPO_ROOT_DIR" -path "*/build-appletvsimulator-$DOL_CORE_BUILD_TARGET/*" -name "libdolphin-tvos*.dylib" | head -n 1)

echo "📱 iOS dylib: $IOS_DYLIB"
echo "🔧 iOS Simulator dylib: $IOS_SIM_DYLIB"
echo "📺 tvOS dylib: $TVOS_DYLIB"
echo "🔧 tvOS Simulator dylib: $TVOS_SIM_DYLIB"

# Verify all dylibs were found and exist
echo ""
echo "✅ Verifying all dylib files exist..."
MISSING_DYLIBS=()

if [ -z "$IOS_DYLIB" ] || [ ! -f "$IOS_DYLIB" ]; then
    echo "❌ iOS dylib not found or doesn't exist"
    MISSING_DYLIBS+=("iOS")
else
    echo "✅ iOS dylib verified: $(basename "$IOS_DYLIB")"
fi

if [ -z "$IOS_SIM_DYLIB" ] || [ ! -f "$IOS_SIM_DYLIB" ]; then
    echo "❌ iOS Simulator dylib not found or doesn't exist"
    MISSING_DYLIBS+=("iOS Simulator")
else
    echo "✅ iOS Simulator dylib verified: $(basename "$IOS_SIM_DYLIB")"
fi

if [ -z "$TVOS_DYLIB" ] || [ ! -f "$TVOS_DYLIB" ]; then
    echo "❌ tvOS dylib not found or doesn't exist"
    MISSING_DYLIBS+=("tvOS")
else
    echo "✅ tvOS dylib verified: $(basename "$TVOS_DYLIB")"
fi

if [ -z "$TVOS_SIM_DYLIB" ] || [ ! -f "$TVOS_SIM_DYLIB" ]; then
    echo "❌ tvOS Simulator dylib not found or doesn't exist"
    MISSING_DYLIBS+=("tvOS Simulator")
else
    echo "✅ tvOS Simulator dylib verified: $(basename "$TVOS_SIM_DYLIB")"
fi

# Exit if any dylibs are missing
if [ ${#MISSING_DYLIBS[@]} -gt 0 ]; then
    echo ""
    echo "💥 ERROR: Missing dylib files for platforms: ${MISSING_DYLIBS[*]}"
    echo "   Build may have failed silently or dylibs were not generated in expected locations."
    echo "   Please check the build logs above for errors."
    exit 1
fi

echo ""
echo "🎯 All dylib files verified successfully!"

# Function to create a framework from a dylib
create_framework() {
    local dylib_path="$1"
    local platform="$2"
    local framework_path="$XCFRAMEWORK_DIR/$FRAMEWORK_NAME-$platform.framework"

    echo "Creating framework for $platform from $dylib_path"

    # Create framework directory structure
    mkdir -p "$framework_path"

    # Get the actual filename without path
    local dylib_filename=$(basename "$dylib_path")

    # Copy dylib to framework and rename it to match framework name
    cp "$dylib_path" "$framework_path/$FRAMEWORK_NAME-$platform"

    # Make sure the binary is executable
    chmod +x "$framework_path/$FRAMEWORK_NAME-$platform"

    # Fix the install name to match the framework structure
    install_name_tool -id "@rpath/$FRAMEWORK_NAME-$platform.framework/$FRAMEWORK_NAME-$platform" "$framework_path/$FRAMEWORK_NAME-$platform"

    # Create Info.plist
    cat > "$framework_path/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$FRAMEWORK_NAME-$platform</string>
    <key>CFBundleIdentifier</key>
    <string>org.dolphin-emu.$FRAMEWORK_NAME-$platform</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$FRAMEWORK_NAME-$platform</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>MinimumOSVersion</key>
    <string>11.0</string>
</dict>
</plist>
EOF

    echo "Framework created at $framework_path"
}

# Create frameworks for each platform
# Check if dylibs exist
if [ -f "$IOS_DYLIB" ]; then
    create_framework "$IOS_DYLIB" "ios"
else
    echo "Warning: iOS dylib not found"
fi

if [ -f "$IOS_SIM_DYLIB" ]; then
    create_framework "$IOS_SIM_DYLIB" "ios-sim"
else
    echo "Warning: iOS Simulator dylib not found"
fi

if [ -f "$TVOS_DYLIB" ]; then
    create_framework "$TVOS_DYLIB" "tvos"
else
    echo "Warning: tvOS dylib not found"
fi

if [ -f "$TVOS_SIM_DYLIB" ]; then
    create_framework "$TVOS_SIM_DYLIB" "tvos-sim"
else
    echo "Warning: tvOS Simulator dylib not found"
fi

# Create XCFramework
echo "Creating XCFramework..."
XCFRAMEWORK_PATH="$XCFRAMEWORK_DIR/$FRAMEWORK_NAME.xcframework"

# Remove existing XCFramework if it exists
if [ -d "$XCFRAMEWORK_PATH" ]; then
    rm -rf "$XCFRAMEWORK_PATH"
fi

# Build the xcodebuild command
XCFRAMEWORK_CMD="xcodebuild -create-xcframework -output $XCFRAMEWORK_PATH"

# Add frameworks to command if they exist
if [ -f "$IOS_DYLIB" ]; then
    IOS_FRAMEWORK="$XCFRAMEWORK_DIR/$FRAMEWORK_NAME-ios.framework"
    XCFRAMEWORK_CMD="$XCFRAMEWORK_CMD -framework $IOS_FRAMEWORK"
fi

if [ -f "$IOS_SIM_DYLIB" ]; then
    IOS_SIM_FRAMEWORK="$XCFRAMEWORK_DIR/$FRAMEWORK_NAME-ios-sim.framework"
    XCFRAMEWORK_CMD="$XCFRAMEWORK_CMD -framework $IOS_SIM_FRAMEWORK"
fi

if [ -f "$TVOS_DYLIB" ]; then
    TVOS_FRAMEWORK="$XCFRAMEWORK_DIR/$FRAMEWORK_NAME-tvos.framework"
    XCFRAMEWORK_CMD="$XCFRAMEWORK_CMD -framework $TVOS_FRAMEWORK"
fi

if [ -f "$TVOS_SIM_DYLIB" ]; then
    TVOS_SIM_FRAMEWORK="$XCFRAMEWORK_DIR/$FRAMEWORK_NAME-tvos-sim.framework"
    XCFRAMEWORK_CMD="$XCFRAMEWORK_CMD -framework $TVOS_SIM_FRAMEWORK"
fi

# Execute the command if at least one framework exists
if [[ "$XCFRAMEWORK_CMD" != "xcodebuild -create-xcframework -output $XCFRAMEWORK_PATH" ]]; then
    echo "Executing: $XCFRAMEWORK_CMD"
    eval "$XCFRAMEWORK_CMD"
    echo "XCFramework created at $XCFRAMEWORK_PATH"
else
    echo "Error: No frameworks found to create XCFramework"
    exit 1
fi

echo "XCFramework created at $XCFRAMEWORK_PATH"
ls -la "$XCFRAMEWORK_PATH"

# Copy XCFramework to the expected output location
OUTPUT_PATH="$BUILT_PRODUCTS_DIR/$FRAMEWORK_NAME.xcframework"
echo "Copying XCFramework to $OUTPUT_PATH"
rm -rf "$OUTPUT_PATH"
cp -R "$XCFRAMEWORK_PATH" "$OUTPUT_PATH"

echo "Build completed successfully!"
