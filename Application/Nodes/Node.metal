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

float nodeEquilateralTriangle( float2 p )
{
    const float k = sqrt(3.0);
    
    p.x = abs(p.x) - 1.0;
    p.y = p.y + 1.0/k;
    if( p.x + k*p.y > 0.0 ) p = float2( p.x - k*p.y, -k*p.x - p.y )/2.0;
    p.x -= clamp( p.x, -2.0, 0.0 );
    return -length(p)*sign(p.y);
}

float nodeTriangleIsosceles( float2 p, float2 q )
{
    p.x = abs(p.x);
    
    float2 a = p - q*clamp( dot(p,q)/dot(q,q), 0.0, 1.0 );
    float2 b = p - q*float2( clamp( p.x/q.x, 0.0, 1.0 ), 1.0 );
    float s = -sign( q.y );
    float2 d = min( float2( dot(a,a), s*(p.x*q.y-p.y*q.x) ),
                 float2( dot(b,b), s*(p.y-q.y)  ));
    
    return -sqrt(d.x)*sign(d.y);
}

float2 nodeRotateCW(float2 pos, float angle)
{
    float ca = cos(angle), sa = sin(angle);
    return pos * float2x2(ca, -sa, sa, ca);
}

float opSmoothUnion( float d1, float d2, float k ) {
    float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) - k*h*(1.0-h);
}

// --- Normal Gizmo

