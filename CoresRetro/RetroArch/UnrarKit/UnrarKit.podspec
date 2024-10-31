Pod::Spec.new do |s|
  s.name             = "UnrarKit"
  s.version          = ENV["TRAVIS_TAG"]
  s.summary          = "UnrarKit is here to enable Mac and iOS Cocoa apps to easily work with RAR files for read-only operations"
  s.license          = "BSD"
  s.homepage         = "https://github.com/abbeycode/UnrarKit"
  s.author           = { "Dov Frankel" => "dov@abbey-code.com" }
  # Removed to silence validation warnings until issue is resolved: https://github.com/CocoaPods/CocoaPods/issues/10291
#   s.social_media_url = "https://twitter.com/dovfrankel"
  s.source           = { :git => "https://github.com/abbeycode/UnrarKit.git", :tag => "#{s.version}" }
  s.ios.deployment_target = "12.0"
  s.osx.deployment_target = "10.13"
  s.requires_arc = "Classes/**/*"
  s.source_files = "Classes/**/*.{mm,m,h}"
  s.public_header_files = "Classes/*.h"
  s.resource_bundles = {
      'UnrarKitResources' => ['Resources/**/*']
  }
  s.library = "z"
  
  s.test_spec 'Tests' do |test_spec|
    test_spec.requires_arc = "Tests/**/*"
    test_spec.source_files = "Tests/*.{h,m}"
    test_spec.resources = ["Tests/Test Data"]
  end

  s.subspec "unrar-lib" do |ss|
    ss.public_header_files = "Libraries/unrar/raros.hpp",
                             "Libraries/unrar/dll.hpp"
    ss.source_files = "Libraries/unrar/*.hpp",
                      "Libraries/unrar/rar.cpp",
                      "Libraries/unrar/strlist.cpp",
                      "Libraries/unrar/strfn.cpp",
                      "Libraries/unrar/pathfn.cpp",
                      "Libraries/unrar/smallfn.cpp",
                      "Libraries/unrar/global.cpp",
                      "Libraries/unrar/file.cpp",
                      "Libraries/unrar/filefn.cpp",
                      "Libraries/unrar/filcreat.cpp",
                      "Libraries/unrar/archive.cpp",
                      "Libraries/unrar/arcread.cpp",
                      "Libraries/unrar/unicode.cpp",
                      "Libraries/unrar/system.cpp",
                      "Libraries/unrar/crypt.cpp",
                      "Libraries/unrar/crc.cpp",
                      "Libraries/unrar/rawread.cpp",
                      "Libraries/unrar/encname.cpp",
                      "Libraries/unrar/resource.cpp",
                      "Libraries/unrar/match.cpp",
                      "Libraries/unrar/timefn.cpp",
                      "Libraries/unrar/rdwrfn.cpp",
                      "Libraries/unrar/consio.cpp",
                      "Libraries/unrar/options.cpp",
                      "Libraries/unrar/errhnd.cpp",
                      "Libraries/unrar/rarvm.cpp",
                      "Libraries/unrar/secpassword.cpp",
                      "Libraries/unrar/rijndael.cpp",
                      "Libraries/unrar/getbits.cpp",
                      "Libraries/unrar/sha1.cpp",
                      "Libraries/unrar/sha256.cpp",
                      "Libraries/unrar/blake2s.cpp",
                      "Libraries/unrar/hash.cpp",
                      "Libraries/unrar/extinfo.cpp",
                      "Libraries/unrar/extract.cpp",
                      "Libraries/unrar/volume.cpp",
                      "Libraries/unrar/list.cpp",
                      "Libraries/unrar/find.cpp",
                      "Libraries/unrar/unpack.cpp",
                      "Libraries/unrar/headers.cpp",
                      "Libraries/unrar/threadpool.cpp",
                      "Libraries/unrar/rs16.cpp",
                      "Libraries/unrar/cmddata.cpp",
                      "Libraries/unrar/ui.cpp",
                      "Libraries/unrar/filestr.cpp",
                      "Libraries/unrar/recvol.cpp",
                      "Libraries/unrar/rs.cpp",
                      "Libraries/unrar/scantree.cpp",
                      "Libraries/unrar/qopen.cpp",
                      "Libraries/unrar/dll.cpp"
                      # These files are built implicitly as dependencies
    ss.preserve_paths = "Libraries/unrar/arccmt.cpp",
                        "Libraries/unrar/blake2sp.cpp",
                        "Libraries/unrar/cmdfilter.cpp",
                        "Libraries/unrar/cmdmix.cpp",
                        "Libraries/unrar/coder.cpp",
                        "Libraries/unrar/crypt1.cpp",
                        "Libraries/unrar/crypt2.cpp",
                        "Libraries/unrar/crypt3.cpp",
                        "Libraries/unrar/crypt5.cpp",
                        "Libraries/unrar/hardlinks.cpp",
                        "Libraries/unrar/log.cpp",
                        "Libraries/unrar/model.cpp",
                        "Libraries/unrar/rarvmtbl.cpp",
                        "Libraries/unrar/recvol3.cpp",
                        "Libraries/unrar/recvol5.cpp",
                        "Libraries/unrar/suballoc.cpp",
                        "Libraries/unrar/uicommon.cpp",
                        "Libraries/unrar/uisilent.cpp",
                        "Libraries/unrar/ulinks.cpp",
                        "Libraries/unrar/unpack15.cpp",
                        "Libraries/unrar/unpack20.cpp",
                        "Libraries/unrar/unpack30.cpp",
                        "Libraries/unrar/unpack50.cpp",
                        "Libraries/unrar/unpack50frag.cpp",
                        "Libraries/unrar/unpackinline.cpp",
                        "Libraries/unrar/uowners.cpp",
                        "Libraries/unrar/win32stm.cpp"
    ss.pod_target_xcconfig = { "OTHER_LDFLAGS" => "$(inherited) -lc++",
                               "OTHER_CFLAGS" => "$(inherited) -Wno-return-type -Wno-logical-op-parentheses -Wno-conversion -Wno-parentheses -Wno-unused-function -Wno-unused-variable -Wno-switch -Wno-unused-command-line-argument -Wno-strict-prototypes -Wno-conditional-uninitialized",
                               "OTHER_CPLUSPLUSFLAGS" => "$(inherited) -DSILENT -DRARDLL $(OTHER_CFLAGS)" }
    ss.compiler_flags = "-Xanalyzer -analyzer-disable-all-checks"
  end
end
