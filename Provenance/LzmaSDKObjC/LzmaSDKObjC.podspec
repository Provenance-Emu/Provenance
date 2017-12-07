#
# Be sure to run `pod lib lint LzmaSDKObjC.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "LzmaSDKObjC"
  s.version          = "1.0.5"
  s.summary          = "Lzma SDK for Objective-C based on extended functionality of the C++ LZMA code"
  s.description      = <<-DESC
It's not yet another wrapper around C part of the LZMA SDK with all it's limitations.
Based on C++ LZMA SDK version 15.14 (1514 - latest for now) and patched for iOS & MacOS platforms.
The main advantages is:
- List, extract 7z files (Lzma & Lzma2 compression method).
- List, extract encrypted (password protected) 7z files (Lzma & Lzma2 compression method).
- List, extract encrypted (password protected) + encrypted header (no visible content, files list, without password) 7z files (Lzma & Lzma2 compression method).
- Manage memory allocations during listing/extracting.
- Tuned up for using less than 500Kb for listing/extracting, can be easly changed runtime (no hardcoded definitions).
- Manage IO read/write operations, aslo can be easly changed runtime (no hardcoded definitions).
- Track smoothed progress, which becomes possible with prev.
- Support reading archive files with size more than 4GB and extracting files with size more than 4GB eg. HugeFiles=on
                       DESC

  s.homepage         = "https://github.com/OlehKulykov/LzmaSDKObjC"
  s.license          = 'MIT'
  s.author           = { "OlehKulykov" => "info@resident.name" }
  s.source           = { :git => "https://github.com/OlehKulykov/LzmaSDKObjC.git", :tag => s.version.to_s }
  s.deprecated = true
  s.deprecated_in_favor_of = 'LzmaSDK-ObjC'
  
