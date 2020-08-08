//
//  Combo3DGizmo.metal
//  Shape-Z
//
//  Created by Markus Moenig on 23/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#define MOVE_X 2.0
#define MOVE_Y 3.0
#define MOVE_Z 4.0
#define SCALE_X 6.0
#define SCALE_Y 7.0
#define SCALE_Z 8.0
#define ROTATE_X 14.0
#define ROTATE_Y 15.0
#define ROTATE_Z 16.0

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
    float4  rotation;
    float4  pivot;

} GIZMO3D;

#define PI 3.14159265359

float2 rotate(float2 pos, float angle)
{
    float ca = cos(angle), sa = sin(angle);
    return pos * float2x2(ca, sa, -sa, ca);
}

float2 rotatePivot(float2 pos, float angle, float2 pivot)
{
    float ca = cos(angle), sa = sin(angle);
    return pivot + (pos-pivot) * float2x2(ca, sa, -sa, ca);
}

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

float sdConeSection(float3 p, float h, float r1, float r2)
{
    float d1 = -p.y - h;
    float q = p.y - h;
    float si = 0.5*(r1-r2)/h;
    float d2 = max( sqrt( dot(p.xz,p.xz)*(1.0-si*si)) + q*si - r2, q );
    return length(max(float2(d1,d2),0.0)) + min(max(d1,d2), 0.);
}

float sdCappedTorus(float3 p, float2 sc, float ra, float rb)
{
    p.x = abs(p.x);
    float k = (sc.y*p.x>sc.x*p.y) ? dot(p.xy,sc) : length(p.xy);
    return sqrt( dot(p,p) + ra*ra - 2.0*ra*k ) - rb;
}

float dot2( float2 v ) { return dot(v,v); }

float sdJoint3DSphere( float3 p, float l, float a, float w)
{
    // if perfectly straight
    if( abs(a)<0.001 ) return length(p-float3(0,clamp(p.y,0.0,l),0))-w;
    
    // parameters
    float2  sc = float2(sin(a),cos(a));
    float ra = 0.5*l/a;
    
    // recenter
    p.x -= ra;
    
    // reflect
    float2 q = p.xy - 2.0*sc*max(0.0,dot(sc,p.xy));

    float u = abs(ra)-length(q);
    float d2 = (q.y<0.0) ? dot2( q+float2(ra,0.0) ) : u*u;
    return sqrt(d2+p.z*p.z)-w;
}

