//
//  Shader.h
//  Shape-Z
//
//  Created by Markus Moenig on 15/6/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

#ifndef Shader_h
#define Shader_h

#import <simd/simd.h>

typedef struct {
    matrix_float4x4     modelMatrix;
    matrix_float4x4     viewMatrix;
    matrix_float4x4     projectionMatrix;
} ObjectVertexUniforms;

typedef struct {
    
    simd_float3         cameraOrigin;
    simd_float3         cameraLookAt;
    
    simd_float2         screenSize;
    
    float               maxDistance;
} ObjectFragmentUniforms;

#endif /* Shader_h */
