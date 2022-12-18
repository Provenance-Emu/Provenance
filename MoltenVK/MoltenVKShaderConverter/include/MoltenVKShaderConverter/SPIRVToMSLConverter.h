/*
 * SPIRVToMSLConverter.h
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

#ifndef __SPIRVToMSLConverter_h_
#define __SPIRVToMSLConverter_h_ 1

#include <spirv.hpp>
#include <spirv_msl.hpp>
#include <string>
#include <vector>


namespace mvk {

#pragma mark -
#pragma mark SPIRVToMSLConversionConfiguration

	/**
	 * Options for converting SPIR-V to Metal Shading Language
	 *
	 * THIS STRUCT IS STREAMED OUT AS PART OF THE PIEPLINE CACHE.
	 * CHANGES TO THIS STRUCT SHOULD BE CAPTURED IN THE STREAMING LOGIC OF THE PIPELINE CACHE.
	 */
	typedef struct SPIRVToMSLConversionOptions {
		SPIRV_CROSS_NAMESPACE::CompilerMSL::Options mslOptions;
		std::string entryPointName;
		spv::ExecutionModel entryPointStage = spv::ExecutionModelMax;
		spv::ExecutionMode tessPatchKind = spv::ExecutionModeMax;
		uint32_t numTessControlPoints = 0;
		bool shouldFlipVertexY = true;

		/**
		 * Returns whether the specified options match this one.
		 * It does if all corresponding elements are equal.
		 */
		bool matches(const SPIRVToMSLConversionOptions& other) const;

		bool hasEntryPoint() const {
			return !entryPointName.empty() && entryPointStage != spv::ExecutionModelMax;
		}

		static std::string printMSLVersion(uint32_t mslVersion, bool includePatch = false);

		SPIRVToMSLConversionOptions();

	} SPIRVToMSLConversionOptions;

	/**
	 * Defines MSL characteristics of a vertex attribute at a particular location.
	 *
	 * The outIsUsedByShader flag is set to true during conversion of SPIR-V to MSL if the shader
	 * makes use of this vertex attribute. This allows a pipeline to be optimized, and for two
	 * shader conversion configurations to be compared only against the attributes that are
	 * actually used by the shader.
	 *
	 * THIS STRUCT IS STREAMED OUT AS PART OF THE PIPELINE CACHE.
	 * CHANGES TO THIS STRUCT SHOULD BE CAPTURED IN THE STREAMING LOGIC OF THE PIPELINE CACHE.
	 */
	typedef struct MSLShaderInput {
		SPIRV_CROSS_NAMESPACE::MSLShaderInput shaderInput;
		uint32_t binding = 0;
		bool outIsUsedByShader = false;

		/**
		 * Returns whether the specified vertex attribute match this one.
		 * It does if all corresponding elements except outIsUsedByShader are equal.
		 */
		bool matches(const MSLShaderInput& other) const;

		MSLShaderInput();

	} MSLShaderInput;

	/**
	 * Matches the binding index of a MSL resource for a binding within a descriptor set.
	 * Taken together, the stage, desc_set and binding combine to form a reference to a resource
	 * descriptor used in a particular shading stage. Generally, only one of the buffer, texture,
	 * or sampler elements will be populated. The outIsUsedByShader flag is set to true during
	 * compilation of SPIR-V to MSL if the shader makes use of this vertex attribute.
	 *
	 * If requiresConstExprSampler is true, the resource is a sampler whose content must be
	 * hardcoded into the MSL as a constexpr type, instead of passed in as a runtime-bound variable.
	 * The content of that constexpr sampler is defined in the constExprSampler parameter.
	 *
	 * The outIsUsedByShader value is set by the shader converter based on the content of the SPIR-V
	 * (and resulting MSL), and is set to true if the shader makes use of this resource binding.
	 * This allows a pipeline to be optimized, and for two shader conversion configurations to
	 * be compared only against the resource bindings that are actually used by the shader.
	 *
	 * THIS STRUCT IS STREAMED OUT AS PART OF THE PIEPLINE CACHE.
	 * CHANGES TO THIS STRUCT SHOULD BE CAPTURED IN THE STREAMING LOGIC OF THE PIPELINE CACHE.
	 */
	typedef struct MSLResourceBinding {
		SPIRV_CROSS_NAMESPACE::MSLResourceBinding resourceBinding;
		SPIRV_CROSS_NAMESPACE::MSLConstexprSampler constExprSampler;
		bool requiresConstExprSampler = false;
		bool outIsUsedByShader = false;

		/**
		 * Returns whether the specified resource binding match this one.
		 * It does if all corresponding elements except outIsUsedByShader are equal.
		 */
		bool matches(const MSLResourceBinding& other) const;

		MSLResourceBinding();

	} MSLResourceBinding;

	/**
	 * Identifies a descriptor binding, and the index into a buffer that
	 * can be used for providing dynamic content like dynamic buffer offsets.
	 *
	 * THIS STRUCT IS STREAMED OUT AS PART OF THE PIPELINE CACHE.
	 * CHANGES TO THIS STRUCT SHOULD BE CAPTURED IN THE STREAMING LOGIC OF THE PIPELINE CACHE.
	 */
	typedef struct DescriptorBinding {
		spv::ExecutionModel stage = spv::ExecutionModelMax;
		uint32_t descriptorSet = 0;
		uint32_t binding = 0;
		uint32_t index = 0;

		bool matches(const DescriptorBinding& other) const;

	} DescriptorBinding;

	/**
	 * Configuration passed to the SPIRVToMSLConverter.
	 *
	 * THIS STRUCT IS STREAMED OUT AS PART OF THE PIEPLINE CACHE.
	 * CHANGES TO THIS STRUCT SHOULD BE CAPTURED IN THE STREAMING LOGIC OF THE PIPELINE CACHE.
	 */
	typedef struct SPIRVToMSLConversionConfiguration {
		SPIRVToMSLConversionOptions options;
		std::vector<MSLShaderInput> shaderInputs;
		std::vector<MSLResourceBinding> resourceBindings;
		std::vector<uint32_t> discreteDescriptorSets;
		std::vector<DescriptorBinding> dynamicBufferDescriptors;

		/** Returns whether the pipeline stage being converted supports vertex attributes. */
		bool stageSupportsVertexAttributes() const;

        /** Returns whether the shader input variable at the specified location is used by the shader. */
        bool isShaderInputLocationUsed(uint32_t location) const;

		/** Returns the number of shader input variables bound to the specified Vulkan buffer binding, and used by the shader. */
		uint32_t countShaderInputsAt(uint32_t binding) const;

        /** Returns whether the vertex buffer at the specified Vulkan binding is used by the shader. */
		bool isVertexBufferUsed(uint32_t binding) const { return countShaderInputsAt(binding) > 0; }

		/** Returns whether the resource at the specified descriptor set binding is used by the shader. */
		bool isResourceUsed(spv::ExecutionModel stage, uint32_t descSet, uint32_t binding) const;

		/** Marks all input variables and resources as being used by the shader. */
		void markAllInputsAndResourcesUsed();

        /**
         * Returns whether this configuration matches the other configuration. It does if
		 * the respective options match and any vertex attributes and resource bindings used
		 * by this configuration can be found in the other configuration. Vertex attributes
		 * and resource bindings that are in the other configuration but are not used by
		 * the shader that created this configuration, are ignored.
         */
        bool matches(const SPIRVToMSLConversionConfiguration& other) const;

        /** Aligns certain aspects of this configuration with the source configuration. */
        void alignWith(const SPIRVToMSLConversionConfiguration& srcContext);

	} SPIRVToMSLConversionConfiguration;