float sdBox( float3 p, float3 b )
{
    float3 q = abs(p) - b;
    return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

float3 translateForXAxis(float3 pos, float3 off, float3 move)
{
    float3 p = gizmo3DTranslate(pos, off + move);
    p.xy = gimzo3DRotateCW( p.xy, radians(-90) );
    return p;
}

float3 translateForZAxis(float3 pos, float3 off, float3 move)
{
    float3 p = gizmo3DTranslate(pos, off + move);
    p.yz = gimzo3DRotateCW( p.yz, radians(90) );
    return p;
}

float3 gizmo3DTranslate(float3 p, float3 t, constant GIZMO3D *data)
{
    return p - t;
}

float3 transformAll(float3 pos, float3 localOffset, float3 localRotation, constant GIZMO3D *data)
{
    float3 __originalPosition = float3(data->position.xyz + localOffset);
    float3 position = pos - __originalPosition;
    float3 __offsetFromCenter = data->pivot.xyz - __originalPosition;

    float3 rotation = data->rotation.xyz;
    
    position.yz = rotatePivot( position.yz, radians(rotation.x), __offsetFromCenter.yz);
    position.xz = rotatePivot( position.xz, radians(rotation.y), __offsetFromCenter.xz);
    position.xy = rotatePivot( position.xy, radians(rotation.z), __offsetFromCenter.xy);
    
    position.yz = rotate( position.yz, radians(localRotation.x));
    position.xz = rotate( position.xz, radians(localRotation.y));
    position.xy = rotate( position.xy, radians(localRotation.z));
    
    return position;
}

float3 map(float3 pos, constant GIZMO3D *data)
{
    float3 res = float3( 100000, 0, 0);
    
    res = opU(float3(sdCylinder(transformAll(pos, float3(0, 0.15, 0), float3(0), data), float2(0.02, 0.15)), SCALE_Y, SCALE_Y), res);
    res = opU(float3(sdBox(transformAll(pos, float3(0, 0.30, 0), float3(0),data), float3(0.04, 0.04, 0.04)), SCALE_Y, SCALE_Y), res);
    res = opU(float3(sdCylinder(transformAll(pos, float3(0, 0.45, 0), float3(0), data), float2(0.02, 0.15)), MOVE_Y, MOVE_Y), res);
    res = opU(float3(sdConeSection(transformAll(pos, float3(0, 0.65, 0), float3(0), data), 0.05, 0.05, 0.001), MOVE_Y, MOVE_Y), res);
    
    res = opU(float3(sdCylinder(transformAll(pos, float3(0.15, 0, 0), float3(0,0,90), data), float2(0.02, 0.15)), SCALE_X, SCALE_X), res);
    res = opU(float3(sdBox(transformAll(pos, float3(0.30, 0, 0), float3(0,0,90), data), float3(0.04, 0.04, 0.04)), SCALE_X, SCALE_X), res);
    res = opU(float3(sdCylinder(transformAll(pos, float3(0.45, 0, 0), float3(0,0,90), data), float2(0.02, 0.15)), MOVE_X, MOVE_X), res);
    res = opU(float3(sdConeSection(transformAll(pos, float3(0.65, 0, 0), float3(0,0,90), data), 0.05, 0.001, 0.05), MOVE_X, MOVE_X), res);

    res = opU(float3(sdCylinder(transformAll(pos, float3(0, 0, 0.15), float3(-90,0,0), data), float2(0.02, 0.15)), SCALE_Z, SCALE_Z), res);
    res = opU(float3(sdBox(transformAll(pos, float3(0, 0, 0.30), float3(-90,0,0), data), float3(0.04, 0.04, 0.04)), SCALE_Z, SCALE_Z), res);
    res = opU(float3(sdCylinder(transformAll(pos, float3(0, 0, 0.45), float3(-90,0,0), data), float2(0.02, 0.15)), MOVE_Z, MOVE_Z), res);
    res = opU(float3(sdConeSection(transformAll(pos, float3(0, 0, 0.65), float3(-90,0,0), data), 0.05, 0.001, 0.05), MOVE_Z, MOVE_Z), res);
    
    // Rotate
    res = opU(float3(sdJoint3DSphere(transformAll(pos, float3(0.0, 0.45, 0), float3(0,90,-90), data), 0.7, 3.14 / 4, 0.02), ROTATE_X, ROTATE_X), res);
    res = opU(float3(sdJoint3DSphere(transformAll(pos, float3(0.0, 0, 0.45), float3(90,0,-90), data), 0.7, 3.14 / 4, 0.02), ROTATE_Y, ROTATE_Y), res);
    res = opU(float3(sdJoint3DSphere(transformAll(pos, float3(0.0, 0.45, 0), float3(0,0,-90), data), 0.7, 3.14 / 4, 0.02), ROTATE_Z, ROTATE_Z), res);

    return res;
}

float3 mapPoint(float3 pos, float3 off, constant GIZMO3D *data)
{
    float3 res = float3( 100000, 0, 0);
    
    res = opU(float3(sdCylinder(gizmo3DTranslate(pos, off + float3(0, 0.30, 0)), float2(0.02, 0.30)), MOVE_Y, MOVE_Y), res);
    res = opU(float3(sdConeSection(gizmo3DTranslate(pos, off + float3(0, 0.65, 0)), 0.05, 0.05, 0.001), MOVE_Y, MOVE_Y), res);
    
    res = opU(float3(sdCylinder(translateForXAxis(pos, off, float3(0.30, 0, 0)), float2(0.02, 0.30)), MOVE_X, MOVE_X), res);
    res = opU(float3(sdConeSection(translateForXAxis(pos, off, float3(0.65, 0, 0)), 0.05, 0.001, 0.05), MOVE_X, MOVE_X), res);

    res = opU(float3(sdCylinder(translateForZAxis(pos, off, float3(0, 0, 0.30)), float2(0.02, 0.30)), MOVE_Z, MOVE_Z), res);
    res = opU(float3(sdConeSection(translateForZAxis(pos, off, float3(0, 0, 0.65)), 0.05, 0.001, 0.05), MOVE_Z, MOVE_Z), res);

    return res;
}

float3 castRay(float3 ro, float3 rd, constant GIZMO3D *data)
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

            float3 res = map(ro+rd*t, data);
            if( t < precis || t>tmax ) break;
            t += res.x * 0.7;
            m = res.y;
            id = res.z;
        }

        if( t > tmax ) { m=-1.0; id=-1.0; }
    }
    return float3( t, m, id );
}

