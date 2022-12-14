/*
 * SPIRVConversion.h
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

#ifndef __SPIRVConversion_h_
#define __SPIRVConversion_h_ 1

#ifdef __cplusplus
extern "C" {
#endif	//  __cplusplus


#include <stdlib.h>

	
/** This file contains convenience functions for converting SPIR-V to MSL, callable from standard C code. */


/**
 * Convenience function that converts the specified SPIR-V code to Metal Shading Language (MSL),
 * source code, and returns whether the conversion was successful.
 *
 * If the pMSL parameter is not NULL, this function allocates space for the converted 
 * MSL source code, and returns a pointer to that MSL code in the location indicated 
 * by this parameter. It is the responsibility of the caller to free() the memory returned 
 * in this parameter.
 *
 * If the pResultLog parameter is not NULL, a pointer to the contents of the converter
 * results log will be set at the location pointed to by the pResultLog parameter.
 * It is the responsibility of the caller to free() the memory returned in this parameter.
 *
 * The boolean flags indicate whether the original SPIR-V code and resulting MSL source code
 * should be logged to the converter results log. This can be useful during shader debugging.
 */
bool mvkConvertSPIRVToMSL(uint32_t* spvCode,
                          size_t spvLength,
                          char** pMSL,
                          char** pResultLog,
                          bool shouldLogSPIRV,
                          bool shouldLogMSL);

/**
 * Convenience function that converts SPIR-V code in the specified file to 
 * Metal Shading Language (MSL) source code. The file path should either be 
 * absolute or relative to the resource directory.
 *
 * If the pMSL parameter is not NULL, this function allocates space for the converted
 * MSL source code, and returns a pointer to that MSL code in the location indicated
 * by this parameter. It is the responsibility of the caller to free() the memory returned
 * in this parameter.
 *
 * If the pResultLog parameter is not NULL, a pointer to the contents of the converter
 * results log will be set at the location pointed to by the pResultLog parameter.
 * It is the responsibility of the caller to free() the memory returned in this parameter.
 *
 * The boolean flags indicate whether the original SPIR-V code and resulting MSL source code
 * should be logged to the converter results log. This can be useful during shader debugging.
 */
bool mvkConvertSPIRVFileToMSL(const char* spvFilepath,
                              char** pMSL,
                              char** pResultLog,
                              bool shouldLogSPIRV,
                              bool shouldLogMSL);


#ifdef __cplusplus
}
#endif	//  __cplusplus

#endif
