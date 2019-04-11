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

// --- moduloPattern
fragment float4 moduloPattern(RasterizerData in [[stage_in]],
                                constant MODULO_PATTERN *data [[ buffer(0) ]] )
{
    const float4 checkerColor1 = float4( 0.0, 0.0, 0.0, 1.0 );
    const float4 checkerColor2 = float4( 0.2, 0.2, 0.2, 1.0 );
    
    float2 uv = in.textureCoordinate * data->size;
    uv -= float2( data->size / 2 );
    
    float2 q = floor(uv/12.);
    float4 col = mix( checkerColor1, checkerColor2, abs(fmod(q.x+q.y, 2.0)) );
    
    return col;
}

typedef struct
{
    float2 size;
    float2 camera;
} COORDINATE_SYSTEM;

float IsGridLine(float2 fragCoord)
{
    float2 vPixelsPerGridSquare = float2(40.0, 40.0);
    float2 vScreenPixelCoordinate = fragCoord.xy;
    float2 vGridSquareCoords = fract(vScreenPixelCoordinate / vPixelsPerGridSquare);
    float2 vGridSquarePixelCoords = vGridSquareCoords * vPixelsPerGridSquare;
    float2 vIsGridLine = step(vGridSquarePixelCoords, float2(1.0));
    
    float fIsGridLine = max(vIsGridLine.x, vIsGridLine.y);
    return fIsGridLine;
}

fragment float4 coordinateSystem(RasterizerData in [[stage_in]],
                                constant COORDINATE_SYSTEM *data [[ buffer(0) ]] )
{
    float2 uv = in.textureCoordinate * data->size;
    uv -= float2( data->size / 2 );
    uv += float2( data->camera.x, -data->camera.y);
    
    float4 checkerColor1 = float4(0.149, 0.149, 0.149, 1.000);
    float4 checkerColor2 = float4( 0.1, 0.1, 0.1, 1.0 );
    
    float grid = IsGridLine( uv );
    float4 col = mix(checkerColor2, checkerColor1, grid);
    
    float axis = min(abs(uv.x), abs(uv.y));
    col = mix( abs(uv.x) < abs(uv.y) ? float4(0.871, 0.122, 0.184, 1.000) : float4(0.165, 0.239, 0.969, 1.000), col, smoothstep( 0, 1, axis ) );
    
    return col;
}

fragment float4 nodeGridPattern(RasterizerData in [[stage_in]],
                                constant MODULO_PATTERN *data [[ buffer(0) ]] )
{
    
    float4 checkerColor1 = float4(0.149, 0.149, 0.149, 1.000);
    float4 checkerColor2 = float4( 0.1, 0.1, 0.1, 1.0 );
    
    float2 uv = in.textureCoordinate * data->size;
    uv -= float2( data->size / 2 );

    float grid = IsGridLine( uv );
    float4 col = mix(checkerColor2, checkerColor1, grid);
    
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
