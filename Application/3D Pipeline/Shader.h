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
    
    simd_float4         ambientColor;

    // bbox
    simd_float3         P;
    simd_float3         L;
    matrix_float3x3     F;
    
    float               maxDistance;
} ObjectFragmentUniforms;

typedef struct {
    int                 lightType;
    simd_float4         lightColor;
    simd_float4         directionToLight;
} Light;

typedef struct {
    int                 numberOfLights;
    Light               lights[10];
} LightUniforms;

typedef struct {
    int                 numberOfSpheres;
    simd_float3         position;
    simd_float3         rotation;
} SphereUniforms;

#endif /* Shader_h */
