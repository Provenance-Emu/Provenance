/*
 * GLSLConversion.h
 *
 * Copyright (c) 2015-2022 The Brenwill Workshop Ltd. (http://www.brenwill.com)
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *     http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef __GLSLConversion_h_
#define __GLSLConversion_h_ 1

#ifdef __cplusplus
extern "C" {
#endif	//  __cplusplus


#include <stdlib.h>

	
/** This file contains convenience functions for converting GLSL to SPIR-V, callable from standard C code. */


/** Enumeration of the pipeline stages for which a shader can be compiled. */
typedef enum {
	kMVKGLSLConversionShaderStageAuto,
	kMVKGLSLConversionShaderStageVertex,
	kMVKGLSLConversionShaderStageTessControl,
	kMVKGLSLConversionShaderStageTessEval,
	kMVKGLSLConversionShaderStageGeometry,
	kMVKGLSLConversionShaderStageFragment,
	kMVKGLSLConversionShaderStageCompute,
} MVKGLSLConversionShaderStage;


/**
 * Convenience function that converts the specified GLSL code to SPIR-V code,
 * and returns whether the conversion was successful.
 *
 * If the pSPIRVCode parameter is not NULL, this function allocates space for the
 * converted SPIR-V code, and returns a pointer to that SPIR-V code in the location
 * indicated by this parameter. It is the responsibility of the caller to free() 
 * the memory returned in this parameter.
 *
 * If the pSPIRVLength parameter is not NULL, the length of the SPIR-V code (as 
 * returned in the pSPIRVCode parameter) is returned in the value pointed to by 
 * the pSPIRVLength parameter.
 *
 * If the pResultLog parameter is not NULL, a pointer to the contents of the converter
 * results log will be set at the location pointed to by the pResultLog parameter.
 * It is the responsibility of the caller to free() the memory returned in this parameter.
 *
 * The boolean flags indicate whether the original GLSL code and resulting SPIR-V code
 * should be logged to the converter results log. This can be useful during shader debugging.
 */
bool mvkConvertGLSLToSPIRV(const char* glslSource,
                           MVKGLSLConversionShaderStage shaderStage,
                           uint32_t** pSPIRVCode,
                           size_t *pSPIRVLength,
                           char** pResultLog,
                           bool shouldLogGLSL,
                           bool shouldLogSPIRV);
/**
 * Convenience function that converts GLSL code in the specified file to SPIR-V code.
 * The file path should either be absolute or relative to the resource directory.
 *
 * If the pSPIRVCode parameter is not NULL, this function allocates space for the
 * converted SPIR-V code, and returns a pointer to that SPIR-V code in the location
 * indicated by this parameter. It is the responsibility of the caller to free()
 * the memory returned in this parameter.
 *
 * If the pSPIRVLength parameter is not NULL, the length of the SPIR-V code (as
 * returned in the pSPIRVCode parameter) is returned in the value pointed to by
 * the pSPIRVLength parameter.
 *
 * If the pResultLog parameter is not NULL, a pointer to the contents of the converter
 * results log will be set at the location pointed to by the pResultLog parameter.
 * It is the responsibility of the caller to free() the memory returned in this parameter.
 *
 * The boolean flags indicate whether the original GLSL code and resulting SPIR-V code
 * should be logged to the converter results log. This can be useful during shader debugging.
 */
bool mvkConvertGLSLFileToSPIRV(const char* glslFilepath,
                               MVKGLSLConversionShaderStage shaderStage,
                               uint32_t** pSPIRVCode,
                               size_t *pSPIRVLength,
                               char** pResultLog,
                               bool shouldLogGLSL,
                               bool shouldLogSPIRV);


#ifdef __cplusplus
}
#endif	//  __cplusplus

#endif
