// perl -p -i -e "s/\r\n/\\\n\\\\\n/g" test
/*
<?xml version="1.0" encoding="UTF-8"?>
<!--
	SABR v3.0 Shader
	Joshua Street
	
	Portions of this algorithm were taken from Hyllian's 5xBR v3.7c
	shader.
	
	This program is free software; you can redistribute it and/or
	modify it under the terms of the GNU General Public License
	as published by the Free Software Foundation; either version 2
	of the License, or (at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program; if not, write to the Free Software
	Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
-->
<shader language="GLSL">
	<vertex><![CDATA[

*/

static const char *vertSABR = "\n\
		uniform vec2 rubyTextureSize;\n\
		\n\
		varying vec2 tc;\n\
		varying vec4 xyp_1_2_3;\n\
		varying vec4 xyp_5_10_15;\n\
		varying vec4 xyp_6_7_8;\n\
		varying vec4 xyp_9_14_9;\n\
		varying vec4 xyp_11_12_13;\n\
		varying vec4 xyp_16_17_18;\n\
		varying vec4 xyp_21_22_23;\n\
		\n\
		void main() {\n\
			gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;\n\
			\n\
			float x = 1.0 / rubyTextureSize.x;\n\
			float y = 1.0 / rubyTextureSize.y;\n\
			\n\
			\n\
			\n\
			/*\n\
				Mask for algorhithm\n\
				+-----+-----+-----+-----+-----+\n\
				|     |  1  |  2  |  3  |     |\n\
				+-----+-----+-----+-----+-----+\n\
				|  5  |  6  |  7  |  8  |  9  |\n\
				+-----+-----+-----+-----+-----+\n\
				| 10  | 11  | 12  | 13  | 14  |\n\
				+-----+-----+-----+-----+-----+\n\
				| 15  | 16  | 17  | 18  | 19  |\n\
				+-----+-----+-----+-----+-----+\n\
				|     | 21  | 22  | 23  |     |\n\
				+-----+-----+-----+-----+-----+\n\
			*/\n\
			\n\
			tc = gl_MultiTexCoord0.xy;\n\
			\n\
			xyp_1_2_3    = tc.xxxy + vec4(      -x, 0.0,   x, -2.0 * y);\n\
			xyp_6_7_8    = tc.xxxy + vec4(      -x, 0.0,   x,       -y);\n\
			xyp_11_12_13 = tc.xxxy + vec4(      -x, 0.0,   x,      0.0);\n\
			xyp_16_17_18 = tc.xxxy + vec4(      -x, 0.0,   x,        y);\n\
			xyp_21_22_23 = tc.xxxy + vec4(      -x, 0.0,   x,  2.0 * y);\n\
			xyp_5_10_15  = tc.xyyy + vec4(-2.0 * x,  -y, 0.0,        y);\n\
			xyp_9_14_9   = tc.xyyy + vec4( 2.0 * x,  -y, 0.0,        y);\n\
		}";

/*
	]]></vertex>
	<fragment filter="nearest"><![CDATA[
*/

