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
    var isDecorator     : Bool = false
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
        float4 gridMaterial( float2 uv, float4 value) {
            float2 vPixelsPerGridSquare = float2(20.0, 20.0);
            float2 vScreenPixelCoordinate = uv;
            float2 vGridSquareCoords = fract(vScreenPixelCoordinate / vPixelsPerGridSquare);
            float2 vGridSquarePixelCoords = vGridSquareCoords * vPixelsPerGridSquare;
            float2 vIsGridLine = step(vGridSquarePixelCoords, float2(1.0));
        
            float fIsGridLine = max(vIsGridLine.x, vIsGridLine.y);
            return mix( float4(0), value, fIsGridLine);
        }
        """
        def.code = "gridMaterial(__uv__, __value__)"
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
        float4 checkerMaterial( float2 uv, float4 value) {
            float2 q = floor(uv/20.);
            float4 col = mix( float4(0), value, abs(fmod(q.x+q.y, 2.0)) );
            return col;
        }
        """
        def.code = "checkerMaterial(__uv__, __value__)"
        def.properties["value_x"] = 0.3
        def.properties["value_y"] = 0.3
        def.properties["value_z"] = 0.3
        def.properties["value_w"] = 1
        
        def.properties["width"] = defaultSize
        def.properties["height"] = defaultSize
        def.widthProperty = "width"
        def.heightProperty = "height"
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
            material.isDecorator = def.isDecorator
        }
        
        return material
    }
}
