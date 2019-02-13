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
    float   selected;
    float   hoverIndex;
    
} NODE;

float nodeFillMask(float dist)
{
    return clamp(-dist, 0.0, 1.0);
}

float nodeBorderMask(float dist, float width)
{
    return clamp(dist + width, 0.0, 1.0) - clamp(dist, 0.0, 1.0);
}

float nodeGradient_linear(float2 uv, float2 p1, float2 p2) {
    return clamp(dot(uv-p1,p2-p1)/dot(p2-p1,p2-p1),0.,1.);
}

// --- Normal Gizmo

fragment float4 drawNode(RasterizerData        in [[stage_in]],
                         constant NODE       *data [[ buffer(0) ]] )
{
//    float2 uv = in.textureCoordinate * data->size;
//    uv -= float2( data->size / 2 );
//    float2 tuv = uv, d;
//    float dist;
    float4 color, finalColor = float4( 0 );
    
//    const float4 inactiveColor = float4(0.545, 0.545, 0.545, 1.000);
    const float4 borderColor = float4(0.173, 0.173, 0.173, 1.000);
    const float4 selBorderColor = float4(0.820, 0.820, 0.820, 1.000);
    const float4 centerColor = float4(0.702, 0.702, 0.702, 1.000);
    const float4 iconColor = float4(0.5, 0.5, 0.5, 1);
    const float4 iconHoverColor = float4(1);

    const float borderSize = 2;
    const float borderRound = 4;

    // Body
    
    float2 uv = in.textureCoordinate * ( data->size + float2( borderSize ) * 2.0 );
    uv -= float2( data->size / 2.0 + borderSize / 2.0 );
    float2 uvCopy = uv;
    
    float2 d = abs( uv ) - data->size / 2 + borderRound;
    float dist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0) - borderRound;
    
    float2 point = in.textureCoordinate * data->size;
    point.y = data->size.y - point.y;

    if ( point.y <= 25 ) {
        float s = nodeGradient_linear(point, float2( 0, 19 ), float2( 0, 0 ) );
        color = mix(float4(0.251, 0.251, 0.251, 1.000), float4(0.298, 0.298, 0.298, 1.000), clamp(s, 0, 1) );

        finalColor = mix( finalColor, color, nodeFillMask( dist ) * color.w );
        color = data->selected == 1 ? selBorderColor : borderColor;
        finalColor = mix( finalColor, color, nodeBorderMask( dist, borderSize ) * color.w );
    } else
    if ( point.y <= 26 && point.x > 3 && point.x < data->size.x - 5 ) {
        color = float4(0, 0, 0, 1.000);
        finalColor = mix( finalColor, color, nodeFillMask( dist ) * color.w );
    }
    else {
        color = centerColor;
        finalColor = mix( finalColor, color, nodeFillMask( dist ) * color.w );
    
        color = data->selected == 1 ? selBorderColor : borderColor;
        finalColor = mix( finalColor, color, nodeBorderMask( dist, borderSize ) * color.w );
    }
    
    // Header

    uv = uvCopy;
    uv -= float2( 60, 120.5 );

    d = abs( uv ) - float2(6,5);
    dist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0) - 2;
    
    uv -= float2( 0, 10 );
    d = abs( uv ) - float2(7, 1);
    dist = min( dist, length(max(d,float2(0))) + min(max(d.x,d.y),0.0) - 1);
    
    color = data->hoverIndex == 1 ? iconHoverColor : iconColor;
    finalColor = mix( finalColor, color, nodeFillMask( dist ) * color.w );
    
    /*
    // Right arrow - Scale
    tuv = uv - float2(25,0);
    d = abs( tuv ) -  float2( 25, 3);
    dist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0);
    
    tuv = uv - float2(50,0.4);
    d = abs( tuv ) - float2( 8, 7);
    dist = min( dist, length(max(d,float2(0))) + min(max(d.x,d.y),0.0) );
    
    color = data->hoverState == 5.0 || data->lockedScaleAxes == 1.0 ? hoverColor : xAxisColor;
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
    
    tuv = uv - float2(0.4,50);
    d = abs( tuv ) - float2( 7, 8);
    dist = min( dist, length(max(d,float2(0))) + min(max(d.x,d.y),0.0) );
    
    color = data->hoverState == 6.0 || data->lockedScaleAxes == 1.0 ? hoverColor : yAxisColor;
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
     */
    
    return finalColor;
}
