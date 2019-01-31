//
//  ShapeFactory.swift
//  Shape-Z
//
//  Created by Markus Moenig on 16/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Foundation

struct ShapeDefinition
{
    var name            : String = ""
    var distanceCode    : String = ""
    var globalCode      : String = ""
    var properties      : [String:Float] = [:]
}

class ShapeFactory
{
    var shapes          : [ShapeDefinition]

    init()
    {
        shapes = []
        
        let defaultSize : Float = 20
        var def : ShapeDefinition = ShapeDefinition()
        
        
        // --- Box
        def.name = "Box"
        def.distanceCode = "sdBox(__uv__, float2(__width__,__height__) )"
        def.globalCode =
        """
        float sdBox( float2 p, float2 b )
        {
            float2 d = abs(p)-b;
            return length(max(d,float2(0))) + min(max(d.x,d.y),0.0);
        }
        """
        def.properties["width"] = defaultSize
        def.properties["height"] = defaultSize
        shapes.append( def )
        
        // --- Disk
        def = ShapeDefinition()
        def.name = "Disk"
        def.distanceCode = "length(__uv__) - __radius__"
        def.properties["radius"] = defaultSize
        shapes.append( def )
    }
    
    func createShape(_ name: String, size: Float = 20) -> Shape
    {
        let shape = Shape()
        
        var shapeDef : ShapeDefinition?
        
        for sh in shapes {
            if sh.name == name {
                shapeDef = sh
                break
            }
        }
        
        if let def = shapeDef {
            shape.name = def.name
            shape.distanceCode = def.distanceCode
            shape.globalCode = def.globalCode
            shape.properties = shape.properties.merging(def.properties) { (current, _) in current }
            
            for (name,_) in shape.properties {
                if name == "radius" || name == "width" || name == "height"  {
                    shape.properties[name] = size
                }
            }
        }
        
        return shape
    }
}