# Platforms
  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.7"

  s.requires_arc = true

  s.public_header_files = 'Pod/Classes/src/LzmaSDKObjCTypes.h',
    'Pod/Classes/src/LzmaSDKObjCReader.h',
    'Pod/Classes/src/LzmaSDKObjCItem.h',
    'Pod/Classes/src/LzmaSDKObjC.h'

  s.source_files = 'Pod/Classes/src/*.{h,cpp,mm}',
    'Pod/Classes/lzma/CPP/7zip/*.{h}',
    'Pod/Classes/lzma/CPP/7zip/Crypto/*.{h}',
    'Pod/Classes/lzma/CPP/7zip/Crypto/7zAes.cpp',
    'Pod/Classes/lzma/CPP/7zip/Crypto/7zAesRegister.cpp',
    'Pod/Classes/lzma/CPP/7zip/Crypto/MyAes.cpp',
    'Pod/Classes/lzma/CPP/7zip/Crypto/MyAesReg.cpp',
    'Pod/Classes/lzma/CPP/7zip/Crypto/RandGen.cpp',
    'Pod/Classes/lzma/CPP/7zip/Archive/7z/*.{h}',
    'Pod/Classes/lzma/CPP/7zip/Archive/7z/7zRegister.cpp',
    'Pod/Classes/lzma/CPP/7zip/Archive/7z/7zSpecStream.cpp',
    'Pod/Classes/lzma/CPP/7zip/Archive/7z/7zExtract.cpp',
    'Pod/Classes/lzma/CPP/7zip/Archive/7z/7zProperties.cpp',
    'Pod/Classes/lzma/CPP/7zip/Archive/7z/7zDecode.cpp',
    'Pod/Classes/lzma/CPP/7zip/Archive/7z/7zEncode.cpp',
    'Pod/Classes/lzma/CPP/7zip/Archive/7z/7zFolderInStream.cpp',
    'Pod/Classes/lzma/CPP/7zip/Archive/7z/7zUpdate.cpp',
    'Pod/Classes/lzma/CPP/7zip/Archive/7z/7zHeader.cpp',
    'Pod/Classes/lzma/CPP/7zip/Archive/7z/7zOut.cpp',
    'Pod/Classes/lzma/CPP/7zip/Archive/7z/7zHandlerOut.cpp',
    'Pod/Classes/lzma/CPP/7zip/Archive/7z/7zIn.cpp',
    'Pod/Classes/lzma/CPP/7zip/Archive/7z/7zHandler.cpp',
    'Pod/Classes/lzma/CPP/7zip/Archive/7z/StdAfx.cpp',
    'Pod/Classes/lzma/CPP/7zip/Archive/*.{h}',
    'Pod/Classes/lzma/CPP/7zip/Archive/XzHandler.cpp',
    'Pod/Classes/lzma/CPP/7zip/Archive/LzmaHandler.cpp',
    'Pod/Classes/lzma/CPP/7zip/Archive/ArchiveExports.cpp',
    'Pod/Classes/lzma/CPP/7zip/Archive/DllExports2.cpp',
    'Pod/Classes/lzma/CPP/7zip/Archive/Common/*.{h}',
    'Pod/Classes/lzma/CPP/7zip/Archive/Common/ItemNameUtils.cpp',
    'Pod/Classes/lzma/CPP/7zip/Archive/Common/CoderMixer2.cpp',
    'Pod/Classes/lzma/CPP/7zip/Archive/Common/DummyOutStream.cpp',
    'Pod/Classes/lzma/CPP/7zip/Archive/Common/HandlerOut.cpp',
    'Pod/Classes/lzma/CPP/7zip/Archive/Common/OutStreamWithCRC.cpp',
    'Pod/Classes/lzma/CPP/7zip/Compress/*.{h}',
    'Pod/Classes/lzma/CPP/7zip/Compress/BcjCoder.cpp',
    'Pod/Classes/lzma/CPP/7zip/Compress/BcjRegister.cpp',
    'Pod/Classes/lzma/CPP/7zip/Compress/CopyCoder.cpp',
    'Pod/Classes/lzma/CPP/7zip/Compress/CodecExports.cpp',
    'Pod/Classes/lzma/CPP/7zip/Compress/LzmaDecoder.cpp',
    'Pod/Classes/lzma/CPP/7zip/Compress/LzmaEncoder.cpp',
    'Pod/Classes/lzma/CPP/7zip/Compress/LzmaRegister.cpp',
    'Pod/Classes/lzma/CPP/7zip/Compress/Lzma2Decoder.cpp',
    'Pod/Classes/lzma/CPP/7zip/Compress/Lzma2Encoder.cpp',
    'Pod/Classes/lzma/CPP/7zip/Compress/Lzma2Register.cpp',
    'Pod/Classes/lzma/CPP/7zip/Common/*.{h}',
    'Pod/Classes/lzma/CPP/7zip/Common/LimitedStreams.cpp',
    'Pod/Classes/lzma/CPP/7zip/Common/StreamObjects.cpp',
    'Pod/Classes/lzma/CPP/7zip/Common/InOutTempBuffer.cpp',
    'Pod/Classes/lzma/CPP/7zip/Common/StreamBinder.cpp',
    'Pod/Classes/lzma/CPP/7zip/Common/VirtThread.cpp',
    'Pod/Classes/lzma/CPP/7zip/Common/OutBuffer.cpp',
    'Pod/Classes/lzma/CPP/7zip/Common/MethodProps.cpp',
    'Pod/Classes/lzma/CPP/7zip/Common/PropId.cpp',
    'Pod/Classes/lzma/CPP/7zip/Common/ProgressUtils.cpp',
    'Pod/Classes/lzma/CPP/7zip/Common/FilterCoder.cpp',
    'Pod/Classes/lzma/CPP/7zip/Common/CWrappers.cpp',
    'Pod/Classes/lzma/CPP/7zip/Common/StreamUtils.cpp',
    'Pod/Classes/lzma/CPP/7zip/Common/CreateCoder.cpp',
    'Pod/Classes/lzma/CPP/7zip/Common/FileStreams.cpp',
    'Pod/Classes/lzma/CPP/7zip/Common/LockedStream.cpp',
    'Pod/Classes/lzma/CPP/Windows/*.{h}',
    'Pod/Classes/lzma/CPP/Windows/PropVariantConv.cpp',
    'Pod/Classes/lzma/CPP/Windows/System.cpp',
    'Pod/Classes/lzma/CPP/Windows/PropVariant.cpp',
    'Pod/Classes/lzma/CPP/Windows/FileName.cpp',
    'Pod/Classes/lzma/CPP/Windows/FileFind.cpp',
    'Pod/Classes/lzma/CPP/Windows/FileDir.cpp',
    'Pod/Classes/lzma/CPP/Windows/DLL.cpp',
    'Pod/Classes/lzma/CPP/Common/*.{h}',
    'Pod/Classes/lzma/CPP/Common/Sha256Reg.cpp',
    'Pod/Classes/lzma/CPP/Common/XzCrc64Reg.cpp',
    'Pod/Classes/lzma/CPP/Common/CrcReg.cpp',
    'Pod/Classes/lzma/CPP/Common/Wildcard.cpp',
    'Pod/Classes/lzma/CPP/Common/StringToInt.cpp',
    'Pod/Classes/lzma/CPP/Common/C_FileIO.cpp',
    'Pod/Classes/lzma/CPP/Common/MyString.cpp',
    'Pod/Classes/lzma/CPP/Common/StringConvert.cpp',
    'Pod/Classes/lzma/CPP/Common/IntToString.cpp',
    'Pod/Classes/lzma/CPP/Common/MyWindows.cpp',
    'Pod/Classes/lzma/C/*.{h}',
    'Pod/Classes/lzma/C/AesOpt.c',
    'Pod/Classes/lzma/C/Aes.c',
    'Pod/Classes/lzma/C/XzCrc64Opt.c',
    'Pod/Classes/lzma/C/Sha256.c',
    'Pod/Classes/lzma/C/Delta.c',
    'Pod/Classes/lzma/C/7zCrcOpt.c',
    'Pod/Classes/lzma/C/CpuArch.c',
    'Pod/Classes/lzma/C/7zCrc.c',
    'Pod/Classes/lzma/C/XzCrc64.c',
    'Pod/Classes/lzma/C/Bra86.c',
    'Pod/Classes/lzma/C/BraIA64.c',
    'Pod/Classes/lzma/C/Bra.c',
    'Pod/Classes/lzma/C/XzEnc.c',
    'Pod/Classes/lzma/C/XzIn.c',
    'Pod/Classes/lzma/C/Xz.c',
    'Pod/Classes/lzma/C/XzDec.c',
    'Pod/Classes/lzma/C/7zStream.c',
    'Pod/Classes/lzma/C/Alloc.c',
    'Pod/Classes/lzma/C/MtCoder.c',
    'Pod/Classes/lzma/C/LzFind.c',
    'Pod/Classes/lzma/C/LzFindMt.c',
    'Pod/Classes/lzma/C/Lzma2Dec.c',
    'Pod/Classes/lzma/C/Lzma2Enc.c',
    'Pod/Classes/lzma/C/LzmaDec.c',
    'Pod/Classes/lzma/C/LzmaEnc.c',
    'Pod/Classes/lzma/C/Threads.c'

  s.compiler_flags = '-DLZMASDKOBJC=1', '-DLZMASDKOBJC_OMIT_UNUSED_CODE=1'
  s.libraries    = 'stdc++'
  # s.frameworks = 'UIKit'
  s.dependency 'Inlineobjc'
end
