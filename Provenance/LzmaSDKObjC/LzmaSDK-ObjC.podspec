#
# Be sure to run `pod lib lint LzmaSDK-ObjC.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "LzmaSDK-ObjC"
  s.version          = "2.0.13"
  s.summary          = "Lzma SDK for Objective-C based on extended functionality of the C++ LZMA code"
  s.description      = <<-DESC
It's not yet another wrapper around C part of the LZMA SDK with all it's limitations.
Based on C++ LZMA SDK version 16.04 (1604 - latest for now) and patched for iOS & MacOS platforms.
Can be used with Swift and Objective-C.
The main advantages is:
- List, extract 7z files (Lzma & Lzma2 compression method).
- List, extract encrypted (password protected) 7z files (Lzma & Lzma2 compression method).
- List, extract encrypted (password protected) + encrypted header (no visible content, files list, without password) 7z files (Lzma & Lzma2 compression method).
- Create 7z archives (Lzma & Lzma2 compression method).
- Create encrypted (password protected) 7z archives (Lzma & Lzma2 compression method).
- Create encrypted (password protected) + encrypted header (no visible content, files list, without password) 7z archives (Lzma & Lzma2 compression method).
- Manage memory allocations during listing/extracting.
- Tuned up for using less than 500Kb for listing/extracting, can be easly changed runtime (no hardcoded definitions).
- Manage IO read/write operations, aslo can be easly changed runtime (no hardcoded definitions).
- Track smoothed progress, which becomes possible with prev.
- Support reading and extracting archive files with size more than 4GB. HugeFiles=on
- UTF8 support.
- Extra compression/decompression functionality of single NSData object with Lzma2.
                       DESC

  s.homepage         = "https://github.com/OlehKulykov/LzmaSDKObjC"
  s.license          = 'MIT'
  s.author           = { "OlehKulykov" => "info@resident.name" }
  s.source           = { :git => "https://github.com/OlehKulykov/LzmaSDKObjC.git", :tag => s.version.to_s }

