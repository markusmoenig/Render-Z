//
//  ShaderTypes.h
//  Framework
//
//  Created by Markus Moenig on 01.01.19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

typedef struct
{
    vector_float2 position;
    vector_float2 textureCoordinate;
} MM_Vertex;

typedef struct
{
    vector_float4 fillColor;
    vector_float4 borderColor;
    float radius, borderSize;
} MM_SPHERE;

typedef struct
{
    vector_float2 size;
    float round, borderSize;
    vector_float4 fillColor;
    vector_float4 borderColor;

} MM_CUBE;

typedef struct
{
    vector_float2 size;
    float round, borderSize;
    vector_float2 uv1;
    vector_float2 uv2;
    vector_float4 gradientColor1;
    vector_float4 gradientColor2;
    vector_float4 borderColor;
    
} MM_CUBE_GRADIENT;

typedef struct
{
    vector_float2 screenSize;
    vector_float2 pos;
    vector_float2 size;
    
} MM_TEXTURE;

typedef struct
{
    vector_float2 atlasSize;
    vector_float2 fontPos;
    vector_float2 fontSize;
} MM_TEXT;

#endif /* Mad4Metal_types.h */
