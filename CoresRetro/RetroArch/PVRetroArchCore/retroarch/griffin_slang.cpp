#include "./localintermediate.h" // Fixes slang shader
#include "../griffin/griffin_glslang.cpp"

/* Need these to fix a linker issue with missing symbols
 "glslang::HlslScanContext::deleteKeywordMap()", referenced from:
     _ShFinalize in libretroarch.a[4](griffin_slang.o)
 "glslang::HlslScanContext::fillInKeywordMap()", referenced from:
     _ShInitialize in libretroarch.a[4](griffin_slang.o)
 "glslang::HlslParseContext::HlslParseContext(glslang::TSymbolTable&, glslang::TIntermediate&, bool, int, EProfile, glslang::SpvVersion const&, EShLanguage, TInfoSink&, std::__1::basic_string<char, std::__1::char_traits<char>, glslang::pool_allocator<char>>, bool, EShMessages)", referenced from:
     (anonymous namespace)::CreateParseContext(glslang::TSymbolTable&, glslang::TIntermediate&, int, EProfile, glslang::EShSource, EShLanguage, TInfoSink&, glslang::SpvVersion, bool, EShMessages, bool, std::__1::basic_string<char, std::__1::char_traits<char>, std::__1::allocator<char>>) in libretroarch.a[4](griffin_slang.o)
 "glslang::TBuiltInParseablesHlsl::TBuiltInParseablesHlsl()", referenced from:
     (anonymous namespace)::CreateBuiltInParseables(TInfoSink&, glslang::EShSource) in libretroarch.a[4](griffin_slang.o)

TBuiltInParseablesHlsl::TBuiltInParseablesHlsl is in hlslParseables.cpp
used in ShaderLang.cpp if ‘#ifdef ENABLE_HLSL’
ShaderLang.cpp included in griffin_slang.cpp if WANT_GLSLANG which we set
 */
#if defined(ENABLE_HLSL)
#include "../deps/glslang/glslang/hlsl/hlslAttributes.cpp"
#include "../deps/glslang/glslang/hlsl/hlslGrammar.cpp"
#include "../deps/glslang/glslang/hlsl/hlslOpMap.cpp"
#include "../deps/glslang/glslang/hlsl/hlslParseables.cpp"
#include "../deps/glslang/glslang/hlsl/hlslParseHelper.cpp"
#include "../deps/glslang/glslang/hlsl/hlslScanContext.cpp"
#include "../deps/glslang/glslang/hlsl/hlslTokenStream.cpp"
#endif
