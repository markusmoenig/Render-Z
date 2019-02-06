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

float2 rotateCW(float2 pos, float angle)
{
    float ca = cos(angle), sa = sin(angle);
    return pos * float2x2(ca, -sa, sa, ca);
}

float sdTriangleIsosceles( float2 p, float2 q )
{
    p.x = abs(p.x);
    
    float2 a = p - q*clamp( dot(p,q)/dot(q,q), 0.0, 1.0 );
    float2 b = p - q*float2( clamp( p.x/q.x, 0.0, 1.0 ), 1.0 );
    float s = -sign( q.y );
    float2 d = min( float2( dot(a,a), s*(p.x*q.y-p.y*q.x) ),
                 float2( dot(b,b), s*(p.y-q.y)  ));
    
    return -sqrt(d.x)*sign(d.y);
}

fragment float4 drawGizmo(RasterizerData        in [[stage_in]],
                          constant GIZMO       *data [[ buffer(0) ]] )
{
    float2 uv = in.textureCoordinate * data->size;
    uv -= float2( data->size / 2 );
    float2 tuv = uv, d;
    float dist;
    float4 color, finalColor = float4( 0 );
    
    const float4 inactiveColor = float4(0.545, 0.545, 0.545, 1.000);
    const float4 hoverColor = float4(0.188, 0.933, 0.176, 1.000);
    const float4 centerColor = float4(0.996, 0.941, 0.208, 1.000);
    const float4 xAxisColor = float4(0.153, 0.192, 0.984, 1.000);
    const float4 yAxisColor = float4(0.882, 0.102, 0.153, 1.000);

    // Rotation Ring
    tuv = uv;
    dist = length( tuv ) - 70;
    color = data->hoverState == 4.0 ? hoverColor : centerColor;
    finalColor = mix( finalColor, color, gizmoBorderMask( dist, 3.0 ) * color.w );

    // Right arrow - Scale
    tuv = uv - float2(25,0);
    d = abs( tuv ) -  float2( 25, 3);
    dist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0);
    
    tuv = uv - float2(50,0.4);
    d = abs( tuv ) - float2( 8, 7);
    dist = min( dist, length(max(d,float2(0))) + min(max(d.x,d.y),0.0) );
    
    color = data->hoverState == 5.0 ? hoverColor : xAxisColor;
    finalColor = mix( finalColor, color, gizmoFillMask( dist ) * color.w );
    
    // Right arrow - Move
    tuv = uv - float2(75,0);
    d = abs( tuv ) -  float2( 18, 3);
    dist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0);
    
    tuv = uv - float2(110,0);
    tuv = rotateCW( tuv, 1.5708 );
    dist = min( dist, sdTriangleIsosceles( tuv, float2( 10, -20 ) ) );
    
    color = data->hoverState == 2.0 ? hoverColor : xAxisColor;
    finalColor = mix( finalColor, color, gizmoFillMask( dist ) * color.w );

    // Up arrow Scale
    tuv = uv - float2(0,25);
    d = abs( tuv ) -  float2( 3, 25);
    dist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0);
    
    tuv = uv - float2(0.3,50);
    d = abs( tuv ) - float2( 7, 8);
    dist = min( dist, length(max(d,float2(0))) + min(max(d.x,d.y),0.0) );
    
    color = data->hoverState == 6.0 ? hoverColor : xAxisColor;
    finalColor = mix( finalColor, color, gizmoFillMask( dist ) * color.w );
    
    // Up arrow Move
    tuv = uv - float2(0,75);
    d = abs( tuv ) -  float2( 3, 18);
    dist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0);
    tuv = uv - float2(0,110);
    dist = min( dist, sdTriangleIsosceles( tuv, float2( 10, -20 ) ) );
    
    color = data->hoverState == 3.0 ? hoverColor : yAxisColor;
    finalColor = mix( finalColor, color, gizmoFillMask( dist ) * color.w );

    // Center
    
    tuv = uv;
    dist = length( tuv ) - 5;
    color = data->hoverState == 1.0 ? hoverColor : centerColor;
    finalColor = mix( finalColor, color, gizmoFillMask( dist ) * color.w );

    dist = length( tuv ) - 15;
    if ( dist <= 0 ) {
        
        if ( data->hoverState == 1 ) finalColor = float4( hoverColor.xyz, gizmoFillMask( dist ) );
        else {
            float4 overlayColor = float4( centerColor.xyz, gizmoFillMask( dist ) );
            finalColor = mix( finalColor, overlayColor, 0.7 );
        }
    }
    
    return finalColor;
}
