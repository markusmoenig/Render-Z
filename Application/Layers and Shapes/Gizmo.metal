//
//  Gizmo.metal
//  Shape-Z
//
//  Created by Markus Moenig on 23/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

typedef struct
{
    float4 clipSpacePosition [[position]];
    float2 textureCoordinate;
} RasterizerData;

typedef struct
{
    float2  size;
    float   hoverState;
    float fill;
    
} GIZMO;

float gizmoFillMask(float dist)
{
    return clamp(-dist, 0.0, 1.0);
}

float gizmoBorderMask(float dist, float width)
{
    return clamp(dist + width, 0.0, 1.0) - clamp(dist, 0.0, 1.0);
}

fragment float4 drawGizmo(RasterizerData        in [[stage_in]],
                          constant GIZMO       *data [[ buffer(0) ]] )
{
    float2 uv = in.textureCoordinate * data->size;
    uv -= float2( data->size / 2 );
    
    const float4 inactiveColor = float4(0.545, 0.545, 0.545, 1.000);
    const float4 hoverColor = float4(0.188, 0.933, 0.176, 1.000);

    float dist = length( uv ) - 15;
    
    float4 centerColor = data->hoverState == 1.0 ? hoverColor : inactiveColor;
    
    float4 col = float4( centerColor.xyz, gizmoFillMask( dist ) * centerColor.w );
    
    return col;
}