#pragma mark -
#pragma mark SPIRVToMSLConversionResults

    /**
     * Describes one dimension of the workgroup size of a SPIR-V entry point, including whether
	 * it is specialized, and if so, the value of the corresponding specialization ID, which
	 * is used to map to a value which will be provided when the MSL is compiled into a pipeline.
	 *
	 * THIS STRUCT IS STREAMED OUT AS PART OF THE PIEPLINE CACHE.
	 * CHANGES TO THIS STRUCT SHOULD BE CAPTURED IN THE STREAMING LOGIC OF THE PIPELINE CACHE.
     */
	typedef struct SPIRVWorkgroupSizeDimension {
		uint32_t size = 1;
		uint32_t specializationID = 0;
		bool isSpecialized = false;
	} SPIRVWorkgroupSizeDimension;

	/**
     * Describes a SPIRV entry point, including the Metal function name (which may be
     * different than the Vulkan entry point name if the original name was illegal in Metal),
     * and the size of each workgroup, if the shader is a compute shader.
	 *
	 * THIS STRUCT IS STREAMED OUT AS PART OF THE PIEPLINE CACHE.
	 * CHANGES TO THIS STRUCT SHOULD BE CAPTURED IN THE STREAMING LOGIC OF THE PIPELINE CACHE.
     */
	typedef struct SPIRVEntryPoint {
		std::string mtlFunctionName = "main0";
		struct {
			SPIRVWorkgroupSizeDimension width;
			SPIRVWorkgroupSizeDimension height;
			SPIRVWorkgroupSizeDimension depth;
		} workgroupSize;
		bool supportsFastMath = true;
	} SPIRVEntryPoint;

	/**
	 * Contains the results of the shader conversion that can be used to populate a pipeline.
	 *
	 * THIS STRUCT IS STREAMED OUT AS PART OF THE PIEPLINE CACHE.
	 * CHANGES TO THIS STRUCT SHOULD BE CAPTURED IN THE STREAMING LOGIC OF THE PIPELINE CACHE.
	 */
	typedef struct SPIRVToMSLConversionResults {
		SPIRVEntryPoint entryPoint;
		bool isRasterizationDisabled = false;
		bool isPositionInvariant = false;
		bool needsSwizzleBuffer = false;
		bool needsOutputBuffer = false;
		bool needsPatchOutputBuffer = false;
		bool needsBufferSizeBuffer = false;
		bool needsDynamicOffsetBuffer = false;
		bool needsInputThreadgroupMem = false;
		bool needsDispatchBaseBuffer = false;
		bool needsViewRangeBuffer = false;

		void reset() { *this = SPIRVToMSLConversionResults(); }

	} SPIRVToMSLConversionResults;


