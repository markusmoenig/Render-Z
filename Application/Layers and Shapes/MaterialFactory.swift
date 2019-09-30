//
//  ShapeFactory.swift
//  Shape-Z
//
//  Created by Markus Moenig on 16/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

struct MaterialDefinition
{
    var name            : String = ""
    var code            : String = ""
    var globalCode      : String = ""
    var properties      : [String:Float] = [:]
    var widthProperty   : String = ""
    var heightProperty  : String = ""
    
    var pointCount      : Int = 0
    var isCompound      : Bool = false
}

class MaterialFactory
{
    var materials       : [MaterialDefinition]

    init()
    {
        materials = []

        let defaultSize : Float = 40
        var def : MaterialDefinition = MaterialDefinition()
        
        // --- Static
        def.name = "Static"
        def.code = "__value__"
        def.properties["value_x"] = 0.3
        def.properties["value_y"] = 0.3
        def.properties["value_z"] = 0.3
        def.properties["value_w"] = 1

        def.properties["width"] = defaultSize
        def.properties["height"] = defaultSize
        def.widthProperty = "width"
        def.heightProperty = "height"
        materials.append( def )
        
        // --- Gradient
        def = MaterialDefinition()
        def.name = "Gradient"
        def.code = "gradientMaterial(__uv__, __point_0__, __point_1__, __pointvalue_0__, __pointvalue_1__)"
        def.globalCode =
        """
        float4 gradientMaterial( float2 uv, float2 p1, float2 p2, float4 v1, float4 v2) {
            float s = clamp(dot(uv-p1,p2-p1)/dot(p2-p1,p2-p1),0.,1.);
            return mix(v1, v2, s);
        }

        """
        def.properties["point_0_x"] = -35
        def.properties["point_0_y"] = -35
        def.properties["point_1_x"] = 35
        def.properties["point_1_y"] = 35
        
        def.properties["pointvalue_0_x"] = 0
        def.properties["pointvalue_0_y"] = 0
        def.properties["pointvalue_0_z"] = 0
        def.properties["pointvalue_0_w"] = 1
        
        def.properties["pointvalue_1_x"] = 1
        def.properties["pointvalue_1_y"] = 1
        def.properties["pointvalue_1_z"] = 1
        def.properties["pointvalue_1_w"] = 1

        def.properties["width"] = defaultSize
        def.properties["height"] = defaultSize

        def.widthProperty = "width"
        def.heightProperty = "height"
        def.pointCount = 2
        materials.append( def )
        
        // --- Distance
        def = MaterialDefinition()
        def.name = "Distance"
        def.globalCode =
        """
        float4 distanceMaterial( float2 uv, float4 value, float2 size, float dist) {
            //float alpha = mix( 0, 1, abs(dist) / size.x);
            //float alpha = mix( 0, 1, smoothstep( 0, 1, -dist / size.x ) );
            //value = mix( pt1->y, pt2->y, smoothstep(0, 1, dist / (pt2->x - pt1->x) ) );

            dist = abs(dist);
        /*
        float x = dist;// - pt1->x;
        float r = (pt2->x - pt1->x);
        float center = (pt2->x + pt1->x);
        float xM = x - center;
        value = mix( pt1->y, pt2->y, clamp( dist / (pt2->x - pt1->x), 0, 1 ) ) + sqrt( r * r - xM * xM );*/
        
            float sized = size.x * 25;
            dist = min(dist, sized);
        
            float x = dist;// - pt1->x;
            float r = sized;//(pt2->x - pt1->x);
            float center = sized;//size.x / 2;//(pt2->x + pt1->x);
            float xM = x - center;
            float alpha = (sqrt( r * r - xM * xM )) / (sized/4);
        
            return float4( value.xyz, alpha);//clamp(alpha, 0, 1) );
        }
        """
        def.code = "distanceMaterial(__uv__, __value__, __size__, __distance__)"
        def.properties["value_x"] = 1
        def.properties["value_y"] = 1
        def.properties["value_z"] = 1
        def.properties["value_w"] = 1
        
        def.properties["size"] = defaultSize
        def.properties["size"] = defaultSize
        def.widthProperty = "size"
        def.heightProperty = "size"
        materials.append( def )
        
        // --- Checker
        def = MaterialDefinition()
        def.name = "Checker"
        def.globalCode =
        """
        float4 checkerMaterial( float2 uv, float4 value, float2 size) {
            float2 q = floor(uv/size);
            float4 col = mix( float4(0), value, abs(fmod(q.x+q.y, 2.0)) );
            return col;
        }
        """
        def.code = "checkerMaterial(__uv__, __value__, __size__)"
        def.properties["value_x"] = 0.3
        def.properties["value_y"] = 0.3
        def.properties["value_z"] = 0.3
        def.properties["value_w"] = 1
        
        def.properties["size"] = defaultSize / 2
        def.properties["size"] = defaultSize / 2
        def.widthProperty = "size"
        def.heightProperty = "size"
        materials.append( def )
        
        // --- Hex
        def = MaterialDefinition()
        def.name = "Hex"
        def.globalCode =
        """
        
        // { 2d cell id, distance to border, distnace to center )
        float4 hexPatternMaterial( float2 p )
        {
            float2 q = float2( p.x*2.0*0.5773503, p.y + p.x*0.5773503 );
            
            float2 pi = floor(q);
            float2 pf = fract(q);

            float v = fmod(pi.x + pi.y, 3.0);

            float ca = step(1.0,v);
            float cb = step(2.0,v);
            float2  ma = step(pf.xy,pf.yx);
            
            // distance to borders
            float e = dot( ma, 1.0-pf.yx + ca*(pf.x+pf.y-1.0) + cb*(pf.yx-2.0*pf.xy) );

            // distance to center
            p = float2( q.x + floor(0.5+p.y/1.5), 4.0*p.y/3.0 )*0.5 + 0.5;
            float f = length( (fract(p) - 0.5)*float2(1.0,0.85) );
            
            return float4( pi + ca - cb*ma, e, f );
        }
        
        float4 hexMaterial( float2 uv, float4 value, float2 size, float s) {
            uv = abs(uv / size.x);
        
            /*
            // Tiling
        
            float2 d = float2(1.0, sqrt(3.0));
            float2 h = 0.5*d;
            float2 a = fmod(uv, d) - h;
            float2 b = fmod(uv + h, d) - h;
            float2 p = dot(a, a) < dot(b, b)? a: b;
        
            //tile_id = p - uv;
            s /= 2;
        
            p = abs(p);
        
            float shape = smoothstep(p.x, p.x+0.01, s);
            float hd = dot(p, normalize(float2(1.0, 1.73)));
            shape *= smoothstep(hd, hd+0.01, s);
                
            return mix( float4(0), value, shape );
            */
        
            float4 rc = hexPatternMaterial(uv);
        
            s = 1.0 - s;
            return mix( float4(0), value, smoothstep( s, s + 0.01, rc.z ) );
        }
        """
        def.code = "hexMaterial(__uv__, __value__, __size__,__custom_gap__)"
        def.properties["value_x"] = 0.3
        def.properties["value_y"] = 0.3
        def.properties["value_z"] = 0.3
        def.properties["value_w"] = 1
        
        def.properties["custom_gap"] = 0.9
        def.properties["gap_min"] = 0
        def.properties["gap_max"] = 1
        def.properties["gap_int"] = 0
        
        def.properties["size"] = defaultSize / 2
        def.properties["size"] = defaultSize / 2
        def.widthProperty = "size"
        def.heightProperty = "size"
        materials.append( def )
        
        // --- Bricks
        def = MaterialDefinition()
        def.name = "Bricks"
        def.globalCode =
        """
        float4 bricksMaterial( float2 uv, float4 value, float2 size, float2 screenSize, float bevel, float gap, float rounding) {
            float CELL = round(size.y);//20;
            float RATIO = round(size.x); //3
        
            float2 U = uv / screenSize;

            float2 BEVEL = bevel;
            float2 GAP  = gap;//float2(.5)/8.;
            float ROUND  = rounding;//float2(.5)/8.;

            float2 W = float2(RATIO,1);
            U *= CELL/W;

            U.x += .5* fmod(floor(U.y),2.);

            float2 S = W* (fract(U) - 1./2.);
        
            float2 A = W/2.-GAP - abs(S);
            float2 B = A * 2. / BEVEL;
            float m = min(B.x,B.y);
            if (A.x<ROUND && A.y<ROUND)
                m = (ROUND-length(ROUND-A)) *2./dot(BEVEL,normalize(ROUND-A));
        
            float alpha = clamp( m ,0.,1.);
            return float4( value.xyz, alpha);
        }
        """
        def.code = "bricksMaterial(__uv__, __value__, __size__, __screenSize__, __custom_bevel__,__custom_gap__,__custom_round__)"
        def.properties["value_x"] = 0.3
        def.properties["value_y"] = 0.3
        def.properties["value_z"] = 0.3
        def.properties["value_w"] = 1
        
        def.properties["custom_bevel"] = 0.2
        def.properties["bevel_min"] = 0
        def.properties["bevel_max"] = 1
        def.properties["bevel_int"] = 0
        
        def.properties["custom_gap"] = 0.1
        def.properties["gap_min"] = 0
        def.properties["gap_max"] = 1
        def.properties["gap_int"] = 0
        
        def.properties["custom_round"] = 0.1
        def.properties["round_min"] = 0
        def.properties["round_max"] = 1
        def.properties["round_int"] = 0
        
        def.properties["ratio"] = 2
        def.properties["scale"] = 40
        def.widthProperty = "ratio"
        def.heightProperty = "scale"
        materials.append( def )
        
        // --- Polar Bricks
        def = MaterialDefinition()
        def.name = "C. Bricks"
        def.globalCode =
        """
        float4 polarBricksMaterial( float2 uv, float4 value, float2 size, float2 screenSize, float bevel, float gap, float rounding, float center) {
            float CELL = round(size.y);//20;
            float RATIO = round(size.x); //3
            float2  CYCLE = float2( round(CELL / RATIO), CELL );
        
            float HOLLOW = center;
        
            float2 U = uv / screenSize.y;
        
            float l = length(U)*CELL, a = atan2(U.y,U.x), k;
            U = float2( a*(floor(l)+.5), l );             // polar bands
            if (U.y<HOLLOW) gap = 1.;                 // empty center
            k = 6.28*(floor(l)+.5)/RATIO;
            U.x *= (floor(k)) / k;    // integer #cells

            float2 BEVEL = bevel;
            float2 GAP  = float2(gap);//float2(.5)/8.;
            float ROUND  = rounding;//float2(.5)/8.;
        
            float2 W = float2(RATIO,1);
            U /= W;
        
            U.x += .5* fmod(floor(U.y),2.);
        
            float2 S = W* (fract(U) - 1./2.);
        
            float2 A = W/2.-GAP - abs(S);
            float2 B = A * 2. / BEVEL;
            float m = min(B.x,B.y);
            if (A.x<ROUND && A.y<ROUND)
            m = (ROUND-length(ROUND-A)) *2./dot(BEVEL,normalize(ROUND-A));
        
            float alpha = clamp( gap == 0. ? 0 : m,0.,1.);
            return float4( value.xyz, alpha);
        }
        """
        def.code = "polarBricksMaterial(__uv__, __value__, __size__, __screenSize__, __custom_bevel__,__custom_gap__,__custom_round__, __custom_center__)"
        def.properties["value_x"] = 0.3
        def.properties["value_y"] = 0.3
        def.properties["value_z"] = 0.3
        def.properties["value_w"] = 1
        
        def.properties["custom_bevel"] = 0.2
        def.properties["bevel_min"] = 0
        def.properties["bevel_max"] = 1
        def.properties["bevel_int"] = 0
        
        def.properties["custom_gap"] = 0.1
        def.properties["gap_min"] = 0
        def.properties["gap_max"] = 1
        def.properties["gap_int"] = 0
        
        def.properties["custom_round"] = 0.1
        def.properties["round_min"] = 0
        def.properties["round_max"] = 1
        def.properties["round_int"] = 0
        
        def.properties["custom_center"] = 1
        def.properties["center_min"] = 1
        def.properties["center_max"] = 10
        def.properties["center_int"] = 1
        
        def.properties["ratio"] = 2
        def.properties["scale"] = 40
        def.widthProperty = "ratio"
        def.heightProperty = "scale"
        materials.append( def )
        
        // --- Value Noise
        def = MaterialDefinition()
        def.name = "Noise #1"
        def.globalCode =
        """
        float4 valueNoiseMaterial( float2 x, float4 value, float2 size, float2 screenSize, int smoothing)
        {
            x /= size;
            float noise = valueNoise2DFBM(x, smoothing);
            return float4(value.xyz, noise);
        }
        """
        def.code = "valueNoiseMaterial(__uv__, __value__, __size__,__screenSize__,__custom_smoothing__)"
        def.properties["value_x"] = 1
        def.properties["value_y"] = 1
        def.properties["value_z"] = 1
        def.properties["value_w"] = 1
        
        def.properties["custom_smoothing"] = 5
        def.properties["smoothing_min"] = 1
        def.properties["smoothing_max"] = 10
        def.properties["smoothing_int"] = 1
        
        def.properties["size"] = defaultSize / 4
        def.properties["size"] = defaultSize / 4
        def.widthProperty = "size"
        def.heightProperty = "size"
        materials.append( def )
        
        // --- Wood
        def = MaterialDefinition()
        def.name = "Wood"
        def.globalCode =
        """
        float woodMaterial_repramp(float x) {
            return pow(sin(x)*0.5+0.5, 8.0) + cos(x)*0.7 + 0.7;
        }
        float4 woodMaterial( float2 uv, float4 value, float2 size) {

            uv /= size;
        
            float rings = woodMaterial_repramp(length(uv + float2(valueNoise2DFBM(uv*float2(8.0, 1.5)), valueNoise2DFBM(-uv*float2(8.0, 1.5)+4.5678))*0.05)*64.0) / 1.8;
        
            rings -= valueNoise2DFBM(uv *1.0)*0.75;
        
            //float3 texColor = mix(value0.xyz, value1.xyz, rings);//*1.5;
            //texColor = max(float3(0.0), texColor);
            float rough = (valueNoise2DFBM(uv*64.0*float2(1.0, 0.2))*0.1+0.9);
            //texColor *= rough;

            return float4( value.xyz, rings * rough);
        }
        """
        def.code = "woodMaterial(__uv__, __value__, __size__)"
        
        def.properties["value_x"] = 1
        def.properties["value_y"] = 1
        def.properties["value_z"] = 1
        def.properties["value_w"] = 1
        
        def.properties["scaleX"] = defaultSize * 2
        def.properties["scaleY"] = defaultSize * 2
        def.widthProperty = "scaleX"
        def.heightProperty = "scaleY"
        materials.append( def )
        
        // --- Grid
        def = MaterialDefinition()
        def.name = "Grid"
        def.globalCode =
        """
        float4 gridMaterial( float2 uv, float4 value, float2 size, float2 screenSize, float thickness) {
            float2 vPixelsPerGridSquare = size;
            float2 vScreenPixelCoordinate = uv;
            float2 vGridSquareCoords = fract(vScreenPixelCoordinate / vPixelsPerGridSquare);
            float2 vGridSquarePixelCoords = vGridSquareCoords * vPixelsPerGridSquare;
            float2 vIsGridLine = step(vGridSquarePixelCoords, float2(1.0) * thickness);
            
            float fIsGridLine = max(vIsGridLine.x, vIsGridLine.y);
            return mix( float4(0), value, fIsGridLine);
        }
        """
        def.code = "gridMaterial(__uv__, __value__, __size__,__screenSize__,__custom_thickness__)"
        def.properties["value_x"] = 0.3
        def.properties["value_y"] = 0.3
        def.properties["value_z"] = 0.3
        def.properties["value_w"] = 1
        
        def.properties["custom_thickness"] = 2
        def.properties["thickness_min"] = 1
        def.properties["thickness_max"] = 40
        def.properties["thickness_int"] = 0
        
        def.properties["width"] = defaultSize
        def.properties["height"] = defaultSize
        def.widthProperty = "width"
        def.heightProperty = "height"
        materials.append( def )
        
        // --- Stars
        def = MaterialDefinition()
        def.name = "Stars #1"
        def.globalCode =
        """
        
        float starsMaterialRandom(float2 par) {
            return fract(sin(dot(par.xy,float2(12.9898,78.233))) * 43758.5453);
        }
        
        float2 starsMaterialRandom2(float2 par) {
            float rand = starsMaterialRandom(par);
            return float2(rand, starsMaterialRandom(par+rand));
        }
        
        float4 starsMaterial( float2 uv, float4 value, float2 iResolution, float time, float speed, float rotationSpeed) {
        
            //The ratio of the width and height of the screen
            //float widthHeightRatio = iResolution.x/iResolution.y;
        
            float t = time * speed;
            float dist = 0.0;
            float layers = 16.0;
            float scale = 32.0;
            float depth;
            float size;
            float rotationAngle = time * rotationSpeed;
        
            float2 offset;
            float2 local_uv;
            float2 index;
            float2 pos;
            float2 seed;
            float2 centre = float2(0.5, 0.5);
            float2 uvCopy = uv;
        
            float2x2 rotation = float2x2(cos(rotationAngle), -sin(rotationAngle), sin(rotationAngle),  cos(rotationAngle));
        
            for(float i = 0.0; i < layers; i++){
                depth = fract(i/layers + t);
        
                //Move centre in a circle depending on the depth of the layer
                centre.x = 0.5 + 0.1 * cos(t) * depth;
                centre.y = 0.5 + 0.1 * sin(t) * depth;
        
                //Get uv from the fragment coordinates, rotation and depth
                uv = centre - uvCopy;//fragCoord/iResolution;
                //uv.y /= widthHeightRatio;
                uv *= rotation;
                uv *= mix(iResolution/100, 0.0, depth);
        
                //The local cell
                index = floor(uv);
        
                //Local cell seed;
                seed = 20.0 * i + index;
        
                //The local cell coordinates
                local_uv = fract(i + uv) - 0.5;
        
                //Get a random position for the local cell
                pos = 0.8 * (starsMaterialRandom2(seed) - 0.5);
        
                //Get a random size
                size = 0.01 + 0.02*starsMaterialRandom(seed);
        
                //Get distance to the generated point, add fading to distant points
                //Add the distance to the sum
                dist += smoothstep(size, 0.0, length(local_uv-pos)) * min(1.0, depth*2.0);
            }
        
            return float4(value.xyz,dist);
        }
        """
        def.code = "starsMaterial(__uv__, __value__, __size__, __time__, __custom_speed__,__custom_rotation__)"
        def.properties["value_x"] = 1
        def.properties["value_y"] = 1
        def.properties["value_z"] = 1
        def.properties["value_w"] = 1
        
        def.properties["custom_speed"] = 0.1
        def.properties["speed_min"] = 0
        def.properties["speed_max"] = 1
        def.properties["speed_int"] = 0
        
        def.properties["custom_rotation"] = 0.2
        def.properties["rotation_min"] = -2
        def.properties["rotation_max"] = 2
        def.properties["rotation_int"] = 0
        
        def.properties["size"] = defaultSize / 2
        def.properties["size"] = defaultSize / 2
        def.widthProperty = "size"
        def.heightProperty = "size"
        materials.append( def )
        
        // --- Compounds
        
        // --- Aluminium
        def = MaterialDefinition()
        def.name = "Alu"
        def.globalCode =
        """
        void aluminiumMaterial( float2 uv, float4 value, thread MATERIAL_DATA *material, float blend) {
            material->baseColor = mix(material->baseColor, value, blend);
            material->metallic = mix(material->metallic, 1., blend);
            material->roughness = mix(material->roughness, 0.53, blend);
            material->specular = mix(material->specular, 0.3, blend);
        }
        """
        def.code = "aluminiumMaterial(__uv__, __value__, __material__,__componentBlend__)"
        def.properties["value_x"] = 0.91
        def.properties["value_y"] = 0.92
        def.properties["value_z"] = 0.92
        def.properties["value_w"] = 1
        
        def.properties["width"] = defaultSize
        def.properties["height"] = defaultSize
        def.widthProperty = "width"
        def.heightProperty = "height"
        def.isCompound = true
        materials.append( def )
        
        // --- Gold
        def = MaterialDefinition()
        def.name = "Gold"
        def.globalCode =
        """
        void goldMaterial( float2 uv, float4 value, thread MATERIAL_DATA *material, float blend) {
            material->baseColor = mix(material->baseColor, value, blend);
            material->metallic = mix(material->metallic, 1., blend);
            material->roughness = mix(material->roughness, 0.53, blend);
            material->specular = mix(material->specular, 0.3, blend);
        }
        """
        def.code = "goldMaterial(__uv__, __value__, __material__,__componentBlend__)"
        def.properties["value_x"] = 1.0
        def.properties["value_y"] = 0.71
        def.properties["value_z"] = 0.29
        def.properties["value_w"] = 1
        
        def.properties["width"] = defaultSize
        def.properties["height"] = defaultSize
        def.widthProperty = "width"
        def.heightProperty = "height"
        def.isCompound = true
        materials.append( def )
        
        // --- Iron
        def = MaterialDefinition()
        def.name = "Iron"
        def.globalCode =
        """
        void ironMaterial( float2 uv, float4 value, thread MATERIAL_DATA *material, float blend) {
            material->baseColor = mix(material->baseColor, value, blend);
            material->metallic = mix(material->metallic, 1., blend);
            material->roughness = mix(material->roughness, 0.53, blend);
            material->specular = mix(material->specular, 0.3, blend);
        }
        """
        def.code = "ironMaterial(__uv__, __value__, __material__,__componentBlend__)"
        def.properties["value_x"] = 0.56
        def.properties["value_y"] = 0.57
        def.properties["value_z"] = 0.58
        def.properties["value_w"] = 1
        
        def.properties["width"] = defaultSize
        def.properties["height"] = defaultSize
        def.widthProperty = "width"
        def.heightProperty = "height"
        def.isCompound = true
        materials.append( def )
        
        // --- Silver
        def = MaterialDefinition()
        def.name = "Silver"
        def.globalCode =
        """
        void silverMaterial( float2 uv, float4 value, thread MATERIAL_DATA *material, float blend) {
            material->baseColor = mix(material->baseColor, value, blend);
            material->metallic = mix(material->metallic, 1., blend);
            material->roughness = mix(material->roughness, 0.53, blend);
            material->specular = mix(material->specular, 0.3, blend);
        }
        """
        def.code = "silverMaterial(__uv__, __value__, __material__,__componentBlend__)"
        def.properties["value_x"] = 0.91
        def.properties["value_y"] = 0.92
        def.properties["value_z"] = 0.92
        def.properties["value_w"] = 1
        
        def.properties["width"] = defaultSize
        def.properties["height"] = defaultSize
        def.widthProperty = "width"
        def.heightProperty = "height"
        def.isCompound = true
        materials.append( def )
    }
    
    /// Create a shape
    func createMaterial(_ name: String, size: Float = 20) -> Material
    {
        let material = Material()
        var materialDef : MaterialDefinition? = nil
        
        for mat in materials {
            if mat.name == name {
                materialDef = mat
                break
            }
        }
        
        if let def = materialDef {
            material.name = def.name
            material.code = def.code
            material.globalCode = def.globalCode
            material.properties = material.properties.merging(def.properties) { (current, _) in current }
            material.widthProperty = def.widthProperty
            material.heightProperty = def.heightProperty
            material.pointCount = def.pointCount
            material.isCompound = def.isCompound
        }
        
        return material
    }
}
