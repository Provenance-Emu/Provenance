# Realm Object Store

The object store contains cross-platform abstractions used in Realm products. It is not intended to be used directly.

The object store consists of the following components:
- `object_store`/`schema`/`object_schema`/`property` - contains the structures and logic used to setup and modify Realm files and their schema.
- `shared_realm` - wraps the `object_store` APIs to provide transactions, notifications, Realm caching, migrations, and other higher level functionality.
- `object_accessor`/`results`/`list` - accessor classes, object creation/update pipeline, and helpers for creating platform specific property getters and setters.

Each Realm product may use only a subset of the provided components depending on its needs.

## Reporting Bugs

Please report bugs against the Realm product that you're using:

* [Realm Java](https://github.com/realm/realm-java)
* [Realm Objective-C](https://github.com/realm/realm-cocoa)
* [Realm React Native](https://github.com/realm/realm-js)
* [Realm Swift](https://github.com/realm/realm-cocoa)
* [Realm Xamarin](https://github.com/realm/realm-dotnet)

## Supported Platforms

The object store's CMake build system currently only supports building for OS X, Linux, and Android.

The object store code supports being built for all Apple platforms, Linux and Android when used along with the relevant Realm product's build system.

## Building

1. Download dependencies:
    ```
    git submodule update --init
    ```

2. Install CMake. You can download an installer for OS X from the [CMake download page](https://cmake.org/download/), or install via [Homebrew](http://brew.sh):
    ```
    brew install cmake
    ```

3. Generate build files:

    ```
    cmake .
    ```

    If building for Android, the path for the Android NDK must be specified. For example, if it was installed with homebrew:

    ```
    cmake -DREALM_PLATFORM=Android -DANDROID_NDK=/usr/local/Cellar/android-ndk-r10e/r10e/ .
    ```

    If you want to use XCode as your editor, you can generate a XCode project with:
    ```
    cmake -G Xcode .
    ```

4. Build:

    ```
    make
    ```

## Building With Sync Support

If you wish to build with sync enabled, invoke `cmake` like so:

```
cmake -DREALM_ENABLE_SYNC=1
```

### Building Against a Local Version of Core

If you wish to build against a local version of core you can invoke `cmake` like so:

```
cmake -DREALM_CORE_PREFIX=/path/to/realm-core
```

The given core tree will be built as part of the object store build.

### Building Against a Local Version of Sync

Specify the path to realm-core and realm-sync when invoking `cmake`:

```
cmake -DREALM_ENABLE_SYNC=1 -DREALM_CORE_PREFIX=/path/to/realm-core -DREALM_SYNC_PREFIX=/path/to/realm-sync
```

Prebuilt sync binaries are currently not supported.

### Building with Sanitizers

The object store can be built using ASan, TSan and/or UBSan by specifying `-DSANITIZE_ADDRESS=1`, `-DSANITIZE_THREAD=1`, or `-DSANITIZE_UNDEFINED=1` when invoking CMake.
Building with ASan requires specifying a path to core with `-DREALM_CORE_PREFIX` as core needs to also be built with ASan enabled.

On OS X, the Xcode-provided copy of Clang only comes with ASan, and using TSan or UBSan requires a custom build of Clang.
If you have installed Clang as an external Xcode toolchain (using the `install-xcode-toolchain` when building LLVM), note that you'll have to specify `-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++` when running `cmake` to stop cmake from being too clever.

## Testing

```
make run-tests
```

### Android

It requires a root device or an emulator:

```
make
adb push tests/tests /data/local/tmp
adb shell /data/local/tmp/tests
```

## Using Docker

The `Dockerfile` included in this repo will provision a Docker image suitable
for building and running tests for both the Linux and Android platforms.

```
# Build Docker image from Dockerfile
docker build -t "objectstore" .
# Run bash interactively from the built Docker image,
# mounting the current directory
docker run --rm -it -v $(pwd):/tmp -w /tmp objectstore bash
# Build the object store for Linux and run tests
> cmake .
> make
> make run-tests
```

Refer to the rest of this document for instructions to build/test in other
configurations.

## License

Realm Object Store is published under the Apache 2.0 license. The [underlying core](https://github.com/realm/realm-core) is also published under the Apache 2.0 license.

**This product is not being made available to any person located in Cuba, Iran,
North Korea, Sudan, Syria or the Crimea region, or to any other person that is
not eligible to receive the product under U.S. law.**

![analytics](https://ga-beacon.appspot.com/UA-50247013-2/realm-object-store/README?pixel)