#pragma mark -
#pragma mark SPIRVToMSLConverter

	/** Converts SPIR-V code to Metal Shading Language code. */
	class SPIRVToMSLConverter {

	public:

		/** Sets the SPIRV code. */
		void setSPIRV(const std::vector<uint32_t>& spirv) { _spirv = spirv; }

		/**
		 * Sets the SPIRV code from the specified array of values.
		 * The length parameter indicates the number of uint values to store.
		 */
		void setSPIRV(const uint32_t* spirvCode, size_t length);

		/** Returns a reference to the SPIRV code, set by one of the setSPIRV() functions. */
		const std::vector<uint32_t>& getSPIRV() { return _spirv; }

		/** Returns whether the SPIR-V code has been set. */
		bool hasSPIRV() { return !_spirv.empty(); }

		/**
		 * Converts SPIR-V code, set using setSPIRV() to MSL code, which can be retrieved using getMSL().
		 *
		 * The boolean flags indicate whether the original SPIR-V code, the resulting MSL code, 
         * and optionally, the original GLSL (as converted from the SPIR_V), should be logged 
         * to the result log of this converter. This can be useful during shader debugging.
		 */
		bool convert(SPIRVToMSLConversionConfiguration& shaderConfig,
                     bool shouldLogSPIRV = false,
                     bool shouldLogMSL = false,
                     bool shouldLogGLSL = false);

		/**
		 * Returns whether the most recent conversion was successful.
		 *
		 * The initial value of this property is NO. It is set to YES upon successful conversion.
		 */
		bool wasConverted() { return _wasConverted; }

		/**
		 * Returns the Metal Shading Language source code most recently converted
         * by the convert() function, or set directly using the setMSL() function.
		 */
		const std::string& getMSL() { return _msl; }

		/** Returns information about the shader conversion. */
		const SPIRVToMSLConversionResults& getConversionResults() { return _shaderConversionResults; }

        /** Sets the number of threads in a single compute kernel workgroup, per dimension. */
        void setWorkgroupSize(uint32_t x, uint32_t y, uint32_t z) {
			auto& wgSize = _shaderConversionResults.entryPoint.workgroupSize;
            wgSize.width.size = x;
            wgSize.height.size = y;
            wgSize.depth.size = z;
        }
        
		/**
		 * Returns a human-readable log of the most recent conversion activity.
		 * This may be empty if the conversion was successful.
		 */
		const std::string& getResultLog() { return _resultLog; }

        /** Sets MSL source code. This can be used when MSL is supplied directly. */
		void setMSL(const std::string& msl, const SPIRVToMSLConversionResults* pShaderConversionResults) {
			_msl = msl;
			if (pShaderConversionResults) { _shaderConversionResults = *pShaderConversionResults; }
		}

	protected:
		void logMsg(const char* logMsg);
		bool logError(const char* errMsg);
		void logSPIRV(const char* opDesc);
		bool validateSPIRV();
		void writeSPIRVToFile(std::string spvFilepath);
        void logSource(std::string& src, const char* srcLang, const char* opDesc);
		void populateWorkgroupDimension(SPIRVWorkgroupSizeDimension& wgDim, uint32_t size, SPIRV_CROSS_NAMESPACE::SpecializationConstant& spvSpecConst);
		void populateEntryPoint(SPIRV_CROSS_NAMESPACE::Compiler* pCompiler, SPIRVToMSLConversionOptions& options);

		std::vector<uint32_t> _spirv;
		std::string _msl;
		std::string _resultLog;
		SPIRVToMSLConversionResults _shaderConversionResults;
		bool _wasConverted = false;
	};

}
#endif
