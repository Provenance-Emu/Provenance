# New ZipArchive release

The following steps should be taken by project maintainers when they create a new release.

1. Create a new release and tag for the release.

    - Tags should be in the form of Major.Minor.Revision 
    
     *(Xcode SPM tools do not pick up vMajor.Minor.Revision used in older releases. After 2.4.2 please do not include the v in the tag name)*

    - Release names should be  more human readable: Version Major.Minor.Revision

2. Update the podspec and test it

    - *pod lib lint SSZipArchive.podspec*

3. Push the pod to the trunk

    - *pod trunk push SSZipArchive.podspec*


Note: We are no longer releasing a Carthage release as of 2.2.3. Developers are encouraged to build one themselves.


# Minizip-ng (formally minizip) update

The following steps should be taken by project maintainers when they update minizip files.

1. Source is at https://github.com/zlib-ng/minizip-ng.
2. Have cmake:
`brew install cmake`
3. Run cmake on minizip repo with our desired configuration:
`cmake . -DMZ_BZIP2=OFF -DMZ_LZMA=OFF -DMZ_ZLIB=ON -DMZ_LIBCOMP=OFF`
4. Look at the file `./CMakeFiles/minizip.dir/DependInfo.cmake` it will give you the following information:
- The list of C files that we need to include.

5. Look at the file `./CMakeFiles/minizip.dir/flags.make` it will give you the following information:

- The list of compiler flags that we need to include (as of minizip 3.0.5 we have to include either zlib-ng OR ZLIB_COMPAT)

Note: These should not be changed unless you have issues compiling or we bump the min os versions. 

HAVE_INTTYPES_H HAVE_PKCRYPT HAVE_STDINT_H HAVE_WZAES HAVE_ZLIB ZLIB_COMPAT

With the exception of the last two: "MZ_ZIP_SIGNING" "_POSIX_C_SOURCE=200112L"


6. Set those flags in SSZipArchive.podspec (for CocoaPods) and in ZipArchive.xcodeproj (for Carthage)

7. Replace the .h and .c files with the latest ones, except for `mz_compat.h`, which is customized to expose some struct in SSZipCommon.h and to provide support for optional aes.

Note: we can also use `cmake -G Xcode . -DMZ_BZIP2=OFF -DMZ_LZMA=OFF -DMZ_ZLIB=ON -DMZ_LIBCOMP=OFF` to get the list of files to include in an xcodeproj of its own, from where we can remove unneeded `zip.h` and `unzip.h`.
