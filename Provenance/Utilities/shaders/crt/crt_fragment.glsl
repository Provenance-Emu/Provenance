// PUBLIC DOMAIN CRT SHADER
//
//   Originally by Jay Mattis, tweaked by MrJ
//
// I'm a big fan of Timothy Lottes' shader, but it doesn't scale well and I was looking for something that
// was performant on my 4K TV and still looked decent on my phone. This takes a lot of inspiration from his
// shader but is 3 taps instead of 15, calculates the shadow/slot mask very differently, and bases a lot
// more on the input resolution rather than the output resolution (as long as the output resolution is
// high enough).
//
// Left it unoptimized to show the theory behind the algorithm. (This is now no longer the case)
//
// It is an example what I personally would want as a display option for pixel art games.
// Please take and use, change, or whatever.
//
// The original shader from Jay Mattis has been further machine optimized to allow for (sub) 16.6ms frame times 
// resulting in stable 60fps CRT shader performance in Provenance on the original iPad Air (A7 GPU architecture 
// from 2013(!!!). This optimization, together with the new Multi-threaded GL option in the 1.5 beta, 
// should allow even the oldest iPad Air's to run the consoles of yesteryear at speed with full CRT shader effect. 
// 
// Other changes/comments
// - Lowered the minimum black point set in the shader to 0.0015, down from 0.003.
// - Couple this shader with the "Image Smoothing" option to reduce the anti-aliasing issues that could show up.

#ifdef GL_ES
precision mediump float;
#endif

#if __VERSION__ < 300
#define texture texture2D
#endif

