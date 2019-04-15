//
//  Compute.metal
//  Framework
//
//  Created by Markus Moenig on 01.01.19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;

#import "Mad4Metal_types.h"

typedef struct
{
    float4 clipSpacePosition [[position]];
    float2 textureCoordinate;
} RasterizerData;

// Quad Vertex Function
vertex RasterizerData
m4mQuadVertexShader(uint vertexID [[ vertex_id ]],
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

// --- SDF utilities

float m4mFillMask(float dist)
{
    return clamp(-dist, 0.0, 1.0);
}

float m4mBorderMask(float dist, float width)
{
    //dist += 1.0;
    return clamp(dist + width, 0.0, 1.0) - clamp(dist, 0.0, 1.0);
}

// --- Sphere Drawable
fragment float4 m4mSphereDrawable(RasterizerData in [[stage_in]],
                               constant MM_SPHERE *data [[ buffer(0) ]] )
{
    float2 uv = in.textureCoordinate * float2( data->radius * 2 + data->borderSize, data->radius * 2 + data->borderSize );
    uv -= float2( data->radius + data->borderSize / 2 );
    
    float dist = length( uv ) - data->radius;
    
    float4 col = float4( data->fillColor.x, data->fillColor.y, data->fillColor.z, m4mFillMask( dist ) );
    col = mix( col, data->borderColor, m4mBorderMask( dist, data->borderSize ) );
    return col;
}

float m4mGradient_linear(float2 uv, float2 p1, float2 p2) {
    return clamp(dot(uv-p1,p2-p1)/dot(p2-p1,p2-p1),0.,1.);
}
/*
float sdLine( float2 uv, float2 pa, float2 pb, float r) {
    float2 o = uv-pa;
    float2 l = pb-pa;
    float h = clamp( dot(o,l)/dot(l,l), 0.0, 1.0 );
    return -(r-distance(o,l*h));
}*/

fragment float4 m4mLineDrawable(RasterizerData in [[stage_in]],
                               constant MM_LINE *data [[ buffer(0) ]] )
{
    float2 uv = in.textureCoordinate * ( data->size + float2( data->borderSize ) * 2.0 );
    uv -= float2( data->size / 2.0 + data->borderSize / 2.0 );
//    uv -= (data->sp + data->ep) / 2;

    float2 o = uv - data->sp;
    float2 l = data->ep - data->sp;
    
    float h = clamp( dot(o,l)/dot(l,l), 0.0, 1.0 );
    float dist = -(data->width-distance(o,l*h));
    
    float4 col = float4( data->fillColor.x, data->fillColor.y, data->fillColor.z, m4mFillMask( dist ) * data->fillColor.w );
    col = mix( col, data->borderColor, m4mBorderMask( dist, data->borderSize ) );
    
    return col;
}

// --- Box Drawable
fragment float4 m4mBoxDrawable(RasterizerData in [[stage_in]],
                               constant MM_BOX *data [[ buffer(0) ]] )
{
    float2 uv = in.textureCoordinate * ( data->size + float2( data->borderSize ) * 2.0 );
    uv -= float2( data->size / 2.0 + data->borderSize );

    float2 d = abs( uv ) - data->size / 2 + data->round;
    float dist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0) - data->round;
    
    float4 col = float4( data->fillColor.x, data->fillColor.y, data->fillColor.z, m4mFillMask( dist ) * data->fillColor.w );
    col = mix( col, data->borderColor, m4mBorderMask( dist, data->borderSize ) );
    return col;
}

// --- Box Gradient
fragment float4 m4mBoxGradientDrawable(RasterizerData in [[stage_in]],
                                       constant MM_BOX_GRADIENT *data [[ buffer(0) ]] )
{
    float2 uv = in.textureCoordinate * ( data->size + float2( data->borderSize ) * 2.0);
    uv -= float2( data->size / 2.0 + data->borderSize / 2.0 );
    
    float2 d = abs( uv ) - data->size / 2 + data->round;
    float dist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0) - data->round;
    
    uv = in.textureCoordinate;
    uv.y = 1 - uv.y;
    float s = m4mGradient_linear( uv, data->uv1, data->uv2 ) / 1;
    s = clamp(s, 0.0, 1.0);
    float4 col = float4( mix( data->gradientColor1.rgb, data->gradientColor2.rgb, s ), m4mFillMask( dist ) );
    col = mix( col, data->borderColor, m4mBorderMask( dist, data->borderSize ) );
    
    return col;
}