static const char *fragSABR = "\n\
		/*\n\
			Uniforms\n\
			- rubyTexture: texture sampler\n\
			- rubyTextureSize: size of the texture before rendering\n\
		*/\n\
		uniform sampler2D rubyTexture;\n\
		uniform vec2 rubyTextureSize;\n\
		\n\
		/*\n\
			Varying attributes\n\
			- tc: coordinate of the texel being processed\n\
			- xyp_[]_[]_[]: a packed coordinate for 3 areas within the texture\n\
		*/\n\
		varying vec2 tc;\n\
		varying vec4 xyp_1_2_3;\n\
		varying vec4 xyp_5_10_15;\n\
		varying vec4 xyp_6_7_8;\n\
		varying vec4 xyp_9_14_9;\n\
		varying vec4 xyp_11_12_13;\n\
		varying vec4 xyp_16_17_18;\n\
		varying vec4 xyp_21_22_23;\n\
		\n\
		/*\n\
			Constants\n\
		*/\n\
		/*\n\
			Inequation coefficients for interpolation\n\
				Equations are in the form: Ay + Bx = C\n\
				45, 30, and 60 denote the angle from x each line the cooeficient variable set builds\n\
		*/\n\
		const vec4 Ai  = vec4( 1.0, -1.0, -1.0,  1.0);\n\
		const vec4 B45 = vec4( 1.0,  1.0, -1.0, -1.0);\n\
		const vec4 C45 = vec4( 1.5,  0.5, -0.5,  0.5);\n\
		const vec4 B30 = vec4( 0.5,  2.0, -0.5, -2.0);\n\
		const vec4 C30 = vec4( 1.0,  1.0, -0.5,  0.0);\n\
		const vec4 B60 = vec4( 2.0,  0.5, -2.0, -0.5);\n\
		const vec4 C60 = vec4( 2.0,  0.0, -1.0,  0.5);\n\
		\n\
		const vec4 M45 = vec4(0.4, 0.4, 0.4, 0.4);\n\
		const vec4 M30 = vec4(0.2, 0.4, 0.2, 0.4);\n\
		const vec4 M60 = M30.yxwz;\n\
		const vec4 Mshift = vec4(0.2);\n\
		\n\
		// Coefficient for weighted edge detection\n\
		const float coef = 2.0;\n\
		// Threshold for if luminance values are \"equal\"\n\
		const vec4 threshold = vec4(0.32);\n\
		\n\
		// Conversion from RGB to Luminance (from GIMP)\n\
		const vec3 lum = vec3(0.21, 0.72, 0.07);\n\
		\n\
		// Performs same logic operation as && for vectors\n\
		bvec4 _and_(bvec4 A, bvec4 B) {\n\
			return bvec4(A.x && B.x, A.y && B.y, A.z && B.z, A.w && B.w);\n\
		}\n\
		\n\
		// Performs same logic operation as || for vectors\n\
		bvec4 _or_(bvec4 A, bvec4 B) {\n\
			return bvec4(A.x || B.x, A.y || B.y, A.z || B.z, A.w || B.w);\n\
		}\n\
		\n\
		// Converts 4 3-color vectors into 1 4-value luminance vector\n\
		vec4 lum_to(vec3 v0, vec3 v1, vec3 v2, vec3 v3) {\n\
			return vec4(dot(lum, v0), dot(lum, v1), dot(lum, v2), dot(lum, v3));\n\
		}\n\
		\n\
		// Gets the difference between 2 4-value luminance vectors\n\
		vec4 lum_df(vec4 A, vec4 B) {\n\
			return abs(A - B);\n\
		}\n\
		\n\
		// Determines if 2 4-value luminance vectors are \"equal\" based on threshold\n\
		bvec4 lum_eq(vec4 A, vec4 B) {\n\
			return lessThan(lum_df(A, B), threshold);\n\
		}\n\
		\n\
		vec4 lum_wd(vec4 a, vec4 b, vec4 c, vec4 d, vec4 e, vec4 f, vec4 g, vec4 h) {\n\
			return lum_df(a, b) + lum_df(a, c) + lum_df(d, e) + lum_df(d, f) + 4.0 * lum_df(g, h);\n\
		}\n\
		\n\
		// Gets the difference between 2 3-value rgb colors\n\
		float c_df(vec3 c1, vec3 c2) {\n\
			vec3 df = abs(c1 - c2);\n\
			return df.r + df.g + df.b;\n\
		}\n\
		\n\
		void main() {\n\
			/*\n\
				Mask for algorhithm\n\
				+-----+-----+-----+-----+-----+\n\
				|     |  1  |  2  |  3  |     |\n\
				+-----+-----+-----+-----+-----+\n\
				|  5  |  6  |  7  |  8  |  9  |\n\
				+-----+-----+-----+-----+-----+\n\
				| 10  | 11  | 12  | 13  | 14  |\n\
				+-----+-----+-----+-----+-----+\n\
				| 15  | 16  | 17  | 18  | 19  |\n\
				+-----+-----+-----+-----+-----+\n\
				|     | 21  | 22  | 23  |     |\n\
				+-----+-----+-----+-----+-----+\n\
			*/\n\
			// Get mask values by performing texture lookup with the uniform sampler\n\
			vec3 P1  = texture2D(rubyTexture, xyp_1_2_3.xw   ).rgb;\n\
			vec3 P2  = texture2D(rubyTexture, xyp_1_2_3.yw   ).rgb;\n\
			vec3 P3  = texture2D(rubyTexture, xyp_1_2_3.zw   ).rgb;\n\
			\n\
			vec3 P6  = texture2D(rubyTexture, xyp_6_7_8.xw   ).rgb;\n\
			vec3 P7  = texture2D(rubyTexture, xyp_6_7_8.yw   ).rgb;\n\
			vec3 P8  = texture2D(rubyTexture, xyp_6_7_8.zw   ).rgb;\n\
			\n\
			vec3 P11 = texture2D(rubyTexture, xyp_11_12_13.xw).rgb;\n\
			vec3 P12 = texture2D(rubyTexture, xyp_11_12_13.yw).rgb;\n\
			vec3 P13 = texture2D(rubyTexture, xyp_11_12_13.zw).rgb;\n\
			\n\
			vec3 P16 = texture2D(rubyTexture, xyp_16_17_18.xw).rgb;\n\
			vec3 P17 = texture2D(rubyTexture, xyp_16_17_18.yw).rgb;\n\
			vec3 P18 = texture2D(rubyTexture, xyp_16_17_18.zw).rgb;\n\
			\n\
			vec3 P21 = texture2D(rubyTexture, xyp_21_22_23.xw).rgb;\n\
			vec3 P22 = texture2D(rubyTexture, xyp_21_22_23.yw).rgb;\n\
			vec3 P23 = texture2D(rubyTexture, xyp_21_22_23.zw).rgb;\n\
			\n\
			vec3 P5  = texture2D(rubyTexture, xyp_5_10_15.xy ).rgb;\n\
			vec3 P10 = texture2D(rubyTexture, xyp_5_10_15.xz ).rgb;\n\
			vec3 P15 = texture2D(rubyTexture, xyp_5_10_15.xw ).rgb;\n\
			\n\
			vec3 P9  = texture2D(rubyTexture, xyp_9_14_9.xy  ).rgb;\n\
			vec3 P14 = texture2D(rubyTexture, xyp_9_14_9.xz  ).rgb;\n\
			vec3 P19 = texture2D(rubyTexture, xyp_9_14_9.xw  ).rgb;\n\
			\n\
			// Store luminance values of each point in groups of 4\n\
			// so that we may operate on all four corners at once\n\
			vec4 p7  = lum_to(P7,  P11, P17, P13);\n\
			vec4 p8  = lum_to(P8,  P6,  P16, P18);\n\
			vec4 p11 = p7.yzwx;                      // P11, P17, P13, P7\n\
			vec4 p12 = lum_to(P12, P12, P12, P12);\n\
			vec4 p13 = p7.wxyz;                      // P13, P7,  P11, P17\n\
			vec4 p14 = lum_to(P14, P2,  P10, P22);\n\
			vec4 p16 = p8.zwxy;                      // P16, P18, P8,  P6\n\
			vec4 p17 = p7.zwxy;                      // P17, P13, P7,  P11\n\
			vec4 p18 = p8.wxyz;                      // P18, P8,  P6,  P16\n\
			vec4 p19 = lum_to(P19, P3,  P5,  P21);\n\
			vec4 p22 = p14.wxyz;                     // P22, P14, P2,  P10\n\
			vec4 p23 = lum_to(P23, P9,  P1,  P15);\n\
			\n\
			// Scale current texel coordinate to [0..1]\n\
			vec2 fp = fract(tc * rubyTextureSize);\n\
			\n\
			// Determine amount of \"smoothing\" or mixing that could be done on texel corners\n\
			vec4 ma45 = smoothstep(C45 - M45, C45 + M45, Ai * fp.y + B45 * fp.x);\n\
			vec4 ma30 = smoothstep(C30 - M30, C30 + M30, Ai * fp.y + B30 * fp.x);\n\
			vec4 ma60 = smoothstep(C60 - M60, C60 + M60, Ai * fp.y + B60 * fp.x);\n\
			vec4 marn = smoothstep(C45 - M45 + Mshift, C45 + M45 + Mshift, Ai * fp.y + B45 * fp.x);\n\
			\n\
			// Perform edge weight calculations\n\
			vec4 e45   = lum_wd(p12, p8, p16, p18, p22, p14, p17, p13);\n\
			vec4 econt = lum_wd(p17, p11, p23, p13, p7, p19, p12, p18);\n\
			vec4 e30   = lum_df(p13, p16);\n\
			vec4 e60   = lum_df(p8, p17);\n\
			\n\
			// Calculate rule results for interpolation\n\
			bvec4 r45_1   = _and_(notEqual(p12, p13), notEqual(p12, p17));\n\
			bvec4 r45_2   = _and_(not(lum_eq(p13, p7)), not(lum_eq(p13, p8)));\n\
			bvec4 r45_3   = _and_(not(lum_eq(p17, p11)), not(lum_eq(p17, p16)));\n\
			bvec4 r45_4_1 = _and_(not(lum_eq(p13, p14)), not(lum_eq(p13, p19)));\n\
			bvec4 r45_4_2 = _and_(not(lum_eq(p17, p22)), not(lum_eq(p17, p23)));\n\
			bvec4 r45_4   = _and_(lum_eq(p12, p18), _or_(r45_4_1, r45_4_2));\n\
			bvec4 r45_5   = _or_(lum_eq(p12, p16), lum_eq(p12, p8));\n\
			bvec4 r45     = _and_(r45_1, _or_(_or_(_or_(r45_2, r45_3), r45_4), r45_5));\n\
			bvec4 r30 = _and_(notEqual(p12, p16), notEqual(p11, p16));\n\
			bvec4 r60 = _and_(notEqual(p12, p8), notEqual(p7, p8));\n\
			\n\
			// Combine rules with edge weights\n\
			bvec4 edr45 = _and_(lessThan(e45, econt), r45);\n\
			bvec4 edrrn = lessThanEqual(e45, econt);\n\
			bvec4 edr30 = _and_(lessThanEqual(coef * e30, e60), r30);\n\
			bvec4 edr60 = _and_(lessThanEqual(coef * e60, e30), r60);\n\
			\n\
			// Finalize interpolation rules and cast to float (0.0 for false, 1.0 for true)\n\
			vec4 final45 = vec4(_and_(_and_(not(edr30), not(edr60)), edr45));\n\
			vec4 final30 = vec4(_and_(_and_(edr45, not(edr60)), edr30));\n\
			vec4 final60 = vec4(_and_(_and_(edr45, not(edr30)), edr60));\n\
			vec4 final36 = vec4(_and_(_and_(edr60, edr30), edr45));\n\
			vec4 finalrn = vec4(_and_(not(edr45), edrrn));\n\
			\n\
			// Determine the color to mix with for each corner\n\
			vec4 px = step(lum_df(p12, p17), lum_df(p12, p13));\n\
			\n\
			// Determine the mix amounts by combining the final rule result and corresponding\n\
			// mix amount for the rule in each corner\n\
			vec4 mac = final36 * max(ma30, ma60) + final30 * ma30 + final60 * ma60 + final45 * ma45 + finalrn * marn;\n\
			\n\
			/*\n\
				Calculate the resulting color by traversing clockwise and counter-clockwise around\n\
				the corners of the texel\n\
				\n\
				Finally choose the result that has the largest difference from the texel's original\n\
				color\n\
			*/\n\
			vec3 res1 = P12;\n\
			res1 = mix(res1, mix(P13, P17, px.x), mac.x);\n\
			res1 = mix(res1, mix(P7, P13, px.y), mac.y);\n\
			res1 = mix(res1, mix(P11, P7, px.z), mac.z);\n\
			res1 = mix(res1, mix(P17, P11, px.w), mac.w);\n\
			\n\
			vec3 res2 = P12;\n\
			res2 = mix(res2, mix(P17, P11, px.w), mac.w);\n\
			res2 = mix(res2, mix(P11, P7, px.z), mac.z);\n\
			res2 = mix(res2, mix(P7, P13, px.y), mac.y);\n\
			res2 = mix(res2, mix(P13, P17, px.x), mac.x);\n\
			\n\
			gl_FragColor = vec4(mix(res1, res2, step(c_df(P12, res1), c_df(P12, res2))), 1.0);\n\
		}";
/*
	]]></fragment>\n\
</shader>\n\
*/
