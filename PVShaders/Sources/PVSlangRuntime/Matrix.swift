// swiftformat:disable consecutiveSpaces

//
//  File.swift
//
//
//  Created by Stuart Carnie on 25/5/2022.
//

import simd

extension simd_float4x4 {
    // swiftlint:disable identifier_name colon
    static func makeOrtho(left: Float, right: Float, top: Float, bottom: Float) -> Self {
        let near: Float = 0.0
        let far: Float = 1.0

        let sx: Float = 2.0 / (right - left)
        let sy: Float = 2.0 / (top - bottom)
        let sz: Float = 1.0 / (far - near)
        let tx: Float = (right + left) / (left - right)
        let ty: Float = (top + bottom) / (bottom - top)
        let tz: Float = near / (far - near)

        let P = simd_float4(x: sx, y:  0, z:  0, w: 0)
        let Q = simd_float4(x:  0, y: sy, z:  0, w: 0)
        let R = simd_float4(x:  0, y:  0, z: sz, w: 0)
        let S = simd_float4(x: tx, y: ty, z: tz, w: 1)

        return simd_float4x4(P, Q, R, S)
    }

    static func makeRotated(z: Float) -> Self {
        var cz: Float = 0, sz: Float = 0
        __sincosf(z, &sz, &cz)

        let P = simd_float4(x: cz, y: -sz, z: 0, w: 0)
        let Q = simd_float4(x: sz, y:  cz, z: 0, w: 0)
        let R = simd_float4(x:  0, y:   0, z: 0, w: 0)
        let S = simd_float4(x:  0, y:   0, z: 0, w: 1)

        return simd_float4x4(P, Q, R, S)
    }
}