// --- Box Drawable
fragment float4 m4mBoxedMenuDrawable(RasterizerData in [[stage_in]],
                                     constant MM_BOXEDMENU *data [[ buffer(0) ]] )
{
    float2 uv = in.textureCoordinate * ( data->size + float2( data->borderSize ) * 2.0 );
    uv -= float2( data->size / 2.0 + data->borderSize / 2.0 );
    
    // Main
    float2 d = abs( uv ) - data->size / 2 + data->round;
    float dist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0) - data->round;
    
    float4 col = float4( data->fillColor.x, data->fillColor.y, data->fillColor.z, m4mFillMask( dist ) * data->fillColor.w );
    col = mix( col, data->borderColor, m4mBorderMask( dist, data->borderSize ) );
    
    // --- Lines
    
    float lineWidth = 1.5;
    float lineRound = 4.0;

    // --- Middle
    uv = in.textureCoordinate * data->size;
    uv -= data->size / 2.0;

    d = abs( uv ) -  float2( data->size.x / 3, lineWidth) + lineRound;
    dist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0) - lineRound;
    
//    col = float4( data->fillColor.x, data->fillColor.y, data->fillColor.z, m4mFillMask( dist ) * data->fillColor.w );
    col = mix( col,  float4( 0.957, 0.957, 0.957, 1 ), m4mFillMask( dist ) );

    // --- Top
    uv = in.textureCoordinate * data->size;
    uv -= data->size / 2.0;
    uv.y -= data->size.y / 4;
    
    d = abs( uv ) -  float2( data->size.x / 3, lineWidth) + lineRound;
    dist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0) - lineRound;
    col = mix( col,  float4( 0.957, 0.957, 0.957, 1 ), m4mFillMask( dist ) );
    
    // --- Bottom
    uv = in.textureCoordinate * data->size;
    uv -= data->size / 2.0;
    uv.y += data->size.y / 4;
    
    d = abs( uv ) -  float2( data->size.x / 3, lineWidth) + lineRound;
    dist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0) - lineRound;
    col = mix( col,  float4( 0.957, 0.957, 0.957, 1 ), m4mFillMask( dist ) );
    
    return col;
}

// --- Boxed Plus Drawable
fragment float4 m4mBoxedPlusDrawable(RasterizerData in [[stage_in]],
                                      constant MM_BOXEDMENU *data [[ buffer(0) ]] )
{
    float2 uv = in.textureCoordinate * ( data->size + float2( data->borderSize ) * 2.0 );
    uv -= float2( data->size / 2.0 + data->borderSize / 2.0 );
    
    // Main
    float2 d = abs( uv ) - data->size / 2 + data->round;
    float dist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0) - data->round;
    
    float4 col = float4( data->fillColor.x, data->fillColor.y, data->fillColor.z, m4mFillMask( dist ) * data->fillColor.w );
    col = mix( col, data->borderColor, m4mBorderMask( dist, data->borderSize ) );
    
    // --- Lines
    
    float lineWidth = 2.5;
    float lineRound = 4.0;
    
    // --- Middle
    uv = in.textureCoordinate * data->size;
    uv -= data->size / 2.0;
    
    d = abs( uv ) -  float2( data->size.x / 3, lineWidth) + lineRound;
    dist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0) - lineRound;
    col = mix( col,  float4( 0.957, 0.957, 0.957, 1 ), m4mFillMask( dist ) );
    
    d = abs( uv ) -  float2(lineWidth, data->size.y / 3) + lineRound;
    dist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0) - lineRound;
    col = mix( col,  float4( 0.957, 0.957, 0.957, 1 ), m4mFillMask( dist ) );
    
    return col;
}

// --- Boxed Minus Drawable
fragment float4 m4mBoxedMinusDrawable(RasterizerData in [[stage_in]],
                                     constant MM_BOXEDMENU *data [[ buffer(0) ]] )
{
    float2 uv = in.textureCoordinate * ( data->size + float2( data->borderSize ) * 2.0 );
    uv -= float2( data->size / 2.0 + data->borderSize / 2.0 );
    
    // Main
    float2 d = abs( uv ) - data->size / 2 + data->round;
    float dist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0) - data->round;
    
    float4 col = float4( data->fillColor.x, data->fillColor.y, data->fillColor.z, m4mFillMask( dist ) * data->fillColor.w );
    col = mix( col, data->borderColor, m4mBorderMask( dist, data->borderSize ) );
    
    // --- Lines
    
    float lineWidth = 2.5;
    float lineRound = 4.0;
    
    // --- Middle
    uv = in.textureCoordinate * data->size;
    uv -= data->size / 2.0;
    
    d = abs( uv ) -  float2( data->size.x / 3, lineWidth) + lineRound;
    dist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0) - lineRound;
    col = mix( col,  float4( 0.957, 0.957, 0.957, 1 ), m4mFillMask( dist ) );
    
    return col;
}


