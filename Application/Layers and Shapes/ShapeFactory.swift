//
//  ShapeFactory.swift
//  Shape-Z
//
//  Created by Markus Moenig on 16/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

struct ShapeDefinition
{
    var name            : String = ""
    var distanceCode    : String = ""
    var globalCode      : String = ""
    var properties      : [String:Float] = [:]
    var widthProperty   : String = ""
    var heightProperty  : String = ""
    var pointCount      : Int = 0
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
        def.widthProperty = "width"
        def.heightProperty = "height"
        shapes.append( def )
        
        // --- Disk
        def = ShapeDefinition()
        def.name = "Disk"
        def.distanceCode = "length(__uv__) - __radius__"
        def.properties["radius"] = defaultSize
        def.widthProperty = "radius"
        def.heightProperty = "radius"
        shapes.append( def )
        
        // --- Line
        def = ShapeDefinition()
        def.name = "Line"
        def.distanceCode = "sdLine(__uv__, float2(__point_0_x__,__point_0_y__), float2(__point_1_x__,__point_1_y__), __lineWidth__, 20)"
        def.globalCode =
        """
            float sdLine(float2 uv, float2 pA, float2 pB, float2 thick, float rounded) {
                rounded = min(thick.y, rounded);
                float2 mid = (pB + pA) * 0.5;
                float2 delta = pB - pA;
                float lenD = length(delta);
                float2 unit = delta / lenD;
                if (lenD < 0.0001) unit = float2(1.0, 0.0);
                float2 perp = unit.yx * float2(-1.0, 1.0);
                float dpx = dot(unit, uv - mid);
                float dpy = dot(perp, uv - mid);
                float disty = abs(dpy) - thick.y + rounded;
                float distx = abs(dpx) - lenD * 0.5 - thick.x + rounded;
        
                float dist = length(float2(max(0.0, distx), max(0.0,disty))) - rounded;
                dist = min(dist, max(distx, disty));
        
                return dist;
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
            shape.widthProperty = def.widthProperty
            shape.heightProperty = def.heightProperty
            shape.pointCount = def.pointCount

            for (name,_) in shape.properties {
                if name == "radius" || name == "width" || name == "height"  {
                    shape.properties[name] = size
                }
            }
        }
        
        return shape
    }
}