float3 castRayPoint(float3 ro, float3 rd, float3 off, constant GIZMO3D *data)
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

            float3 res = mapPoint(ro+rd*t, off, data);
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
float3 calcNormal(float3 pos, constant GIZMO3D *data){
    float3 eps = float3(.0001,0,0);
    float3 nor = float3(
        map(pos+eps.xyy, data).x - map(pos-eps.xyy, data).x,
        map(pos+eps.yxy, data).x - map(pos-eps.yxy, data).x,
        map(pos+eps.yyx, data).x - map(pos-eps.yyx, data).x
    );
    return normalize(nor);
}*/

float3 calcNormal(float3 pos, constant GIZMO3D *data)
{
    float2 e = float2(1.0,-1.0)*0.5773*0.0005;
    return normalize( e.xyy*map( pos + e.xyy, data ).x +
                      e.yyx*map( pos + e.yyx, data ).x +
                      e.yxy*map( pos + e.yxy, data ).x +
                      e.xxx*map( pos + e.xxx, data ).x );
}

float3 calcNormalPoint(float3 pos, float3 off, constant GIZMO3D *data){
    float3 eps = float3(.0001,0,0);
    float3 nor = float3(
        mapPoint(pos+eps.xyy, off, data).x - mapPoint(pos-eps.xyy, off, data).x,
        mapPoint(pos+eps.yxy, off, data).x - mapPoint(pos-eps.yxy, off, data).x,
        mapPoint(pos+eps.yyx, off, data).x - mapPoint(pos-eps.yyx, off, data).x
    );
    return normalize(nor);
}

float bbox(float3 C, float3 D, float3 P, float3 L, float3x3 F)
{
    float d = 1e5, l;
    
    C = (C-P) * F;    D *= F;
    float3 I = abs(C-.5); bool inside = max(I.x, max(I.y,I.z)) <= .5;
    if ( inside ) return 0.;
        
    #define test(i)                                                       \
    l =  D[i] > 0. ?  C[i] < 0. ? -C[i]   : C[i] < 1. ? 1.-C[i] : -1.     \
                   :  C[i] > 1. ? 1.-C[i] : C[i] > 0. ? -C[i]   :  1.;    \
    l /= D[i];                                                            \
    I = C+l*D;                                                            \
    if ( l > 0. && l < d                                                  \
         && I[(i+1)%3] >= 0. && I[(i+1)%3] <= 1.                          \
         && I[(i+2)%3] >= 0. && I[(i+2)%3] <= 1.                          \
       )  d = l

    test(0);
    test(1);
    test(2);
    return d==1e5 ? -1. : d;
}

kernel void cameraGizmoCombo3D(
                               constant GIZMO3D               *data        [[ buffer(1) ]],
                               device float4                  *out         [[ buffer(0) ]],
                               uint                            gid         [[thread_position_in_grid]])
{
    float2 size = data->size;
    float3 pos = data->position.xyz;
    float2 uv = float2( pos.x, pos.y ) / size;

    float3 origin = data->origin.xyz;
    float3 lookAt = data->lookAt.xyz;

    float ratio = size.x / size.y;
    float2 pixelSize = float2(1.0) / size.xy;

    // --- Camera

    const float fov = data->origin.w;
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
    dir += vertical * (pixelSize.y * rand.y + uv.y);
    
    dir = normalize(dir);

    out[gid] = float4(dir, 0);
}

kernel void idsGizmoCombo3D(
                            texture2d<half, access::write>  outTexture  [[texture(0)]],
                            constant GIZMO3D               *data        [[ buffer(1) ]],
                            uint2                           gid         [[thread_position_in_grid]])
{
    float2 size = data->size;
    float2 uv = float2( gid.x, gid.y ) / size;

    float3 origin = data->origin.xyz;
    float3 lookAt = data->lookAt.xyz;

    float ratio = size.x / size.y;
    float2 pixelSize = float2(1.0) / size.xy;

    // --- Camera

    const float fov = data->origin.w;
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
    dir += vertical * (pixelSize.y * rand.y + uv.y);
    
    dir = normalize(dir);

    float3 hit = castRay(origin, dir, data);

    outTexture.write(half(hit.y), gid);
}

