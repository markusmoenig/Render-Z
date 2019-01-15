//
//  AppShaders.metal
//  Framework
//
//  Created by Markus Moenig on 11.01.19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;

typedef struct
{
    float4 clipSpacePosition [[position]];
    float2 textureCoordinate;
} RasterizerData;

typedef struct
{
    float2 size;
    
} MODULO_PATTERN;

// --- Cube Drawable
fragment float4 moduloPattern(RasterizerData in [[stage_in]],
                                constant MODULO_PATTERN *data [[ buffer(0) ]] )
{
    
    float4 checkerColor1 = float4( 0.0, 0.0, 0.0, 1.0 );
    float4 checkerColor2 = float4( 0.2, 0.2, 0.2, 1.0 );
    
    float2 uv = in.textureCoordinate * data->size;
    uv -= float2( data->size / 2 );

    float4 col = checkerColor1;
    
    float cWidth = 12.0;
    float cHeight = 12.0;
    
    if ( fmod( floor( uv.x / cWidth ), 2.0 ) == 0.0 ) {
        if ( fmod( floor( uv.y / cHeight ), 2.0 ) != 0.0 ) col=checkerColor2;
    } else {
        if ( fmod( floor( uv.y / cHeight ), 2.0 ) == 0.0 ) col=checkerColor2;
    }
    
    return col;
}

typedef struct
{
    vector_float2 size;
    float round, borderSize;
    vector_float2 uv1;
    vector_float2 uv2;
    vector_float4 gradientColor1;
    vector_float4 gradientColor2;
    vector_float4 borderColor;
    
} CUBE_GRADIENT;

float fillMask(float dist)
{
    return clamp(-dist, 0.0, 1.0);
}

float borderMask(float dist, float width)
{
    //dist += 1.0;
    return clamp(dist + width, 0.0, 1.0) - clamp(dist, 0.0, 1.0);
}

float gradient_linear(float2 uv, float2 p1, float2 p2) {
    return clamp(dot(uv-p1,p2-p1)/dot(p2-p1,p2-p1),0.,1.);
}

kernel void
cubeGradient(texture2d<half, access::write> outTexture  [[texture(0)]],
             constant CUBE_GRADIENT        *data        [[buffer(1)]],
             uint2                          gid         [[thread_position_in_grid]])
{
    float2 uv = float2(gid) + data->borderSize/2;//float2(gid) * ( data->size + float2( data->borderSize ) );
    uv -= float2( data->size / 2 + data->borderSize / 2 );
    
    float2 d = abs( uv ) - data->size / 2 + data->round;
    float dist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0) - data->round;
    
    uv = float2(gid) / data->size;//in.textureCoordinate;
    uv.y = 1 - uv.y;
    float s = gradient_linear( uv, data->uv1, data->uv2 ) / 1;
    s = clamp(s, 0.0, 1.0);
    float4 col = float4( mix( data->gradientColor1.rgb, data->gradientColor2.rgb, s ), fillMask( dist ) );
    col = mix( col, data->borderColor, borderMask( dist, data->borderSize ) );

    outTexture.write(half4(col.x, col.y, col.z,fillMask( dist ) ), gid);
}
