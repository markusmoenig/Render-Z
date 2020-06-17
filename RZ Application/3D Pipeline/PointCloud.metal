//
//  PointCloud.metal
//  Shape-Z
//
//  Created by Markus Moenig on 11/6/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
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
    vector_float2 position;
    vector_float2 textureCoordinate;
} MM_Vertex;

vertex RasterizerData
PRTQuadVertexShader(uint vertexID [[ vertex_id ]],
             constant MM_Vertex *vertexArray [[ buffer(0) ]],
             constant vector_uint2 *viewportSizePointer  [[ buffer(1) ]])
{
    RasterizerData out;
    
    float2 pixelSpacePosition = vertexArray[vertexID].position.xy;
    float2 viewportSize = float2(*viewportSizePointer);
    
    out.clipSpacePosition.xy = pixelSpacePosition / (viewportSize / 2.0);
    out.clipSpacePosition.z = 0.0;
    out.clipSpacePosition.w = 1.0;
    
    out.textureCoordinate = vertexArray[vertexID].textureCoordinate;
    return out;
}

fragment float4 prtMergeLocal(RasterizerData in [[stage_in]])
{
    /*
    float2 uv = in.textureCoordinate * float2( data->radius * 2 + data->borderSize, data->radius * 2 + data->borderSize );
    uv -= float2( data->radius + data->borderSize / 2 );
    
    float dist = length( uv ) - data->radius;
    
    
    float4 col = float4( data->fillColor.x, data->fillColor.y, data->fillColor.z, m4mFillMask( dist ) * data->fillColor.w );
    col = mix( col, data->borderColor, m4mBorderMask( dist, data->borderSize ) );
    */
    
    float4 outColor = float4(0);
    return outColor;
}
