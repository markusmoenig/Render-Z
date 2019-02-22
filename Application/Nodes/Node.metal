//
//  Gizmo.metal
//  Shape-Z
//
//  Created by Markus Moenig on 23/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

#include <metal_stdlib>
#include "Application/Data.h"

using namespace metal;

typedef struct
{
    float4 clipSpacePosition [[position]];
    float2 textureCoordinate;
} RasterizerData;

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
                         constant NODE_DATA   *data [[ buffer(0) ]] )
{
//    float2 uv = in.textureCoordinate * data->size;
//    uv -= float2( data->size / 2 );
//    float2 tuv = uv, d;
//    float dist;
    float4 color = float4( 0 ), finalColor = float4( 0 );
    float2 size = data->size;
    float scale = data->scale;
    
//    const float4 inactiveColor = float4(0.545, 0.545, 0.545, 1.000);
    const float4 borderColor = float4(0.173, 0.173, 0.173, 1.000);
    const float4 selBorderColor = float4(0.820, 0.820, 0.820, 1.000);
//    const float4 centerColor = float4(0.702, 0.702, 0.702, 1.000);
    const float4 iconColor = float4(0.5, 0.5, 0.5, 1);
    const float4 iconHoverColor = float4(1);

    const float borderSize = 4 * scale;
    const float borderRound = 4;

    // Body
    float2 uv = in.textureCoordinate * ( data->size + float2( borderSize ) * 2 );
    float2 uvCopy = uv;

    uv -= float2( data->size / 2.0 + borderSize / 2.0 );

    float2 d = abs( uv ) - data->size / 2 + borderRound + 5 * scale;
    float dist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0) - borderRound;

    float2 point = in.textureCoordinate * data->size;
    point.y = data->size.y - point.y;

    for( int i = 0; i < data->leftTerminalCount; i += 1)
    {
        uv = uvCopy;
        uv -= float2( 10 * scale, size.y - data->leftTerminals[i].w );
        dist = min( dist, length( uv ) - 10 * scale );
    }
    
    if ( data->rightTerminalCount == 1 )
    {
        uv = uvCopy;
        uv -= float2( size.x - 8 * scale, size.y - data->rightTerminal.w );
        dist = min( dist, length( uv ) - 10 * scale );
    }
    
    // Body Color
    color = float4(0.118, 0.118, 0.118, 1.000);
    finalColor = mix( finalColor, color, nodeFillMask( dist ) * color.w );
    color = data->selected != 0 ? selBorderColor : borderColor;
    finalColor = mix( finalColor, color, nodeBorderMask( dist, borderSize ) * color.w );
    
    // Terminal Bodies
    for( int i = 0; i < data->leftTerminalCount; i += 1)
    {
        uv = uvCopy;
        uv -= float2( 10 * scale, size.y - data->leftTerminals[i].w );
        dist = length( uv ) - 7 * scale;
        
        color = float4( data->leftTerminals[i].xyz, 1);
        finalColor = mix( finalColor, color, nodeFillMask( dist ) * color.w );
    }
    
    if ( data->rightTerminalCount == 1 )
    {
        uv = uvCopy;
        uv -= float2( size.x - 8 * scale, size.y - data->rightTerminal.w );
        dist = length( uv ) - 7 * scale;
        
        color = float4( data->rightTerminal.xyz, 1);
        finalColor = mix( finalColor, color, nodeFillMask( dist ) * color.w );
    }
    
    // Body Color
    float s = nodeGradient_linear(point, float2( 0, 0 ), float2( 0, data->size.y ) );
    color = mix( float4(0.251, 0.251, 0.251, 1.000), float4(0.224, 0.224, 0.224, 1.000), clamp(s, 0, 1) );
    
    color = float4(0.118, 0.118, 0.118, 1.000);
    
    // Maximize Icon
    if ( data->hasIcons1.x == 1 )
    {
        uv = uvCopy;
        uv -= float2( size.x - 41 * scale + 16 * scale, size.y - borderSize - 22 * scale );
        
        d = abs( uv ) - float2(6,5) * scale;
        dist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0) - 2 * scale;
        
        uv -= float2( 0, 10 ) * scale;
        d = abs( uv ) - float2(7, 1) * scale;
        dist = min( dist, length(max(d,float2(0))) + min(max(d.x,d.y),0.0) - 1);
        
        color = data->hoverIndex == 1 ? iconHoverColor : iconColor;
        finalColor = mix( finalColor, color, nodeFillMask( dist ) * color.w );
    }