# Platforms
  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.7"

  s.requires_arc = true

  s.public_header_files = 'src/LzmaSDKObjCTypes.h',
    'src/LzmaSDKObjCExtern.h',
    'src/LzmaSDKObjCReader.h',
    'src/LzmaSDKObjCWriter.h',
    'src/LzmaSDKObjCItem.h',
    'src/LzmaSDKObjCMutableItem.h',
    'src/LzmaSDKObjCBufferProcessor.h',
    'src/LzmaSDKObjC.h'

  s.source_files = 'src/*.{h,cpp,mm}',
    'lzma/C/*.{h}',
    'lzma/C/7zCrc.c',
    'lzma/C/7zCrcOpt.c',
    'lzma/C/7zStream.c',
    'lzma/C/Aes.c',
    'lzma/C/AesOpt.c',
    'lzma/C/Alloc.c',
    'lzma/C/Bcj2.c',
    'lzma/C/Bcj2Enc.c',
    'lzma/C/Bra.c',
    'lzma/C/Bra86.c',
    'lzma/C/BraIA64.c',
    'lzma/C/CpuArch.c',
    'lzma/C/Delta.c',
    'lzma/C/LzFind.c',
    'lzma/C/LzFindMt.c',
    'lzma/C/Lzma2Dec.c',
    'lzma/C/Lzma2Enc.c',
    'lzma/C/LzmaDec.c',
    'lzma/C/LzmaEnc.c',
    'lzma/C/MtCoder.c',
    'lzma/C/Ppmd7.c',
    'lzma/C/Ppmd7Dec.c',
    'lzma/C/Ppmd7Enc.c',
    'lzma/C/Sha256.c',
    'lzma/C/Threads.c',
    'lzma/C/Xz.c',
    'lzma/C/XzCrc64.c',
    'lzma/C/XzCrc64Opt.c',
    'lzma/C/XzDec.c',
    'lzma/C/XzEnc.c',
    'lzma/C/XzIn.c',
    'lzma/CPP/7zip/*.{h}',
    'lzma/CPP/7zip/Archive/*.{h}',
    'lzma/CPP/7zip/Archive/7z/*.{h}',
    'lzma/CPP/7zip/Archive/7z/7zDecode.cpp',
    'lzma/CPP/7zip/Archive/7z/7zEncode.cpp',
    'lzma/CPP/7zip/Archive/7z/7zExtract.cpp',
    'lzma/CPP/7zip/Archive/7z/7zFolderInStream.cpp',
    'lzma/CPP/7zip/Archive/7z/7zHandler.cpp',
    'lzma/CPP/7zip/Archive/7z/7zHandlerOut.cpp',
    'lzma/CPP/7zip/Archive/7z/7zHeader.cpp',
    'lzma/CPP/7zip/Archive/7z/7zIn.cpp',
    'lzma/CPP/7zip/Archive/7z/7zOut.cpp',
    'lzma/CPP/7zip/Archive/7z/7zProperties.cpp',
    'lzma/CPP/7zip/Archive/7z/7zRegister.cpp',
    'lzma/CPP/7zip/Archive/7z/7zSpecStream.cpp',
    'lzma/CPP/7zip/Archive/7z/7zUpdate.cpp',
    'lzma/CPP/7zip/Archive/ArchiveExports.cpp',
    'lzma/CPP/7zip/Archive/Common/*.{h}',
    'lzma/CPP/7zip/Archive/Common/CoderMixer2.cpp',
    'lzma/CPP/7zip/Archive/Common/DummyOutStream.cpp',
    'lzma/CPP/7zip/Archive/Common/HandlerOut.cpp',
    'lzma/CPP/7zip/Archive/Common/ItemNameUtils.cpp',
    'lzma/CPP/7zip/Archive/Common/OutStreamWithCRC.cpp',
    'lzma/CPP/7zip/Archive/DllExports2.cpp',
    'lzma/CPP/7zip/Archive/LzmaHandler.cpp',
    'lzma/CPP/7zip/Common/*.{h}',
    'lzma/CPP/7zip/Common/CreateCoder.cpp',
    'lzma/CPP/7zip/Common/CWrappers.cpp',
    'lzma/CPP/7zip/Common/FileStreams.cpp',
    'lzma/CPP/7zip/Common/FilterCoder.cpp',
    'lzma/CPP/7zip/Common/InOutTempBuffer.cpp',
    'lzma/CPP/7zip/Common/LimitedStreams.cpp',
    'lzma/CPP/7zip/Common/LockedStream.cpp',
    'lzma/CPP/7zip/Common/MethodProps.cpp',
    'lzma/CPP/7zip/Common/OutBuffer.cpp',
    'lzma/CPP/7zip/Common/ProgressUtils.cpp',
    'lzma/CPP/7zip/Common/PropId.cpp',
    'lzma/CPP/7zip/Common/StreamBinder.cpp',
    'lzma/CPP/7zip/Common/StreamObjects.cpp',
    'lzma/CPP/7zip/Common/StreamUtils.cpp',
    'lzma/CPP/7zip/Common/VirtThread.cpp',
    'lzma/CPP/7zip/Compress/*.{h}',
    'lzma/CPP/7zip/Compress/Bcj2Coder.cpp',
    'lzma/CPP/7zip/Compress/Bcj2Register.cpp',
    'lzma/CPP/7zip/Compress/BcjCoder.cpp',
    'lzma/CPP/7zip/Compress/BcjRegister.cpp',
    'lzma/CPP/7zip/Compress/BranchMisc.cpp',
    'lzma/CPP/7zip/Compress/BranchRegister.cpp',
    'lzma/CPP/7zip/Compress/ByteSwap.cpp',
    'lzma/CPP/7zip/Compress/CodecExports.cpp',
    'lzma/CPP/7zip/Compress/CopyCoder.cpp',
    'lzma/CPP/7zip/Compress/CopyRegister.cpp',
    'lzma/CPP/7zip/Compress/Lzma2Decoder.cpp',
    'lzma/CPP/7zip/Compress/Lzma2Encoder.cpp',
    'lzma/CPP/7zip/Compress/Lzma2Register.cpp',
    'lzma/CPP/7zip/Compress/LzmaDecoder.cpp',
    'lzma/CPP/7zip/Compress/LzmaEncoder.cpp',
    'lzma/CPP/7zip/Compress/LzmaRegister.cpp',
    'lzma/CPP/7zip/Compress/PpmdDecoder.cpp',
    'lzma/CPP/7zip/Compress/PpmdEncoder.cpp',
    'lzma/CPP/7zip/Compress/PpmdRegister.cpp',
    'lzma/CPP/7zip/Crypto/*.{h}',
    'lzma/CPP/7zip/Crypto/7zAes.cpp',
    'lzma/CPP/7zip/Crypto/7zAesRegister.cpp',
    'lzma/CPP/7zip/Crypto/MyAes.cpp',
    'lzma/CPP/7zip/Crypto/MyAesReg.cpp',
    'lzma/CPP/7zip/Crypto/RandGen.cpp',
    'lzma/CPP/Common/*.{h}',
    'lzma/CPP/Common/C_FileIO.cpp',
    'lzma/CPP/Common/CrcReg.cpp',
    'lzma/CPP/Common/IntToString.cpp',
    'lzma/CPP/Common/MyString.cpp',
    'lzma/CPP/Common/MyWindows.cpp',
    'lzma/CPP/Common/Sha256Reg.cpp',
    'lzma/CPP/Common/StringConvert.cpp',
    'lzma/CPP/Common/StringToInt.cpp',
    'lzma/CPP/Common/Wildcard.cpp',
    'lzma/CPP/Common/XzCrc64Reg.cpp',
    'lzma/CPP/Windows/*.{h}',
    'lzma/CPP/Windows/PropVariant.cpp',
    'lzma/CPP/Windows/PropVariantConv.cpp'

  s.compiler_flags = '-DLZMASDKOBJC=1', '-DLZMASDKOBJC_OMIT_UNUSED_CODE=1'
  s.libraries    = 'stdc++'
  # s.frameworks = 'UIKit'
  s.dependency 'Inlineobjc'
end
