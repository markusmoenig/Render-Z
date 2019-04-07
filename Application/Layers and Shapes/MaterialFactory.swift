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

        let defaultSize : Float = 20
        var def : MaterialDefinition = MaterialDefinition()
        
        // --- Static
        def.name = "Static"
        def.code = "staticMaterial(__uv__, __material__)"
        def.globalCode =
        """
        void staticMaterial( float2 p, thread MATERIAL_DATA *material )
        {
            material->baseColor = float4(1);
        }
        """
        def.properties["width"] = defaultSize
        def.properties["height"] = defaultSize
        def.widthProperty = "width"
        def.heightProperty = "height"
        materials.append( def )
        
        /*
        // --- Line
        def = MaterialDefinition()
        def.name = "Gradient"
        def.code = "sdLine(__uv__, float2(__point_0_x__,__point_0_y__), float2(__point_1_x__,__point_1_y__), __lineWidth__)"
        def.globalCode =
        """
        float sdLine( float2 uv, float2 pa, float2 pb, float r) {
            float2 o = uv-pa;
            float2 l = pb-pa;
            float h = clamp( dot(o,l)/dot(l,l), 0.0, 1.0 );
            return -(r-distance(o,l*h));
        }

        """
        def.properties["lineWidth"] = 5
        def.properties["point_0_x"] = -35
        def.properties["point_0_y"] = -35
        def.properties["point_1_x"] = 35
        def.properties["point_1_y"] = 35
        def.widthProperty = "lineWidth"
        def.heightProperty = "lineWidth"
        def.pointCount = 2
        materials.append( def )
        */
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
            material.properties = def.properties.merging(def.properties) { (current, _) in current }
            material.widthProperty = def.widthProperty
            material.heightProperty = def.heightProperty
            material.pointCount = def.pointCount
            material.isDecorator = def.isDecorator

            /*
            for (name,_) in shape.properties {
                if (name == "radius" || name == "width" || name == "height") && shape.name != "Ellipse" && shape.name != "Cross" {
                    shape.properties[name] = size
                }
            }*/
        }
        
        return material
    }
}
