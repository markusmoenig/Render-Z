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
        
        // --- Grid
        def = MaterialDefinition()
        def.name = "Grid"
        def.globalCode =
        """
        float4 gridMaterial( float2 uv, float4 value, float2 size) {
            float2 vPixelsPerGridSquare = size;
            float2 vScreenPixelCoordinate = uv;
            float2 vGridSquareCoords = fract(vScreenPixelCoordinate / vPixelsPerGridSquare);
            float2 vGridSquarePixelCoords = vGridSquareCoords * vPixelsPerGridSquare;
            float2 vIsGridLine = step(vGridSquarePixelCoords, float2(1.0));
        
            float fIsGridLine = max(vIsGridLine.x, vIsGridLine.y);
            return mix( float4(0), value, fIsGridLine);
        }
        """
        def.code = "gridMaterial(__uv__, __value__, __size__)"
        def.properties["value_x"] = 0.3
        def.properties["value_y"] = 0.3
        def.properties["value_z"] = 0.3
        def.properties["value_w"] = 1
        
        def.properties["width"] = defaultSize
        def.properties["height"] = defaultSize
        def.widthProperty = "width"
        def.heightProperty = "height"
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
        
        // --- Checker
        def = MaterialDefinition()
        def.name = "Stars"
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
        void aluminiumMaterial( float2 uv, float4 value, thread MATERIAL_DATA *material) {
        material->baseColor = value;
        material->metallic = 1.;
        material->roughness = 0.53;
        material->specular = 0.3;
        }
        """
        def.code = "aluminiumMaterial(__uv__, __value__, __material__)"
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
        void goldMaterial( float2 uv, float4 value, thread MATERIAL_DATA *material) {
            material->baseColor = value;
            material->metallic = 1.;
            material->roughness = 0.53;
            material->specular = 0.3;
        }
        """
        def.code = "goldMaterial(__uv__, __value__, __material__)"
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
        void ironMaterial( float2 uv, float4 value, thread MATERIAL_DATA *material) {
            material->baseColor = value;
            material->metallic = 1.;
            material->roughness = 0.53;
            material->specular = 0.3;
        }
        """
        def.code = "ironMaterial(__uv__, __value__, __material__)"
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
        void silverMaterial( float2 uv, float4 value, thread MATERIAL_DATA *material) {
            material->baseColor = value;
            material->metallic = 1.;
            material->roughness = 0.53;
            material->specular = 0.3;
        }
        """
        def.code = "silverMaterial(__uv__, __value__, __material__)"
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