kernel void idsGizmoCombo3DPoint(
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

    const float fov = data->origin.w;
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
    dir += vertical * (pixelSize.y * rand.y + uv.y);
    
    dir = normalize(dir);

    float3 hit = castRayPoint(origin, dir, pos, data);

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

    float4 finalColor = float4( 0 );

    float ratio = size.x / size.y;
    float2 pixelSize = float2(1.0) / size.xy;

    // --- Camera

    const float fov = data->origin.w;
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
    dir += vertical * (pixelSize.y * rand.y + uv.y);
    
    const float4 hoverColor = float4(0.263, 0.443, 0.482, 1.000);
    const float4 rotateColor = float4(0.996, 0.941, 0.208, 1.000);
    const float4 xAxisColor = float4(0.153, 0.192, 0.984, 1.000);
    const float4 yAxisColor = float4(0.882, 0.102, 0.153, 1.000);
    const float4 zAxisColor = float4(0.188, 0.933, 0.176, 1.000);
    
    dir = normalize(dir);
    
    float3 X0 = float3(1.5, 0,0), X1 = float3(0, 1.5, 0), X2 = float3(0, 0, 1.5);
    float d = bbox(origin, dir, data->position.xyz - float3(0.75), float3(length(X0), length(X1), length(X2)), float3x3( X0/dot(X0,X0), X1/dot(X1,X1), X2/dot(X2,X2) ) );
    
    if (d >= 0.0) {
        
        float3 hit = castRay(origin, dir, data);
        
        if (hit.y > -0.5) {
            if (hit.y == MOVE_X) {
                finalColor = hoverState == MOVE_X ? hoverColor : xAxisColor;
            } else
            if (hit.y == MOVE_Y) {
                finalColor =  hoverState == MOVE_Y ? hoverColor : yAxisColor;
            } else
            if (hit.y == MOVE_Z) {
                finalColor =  hoverState == MOVE_Z ? hoverColor : zAxisColor;
            } else
            if (hit.y == SCALE_X) {
                finalColor = hoverState == SCALE_X ? hoverColor : xAxisColor;
            } else
            if (hit.y == SCALE_Y) {
                finalColor =  hoverState == SCALE_Y ? hoverColor : yAxisColor;
            } else
            if (hit.y == SCALE_Z) {
                finalColor =  hoverState == SCALE_Z ? hoverColor : zAxisColor;
            }
            if (hit.y == ROTATE_X) {
                finalColor = hoverState == ROTATE_X ? hoverColor : rotateColor;
            } else
            if (hit.y == ROTATE_Y) {
                finalColor =  hoverState == ROTATE_Y ? hoverColor : rotateColor;
            } else
            if (hit.y == ROTATE_Z) {
                finalColor =  hoverState == ROTATE_Z ? hoverColor : rotateColor;
            }
            
            finalColor.r /= finalColor.a;
            finalColor.g /= finalColor.a;
            finalColor.b /= finalColor.a;
            
    //        float3 hitPoint = origin + hit.x * dir;
    //        float3 normal = calcNormal(hitPoint, data);
            
    //        finalColor.xyz += dot(float3(0, 1, 0), normal);
    //        finalColor.xyz += dot(float3(0, -1, 0), normal);
            
    //        finalColor.xyz = mix( float3(0), finalColor.xyz, dot(normalize(float3(0,-1,0)), normal));
        }
    }
    
    return finalColor;
}

// --- Point Gizmo
fragment float4 drawGizmoCombo3DPoint(RasterizerData        in [[stage_in]],
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

    const float fov = data->origin.w;
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
    dir += vertical * (pixelSize.y * rand.y + uv.y);
    
    const float4 hoverColor = float4(0.263, 0.443, 0.482, 1.000);
    const float4 xAxisColor = float4(0.153, 0.192, 0.984, 1.000);
    const float4 yAxisColor = float4(0.882, 0.102, 0.153, 1.000);
    const float4 zAxisColor = float4(0.188, 0.933, 0.176, 1.000);

    dir = normalize(dir);
    
    float3 X0 = float3(1.5, 0,0), X1 = float3(0, 1.5, 0), X2 = float3(0, 0, 1.5);
    float d = bbox(origin, dir, data->position.xyz - float3(0.75), float3(length(X0), length(X1), length(X2)), float3x3( X0/dot(X0,X0), X1/dot(X1,X1), X2/dot(X2,X2) ) );
    
    if (d >= 0.0) {
        float3 hit = castRayPoint(origin, dir, pos, data);
        
        if (hit.y == MOVE_X) {
            finalColor = hoverState == MOVE_X ? hoverColor : xAxisColor;
        } else
        if (hit.y == MOVE_Y) {
            finalColor =  hoverState == MOVE_Y ? hoverColor : yAxisColor;
        } else
        if (hit.y == MOVE_Z) {
            finalColor =  hoverState == MOVE_Z ? hoverColor : zAxisColor;
        }
        
        finalColor.r /= finalColor.a;
        finalColor.g /= finalColor.a;
        finalColor.b /= finalColor.a;
    }
    return finalColor;
}
