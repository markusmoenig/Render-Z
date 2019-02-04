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
        properties["scaleX"] = 0
        properties["scaleY"] = 0
    }
    
    func createDistanceCode( uvName: String, transProperties: [String:Float]? = nil ) -> String
    {
        var code = distanceCode
        let props = transProperties != nil ? transProperties : properties
        
        code = code.replacingOccurrences(of: "__uv__", with: String(uvName))
        
        for (name,value) in props! {
            code = code.replacingOccurrences(of: "__" + name + "__", with: String(value))
        }        
        return code
    }
    
    func getCurrentSize(_ transformed: [String:Float]) -> float2
    {
        var size : float2 =  float2()

        if transformed["radius"] != nil {
            size.x = transformed["radius"]! * 2
            size.y = size.x
        } else
        if transformed["width"] != nil && transformed["height"] != nil {
            size.x = transformed["width"]! * 2
            size.y = transformed["height"]! * 2
        }
        
        return size
    }
}