//    finalColor = mix( finalColor, color, nodeFillMask( dist ) * color.w );
//    color = float4(0.212, 0.208, 0.208, 1.000);

//    finalColor = mix( finalColor, color, nodeBorderMask( dist, borderSize ) * color.w );
    
    /*
    if ( point.y <= 25 ) {
        float s = nodeGradient_linear(point, float2( 0, 19 ), float2( 0, 0 ) );
        color = mix(float4(0.251, 0.251, 0.251, 1.000), float4(0.298, 0.298, 0.298, 1.000), clamp(s, 0, 1) );

        finalColor = mix( finalColor, color, nodeFillMask( dist ) * color.w );
        color = data->selected == 1 ? selBorderColor : borderColor;
        finalColor = mix( finalColor, color, nodeBorderMask( dist, borderSize ) * color.w );
    } else
    if ( point.y <= 26 && point.x > 2.5 && point.x < data->size.x - 4 ) {
        color = float4(0, 0, 0, 1.000);
        finalColor = mix( finalColor, color, nodeFillMask( dist ) * color.w );
    }
    else {
        color = centerColor;
        finalColor = mix( finalColor, color, nodeFillMask( dist ) * color.w );
    
        color = data->selected == 1 ? selBorderColor : borderColor;
        finalColor = mix( finalColor, color, nodeBorderMask( dist, borderSize ) * color.w );
    }
    
    // Preview Area
    
    if ( 1 )
    {
        float previewStartY = data->size.y - 134;
        if ( point.y >= data->size.y - 135 && point.y <= data->size.y - 134 && point.x > 2.5 && point.x < data->size.x - 4)
        {
            color = float4(0, 0, 0, 1.000);
            finalColor = mix( finalColor, color, nodeFillMask( dist ) * color.w );
        }
        if ( point.y > previewStartY && point.x > 2.5 && point.x < data->size.x - 4 )
        {
            float s = nodeGradient_linear(point, float2( 0, previewStartY), float2( 0, previewStartY + 116 ) );
            color = mix(float4(0.631, 0.631, 0.631, 1.000), float4(0.255, 0.255, 0.255, 1.000), clamp(s, 0, 1) );
            
            finalColor = mix( finalColor, color, nodeFillMask( dist ) * color.w );
        }
        
        if ( point.y >= previewStartY + 5 && point.y <= previewStartY + 116 && point.x > 8 && point.x < data->size.x - 10)
        {
            float2 d = abs( uv + float2( 0, 60 ) ) - float2(67, 50);
            float dist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0);
            
            float4 checkerColor1 = float4(0.698, 0.698, 0.698, 0.8);
            float4 checkerColor2 = float4(0.157, 0.157, 0.157, 0.8);
            
            color = checkerColor1;
            
            float cWidth = 20.0;
            float cHeight = 20.0;
            
            float2 uv = in.textureCoordinate * data->size - float2( 4, 4);
            
            if ( fmod( floor( uv.x / cWidth ), 2.0 ) == 0.0 ) {
                if ( fmod( floor( uv.y / cHeight ), 2.0 ) != 0.0 ) color = checkerColor2;
            } else {
                if ( fmod( floor( uv.y / cHeight ), 2.0 ) == 0.0 ) color = checkerColor2;
            }
            
            finalColor = mix( finalColor, color, nodeFillMask( dist ) * color.w );
            color = float4(0, 0, 0, 1);
            finalColor = mix( finalColor, color, nodeBorderMask( dist, 2 ) );
        }
        
        finalColor.w = 1.0;
    }
    
    float footerStartY = data->size.y - 20;
    if ( point.y >= footerStartY && point.y <= footerStartY + 1 && point.x > 2.5 && point.x < data->size.x - 4 )
    {
        color = float4(0, 0, 0, 1.000);
        finalColor = mix( finalColor, color, nodeFillMask( dist ) * color.w );
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
    */
    return finalColor;
}
