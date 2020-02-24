//
//  Combo3DGizmo.metal
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
    float   lockedScaleAxes;
    
    float4  origin;
    float4  lookAt;
    float4  position;
    
} GIZMO3D;

#define PI 3.14159265359

float degrees(float radians)
{
    return radians * 180.0 / PI;
}

float radians(float degrees)
{
    return degrees * PI / 180.0;
}

float3 opU( float3 a, float3 b)
{
    if (a.x < b.x) return a;
    else return b;
}

float3 gizmo3DTranslate(float3 p, float3 t)
{
    return p - t;
}

float2 gimzo3DRotateCW(float2 pos, float angle)
{
    float ca = cos(angle), sa = sin(angle);
    return pos * float2x2(ca, -sa, sa, ca);
}

float2 gimzo3DRotateCWWithPivot(float2 pos, float angle, float2 pivot)
{
    float ca = cos(angle), sa = sin(angle);
    return pivot + (pos-pivot) * float2x2(ca, -sa, sa, ca);
}

/*
float2 rotateCCW (float2 pos, float angle)
{
    float ca = cos(angle), sa = sin(angle);
    return pos * float2x2(ca, sa, -sa, ca);
}

float2 rotateCCWWithPivot (float2 pos, float angle, float2 pivot)
{
    float ca = cos(angle), sa = sin(angle);
    return pivot + (pos-pivot) * float2x2(ca, sa, -sa, ca);
}*/

float sdCylinder( float3 p, float2 h )
{
    float2 d = abs(float2(length(p.xz),p.y)) - h;
    return min(max(d.x,d.y),0.0) + length(max(d,0.0));
}

float3 map(float3 pos, float3 off)
{
    float3 res = float3( 100000, 0, 0);
    
    float3 p = gizmo3DTranslate(pos, off + float3(0, -0.25, 0));

    float3 center = float3(sdCylinder(p, float2(0.02, 0.25)), 3, 3);
    res = opU(center, res);

    p = gizmo3DTranslate(pos, off + float3(0.25, 0, 0));
    p.xy = gimzo3DRotateCW( p.xy, radians(90) );
    float3 xMove = float3(sdCylinder(p, float2(0.02, 0.25)), 2, 2);

    res = opU(xMove, res);
    
    p = gizmo3DTranslate(pos, off + float3(0, 0, 0.25));
    p.yz = gimzo3DRotateCW( p.yz, radians(90) );
    float3 zMove = float3(sdCylinder(p, float2(0.02, 0.25)), 4, 4);

    res = opU(zMove, res);
    
    return res;
}

float3 castRay(float3 ro, float3 rd, float3 off)
{
    float tmin=0.001, tmax=100.0;

    float t=-1.0;
    float m=-1.0, id=-1.0;

    // if ( bbox( ro, rd, bounds, tmin, tmax ) )
    {
        float t=tmin;
        for( int i=0; i< 200; i++ )
        {
            // float precis = 0.02;
            float precis = 0.0005*t;

            float3 res = map(ro+rd*t, off);
            if( t < precis || t>tmax ) break;
            t += res.x * 0.7;
            m = res.y;
            id = res.z;
        }

        if( t > tmax ) { m=-1.0; id=-1.0; }
    }
    return float3( t, m, id );
}

/*
float3 calcNormal(float3 pos){
    float3 eps = float3(.0001,0,0);
    float3 nor = float3(
        map(pos+eps.xyy).x - map(pos-eps.xyy).x,
        map(pos+eps.yxy).x - map(pos-eps.yxy).x,
        map(pos+eps.yyx).x - map(pos-eps.yyx).x
    );
    return normalize(nor);
}*/

kernel void idsGizmoCombo3D(
                            texture2d<half, access::write>  outTexture  [[texture(0)]],
                            constant GIZMO3D               *data        [[ buffer(1) ]],
                            uint2                           gid         [[thread_position_in_grid]])
{
    float2 size = data->size;
    float2 uv = float2( gid.x, gid.y ) / size;

    float3 origin = data->origin.xyz;
    float3 lookAt = data->lookAt.xyz;
    float3 pos = data->position.xyz;

    float ratio = size.x / size.y;
    float2 pixelSize = float2(1.0) / size.xy;

    // --- Camera

    const float fov = 80.0;
    float halfWidth = tan(radians(fov) * 0.5);
    float halfHeight = halfWidth / ratio;

    float3 upVector = float3(0.0, 1.0, 0.0);

    float3 w = normalize(origin - lookAt);
    float3 u = cross(upVector, w);
    float3 v = cross(w, u);

    float3 lowerLeft = origin - halfWidth * u - halfHeight * v - w;
    float3 horizontal = u * halfWidth * 2.0;
    float3 vertical = v * halfHeight * 2.0;

    // ---

    float3 dir = lowerLeft - origin;
    float2 rand = float2(0.5);

    dir += horizontal * (pixelSize.x * rand.x + uv.x);
    dir += vertical * (pixelSize.y * rand.y + 1.0 - uv.y);

    float3 hit = castRay(origin, dir, pos);

    outTexture.write(half(hit.y), gid);
}

// --- Normal Gizmo
fragment float4 drawGizmoCombo3D(RasterizerData        in [[stage_in]],
                          constant GIZMO3D       *data [[ buffer(0) ]] )
{
    float2 uv = in.textureCoordinate;
    
    float2 size = data->size;
    float3 origin = data->origin.xyz;
    float3 lookAt = data->lookAt.xyz;
    float hoverState = data->hoverState;
    float3 pos = data->position.xyz;

    float4 finalColor = float4( 0 );

    float ratio = size.x / size.y;
    float2 pixelSize = float2(1.0) / size.xy;

    // --- Camera

    const float fov = 80.0;
    float halfWidth = tan(radians(fov) * 0.5);
    float halfHeight = halfWidth / ratio;

    float3 upVector = float3(0.0, 1.0, 0.0);

    float3 w = normalize(origin - lookAt);
    float3 u = cross(upVector, w);
    float3 v = cross(w, u);

    float3 lowerLeft = origin - halfWidth * u - halfHeight * v - w;
    float3 horizontal = u * halfWidth * 2.0;
    float3 vertical = v * halfHeight * 2.0;

    // ---

    float3 dir = lowerLeft - origin;
    float2 rand = float2(0.5);

    dir += horizontal * (pixelSize.x * rand.x + uv.x);
    dir += vertical * (pixelSize.y * rand.y + 1.0 - uv.y);
    
    const float4 hoverColor = float4(0.263, 0.443, 0.482, 1.000);
    //const float4 centerColor = float4(0.996, 0.941, 0.208, 1.000);
    const float4 xAxisColor = float4(0.153, 0.192, 0.984, 1.000);
    const float4 yAxisColor = float4(0.882, 0.102, 0.153, 1.000);
    const float4 zAxisColor = float4(0.188, 0.933, 0.176, 1.000);

    float3 hit = castRay(origin, dir, pos);
    
    if (hit.y == 2) {
        finalColor = hoverState == 2 ? hoverColor : xAxisColor;
    } else
    if (hit.y == 3) {
        finalColor =  hoverState == 3 ? hoverColor : yAxisColor;
    } else
    if (hit.y == 4) {
        finalColor =  hoverState == 4 ? hoverColor : zAxisColor;
    }
    
    /*
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
    
    finalColor.r /= finalColor.a;
    finalColor.g /= finalColor.a;
    finalColor.b /= finalColor.a;
    return finalColor;
}

