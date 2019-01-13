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
 
// Rec. 709 luma values for grayscale image conversion
//constant half3 kRec709Luma = half3(0.2126, 0.7152, 0.0722);

// Grayscale compute kernel
kernel void
grayscaleKernel(texture2d<half, access::write>  outTexture  [[texture(0)]],
                texture2d<half, access::read>   inTexture   [[texture(1)]],
                uint2                           gid         [[thread_position_in_grid]])
{
    // Check if the pixel is within the bounds of the output texture
    if((gid.x >= outTexture.get_width()) || (gid.y >= outTexture.get_height()))
    {
//         Return early if the pixel is out of bounds
        outTexture.write(half4(1, 1, 1, 1.0), gid);
        return;
    } 
    
//    half4 inColor  = inTexture.read(gid);
//    half  gray     = dot(inColor.rgb, kRec709Luma);
    //outTexture.write(half4(gray, gray, gray, 1.0), gid);
//    outTexture.write(half4(255.0, 255.0, 255.0, 255.0), gid);
    //outTexture.write(half4(1, 0, 0, 1.0), gid);

    float2 uv = float2( gid.x - outTexture.get_width() / 2.,
                       gid.y - outTexture.get_height() / 2. );
    
    float len = length( uv ) - 20;
    
    if ( len <= 0 ) outTexture.write( half4(1, 1, 1, 1.0), gid );
    else outTexture.write(half4(1, 0, 0, 1.0), gid);
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