varying highp vec2 fTexCoord;
uniform vec4 DisplayRect;
uniform sampler2D EmulatedImage;
uniform vec2 EmulatedImageSize;
uniform vec2 FinalRes;
void main ()
{
    highp vec2 uv_1;
    uv_1 = (((fTexCoord / DisplayRect.zw) * EmulatedImageSize) - (DisplayRect.xy / DisplayRect.zw));
    float bloomAmount_2;
    highp vec2 tmpvar_3;
    highp vec2 uv_4;
    uv_4 = ((uv_1 * 2.0) - 1.0);
    highp vec2 tmpvar_5;
    tmpvar_5.x = (1.0 + ((uv_4.y * uv_4.y) * 0.015625));
    tmpvar_5.y = (1.0 + ((uv_4.x * uv_4.x) * 0.04166667));
    uv_4 = (uv_4 * tmpvar_5);
    tmpvar_3 = ((uv_4 * 0.5) + 0.5);
    highp float tmpvar_6;
    tmpvar_6 = (1.0 - exp2((
                            (1.0 - (max (abs(
                                             (tmpvar_3.x - 0.5)
                                             ), abs(
                                                    (tmpvar_3.y - 0.5)
                                                    )) / 0.5))
                            * -256.0)));
    bloomAmount_2 = 2.0;
    if ((FinalRes.y >= 960.0)) {
        bloomAmount_2 = 4.0;
    };
    highp vec3 tmpvar_7;
    highp vec3 scanlineMultiplier_8;
    lowp vec4 tmpvar_9;
    highp vec2 P_10;
    P_10 = ((DisplayRect.xy / EmulatedImageSize) + ((tmpvar_3 / EmulatedImageSize) * DisplayRect.zw));
    tmpvar_9 = texture2D (EmulatedImage, P_10);
    lowp vec3 tmpvar_11;
    tmpvar_11 = (tmpvar_9.xyz * tmpvar_9.xyz);
    scanlineMultiplier_8 = vec3(1.0, 1.0, 1.0);
    if ((FinalRes.y >= 960.0)) {
        highp float tmpvar_12;
        tmpvar_12 = (abs((
                          ((float(mod (tmpvar_3.y, 0.004166667))) / 0.004166667)
                          - 0.5)) / 0.5);
        scanlineMultiplier_8 = mix (vec3(0.25, 0.25, 0.25), vec3(1.0, 1.0, 1.0), exp2((
                                                                                       (tmpvar_12 * tmpvar_12)
                                                                                       * -4.0)));
    };
    highp vec3 tmpvar_13;
    tmpvar_13 = max ((tmpvar_11 * scanlineMultiplier_8), vec3(0.0015, 0.0015, 0.0015));
    vec2 shadowMaskRes_14;
    if (((FinalRes.y / 3.0) < 720.0)) {
        shadowMaskRes_14 = (FinalRes / 3.0);
    } else {
        vec2 tmpvar_15;
        tmpvar_15.y = 360.0;
        tmpvar_15.x = ((FinalRes.x / FinalRes.y) * 360.0);
        shadowMaskRes_14 = tmpvar_15;
    };
    highp vec2 tmpvar_16;
    tmpvar_16 = ((uv_1 * shadowMaskRes_14) * vec2(3.0, 3.0));
    highp vec3 tmpvar_17;
    tmpvar_17.x = (tmpvar_16.x + 1.0);
    tmpvar_17.y = tmpvar_16.x;
    tmpvar_17.z = (tmpvar_16.x + 2.0);
    highp vec3 tmpvar_18;
    tmpvar_18 = (abs((
                      (vec3(mod (tmpvar_17, 3.0)))
                      - 1.5)) / 1.5);
    tmpvar_7 = (tmpvar_13 * exp2((
                                  (tmpvar_18 * tmpvar_18)
                                  * -16.0)));
    vec2 tmpvar_19;
    tmpvar_19.y = 0.0;
    tmpvar_19.x = (-1.0 / FinalRes.x);
    highp vec2 tmpvar_20;
    tmpvar_20 = (uv_1 + tmpvar_19);
    vec2 tmpvar_21;
    tmpvar_21.y = 0.0;
    tmpvar_21.x = (1.0/(FinalRes.x));
    highp vec2 tmpvar_22;
    tmpvar_22 = (uv_1 + tmpvar_21);
    highp vec2 tmpvar_23;
    highp vec2 uv_24;
    uv_24 = ((tmpvar_20 * 2.0) - 1.0);
    highp vec2 tmpvar_25;
    tmpvar_25.x = (1.0 + ((uv_24.y * uv_24.y) * 0.015625));
    tmpvar_25.y = (1.0 + ((uv_24.x * uv_24.x) * 0.04166667));
    uv_24 = (uv_24 * tmpvar_25);
    tmpvar_23 = ((uv_24 * 0.5) + 0.5);
    highp vec3 tmpvar_26;
    highp vec3 scanlineMultiplier_27;
    lowp vec4 tmpvar_28;
    highp vec2 P_29;
    P_29 = ((DisplayRect.xy / EmulatedImageSize) + ((tmpvar_23 / EmulatedImageSize) * DisplayRect.zw));
    tmpvar_28 = texture2D (EmulatedImage, P_29);
    lowp vec3 tmpvar_30;
    tmpvar_30 = (tmpvar_28.xyz * tmpvar_28.xyz);
    scanlineMultiplier_27 = vec3(1.0, 1.0, 1.0);
    if ((FinalRes.y >= 960.0)) {
        highp float tmpvar_31;
        tmpvar_31 = (abs((
                          ((float(mod (tmpvar_23.y, 0.004166667))) / 0.004166667)
                          - 0.5)) / 0.5);
        scanlineMultiplier_27 = mix (vec3(0.25, 0.25, 0.25), vec3(1.0, 1.0, 1.0), exp2((
                                                                                        (tmpvar_31 * tmpvar_31)
                                                                                        * -4.0)));
    };
    highp vec3 tmpvar_32;
    tmpvar_32 = max ((tmpvar_30 * scanlineMultiplier_27), vec3(0.0015, 0.0015, 0.0015));
    vec2 shadowMaskRes_33;
    if (((FinalRes.y / 3.0) < 720.0)) {
        shadowMaskRes_33 = (FinalRes / 3.0);
    } else {
        vec2 tmpvar_34;
        tmpvar_34.y = 360.0;
        tmpvar_34.x = ((FinalRes.x / FinalRes.y) * 360.0);
        shadowMaskRes_33 = tmpvar_34;
    };
    highp vec2 tmpvar_35;
    tmpvar_35 = ((tmpvar_20 * shadowMaskRes_33) * vec2(3.0, 3.0));
    highp vec3 tmpvar_36;
    tmpvar_36.x = (tmpvar_35.x + 1.0);
    tmpvar_36.y = tmpvar_35.x;
    tmpvar_36.z = (tmpvar_35.x + 2.0);
    highp vec3 tmpvar_37;
    tmpvar_37 = (abs((
                      (vec3(mod (tmpvar_36, 3.0)))
                      - 1.5)) / 1.5);
    tmpvar_26 = (tmpvar_32 * exp2((
                                   (tmpvar_37 * tmpvar_37)
                                   * -16.0)));
    highp vec2 tmpvar_38;
    highp vec2 uv_39;
    uv_39 = ((tmpvar_22 * 2.0) - 1.0);
    highp vec2 tmpvar_40;
    tmpvar_40.x = (1.0 + ((uv_39.y * uv_39.y) * 0.015625));
    tmpvar_40.y = (1.0 + ((uv_39.x * uv_39.x) * 0.04166667));
    uv_39 = (uv_39 * tmpvar_40);
    tmpvar_38 = ((uv_39 * 0.5) + 0.5);
    highp vec3 scanlineMultiplier_41;
    lowp vec4 tmpvar_42;
    highp vec2 P_43;
    P_43 = ((DisplayRect.xy / EmulatedImageSize) + ((tmpvar_38 / EmulatedImageSize) * DisplayRect.zw));
    tmpvar_42 = texture2D (EmulatedImage, P_43);
    lowp vec3 tmpvar_44;
    tmpvar_44 = (tmpvar_42.xyz * tmpvar_42.xyz);
    scanlineMultiplier_41 = vec3(1.0, 1.0, 1.0);
    if ((FinalRes.y >= 960.0)) {
        highp float tmpvar_45;
        tmpvar_45 = (abs((
                          ((float(mod (tmpvar_38.y, 0.004166667))) / 0.004166667)
                          - 0.5)) / 0.5);
        scanlineMultiplier_41 = mix (vec3(0.25, 0.25, 0.25), vec3(1.0, 1.0, 1.0), exp2((
                                                                                        (tmpvar_45 * tmpvar_45)
                                                                                        * -4.0)));
    };
    highp vec3 tmpvar_46;
    tmpvar_46 = max ((tmpvar_44 * scanlineMultiplier_41), vec3(0.0015, 0.0015, 0.0015));
    vec2 shadowMaskRes_47;
    if (((FinalRes.y / 3.0) < 720.0)) {
        shadowMaskRes_47 = (FinalRes / 3.0);
    } else {
        vec2 tmpvar_48;
        tmpvar_48.y = 360.0;
        tmpvar_48.x = ((FinalRes.x / FinalRes.y) * 360.0);
        shadowMaskRes_47 = tmpvar_48;
    };
    highp vec2 tmpvar_49;
    tmpvar_49 = ((tmpvar_22 * shadowMaskRes_47) * vec2(3.0, 3.0));
    highp vec3 tmpvar_50;
    tmpvar_50.x = (tmpvar_49.x + 1.0);
    tmpvar_50.y = tmpvar_49.x;
    tmpvar_50.z = (tmpvar_49.x + 2.0);
    highp vec3 tmpvar_51;
    tmpvar_51 = (abs((
                      (vec3(mod (tmpvar_50, 3.0)))
                      - 1.5)) / 1.5);
    highp vec3 tmpvar_52;
    tmpvar_52 = sqrt(((tmpvar_7 +
                       ((((tmpvar_7 * 0.5) + (tmpvar_26 * 0.25)) + ((tmpvar_46 *
                                                                     exp2(((tmpvar_51 * tmpvar_51) * -16.0))
                                                                     ) * 0.25)) * bloomAmount_2)
                       ) * tmpvar_6));
    gl_FragColor.xyz = tmpvar_52;
    gl_FragColor.w = 1.0;
}
