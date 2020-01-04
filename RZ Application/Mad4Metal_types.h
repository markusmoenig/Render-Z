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
    float2 size;
    float2 sp, ep;
    float width, borderSize;
    float4 fillColor;
    float4 borderColor;
    
} MM_LINE;

typedef struct
{
    float2 size;
    float2 sp, cp, ep;
    float width, borderSize;
    float fill1, fill2;
    float4 fillColor;
    float4 borderColor;
    
} MM_SPLINE;

typedef struct
{
    float4 size, range;
    float4 points[300];
} MM_POINTGRAPH;

typedef struct
{
    vector_float2 size;
    float round, borderSize;
    vector_float4 fillColor;
    vector_float4 borderColor;

} MM_BOX;

typedef struct
{
    vector_float2 size;
    float round, borderSize;
    vector_float4 fillColor;
    vector_float4 borderColor;
    float4 rotation;

} MM_ROTATEDBOX;

typedef struct
{
    vector_float2 size;
    float round, borderSize;
    vector_float4 fillColor;
    vector_float4 borderColor;
    
} MM_BOXEDMENU;

typedef struct
{
    vector_float2 size;
    float round, borderSize;
    vector_float2 uv1;
    vector_float2 uv2;
    vector_float4 gradientColor1;
    vector_float4 gradientColor2;
    vector_float4 borderColor;
    
} MM_BOX_GRADIENT;

typedef struct
{
    float2 screenSize;
    float2 pos;
    float2 size;
    float  prem;
    float  round;
    float4 roundingRect;

} MM_TEXTURE;

typedef struct
{
    float2 atlasSize;
    float2 fontPos;
    float2 fontSize;
    float4 color;
} MM_TEXT;

typedef struct
{
    float2 size;
    float4 color;
    
} MM_COLORWHEEL;

typedef struct
{
    float2 sc;
    float2 r;
    float4 color;
    
} MM_ARC;

#endif /* Mad4Metal_types.h */
