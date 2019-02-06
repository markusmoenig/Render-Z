//
//  Shape.swift
//  Shape-Z
//
//  Created by Markus Moenig on 14/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class Shape : Codable
{
    var name            : String
    var properties      : [String: Float]
    var uuid            : UUID
    
    var globalCode      : String = ""
    var distanceCode    : String = ""
    
    var widthProperty   : String = ""
    var heightProperty  : String = ""
    
    var pointCount      : Int = 0

    var flatLayerIndex  : Int?

    private enum CodingKeys: String, CodingKey {
        case name
        case properties
        case uuid
        case globalCode
        case distanceCode
    }
    
    required init()
    {
        properties = [:]
        name = "Unnamed Shape"
     
        uuid = UUID()
        
        properties["posX"] = 0
        properties["posY"] = 0
        properties["rotate"] = 0
    }
    
    func createDistanceCode( uvName: String, transProperties: [String:Float]? = nil, layerIndex: Int? = nil ) -> String
    {
        var code = distanceCode
        let props = transProperties != nil ? transProperties : properties
        
        code = code.replacingOccurrences(of: "__uv__", with: String(uvName))
        
        for (name,value) in props! {
            if name == widthProperty && layerIndex != nil {
                code = code.replacingOccurrences(of: "__" + name + "__", with: "layerData->shape[\(layerIndex!)].size.x")
            } else
            if name == heightProperty && layerIndex != nil {
                code = code.replacingOccurrences(of: "__" + name + "__", with: "layerData->shape[\(layerIndex!)].size.y")
            } else
            if name.starts(with: "point_") && layerIndex != nil {
                let index = name.index(name.startIndex, offsetBy: 6)
                let coord = name.index(name.endIndex, offsetBy: -1)
                
                if name[index] == "0" && pointCount > 0 {
                    code = code.replacingOccurrences(of: "__" + name + "__", with: "layerData->shape[\(layerIndex!)].point0.\(name[coord])")
                } else
                if name[index] == "1" && pointCount > 1 {
                    code = code.replacingOccurrences(of: "__" + name + "__", with: "layerData->shape[\(layerIndex!)].point1.\(name[coord])")
                } else
                if name[index] == "2" && pointCount > 2 {
                    code = code.replacingOccurrences(of: "__" + name + "__", with: "layerData->shape[\(layerIndex!)].point3.\(name[coord])")
                }
            } else {
                code = code.replacingOccurrences(of: "__" + name + "__", with: String(value))
            }
        }
        
        return code
    }
    
    func getCurrentSize(_ transformed: [String:Float]) -> float2
    {
        var size : float2 =  float2()

        size.x = transformed[widthProperty]! * 2
        size.y = transformed[heightProperty]! * 2
        
        return size
    }
}
