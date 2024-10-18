/**
FXAA implementation for glslify in WebGL, adopted for GLideN64

--

From:
https://github.com/mattdesl/glsl-fxaa
*/
/**
Basic FXAA implementation based on the code on geeks3d.com with the
modification that the texture2DLod stuff was removed since it's
unsupported by WebGL.

--

From:
https://github.com/mitsuhiko/webgl-meincraft

Copyright (c) 2011 by Armin Ronacher.

Some rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

* Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above
copyright notice, this list of conditions and the following
disclaimer in the documentation and/or other materials provided
with the distribution.

* The names of the contributors may not be used to endorse or
promote products derived from this software without specific
prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#include "glsl_FXAA.h"

using namespace glsl;

FXAAVertexShader::FXAAVertexShader(const opengl::GLInfo & _glinfo)
{
	m_part =
		"precision mediump float;                                 \n"
		"                                                         \n"
		"//texcoords computed in vertex step                      \n"
		"//to avoid dependent texture reads                       \n"
		"OUT vec2 v_rgbNW;                                        \n"
		"OUT vec2 v_rgbNE;                                        \n"
		"OUT vec2 v_rgbSW;                                        \n"
		"OUT vec2 v_rgbSE;                                        \n"
		"OUT vec2 v_rgbM;                                         \n"
		"                                                         \n"
		"uniform vec2 uTextureSize;                               \n"
		"IN highp vec4 aRectPosition;                             \n"
		"                                                         \n"
		"void main(void) {                                        \n"
		"  gl_Position = aRectPosition;                           \n"
		"                                                         \n"
		"  //compute the texture coords and send them to varyings \n"
		"  vec2 vUv = (aRectPosition.xy + 1.0) * 0.5;             \n"
		"  vec2 fragCoord = vUv * uTextureSize;                   \n"
		"  vec2 inverseVP = vec2(1.0) / uTextureSize;             \n"
		"  v_rgbNW = (fragCoord + vec2(-1.0, -1.0)) * inverseVP;  \n"
		"  v_rgbNE = (fragCoord + vec2(1.0, -1.0)) * inverseVP;   \n"
		"  v_rgbSW = (fragCoord + vec2(-1.0, 1.0)) * inverseVP;   \n"
		"  v_rgbSE = (fragCoord + vec2(1.0, 1.0)) * inverseVP;    \n"
		"  v_rgbM = vec2(fragCoord * inverseVP);                  \n"
		"}                                                        \n"
		;
}

FXAAFragmentShader::FXAAFragmentShader(const opengl::GLInfo & _glinfo)
{
	m_part =
		"#ifndef FXAA_REDUCE_MIN                                                         \n"
		"    #define FXAA_REDUCE_MIN   (1.0/ 128.0)                                      \n"
		"#endif                                                                          \n"
		"#ifndef FXAA_REDUCE_MUL                                                         \n"
		"    #define FXAA_REDUCE_MUL   (1.0 / 8.0)                                       \n"
		"#endif                                                                          \n"
		"#ifndef FXAA_SPAN_MAX                                                           \n"
		"    #define FXAA_SPAN_MAX     8.0                                               \n"
		"#endif                                                                          \n"
		"                                                                                \n"
		"precision mediump float;                                                        \n"
		"IN vec2 v_rgbNW;                                                                \n"
		"IN vec2 v_rgbNE;                                                                \n"
		"IN vec2 v_rgbSW;                                                                \n"
		"IN vec2 v_rgbSE;                                                                \n"
		"IN vec2 v_rgbM;                                                                 \n"
		"                                                                                \n"
		"uniform vec2 uTextureSize;                                                      \n"
		"uniform sampler2D uTex0;                                                        \n"
		"                                                                                \n"
		"vec4 fxaa(vec2 fragCoord) {                                                     \n"
		"    vec4 color;                                                                 \n"
		"    mediump vec2 inverseVP = vec2(1.0) / uTextureSize;                          \n"
		"    vec3 rgbNW = texture2D(uTex0, v_rgbNW).xyz;                                 \n"
		"    vec3 rgbNE = texture2D(uTex0, v_rgbNE).xyz;                                 \n"
		"    vec3 rgbSW = texture2D(uTex0, v_rgbSW).xyz;                                 \n"
		"    vec3 rgbSE = texture2D(uTex0, v_rgbSE).xyz;                                 \n"
		"    vec4 texColor = texture2D(uTex0, v_rgbM);                                   \n"
		"    vec3 rgbM  = texColor.xyz;                                                  \n"
		"    vec3 luma = vec3(0.299, 0.587, 0.114);                                      \n"
		"    float lumaNW = dot(rgbNW, luma);                                            \n"
		"    float lumaNE = dot(rgbNE, luma);                                            \n"
		"    float lumaSW = dot(rgbSW, luma);                                            \n"
		"    float lumaSE = dot(rgbSE, luma);                                            \n"
		"    float lumaM  = dot(rgbM,  luma);                                            \n"
		"    float lumaMin = min(lumaM, min(min(lumaNW, lumaNE), min(lumaSW, lumaSE)));  \n"
		"    float lumaMax = max(lumaM, max(max(lumaNW, lumaNE), max(lumaSW, lumaSE)));  \n"
		"                                                                                \n"
		"    mediump vec2 dir;                                                           \n"
		"    dir.x = -((lumaNW + lumaNE) - (lumaSW + lumaSE));                           \n"
		"    dir.y =  ((lumaNW + lumaSW) - (lumaNE + lumaSE));                           \n"
		"                                                                                \n"
		"    float dirReduce = max((lumaNW + lumaNE + lumaSW + lumaSE) *                 \n"
		"                          (0.25 * FXAA_REDUCE_MUL), FXAA_REDUCE_MIN);           \n"
		"                                                                                \n"
		"    float rcpDirMin = 1.0 / (min(abs(dir.x), abs(dir.y)) + dirReduce);          \n"
		"    dir = min(vec2(FXAA_SPAN_MAX, FXAA_SPAN_MAX),                               \n"
		"              max(vec2(-FXAA_SPAN_MAX, -FXAA_SPAN_MAX),                         \n"
		"              dir * rcpDirMin)) * inverseVP;                                    \n"
		"                                                                                \n"
		"    vec3 rgbA = 0.5 * (                                                         \n"
		"       texture2D(uTex0, fragCoord * inverseVP + dir * (1.0 / 3.0 - 0.5)).xyz +  \n"
		"       texture2D(uTex0, fragCoord * inverseVP + dir * (2.0 / 3.0 - 0.5)).xyz);  \n"
		"    vec3 rgbB = rgbA * 0.5 + 0.25 * (                                           \n"
		"       texture2D(uTex0, fragCoord * inverseVP + dir * -0.5).xyz +               \n"
		"       texture2D(uTex0, fragCoord * inverseVP + dir * 0.5).xyz);                \n"
		"                                                                                \n"
		"    float lumaB = dot(rgbB, luma);                                              \n"
		"    if ((lumaB < lumaMin) || (lumaB > lumaMax))                                 \n"
		"        color = vec4(rgbA, texColor.a);                                         \n"
		"    else                                                                        \n"
		"        color = vec4(rgbB, texColor.a);                                         \n"
		"    return color;                                                               \n"
		"}                                                                               \n"
		"                                                                                \n"
		"OUT lowp vec4 fragColor;                                                        \n"
		"                                                                                \n"
		"void main() {                                                                   \n"
		"  fragColor = fxaa(gl_FragCoord.xy);                                            \n"
		;
}