/// Texture drawable
fragment float4 m4mTextureDrawable(RasterizerData in [[stage_in]],
                                constant MM_TEXTURE *data [[ buffer(0) ]],
                                texture2d<half> inTexture [[ texture(1) ]])
{
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);
    
    float2 uv = in.textureCoordinate;// * data->screenSize;
    uv.y = 1 - uv.y;
    
    const half4 colorSample = inTexture.sample (textureSampler, uv );
        
    float4 sample = float4( colorSample );
    return sample;
}

float m4mMedian(float r, float g, float b) {
    return max(min(r, g), min(max(r, g), b));
}

/// Draw a text char
fragment float4 m4mTextDrawable(RasterizerData in [[stage_in]],
                                constant MM_TEXT *data [[ buffer(0) ]],
                                texture2d<half> inTexture [[ texture(1) ]])
{
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);
    
    float2 uv = in.textureCoordinate;
    uv.y = 1 - uv.y;

    uv /= data->atlasSize / data->fontSize;
    uv += data->fontPos / data->atlasSize;

    const half4 colorSample = inTexture.sample (textureSampler, uv );
    
    float4 sample = float4( colorSample );
    
    float d = m4mMedian(sample.r, sample.g, sample.b) - 0.5;
    float w = clamp(d/fwidth(d) + 0.5, 0.0, 1.0);
    return float4( data->color.x, data->color.y, data->color.z, w * data->color.w );
}


#define M_PI 3.1415926535897932384626433832795

float3 getHueColor(float2 pos)
{
    float theta = 3.0 + 3.0 * atan2(pos.x, pos.y) / M_PI;
    
//    float3 color = float3(0.0);
    return clamp(abs(fmod(theta + float3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}

float2 hsl2xy(float3 hsl)
{
    float h = hsl.r;
    float s = hsl.g;
    float l = hsl.b;
    float theta = 0;
    
    if(h==0.0){
        if(s==1.0){
            theta = 4.0-l;
        } else {
            theta = 2.0+s;
        }
    }else if(h==1.0){
        if(s==0.0){
            theta = l;
        } else {
            theta = 6.0-s;
        }
    }else{
        if(s==0.0){
            theta = 2.0-h;
        } else {
            theta = 4.0+h;
        }
    }
    
    theta = M_PI/6 * theta;
    return float2(cos(theta), sin(theta));
}

// --- ColorWheel Drawable
fragment float4 m4mColorWheelDrawable(RasterizerData in [[stage_in]],
                               constant MM_COLORWHEEL *data [[ buffer(0) ]] )
{
    float2 uv = float2(2.0, -2.0) * (in.textureCoordinate * data->size - 0.5 * data->size) / data->size.y;

    float l = length(uv);

    l = 1.0 - abs((l - 0.875) * 8.0);
    l = clamp(l * data->size.y * 0.0625, 0.0, 1.0);
    
    float4 col = float4(l * getHueColor(uv), l);
    
    if (l < 0.75)
    {
        uv = uv / 0.75;
        
        float2 mouse = hsl2xy(data->color.xyz);// float2(0.0, -1.0);
        float3 pickedHueColor = getHueColor(mouse);

        mouse = normalize(mouse);
        
        float sat = 1.5 - (dot(uv, mouse) + 0.5); // [0.0,1.5]
        
        if (sat < 1.5)
        {
            float h = sat / sqrt(3.0);
            float2 om = cross(float3(mouse, 0.0), float3(0.0, 0.0, 1.0)).xy;

            float lum = dot(uv, om);
            
            if (abs(lum) <= h)
            {
                l = clamp((h - abs(lum)) * data->size.y * 0.5, 0.0, 1.0) * clamp((1.5 - sat) / 1.5 * data->size.y * 0.5, 0.0, 1.0); // Fake antialiasing
                col = float4(l * mix(pickedHueColor, float3(0.5 * (lum + h) / h), sat / 1.5), l);
            }
        }
    }

    return col;
}