fragment float4 drawNode(RasterizerData        in [[stage_in]],
                         constant NODE_DATA   *data [[ buffer(0) ]] )
{
    float4 color = float4( 0 ), finalColor = float4( 0 );
    float2 size = data->size;
    float scale = data->scale;
    const float borderRound = data->borderRound * scale;

    float4 borderColor = float4(0.282, 0.286, 0.290, 1.000);//float4(0.173, 0.173, 0.173, 1.000);
    const float4 selBorderColor = float4(0.953, 0.957, 0.961, 1.000);//float4(0.820, 0.820, 0.820, 1.000);
    
    const float borderSize = 2 * scale;
    const float tRadius = 7 * scale;
    const float tDiam = 14 * scale;
    const float tSpacing = 25 * scale;

    if ( data->selected == 2 ) {
        // Success
        borderColor = float4(0.192, 0.573, 0.478, 1.000);
    } else
    if ( data->selected == 3 ) {
        // Failure
        borderColor = float4(0.988, 0.129, 0.188, 1.000);
    } else
    if ( data->selected == 4 ) {
        // Running
        borderColor = float4(0.620, 0.506, 0.165, 1.000);
    }
    
    // Body
    float2 uv = in.textureCoordinate * ( data->size + float2( borderSize ) * 2 );
    float2 uvCopy = uv;

    uv -= float2( data->size / 2.0 + borderSize / 2.0 );

    // Whole Body
    float2 d = abs( uv ) - data->size / 2 + borderRound + 5 * scale;
    float dist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0) - borderRound;
    
    // Inner Cutout
    uv.y += 20 * scale;
    float2 innerSize = data->size - float2(borderSize - 2, borderSize + 20 * scale * 2 - 2);
    d = abs( uv ) - innerSize / 2 + borderRound + 5 * scale;
    float innerDist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0) - borderRound;

    float2 point = in.textureCoordinate * data->size;
    point.y = data->size.y - point.y;

    /*
    for( int i = 0; i < data->leftTerminalCount; i += 1)
    {
        uv = uvCopy;
        uv -= float2( 7 * scale, size.y - data->leftTerminals[i].w );
        dist = max( dist, -(length( uv ) - tRadius) );
    }*/
    
    if ( data->topTerminalCount == 1 )
    {
        uv = uvCopy;
        uv -= float2( size.x / 2, size.y - data->topTerminal.w );
        dist = max( dist, -(length( uv ) - tRadius) );
    }
    
    /*
    if ( data->rightTerminalCount == 1 )
    {
        uv = uvCopy;
        uv -= float2( size.x - 4 * scale, size.y - data->rightTerminal.w );
        dist = max( dist, -(length( uv ) - tRadius) );
    }*/
    
    if ( data->bottomTerminalCount > 0 )
    {
        float left = (size.x - (data->bottomTerminalCount * tDiam + (data->bottomTerminalCount-1) * tSpacing)) / 2 + tRadius;
        for( int i = 0; i < data->bottomTerminalCount; i += 1)
        {
            uv = uvCopy;
            uv -= float2( left, 8 * scale );
            dist = max( dist, -(length( uv ) - tRadius) );
            
            left += tSpacing + tDiam;
        }
    }
    
    // Top left decorator
    /*
    {
        uv = uvCopy;
        uv -= float2( 24 * scale, data->size.y - 18 * scale );
    
        float2 d = abs( uv ) - float2(20, 20) * scale;
        float localDist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0) - 4.0 * scale;
        dist = opSmoothUnion( dist, localDist, 3 );
    }*/
    
    // Body Color (Brand)
    color = data->brandColor;
    finalColor = mix( finalColor, color, nodeFillMask( dist ) * color.w );
    
    // Inner Color
    color = float4(0.165, 0.169, 0.173, 1.000);
    finalColor = mix( finalColor, color, nodeFillMask( innerDist ) * color.w );

    // Brand Color
    //float s = nodeGradient_linear(point, float2( 80 * scale, 35 * scale ), float2( 5 * scale, 5 * scale ) );
    //finalColor = mix( finalColor, data->brandColor, nodeFillMask( dist ) * s);
    
    color = data->selected == 1 ? selBorderColor : borderColor;
    finalColor = mix( finalColor, color, nodeBorderMask( dist, borderSize ) * color.w );
    
    // Bottom border
    /*
    if ( data->hasIcons1.y == 1 )
    {
        uv = uvCopy;
        uv -= float2(size.x / 2 + 2.5 * scale, 16 * scale);
        
        d = abs( uv ) - float2((data->size.x - 10 * scale) / 2, 20 * scale);
        float box = (length(max(d,float2(0))) + min(max(d.x,d.y),0.0));
        //dist = min( dist,  );
        if ( dist < 0 ) {
            dist = box;
//            color = borderColor;
            finalColor = mix( finalColor, color, nodeFillMask( dist ) * color.w );
        }
    }*/
    
    // Terminal Bodies
    for( int i = 0; i < data->leftTerminalCount; i += 1)
    {
        uv = uvCopy;
        uv -= float2( 7 * scale, size.y - data->leftTerminals[i].w );
        dist = length( uv ) - tRadius;
        
        color = float4( data->leftTerminals[i].xyz, 1);
        finalColor = mix( finalColor, color, nodeFillMask( dist ) * color.w );
    }
    
    if ( data->topTerminalCount == 1 )
    {
        uv = uvCopy;
        uv -= float2( size.x / 2, size.y - data->topTerminal.w );
        dist = length( uv ) - tRadius;
        
        color = float4( data->topTerminal.xyz, 1);
        finalColor = mix( finalColor, color, nodeFillMask( dist ) * color.w );
    }
    
    if ( data->rightTerminalCount == 1 )
    {
        uv = uvCopy;
        uv -= float2( size.x - 4 * scale, size.y - data->rightTerminal.w );
        dist = length( uv ) - tRadius;
        
        color = float4( data->rightTerminal.xyz, 1);
        finalColor = mix( finalColor, color, nodeFillMask( dist ) * color.w );
    }
    
    if ( data->bottomTerminalCount > 0 )
    {
        float left = (size.x - (data->bottomTerminalCount * tDiam + (data->bottomTerminalCount-1) * tSpacing)) / 2 + tRadius;
        for( int i = 0; i < data->bottomTerminalCount; i += 1)
        {
            uv = uvCopy;
            uv -= float2( left, 8 * scale );
            dist = length( uv ) - tRadius;
            
            color = float4( data->bottomTerminal.xyz, 1);
            finalColor = mix( finalColor, color, nodeFillMask( dist ) * color.w );
            left += tSpacing + tDiam;
        }
    }
    
    /*
    // Maximize Icon
    if ( data->hasIcons1.x == 1 )
    {
        uv = uvCopy;
        uv -= float2( size.x - (41+20) * scale + 16 * scale, size.y - borderSize - 27 * scale );
        
        d = abs( uv ) - float2(6,5) * scale;
        dist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0) - 2 * scale;
        
        uv -= float2( 0, 10 ) * scale;
        d = abs( uv ) - float2(7, 1) * scale;
        dist = min( dist, length(max(d,float2(0))) + min(max(d.x,d.y),0.0) - 1);
        
        color = data->hoverIndex == 1 ? iconHoverColor : iconColor;
        finalColor = mix( finalColor, color, nodeFillMask( dist ) * color.w );
    }*/
    
    /* CLose symbol, dont use anymore
    if ( data->hasIcons1.y == 1 )
    {
        uv = uvCopy;
        uv -= float2( size.x - (38) * scale + 16 * scale, size.y - borderSize - 25 * scale );

        float diam = 7 * scale;
        float2 sp = float2(-diam, -diam);
        float2 ep = float2(diam, diam);
        float width = 1.5 * scale;

        float2 o = uv - sp;
        float2 l = ep - sp;
        
        float h = clamp( dot(o,l)/dot(l,l), 0.0, 1.0 );
        float dist = -(width-distance(o,l*h));
        
        sp = float2(-diam, diam);
        ep = float2(diam, -diam);
        
        o = uv - sp;
        l = ep - sp;
        
        h = clamp( dot(o,l)/dot(l,l), 0.0, 1.0 );
        float newDist = -(width-distance(o,l*h));
        dist = min(dist, newDist);
        
        color = data->hoverIndex == 2 ? iconHoverColor : iconColor;
        finalColor = mix( finalColor, color, nodeFillMask( dist ) * color.w );
     }*/

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
