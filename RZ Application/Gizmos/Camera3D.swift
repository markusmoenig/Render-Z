//
//  Camera3D.swift
//  Shape-Z
//
//  Created by Markus Moenig on 26/2/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit
import simd

class Camera3D
{
    var eye             : SIMD3<Float> = SIMD3<Float>(0,0,0)
    var center          : SIMD3<Float> = SIMD3<Float>(0,0,0)
    var fov             : Float = 60
    var aspect          : Float = 0

    let up              : SIMD3<Float> = SIMD3<Float>(0,1,0)
    
    var projMatrix      : simd_float4x4 = matrix_identity_float4x4

    let near            : Float = 1
    let far             : Float = 100
    
    var originFrag      : CodeFragment? = nil
    var lookAtFrag      : CodeFragment? = nil
    var fovFrag         : CodeFragment? = nil
    
    func initFromCamera(aspect: Float, originFrag: CodeFragment?, lookAtFrag: CodeFragment?, fovFrag : CodeFragment?)
    {
        self.aspect = aspect
        
        self.originFrag = originFrag
        self.lookAtFrag = lookAtFrag
        self.fovFrag = fovFrag
        
        if let frag = originFrag {
            eye = extractValueFromFragment3(frag)
        }
        if let frag = lookAtFrag {
            center = extractValueFromFragment3(frag)
        }
        if let frag = fovFrag {
            fov = extractValueFromFragment(frag).x
        }
    }
    
    func updateProjection()
    {
        projMatrix = matrix_identity_float4x4

        let fovy : Float = Float.pi * fov / 180 / 2
        let s : Float = sin(fovy)

        let rd : Float = 1 / (far - near)
        let ct : Float = cos(fovy) / s
        
        projMatrix[0, 0] = ct / aspect
        projMatrix[0, 1] = 0
        projMatrix[0, 2] = 0
        projMatrix[0, 3] = 0

        projMatrix[1, 0] = 0
        projMatrix[1, 1] = ct
        projMatrix[1, 2] = 0
        projMatrix[1, 3] = 0
        
        projMatrix[2, 0] = 0
        projMatrix[2, 1] = 0
        projMatrix[2, 2] = -(far + near) * rd
        projMatrix[2, 3] = -1
        
        projMatrix[3, 0] = 0
        projMatrix[3, 1] = 0
        projMatrix[3, 2] = -2 * near * far * rd
        projMatrix[3, 3] = 0
    }
    
    func calculateDirXY() -> (SIMD3<Float>, SIMD3<Float>)
    {
        let c_eye = center - eye
        
        let dirX : SIMD3<Float> = up
        let dirY : SIMD3<Float> = simd_normalize(simd_cross(up, c_eye))
        
        return (dirX, dirY)
    }
    
    func rotateToAPoint(p: SIMD3<Float>, o: SIMD3<Float>, v: SIMD3<Float>, alpha: Float) -> SIMD3<Float>
    {
        let c : Float = cos(alpha);
        let s : Float = sin(alpha);
        let C : Float = 1.0 - c;
        var m = matrix_identity_float4x4
        
        m[0, 0] = v.x * v.x * C + c
        m[0, 1] = v.y * v.x * C + v.z * s
        m[0, 2] = v.z * v.x * C - v.y * s
        m[0, 3] = 0

        m[1, 0] = v.x * v.y * C - v.z * s
        m[1, 1] = v.y * v.y * C + c
        m[1, 2] = v.z * v.y * C + v.x * s
        m[1, 3] = 0
        
        m[2, 0] = v.x * v.z * C + v.y * s
        m[2, 1] = v.y * v.z * C - v.x * s
        m[2, 2] = v.z * v.z * C + c
        m[2, 3] = 0
        
        m[3, 0] = 0
        m[3, 1] = 0
        m[3, 2] = 0
        m[3, 3] = 1
        
        let P = p - o
        var out = o
        
        out.x += P.x * m[0, 0] + P.y * m[1, 0] + P.z * m[2, 0] + m[3, 0]
        out.y += P.x * m[0, 1] + P.y * m[1, 1] + P.z * m[2, 1] + m[3, 1]
        out.z += P.x * m[0, 2] + P.y * m[1, 2] + P.z * m[2, 2] + m[3, 2]
        
        return out
    }

    // Zooms the camera in / out
    func zoom(dx: Float, dy: Float)
    {
        eye -= center
        eye *= dy + 1
        eye += center
        
        if let frag = originFrag {
            insertValueToFragment3(frag, eye)
        }
    }
    
    // Zooms the camera in / out
    func zoomRelative(dx: Float, dy: Float, start: SIMD3<Float>)
    {
        eye -= center
        eye = start / dy
        eye += center
        
        if let frag = originFrag {
            insertValueToFragment3(frag, eye)
        }
    }
    
    // Pans the camera
    func pan(dx: Float, dy: Float)
    {
        let dir = calculateDirXY()
        let e = eye - center
        let t : Float = tan(fov/2 * Float.pi / 180)
        let len = 2 * length(e) * t
        
        let add : SIMD3<Float> = dir.1 * (dx * len * aspect) + dir.0 * (dy * len)
        
        center += add
        eye += add
        
        if let frag = originFrag {
            insertValueToFragment3(frag, eye)
        }
        
        if let frag = lookAtFrag {
            insertValueToFragment3(frag, center)
        }
    }
    
    // Rotates the camera
    func rotate(dx: Float, dy: Float)
    {
        let dir = calculateDirXY()

        eye = rotateToAPoint(p: eye, o: center, v: dir.0, alpha: -dx * Float.pi)
        eye = rotateToAPoint(p: eye, o: center, v: dir.1, alpha: dy * Float.pi)
        
        if let frag = originFrag {
            insertValueToFragment3(frag, eye)
        }
    }
}
